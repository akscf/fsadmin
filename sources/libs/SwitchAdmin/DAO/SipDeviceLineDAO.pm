# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::DAO::SipDeviceLineDAO;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use Wstk::EntityHelper;
use Wstk::WstkException;
use Wstk::WstkDefs qw(:ALL);
use Wstk::SearchFilterHelper;
use Wstk::Models::SearchFilter;
use SwitchAdmin::Models::SipDeviceLine;
use constant TABLE_NAME => 'sip_device_lines';
use constant ENTITY_CLASS_NAME => SwitchAdmin::Models::SipDeviceLine::CLASS_NAME;

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
            .'(id INTEGER PRIMARY KEY, deviceId INTEGET NOT NULL, domainId INTEGET, userId INTEGET, lineId INTEGER(4) NOT NULL, enabled TEXT(5) NOT NULL, '
            .'number TEXT(64), realm TEXT(255), proxy TEXT(255), password TEXT(128), description TEXT(255), variables TEXT)'
        );
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx0 ON '.TABLE_NAME.' (id)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx1 ON '.TABLE_NAME.' (deviceId)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx2 ON '.TABLE_NAME.' (domainId)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx3 ON '.TABLE_NAME.' (userId)');
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
    $entity->domainId(undef);
    $entity->enabled(is_true($entity->enabled()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->variables($entity->variables() ? $entity->variables() : '[]');
    validate_entity($self, $entity);
    # 
    if($entity->userId()) {
        my $user = $self->{fsadmin}->dao_lookup('SipUserDAO')->get($entity->userId());
        unless($user) { 
            die Wstk::WstkException->new("User #".$entity->userId(), RPC_ERR_CODE_NOT_FOUND);   
        }
        my $domain = $self->{fsadmin}->dao_lookup('SipDomainDAO')->get($user->domainId());
        unless($domain) { 
            die Wstk::WstkException->new("Domain #".$entity->domainId(), RPC_ERR_CODE_NOT_FOUND);   
        }
        $entity->domainId($user->domainId());        
        $entity->realm($domain->name());
        $entity->password($user->sipPassword())        
    }        
    # 
    if(is_duplicate($self, $entity)) {
        die Wstk::WstkException->new('Line #'.$entity->lineId(), RPC_ERR_CODE_ALREADY_EXISTS);
    }
    #
    $entity->id(assign_id($self));
    #
    my $qres = $self->{'dbm'}->do_query(undef, 
        'INSERT INTO '. TABLE_NAME . ' (id, deviceId, domainId, userId, lineId, enabled, number, realm, proxy, password, description, variables) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [ $entity->id(), $entity->deviceId(), $entity->domainId(), $entity->userId(), $entity->lineId(), $entity->enabled(),
          $entity->number(), $entity->realm(), $entity->proxy(), $entity->password(), $entity->description(), $entity->variables()
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
        die Wstk::WstkException->new('Line #'.$entity->lineId(), RPC_ERR_CODE_NOT_FOUND);
    }
    if($entity->lineId() != $_entity->lineId()) {
        if(is_duplicate($self, $entity)) {
            die Wstk::WstkException->new('Line #'.$entity->lineId(), RPC_ERR_CODE_ALREADY_EXISTS);
        }        
    }
    if($entity->userId() && $entity->userId() != $_entity->userId()) {
        my $user = $self->{fsadmin}->dao_lookup('SipUserDAO')->get($entity->userId());
        unless($user) {
            die Wstk::WstkException->new("User #".$entity->userId(), RPC_ERR_CODE_NOT_FOUND);   
        }
        $entity->domainId($user->domainId());
        $entity->userId($user->id());        
    } else {
        $entity->domainId($_entity->domainId());
        $entity->userId($_entity->userId());        
    }
    #
    $entity->enabled(is_true($entity->enabled()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->variables($entity->variables() ? $entity->variables() : '[]');
    #
    entity_copy_by_fields($_entity, $entity, ['enabled', 'domainId', 'userId', 'lineId', 'number',  'realm', 'proxy', 'password', 'variables', 'description']);
    my $qres = $self->{'dbm'}->do_query(undef, 
        'UPDATE ' . TABLE_NAME . ' SET enabled=?, domainId=?, userId=?, lineId=?, number=?, realm=?, proxy=?, password=?, variables=?, description=? WHERE id=?',
        [ $_entity->enabled(), $_entity->domainId(), $_entity->userId(), $_entity->lineId(), $_entity->number(), $_entity->realm(), $_entity->proxy(), $_entity->password(), 
          $_entity->variables(), $_entity->description(), $_entity->id() 
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
    # related objects
    $self->{fsadmin}->dao_lookup('SipDeviceLineDAO')->delete_by_device($entity_id);
    #
    return $entity;
}

sub delete_by_device {
    my ($self, $device_id) = @_;
    unless(defined($device_id)) {
        die Wstk::WstkException->new("device_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 'DELETE FROM ' . TABLE_NAME . " WHERE deviceId=?", [ int($device_id)] );
    $self->{'dbm'}->clean($qres);    
    #
    return 1;
}

# clean refs to the user
sub clean_refs_by_user {
    my ($self, $user_id) = @_;
    unless(defined($user_id)) {
        die Wstk::WstkException->new("user_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 'UPDATE ' . TABLE_NAME . " SET enabled=0, domainId=NULL, userId=NULL WHERE userId=?", 
        [ int($user_id) ] 
    );
    $self->{'dbm'}->clean($qres);    
    #
    return 1;
}

# clean refs to the domain
sub clean_refs_by_domin {
    my ($self, $domain_id) = @_;
    unless(defined($domain_id)) {
        die Wstk::WstkException->new("domain_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 'UPDATE ' . TABLE_NAME . " SET enabled=0, domainId=NULL, userId=NULL WHERE domainId=?", 
        [ int($domain_id) ] 
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

sub list {
    my ($self, $device_id, $user_id, $filter) = @_;
    my $result = [];
    #
    my $fofs = filter_get_offset($filter);
    my $flimit = filter_get_limit($filter);
    my $fsortColumn = filter_get_sort_column($filter);
    my $fsortDir = filter_get_sort_direction($filter);
    my $ftext = $self->{'dbm'}->format_like(filter_get_text($filter), 1);
    #
    my $query = "SELECT * FROM ".TABLE_NAME." WHERE id > $fofs";
    $query.=" AND deviceId=".int($device_id) if(defined($device_id));
    $query.=" AND userId=".int($user_id)     if(defined($user_id));
    $query.=" AND (number LIKE '$ftext' OR realm LIKE '$ftext' OR proxy LIKE '$ftext' OR description LIKE '$ftext')" if($ftext);
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

sub get_lines_by_device {
    my ($self, $device_id) = @_;
    my $result = [];
    #
    unless (defined($device_id) ) {
        die Wstk::WstkException->new("device_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef,'SELECT * FROM ' . TABLE_NAME . " WHERE deviceId=?", [ int($device_id)] );
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
    unless(defined($entity->deviceId())) {
        die Wstk::WstkException->new("Invalid property: deviceId", RPC_ERR_CODE_VALIDATION_FAIL);
    }
    unless(defined($entity->lineId())) {
        die Wstk::WstkException->new("Invalid property: lineId", RPC_ERR_CODE_VALIDATION_FAIL);
    }    
    unless(defined($entity->number())) {
        die Wstk::WstkException->new("Invalid property: number", RPC_ERR_CODE_VALIDATION_FAIL);
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
    my $qo = $self->{'dbm'}->do_query(undef, 'SELECT id FROM ' . TABLE_NAME . " WHERE deviceId=? AND lineId=? LIMIT 1", [ int($entity->deviceId()), int($entity->lineId()) ]);
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
    return entity_map(SwitchAdmin::Models::SipDeviceLine->new(), $rs);
}

1;
