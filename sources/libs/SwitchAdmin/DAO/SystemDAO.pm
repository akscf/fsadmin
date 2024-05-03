# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::DAO::SystemDAO;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use Wstk::WstkDefs qw(:ALL);
use Wstk::WstkException;

use constant PROPS_TABLE_NAME    => 'sys_props';
use constant SEQUENCE_TABLE_NAME => 'sys_sequence';

sub new ($$;$) {
    my ($class, $pmod) = @_;
    my $self = {
        logger          => Log::Log4perl::get_logger(__PACKAGE__),
        class_name      => $class,
        fsadmin         => $pmod,        
        dbm             => $pmod->{'dbm'}
    };
    bless($self, $class);
    #
    unless($self->{'dbm'}->table_exists(PROPS_TABLE_NAME)) {               
        my $qres = $self->{'dbm'}->do_query(undef, 
            'CREATE TABLE '. PROPS_TABLE_NAME .' (name TEXT(255) NOT NULL, value TEXT(255))'
        );
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.PROPS_TABLE_NAME.'_idx0 ON '.PROPS_TABLE_NAME.' (name)');
        $self->{'dbm'}->clean($qres);
    }
    unless($self->{'dbm'}->table_exists(SEQUENCE_TABLE_NAME)) {               
        my $qres = $self->{'dbm'}->do_query(undef, 
            'CREATE TABLE '. SEQUENCE_TABLE_NAME .' (name TEXT(255) NOT NULL, value INTEGER NOT NULL)'
        );
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.SEQUENCE_TABLE_NAME.'_idx0 ON '.SEQUENCE_TABLE_NAME.' (name)');
        $self->{'dbm'}->clean($qres);
    }
    #        
    return $self;
}

sub get_class_name {
    my ($self) = @_;
    return $self->{class_name};
}

# ---------------------------------------------------------------------------------------------------------------------------------
sub prop_exists {
    my($self, $name) = @_;
    my $result = undef;
    #
    unless (defined $name) {
        die Wstk::WstkException->new("name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 'SELECT name FROM '.PROPS_TABLE_NAME." WHERE lower(name)=? LIMIT 1", [ lc($name) ]);
    if($qres) { $result = (defined($qres->{sth}->fetchrow_array()) ? 1 : undef); }
    $self->{'dbm'}->clean($qres);
    #
    return $result;
}

sub prop_put {
    my ($self, $name, $value) = @_;
    #
    unless (defined $name) {
        die Wstk::WstkException->new("name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = undef;
    if(prop_exists($self, $name)) {
        $qres = $self->{'dbm'}->do_query(undef, 'INSERT INTO '. PROPS_TABLE_NAME . ' (name, value) VALUES(?, ?)', [ $name, $value ]);
    } else {
        $qres = $self->{'dbm'}->do_query(undef, 'UPDATE ' .PROPS_TABLE_NAME. ' SET value=? WHERE lower(name)=?', [ $value, lc($name) ]);
    }
    $self->{'dbm'}->clean($qres);
    return 1;
}

sub prop_get {
    my ($self, $name, $default_value) = @_;
    #
    unless (defined $name) {
        die Wstk::WstkException->new("name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 'SELECT value FROM ' .PROPS_TABLE_NAME. ' WHERE lower(name)=?', [ lc($name) ]);
    my $val = $qres->{sth}->fetchrow_array();    
    $self->{'dbm'}->clean($qres);
    #
    unless(defined $val) { 
        $val = $default_value; 
    }
    return $val;
}

sub prop_delete {
    my ($self, $name) = @_;
    #
    unless (defined $name) {
        die Wstk::WstkException->new("name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 'DELETE FROM ' . PROPS_TABLE_NAME . " WHERE lower(name)=?", [ lc($name) ] );
    $self->{'dbm'}->clean($qres);    
    #
    return 1;
}


sub sequence_get {
    my ($self, $name) = @_;
    #
    unless (defined $name) {
        die Wstk::WstkException->new("name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 'SELECT value FROM '.SEQUENCE_TABLE_NAME." WHERE name=? LIMIT 1", [ $name ]);
    unless($qres) { 
        die Wstk::WstkException->new("SQL fail"); 
    }
    my $result = $qres->{sth}->fetchrow_array();
    unless(defined $result ) {
        $self->{'dbm'}->clean($qres, 1);
        $result = 1;
        $qres = $self->{'dbm'}->do_query(undef, 'INSERT INTO '. SEQUENCE_TABLE_NAME . ' (name, value) VALUES(?, ?)', [ $name, $result ]);
    } else {
        $self->{'dbm'}->clean($qres, 1);
        $result += 1;
        $qres = $self->{'dbm'}->do_query(undef, 'UPDATE ' .SEQUENCE_TABLE_NAME. ' SET value=? WHERE name=?', [ $result, $name ]);
    }
    $self->{'dbm'}->clean($qres);
    #
    return $result;
}

sub sequence_delete {
    my ($self, $name) = @_;
    #
    unless (defined $name) {
        die Wstk::WstkException->new("name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 'DELETE FROM ' . SEQUENCE_TABLE_NAME . " WHERE name=?", [ $name ] );
    $self->{'dbm'}->clean($qres);    
    return 1;
}


1;
