# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::DAO::SipUserGroupDAO;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use Wstk::EntityHelper;
use Wstk::WstkException;
use Wstk::WstkDefs qw(:ALL);
use Wstk::SearchFilterHelper;
use Wstk::Models::SearchFilter;
use SwitchAdmin::Models::SipUserGroup;
use SwitchAdmin::DAO::SipUserDAO;

use constant TABLE_NAME => 'sip_users_groups';
use constant ENTITY_CLASS_NAME  => SwitchAdmin::Models::SipUserGroup::CLASS_NAME;
use constant DEFAULT_GROUP_NAME => 'Default';

sub new ($$;$) {
    my ($class, $pmod) = @_;
    my $self = {
        logger          => Log::Log4perl::get_logger(__PACKAGE__),
        class_name      => $class,
        fsadmin         => $pmod,
        dbm             => $pmod->{'dbm'},
        system_dao      => $pmod->dao_lookup('SystemDAO')        
    };
    bless( $self, $class );
    #
    unless($self->{'dbm'}->table_exists(TABLE_NAME)) {       
        $self->{'logger'}->debug('creating table: ' .TABLE_NAME);        
        my $qres = $self->{'dbm'}->do_query(undef, 'CREATE TABLE '. TABLE_NAME .' '
            .'(id INTEGER PRIMARY KEY, domainId INTEGET NOT NULL, name TEXT(255), variables TEXT)'
        );
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx0 ON '.TABLE_NAME.' (id)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx2 ON '.TABLE_NAME.' (domainId)');
        #
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
sub add {
    my ($self, $entity) = @_;
    unless (defined($entity)) {
        die Wstk::WstkException->new("entity", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    #
    $entity->id(0);    
    $entity->variables($entity->variables() ? $entity->variables() : '[]');
    validate_entity($self, $entity);
    #
    if(is_duplicate($self, $entity)) {
        die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_ALREADY_EXISTS);
    }
    #
    $entity->id(assign_id($self));
    #
    my $qres = $self->{'dbm'}->do_query(undef, 
        'INSERT INTO '. TABLE_NAME . ' (id, domainId, name, variables) VALUES(?, ?, ?, ?)',
        [ $entity->id(), $entity->domainId(), $entity->name(), $entity->variables() ]
    );
    $self->{'dbm'}->clean($qres);
    return $entity;
}

sub update {
    my ($self, $entity) = @_;
    validate_entity($self, $entity);
    #    
    my $_entity = get($self, $entity->id());
    unless($_entity) {
        die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_NOT_FOUND);
    }
    #
    if(lc($_entity->name()) eq lc(DEFAULT_GROUP_NAME) )  { 
        $entity->name($_entity->name()); 
    }
    $entity->variables($entity->variables() ? $entity->variables() : '[]');
    #
    entity_copy_by_fields($_entity, $entity, ['name', 'variables']);
    my $qres = $self->{'dbm'}->do_query(undef, 
        'UPDATE ' . TABLE_NAME . ' SET name=?, variables=? WHERE id=?',
        [ $_entity->name(), $_entity->variables(), $_entity->id() ]
    );
    $self->{'dbm'}->clean($qres);
    #
    return $_entity;
}

sub delete {
    my ($self, $entity_id) = @_;
    unless(defined($entity_id)) {
        die Wstk::WstkException->new("entity_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    #
    my $entity = get($self, $entity_id);
    unless($entity) { return undef; }    
    if(lc($entity->name()) eq lc(DEFAULT_GROUP_NAME)) {
        die Wstk::WstkException->new("Default group can't be deleted", RPC_ERR_CODE_INTERNAL_ERROR);
    }
    unless(group_is_empty($self, $entity_id)) {
        die Wstk::WstkException->new("Group has members, move them to another group and repeat the attempt", RPC_ERR_CODE_INTERNAL_ERROR);
    }
    #
    my $qres = $self->{'dbm'}->do_query(undef, 'DELETE FROM ' . TABLE_NAME . " WHERE id=?", [ int($entity_id)] );
    $self->{'dbm'}->clean($qres);
    #
    return $entity;
}

sub delete_by_domain {
    my ($self, $domain_id) = @_;
    unless(defined($domain_id)) {
        die Wstk::WstkException->new("domain_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 'DELETE FROM ' . TABLE_NAME . " WHERE domainId=?", [ int($domain_id)] );
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

sub group_is_empty {
    my ($self, $entity_id) = @_;
    my $result = 1;
    unless (defined($entity_id) ) {
        die Wstk::WstkException->new("entity_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef,'SELECT id FROM ' .SwitchAdmin::DAO::SipUserDAO::TABLE_NAME . " WHERE groupId=? LIMIT 1", [ int($entity_id)] );
    if($qres) {
        $result = (defined($qres->{sth}->fetchrow_array()) ? undef : 1);
    }
    $self->{'dbm'}->clean($qres);
    return $qres;
}

sub get_default_group {
    my ($self, $domain_id) = @_;
    my $entity = undef;
    #
    unless (defined($domain_id) ) {
        die Wstk::WstkException->new("domain_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef,'SELECT * FROM ' . TABLE_NAME . " WHERE domain_id=? AND lower(name)=? LIMIT 1", [ int($domain_id), lc(DEFAULT_GROUP_NAME) ] );
    if($qres) { 
        $entity = map_rs($self, $qres->{'sth'}->fetchrow_hashref() );
    }
    $self->{'dbm'}->clean($qres);
    #
    return $entity;
}

sub list {
    my ($self, $domain_id, $filter) = @_;
    my $result = [];
    #
    my $fofs = filter_get_offset($filter);
    my $flimit = filter_get_limit($filter);
    my $fsortColumn = filter_get_sort_column($filter);
    my $fsortDir = filter_get_sort_direction($filter);
    my $ftext = $self->{'dbm'}->format_like(filter_get_text($filter), 1);
    #
    my $query = "SELECT * FROM ".TABLE_NAME." WHERE id > $fofs";
    $query.=" AND domainId=".int($domain_id) if(defined($domain_id));
    $query.=" AND (name LIKE '$ftext')" if($ftext);
    $query.=" ORDER BY id ASC";
    $query.=' LIMIT '.$flimit if ($flimit);
    #
    my $qres = $self->{'dbm'}->do_query(undef, $query);
    if($qres) {
        while(my $res = $qres->{sth}->fetchrow_hashref()) {            
            push(@{$result}, map_rs($self, $res));   
        }
    }
    $self->{'dbm'}->clean($qres);
    #
    return $result;
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
    unless(defined($entity->domainId())) {
        die Wstk::WstkException->new("Invalid property: domainId", RPC_ERR_CODE_VALIDATION_FAIL);
    }
    if($entity->name() !~ /^([a-zA-Z0-9\_])+$/) {
        die Wstk::WstkException->new("Invalid property: name", RPC_ERR_CODE_VALIDATION_FAIL);
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
    my $qo = $self->{'dbm'}->do_query(undef, 'SELECT id FROM ' . TABLE_NAME . " WHERE domainId=? AND lower(name)=? LIMIT 1", [ int($entity->domainId()), lc($entity->name()) ]);
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
    return entity_map(SwitchAdmin::Models::SipUserGroup->new(), $rs);
}

1;
