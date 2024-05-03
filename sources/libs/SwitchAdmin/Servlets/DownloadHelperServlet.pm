# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::Servlets::DownloadHelperServlet;

use strict;

use Log::Log4perl;
use MIME::Base64;
use Wstk::WstkException;
use Wstk::WstkDefs qw(:ALL);
use SwitchAdmin::Defs qw(:ALL);
use SwitchAdmin::IOHelper qw(io_get_file_size);

sub new ($$;$) {
	my ( $class, $pmod) = @_;
	my $self = {
		logger          => Log::Log4perl::get_logger(__PACKAGE__),
		class_name 		=> $class,
		fsadmin        	=> $pmod,
        sec_mgr         => $pmod->{sec_mgr},
        fsscript_dao	=> $pmod->dao_lookup('SwitchScriptDAO'),
        fssound_dao		=> $pmod->dao_lookup('SwitchSoundDAO')
	};
	bless( $self, $class );
	return $self;
}

sub get_class_name {
	my ($self) = @_;
	return $self->{class_name};
}

sub execute_request {
	my ( $self, $cgi ) = @_;
	my $credentials = undef;	
	my $auth_hdr = $ENV{'HTTP_AUTHORIZATION'};
	#
	if ($auth_hdr) {
		my ($basic, $ucred) = split(' ', $auth_hdr);
		if ($basic) {
			my ( $user, $pass ) = split( ':', decode_base64($ucred) );
			if ( defined($user) && defined($pass) ) {
				$credentials = { method => $basic, user => $user, password => $pass };
			}
		}
	}
	my $sessionId = $cgi->http("X-SESSION-ID");
	unless(defined $sessionId) { $sessionId = $cgi->param('x-session-id'); }
	my $ctx = {
		time       	=> time(),
		sessionId 	=> $sessionId,
		userAgent	=> $cgi->http("HTTP_USER_AGENT"),
		remoteIp   	=> $ENV{'REMOTE_ADDR'},
		credentials => $credentials
	};
	$@ = "";	
	eval { 
		$self->{sec_mgr}->pass($self->{sec_mgr}->identify($ctx), [ROLE_ADMIN]); 
	} || do {
		die Wstk::WstkException->new('Permission denied', 403);
  	};
  	#
  	my $method = $ENV{REQUEST_METHOD};
	my $qstr = $ENV{'QUERY_STRING'};
  	my $type = $cgi->param('type');
	#  	
  	$self->{logger}->debug('query_string='.$qstr);
  	$self->{logger}->debug('type='.$type);
  	#
  	die Wstk::WstkException->new('Not yet implemented', 501);	
	#
	if('GET' eq $method) {	
		if($type eq 'switch_user_file') {
		}		
		
		if($type eq 'switch_script') {
		}		
		
		if($type eq 'switch_sound') {
		}			
		die Wstk::WstkException->new('Unsupported type: '.$type, 400);
	}
	die Wstk::WstkException->new('Unsupported method: '.$method, 400);
	return 1;
}

# ---------------------------------------------------------------------------------------------------------------------------------
# helper methods
# ---------------------------------------------------------------------------------------------------------------------------------
sub get_content_type {
	my ($self, $fileName) = @_;
	
	if($fileName =~ /\.mp3\z/) {
		return "audio/mpeg";
	} elsif ($fileName =~ /\.wav\z/) {
		return "audio/x-wav";
	}

	return "application/octet-stream";
}

sub read_stream {
	my ($self, $ctype, $abs_path, $rel_path) = @_;
	my $bsize = io_get_file_size($abs_path);
	my ($rd, $bread, $buffer) = (0, 0, undef);
	#
	unless($bsize) {
		print "Content-type: ".$ctype."\n";
		print "Content-length: ".$bsize."\n";
		print "Date: " . localtime(time())."\n\n";
		return;
	}	
	open(my $fio, "<".$abs_path) || die Wstk::WstkException->new("Couldn't open file: ".$rel_path, 500);
	#
	print "Content-type: ".$ctype."\n";
	print "Content-length: ".$bsize."\n";
	print "Date: " . localtime( time() ) . "\n\n";
	#
	while(1) {
		if($bread == $bsize) { last; }
		if($bread > $bsize) {
			$rd = $bsize - $bread;
			unless($rd) {last; }
		} else { 
			$rd = 1024; 
		}
		$self->{logger}->debug("read: rd=$rd, bread=$bread, bsize=$bsize");
		$rd = sysread($fio, $buffer, $rd);
		if($rd <= 0) { last; }
		$bread += $rd;			
		print $buffer;
	}
	$self->{logger}->debug("finished: bread=$bread, bsize=$bsize");
	close($fio);
	return 1;
}

1;
