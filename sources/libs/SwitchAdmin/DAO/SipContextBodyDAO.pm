# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::DAO::SipContextBodyDAO;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use Wstk::EntityHelper;
use Wstk::WstkDefs qw(:ALL);
use Wstk::SearchFilterHelper;
use Wstk::WstkException;
use Wstk::EntityHelper;
use SwitchAdmin::Models::SipContextBody;

use constant TABLE_NAME => 'sip_contexts_body';
use constant ENTITY_CLASS_NAME => SwitchAdmin::Models::SipContextBody::CLASS_NAME;

sub new ($$;$) {
    my ($class, $pmod) = @_;
    my $self = {
        logger          => Log::Log4perl::get_logger(__PACKAGE__),
        class_name      => $class,
        fsadmin         => $pmod,
        dbm             => $pmod->{'dbm'},
        system_dao      => $pmod->dao_lookup('SystemDAO')        
    };
    bless($self, $class);
    #
    unless($self->{'dbm'}->table_exists(TABLE_NAME)) {       
        $self->{'logger'}->debug('creating table: ' .TABLE_NAME);
        my $qres = $self->{'dbm'}->do_query(undef, 
            'CREATE TABLE '. TABLE_NAME .' (id INTEGER PRIMARY KEY, contextId INTEGER NOT NULL, body TEXT)'
        );
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx0 ON '.TABLE_NAME.' (id)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx1 ON '.TABLE_NAME.' (contextId)');
        #
        $self->{'dbm'}->clean($qres);
    }
    return $self;
}

sub get_class_name {
    my ($self) = @_;
    return $self->{class_name};
}

# ---------------------------------------------------------------------------------------------------------------------------------
sub add {
    my ($self, $entity) = @_;
    unless (defined($entity)) {
        die Wstk::WstkException->new("entity", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    #
    $entity->id(0);
    validate_entity($self, $entity);
    #
    if(is_duplicate($self, $entity)) {
        die Wstk::WstkException->new('Context #'.$entity->contextId(), RPC_ERR_CODE_ALREADY_EXISTS);
    }
    #
    $entity->id( assign_id($self) ); 
    #
    my $qres = $self->{'dbm'}->do_query(undef, 
        'INSERT INTO '. TABLE_NAME . ' (id, contextId, body) VALUES(?, ?, ?)',
        [ $entity->id(), $entity->contextId(), $entity->body() ]
    );
    $self->{'dbm'}->clean($qres);
    #
    return $entity;
}

sub update {
    my ( $self, $entity ) = @_;
    validate_entity($self, $entity);
    #
    unless(exists_id($self, $entity->id())) {
    	die Wstk::WstkException->new('Body #'.$entity->id(), RPC_ERR_CODE_NOT_FOUND);
    }
    my $qres = $self->{'dbm'}->do_query(undef,  'UPDATE ' . TABLE_NAME . ' SET body=?  WHERE id=?', [ $entity->body(), int($entity->id()) ]);
    $self->{'dbm'}->clean($qres);
    #
    return $entity;
}

sub delete {
    my ($self, $entity_id) = @_;
    unless(defined($entity_id)) {
        die Wstk::WstkException->new("entity_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 
    	'DELETE FROM ' . TABLE_NAME . " WHERE id=?", [ int($entity_id)]
    );
    $self->{'dbm'}->clean($qres);    
    #
    return 1;
}

sub delete_by_context {
    my ($self, $context_id) = @_;
    unless(defined($context_id)) {
        die Wstk::WstkException->new("context_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 
    	'DELETE FROM ' . TABLE_NAME . " WHERE contextId=?", [ int($context_id)] 
    );
    $self->{'dbm'}->clean($qres);    
    #
    return 1;
}

sub get {
    my ($self, $entity_id) = @_;
    my $entity = undef;
    #
    unless (defined($entity_id) ) {
        die Wstk::WstkException->new("entity_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef,'SELECT * FROM ' . TABLE_NAME . " WHERE id=? LIMIT 1", [ int($entity_id)] );
    if($qres) {
        $entity = map_rs($self, $qres->{'sth'}->fetchrow_hashref() );
    }
    $self->{'dbm'}->clean($qres);
    #
    return $entity;
}

sub get_by_context {
    my ($self, $context_id) = @_;
    my $entity = undef;
    #
    unless (defined($context_id) ) {
        die Wstk::WstkException->new("context_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef,'SELECT * FROM ' . TABLE_NAME . " WHERE contextId=? LIMIT 1", [ int($context_id)] );
    if($qres) {
        $entity = map_rs($self, $qres->{'sth'}->fetchrow_hashref() );
    }
    $self->{'dbm'}->clean($qres);
    #
    return $entity;
}

sub read_body {
    my ($self, $context_id) = @_;
    my $body = undef;
    #
    unless (defined($context_id) ) {
        die Wstk::WstkException->new("context_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef,'SELECT body FROM ' . TABLE_NAME . " WHERE contextId=? LIMIT 1", [ int($context_id)] );
    if($qres) {
        $body = $qres->{sth}->fetchrow_array();
    }
    $self->{'dbm'}->clean($qres);
    return $body;
}

sub write_body {
    my ($self, $context_id, $body) = @_;
    #
    unless (defined($context_id) ) {
        die Wstk::WstkException->new("context_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef,'UPDATE ' . TABLE_NAME . " SET body=? WHERE contextId=?", [ $body, int($context_id)] );
    $self->{'dbm'}->clean($qres);
    return 1;
}

# ---------------------------------------------------------------------------------------------------------------------------------
sub validate_entity {
    my ($self, $entity) = @_;
    unless ($entity) {
        die Wstk::WstkException->new("entity", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    unless(entity_instance_of($entity, ENTITY_CLASS_NAME)) {
        die Wstk::WstkException->new("Type mismatch: " . entity_get_class($entity) . ", require: " . ENTITY_CLASS_NAME);
    }
    unless(defined($entity->id())) {
        die Wstk::WstkException->new("Invalid property: id", RPC_ERR_CODE_VALIDATION_FAIL);
    }
    unless(defined($entity->contextId())) {
        die Wstk::WstkException->new("Invalid property: contextId", RPC_ERR_CODE_VALIDATION_FAIL);
    }
}

sub exists_id {
    my($self, $id) = @_;
    my $result = undef;
    my $qo = $self->{'dbm'}->do_query(undef, 'SELECT id FROM '.TABLE_NAME." WHERE id=? LIMIT 1", [int($id)]);
    if($qo) { $result = (defined($qo->{sth}->fetchrow_array()) ? 1 : undef); }
    $self->{'dbm'}->clean($qo);
    return $result;
}

sub is_duplicate {
    my ($self, $entity ) = @_;
    my $result = undef;
    my $qo = $self->{'dbm'}->do_query(undef, 'SELECT id FROM ' . TABLE_NAME . " WHERE contextId=? LIMIT 1", [ lc( $entity->contextId() )]);
    if($qo) { $result = (defined($qo->{sth}->fetchrow_array()) ? 1 : undef); }
    $self->{'dbm'}->clean($qo);
    return $result;
}

sub assign_id {
    my($self) = @_;
    return $self->{system_dao}->sequence_get(TABLE_NAME);
}

sub map_rs {
    my ($self, $rs) = @_;        
    unless (defined $rs) { return undef; }
    return entity_map(SwitchAdmin::Models::SipContextBody->new(), $rs);
}

1;
