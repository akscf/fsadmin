# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::DAO::SipDomainDAO;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use Wstk::WstkException;
use Wstk::WstkDefs qw(:ALL);
use Wstk::EntityHelper;
use Wstk::SearchFilterHelper;
use Wstk::Models::SearchFilter;
use SwitchAdmin::Models::SipDomain;
use SwitchAdmin::DAO::SipUserGroupDAO;
use SwitchAdmin::DAO::SipUserDAO;

use constant TABLE_NAME => 'sip_domains';
use constant ENTITY_CLASS_NAME => SwitchAdmin::Models::SipDomain::CLASS_NAME;
use constant DEFAULT_DIAL_STRING => '{^^:sip_invite_domain=${dialed_domain}:presence_id=${dialed_user}@${dialed_domain}}${sofia_contact(*/${dialed_user}@${dialed_domain})}';                                     
sub new ($$;$) {
    my ($class, $pmod) = @_;
    my $self = {
        logger          => Log::Log4perl::get_logger(__PACKAGE__),
        class_name      => $class,
        fsadmin         => $pmod,
        dbm             => $pmod->{'dbm'},
        system_dao      => $pmod->dao_lookup('SystemDAO'),
        users_home      => $pmod->get_config('freeswitch', 'users_path')
    };
    bless($self, $class);
    #
    unless($self->{'dbm'}->table_exists(TABLE_NAME)) {       
        $self->{'logger'}->debug('creating table: ' .TABLE_NAME);
        my $qres = $self->{'dbm'}->do_query(undef, 
            'CREATE TABLE '. TABLE_NAME .' (id INTEGER PRIMARY KEY, name TEXT(255) NOT NULL, description TEXT(255), dialString TEXT(255), variables TEXT)'
        );
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx0 ON '.TABLE_NAME.' (id)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx1 ON '.TABLE_NAME.' (name)');
        #
        $self->{'dbm'}->clean($qres);
    }
    unless($self->{users_home}) {
        die Wstk::WstkException->new("Missing property: freeswitch.users_path");
    }
    #    
    $self->{logger}->debug('switch users: '.$self->{users_home});
    #
    unless(-d $self->{users_home}) { 
        mkdir($self->{users_home}); 
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
    $entity->variables($entity->variables() ? $entity->variables() : '[]');
    $entity->dialString($entity->dialString() ? $entity->dialString() : DEFAULT_DIAL_STRING);
    validate_entity($self, $entity);
    #
    if(is_duplicate($self, $entity)) {
        die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_ALREADY_EXISTS);
    }
    #
    $entity->id(assign_id($self)); 
    $entity->name(lc($entity->name()));
    #
    my $qres = $self->{'dbm'}->do_query(undef, 
        'INSERT INTO '. TABLE_NAME . ' (id, name, description, dialString, variables) VALUES(?, ?, ?, ?, ?)',
        [ $entity->id(), $entity->name(), $entity->description(), $entity->dialString(), $entity->variables() ]
    );
    $self->{'dbm'}->clean($qres);
    # add default group
    $self->{fsadmin}->dao_lookup('SipUserGroupDAO')->add(
        SwitchAdmin::Models::SipUserGroup->new(domainId => $entity->id(), name => SwitchAdmin::DAO::SipUserGroupDAO::DEFAULT_GROUP_NAME)
    );
    # create dir for users homes
    my $path = ($self->{users_home} .'/'. $entity->name());
    unless(-d $path) {
        mkdir($path);
    }    
    return $entity;
}

sub update {
    my ( $self, $entity ) = @_;
    validate_entity($self, $entity);
    #       
    my $_entity = get($self, $entity->id());
    unless($_entity) {
        die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_NOT_FOUND);
    }
    #
    $entity->variables($entity->variables() ? $entity->variables() : '[]');
    #
    entity_copy_by_fields($_entity, $entity, ['description', 'dialString', 'variables']);
    my $qres = $self->{'dbm'}->do_query(undef, 
        'UPDATE ' . TABLE_NAME . ' SET description=?, dialString=?, variables=? WHERE id=?',
        [ $_entity->description(), $_entity->dialString(), $_entity->variables(), $_entity->id() ]
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
    my $entity = get($self, $entity_id);
    unless($entity) { return undef; }
    #
    my $qres = $self->{'dbm'}->do_query(undef, 'DELETE FROM ' . TABLE_NAME . " WHERE id=?", [ int($entity_id)] );
    $self->{'dbm'}->clean($qres);    
    # related objects
    $self->{fsadmin}->dao_lookup('SipUserDAO')->delete_by_domain($entity_id);
    $self->{fsadmin}->dao_lookup('SipUserGroupDAO')->delete_by_domain($entity_id);
    $self->{fsadmin}->dao_lookup('SipDeviceLineDAO')->clean_refs_by_domin($entity_id);    
    # delete users home
    my $path = ($self->{users_home} .'/'. $entity->name());
    if(-d $path) {
        system("rm -rf ".$path);
    }        
    return $entity;
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

sub lookup {
    my ($self, $name) = @_;
    my $entity = undef;
    #
    if(is_empty($name)) {
        die Wstk::WstkException->new("name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef,'SELECT * FROM ' . TABLE_NAME . " WHERE name=? LIMIT 1", [ lc($name) ] );
    if($qres) {
        $entity = map_rs($self, $qres->{'sth'}->fetchrow_hashref() );
    }
    $self->{'dbm'}->clean($qres);
    #
    return $entity;
}

sub list {
    my ($self, $filter) = @_;
    my $result = [];
    #
    my $fofs = filter_get_offset($filter);
    my $flimit = filter_get_limit($filter);
    my $fsortColumn = filter_get_sort_column($filter);
    my $fsortDir = filter_get_sort_direction($filter);
    my $ftext = $self->{'dbm'}->format_like(filter_get_text($filter), 1);
    #
    my $query = "SELECT * FROM ".TABLE_NAME." WHERE id > $fofs";
    $query.=" AND (name LIKE '$ftext' OR description LIKE '$ftext')" if($ftext);
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

# for internal use
sub list_names {
    my ($self) = @_;
    my $result = [];
    #
    my $query = "SELECT name FROM ".TABLE_NAME;
    my $qres = $self->{'dbm'}->do_query(undef, $query);
    if($qres) {
        while(my $res = $qres->{sth}->fetchrow_hashref()) {            
            push(@{$result}, $res->{name});
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
    if(is_empty($entity->name())) {
        die Wstk::WstkException->new("Invalid property: name", RPC_ERR_CODE_VALIDATION_FAIL);
    }
    if($entity->name() !~ /^([a-zA-Z0-9\.\_])+$/) {
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
    my $qo = $self->{'dbm'}->do_query(undef, 'SELECT id FROM ' . TABLE_NAME . " WHERE lower(name)=? LIMIT 1", [ lc( $entity->name() )]);
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
    return entity_map(SwitchAdmin::Models::SipDomain->new(), $rs);
}

1;