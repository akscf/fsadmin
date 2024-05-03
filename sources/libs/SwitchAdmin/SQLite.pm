# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::SQLite;

use DBI;
use Wstk::WstkException;

sub new ($$;$) {
    my ($class, $pmod, $db_name) = @_;
    my $self = {
        logger          => Log::Log4perl::get_logger(__PACKAGE__),
        class_name      => $class,
        fsadmin         => $pmod,
        dsn				=> undef,
        dump_query		=> 0,
        connections		=> 0,
        db_name			=> $db_name,
        db_path			=> $pmod->{'wstk'}->get_path('var').'/'.$db_name
    };
    bless( $self, $class );
    unless($self->{'db_name'}) {
    	die Wstk::WstkException->new("database not defined");
    }
    $self->{'dsn'} = "DBI:SQLite:dbname=".$self->{'db_path'};   
    #
    return $self;
}

sub get_class_name {
    my ($self) = @_;
    return $self->{class_name};
}

# ----------------------------------------------------------------------------------------
sub db_open {		
	my ($self) = @_;

	my $dbh = DBI->connect($self->{dsn}, undef, undef, { AutoCommit => 1, RaiseError => 1, PrintError => 1});
	if($dbh) {
		$dbh->sqlite_busy_timeout(10000);
	}
	$self->{connections} = ($self->{connections} + 1);
	
	return $dbh;
}

sub db_close {
	my ($self, $dbh) = @_;	
	
	if($dbh) {
		$dbh->disconnect();
		$self->{connections} = ($self->{connections} - 1);
	}
	return 1;
}

sub clean {
	my($self, $obj, $resource_only) = @_;	
	return 0 unless($obj);
	if($obj->{sth}) {
		$obj->{sth}->finish();
	}
	unless($resource_only) {
		db_close($self, $obj->{dbh});
	}
}

sub do_query {
  my($self, $dbh, $qtxt, $qpar) = @_;
	return undef unless($qtxt);
	#
	unless($dbh) {
		$dbh = db_open($self);
		unless($dbh) {
			die WstkException->new("FAIL: [".$qtxt."], cause: couldn't open db");
		}
	}
	my $sth = $dbh->prepare($qtxt);
	if($qpar) {
		my $prid = 1;
		foreach my $pval (@{$qpar}) {
			$sth->bind_param($prid++, $pval);
		}
	}
	if($self->{dump_query}) {
		my $d_params = "";
		if($qpar) {foreach my $pval (@{$qpar}) { $d_params .= $pval.',';};}
		$self->{logger}->debug("SQL: [".$sth->{Statement}."] {".$d_params."}");
	}
	my $res = $sth->execute();
	unless(defined($res)) {
		my $err = DBI::errstr;
		clean($self, {'sth' => $sth, 'dbh' => $dbh});
		die Wstk::WstkException->new("FAIL: [".$qtxt."], cause: ".$err);
	}
	return {'sth' => $sth, 'dbh' => $dbh};
}

sub table_exists { 
	my($self, $tname, $dbh) = @_;
	#
	my $ldbh = ($dbh ? $dbh : undef);
	my $qo = do_query($self, $ldbh, "SELECT name FROM sqlite_master WHERE type='table' AND name=? LIMIT 1", [ $tname ]);
	my $result = ($qo->{sth}->fetchrow_array() ? 1 : undef);
    unless($dbh) {
    	clean($self, $qo);
    }
    return $result;
}

sub format_like {
	my ($self, $npar, $escape) = @_;
	return $npar unless(defined($npar));
	if($escape) { $npar = $self->escape($npar); }
	#
	$npar = lc($npar);
	$npar=~ s/\%|\?|\_|//g;
	#
	return '%'.$npar.'%';
}

sub escape {
    my($self, $str) = @_;
    return $str unless($str);
    $str =~ s/\'/\'\'/g;
    #$str =~ s/[\_\%\x00-\x1f\x7f-\xff]/\\$&/g;
    #$str =~ s/[\'\_\%\x00-\x1f\x7f-\xff]/\\$&/g;
    return $str;
}
      

1;
