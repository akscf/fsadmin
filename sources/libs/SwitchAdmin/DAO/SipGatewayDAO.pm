# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::DAO::SipGatewayDAO;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use Wstk::EntityHelper;
use Wstk::WstkException;
use Wstk::WstkDefs qw(:ALL);
use Wstk::SearchFilterHelper;
use Wstk::Models::SearchFilter;
use SwitchAdmin::Models::SipGateway;

use constant TABLE_NAME => 'sip_gateways';
use constant ENTITY_CLASS_NAME => SwitchAdmin::Models::SipGateway::CLASS_NAME;

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
        my $qres = $self->{'dbm'}->do_query(undef, 
            'CREATE TABLE '. TABLE_NAME .' (id INTEGER PRIMARY KEY, profileId INTEGER NOT NULL, enabled TEXT(5) NOT NULL, register TEXT(5) NOT NULL, name TEXT(255) NOT NULL, '.
            'username TEXT(128), password TEXT(128), realm TEXT(255), proxy TEXT(255), description TEXT(255), variables TEXT)'
        );
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx0 ON '.TABLE_NAME.' (id)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx1 ON '.TABLE_NAME.' (name)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx2 ON '.TABLE_NAME.' (profileId)');
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
    $entity->enabled(is_true($entity->enabled()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->register(is_true($entity->register()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->variables($entity->variables() ? $entity->variables() : '[]');
    validate_entity($self, $entity);
    # 
    unless($self->{fsadmin}->dao_lookup('SipProfileDAO')->exists_id($entity->profileId())) {
        die Wstk::WstkException->new("Profile #".$entity->profileId(), RPC_ERR_CODE_NOT_FOUND);   
    }
    # 
    if(is_duplicate($self, $entity)) {
        die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_ALREADY_EXISTS);
    }
    #
    $entity->id(assign_id($self));
    $entity->name(lc($entity->name()));
    #
    my $qres = $self->{'dbm'}->do_query(undef, 
        'INSERT INTO '. TABLE_NAME . ' (id, profileId, enabled, register, name, username, password, realm, proxy, description, variables) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [ $entity->id(), $entity->profileId(), $entity->register(), $entity->enabled(), $entity->name(), $entity->username(), $entity->password(), $entity->realm(), 
          $entity->proxy(), $entity->description(), $entity->variables() 
        ]
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
    if($_entity->name() ne $entity->name()) {
        $entity->name( lc($entity->name()) );
        if(is_duplicate($self, $entity)) {
            die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_ALREADY_EXISTS);
        }
    }
    #
    $entity->enabled(is_true($entity->enabled()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->register(is_true($entity->register()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->variables($entity->variables() ? $entity->variables() : '[]');
    #
    entity_copy_by_fields($_entity, $entity, ['name', 'enabled', 'register', 'username', 'password', 'realm', 'proxy', 'description', 'variables']);
    my $qres = $self->{'dbm'}->do_query(undef, 
        'UPDATE ' . TABLE_NAME . ' SET name=?, enabled=?, register=?, username=?, password=?, realm=?, proxy=?, description=?, variables=? WHERE id=?',
        [ $_entity->name(), $_entity->enabled(), $_entity->register(), $_entity->username(), $_entity->password(), $_entity->realm(), 
          $_entity->proxy(), $_entity->description(), $_entity->variables(), $_entity->id()
        ]
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
    #
    my $qres = $self->{'dbm'}->do_query(undef, 'DELETE FROM ' . TABLE_NAME . " WHERE id=?", [ int($entity_id)] );
    $self->{'dbm'}->clean($qres);    
    #
    return $entity;
}

sub delete_by_profile {
    my ($self, $profile_id) = @_;
    #
    unless(defined($profile_id)) {
        die Wstk::WstkException->new("profile_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 'DELETE FROM ' . TABLE_NAME . " WHERE profileId=?", [ int($profile_id)] );
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

sub list {
    my ($self, $profile_id, $filter) = @_;
    my $result = [];
    #
    my $fofs = filter_get_offset($filter);
    my $flimit = filter_get_limit($filter);
    my $fsortColumn = filter_get_sort_column($filter);
    my $fsortDir = filter_get_sort_direction($filter);
    my $ftext = $self->{'dbm'}->format_like(filter_get_text($filter), 1);
    #
    my $query = "SELECT * FROM ".TABLE_NAME." WHERE id > $fofs";
    $query.=" AND profileId=".int($profile_id) if(defined($profile_id));
    $query.=" AND (name LIKE '$ftext' OR username LIKE '$ftext' OR description LIKE '$ftext')" if($ftext);
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
    unless(defined($entity->profileId())) {
        die Wstk::WstkException->new("Invalid property: profileId", RPC_ERR_CODE_VALIDATION_FAIL);
    }
    if(is_empty($entity->name())) {
        die Wstk::WstkException->new("Invalid property: name", RPC_ERR_CODE_VALIDATION_FAIL);
    }
    if(is_empty($entity->username())) {
        die Wstk::WstkException->new("Invalid property: username", RPC_ERR_CODE_VALIDATION_FAIL);
    }
    if(is_empty($entity->password())) {
        die Wstk::WstkException->new("Invalid property: password", RPC_ERR_CODE_VALIDATION_FAIL);
    }
}

sub exists_id {
    my($self, $id) = @_;
    my $result = undef;
    my $qo = $self->{'dbm'}->do_query(undef, 'SELECT id FROM '.TABLE_NAME." WHERE id=? LIMIT 1", [ int($id) ]);
    if($qo) { $result = (defined($qo->{sth}->fetchrow_array()) ? 1 : undef); }
    $self->{'dbm'}->clean($qo);
    return $result;
}

sub is_duplicate {
    my ($self, $entity ) = @_;
    my $result = undef;
    my $qo = $self->{'dbm'}->do_query(undef, 'SELECT id FROM ' . TABLE_NAME . " WHERE profileId=? AND lower(name)=? LIMIT 1", [ int($entity->profileId()), lc($entity->name()) ]);
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
    return entity_map(SwitchAdmin::Models::SipGateway->new(), $rs);
}

1;
