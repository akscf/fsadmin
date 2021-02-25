# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::DAO::SipDeviceDAO;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use Wstk::EntityHelper;
use Wstk::WstkException;
use Wstk::WstkDefs qw(:ALL);
use Wstk::SearchFilterHelper;
use Wstk::Models::SearchFilter;
use SwitchAdmin::Models::SipDevice;

use constant TABLE_NAME => 'sip_devices';
use constant ENTITY_CLASS_NAME => SwitchAdmin::Models::SipDevice::CLASS_NAME;

sub new ($$;$) {
    my ($class, $pmod) = @_;
    my $self = {
        logger          => Log::Log4perl::get_logger(__PACKAGE__),
        class_name      => $class,
        fsadmin         => $pmod,
        dbm             => $pmod->{'dbm'},
        system_dao      => $pmod->dao_lookup('SystemDAO')        
    };
    bless($self, $class );
    #
    unless($self->{'dbm'}->table_exists(TABLE_NAME)) {       
        $self->{'logger'}->debug('creating table: ' .TABLE_NAME);        
        my $qres = $self->{'dbm'}->do_query(undef, 'CREATE TABLE '. TABLE_NAME .' '
            .'(id INTEGER PRIMARY KEY, enabled TEXT(5) NOT NULL, hwAddress TEXT(128), ipAddress TEXT(128), '
            .'secret TEXT(128), model TEXT(255), driver TEXT(128), template TEXT(128), description TEXT(255), lastActiveDate TEXT(64), driverProperties TEXT)'
        );
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx0 ON '.TABLE_NAME.' (id)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx1 ON '.TABLE_NAME.' (hwAddress)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx2 ON '.TABLE_NAME.' (ipAddress)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx3 ON '.TABLE_NAME.' (template)');
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
    $entity->ipAddress(undef);
    $entity->enabled(is_true($entity->enabled()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->driverProperties($entity->driverProperties() ? $entity->driverProperties() : '[]');
    validate_entity($self, $entity);
    #
    if($entity->driver()) {
        my $drv = $self->{'fsadmin'}->driver_lookup($entity->driver());
        unless($drv) {
            die Wstk::WstkException->new("Drivre not found: ".$entity->driver(), RPC_ERR_CODE_NOT_FOUND);
        }        
    }    
    #
    if(is_duplicate($self, $entity)) {
        die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_ALREADY_EXISTS);
    }
    #
    $entity->id(assign_id($self));
    $entity->hwAddress(uc($entity->hwAddress()));
    #
    my $qres = $self->{'dbm'}->do_query(undef, 
        'INSERT INTO '. TABLE_NAME . ' (id, enabled, hwAddress, ipAddress, model, secret, driver, template, description, driverProperties) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [ $entity->id(), $entity->enabled(), $entity->hwAddress(), $entity->ipAddress(), $entity->model(), $entity->secret(), $entity->driver(), $entity->template(), 
          $entity->description(), $entity->driverProperties() 
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
        die Wstk::WstkException->new(($entity->hwAddress() ? $entity->hwAddress() : 'Device #'.entity->id()), RPC_ERR_CODE_NOT_FOUND);
    }
    if($entity->driver() && $entity->driver() ne $_entity->driver()) {
        my $drv = $self->{'fsadmin'}->driver_lookup($entity->driver());
        unless($drv) {
            die Wstk::WstkException->new("Drivre not found: ".$entity->driver(), RPC_ERR_CODE_NOT_FOUND);
        }
    }
    #
    $entity->enabled(is_true($entity->enabled()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->hwAddress(uc($entity->hwAddress()));
    $entity->driverProperties($entity->driverProperties() ? $entity->driverProperties() : '[]');
    #
    entity_copy_by_fields($_entity, $entity, ['enabled', 'hwAddress', 'model', 'secret', 'driver', 'template', 'description', 'driverProperties']);
    my $qres = $self->{'dbm'}->do_query(undef, 
        'UPDATE ' . TABLE_NAME . ' SET enabled=?, hwAddress=?, model=?, secret=?, driver=?, template=?, description=?, driverProperties=? WHERE id=?',
        [ $_entity->enabled(), $_entity->hwAddress(), $_entity->model(), $_entity->secret(), $_entity->driver(), $_entity->template(), 
          $_entity->description(), $_entity->driverProperties(), $_entity->id() 
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
    $query.=" AND (hwAddress LIKE '$ftext' OR ipAddress LIKE '$ftext' OR model LIKE '$ftext' OR description LIKE '$ftext')" if($ftext);
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

sub lookup {
    my ($self, $hw_address) = @_;
    my $entity = undef;
    #
    if(is_empty($hw_address)) {
        die Wstk::WstkException->new("hw_address", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef,'SELECT * FROM ' . TABLE_NAME . " WHERE hwAddress=? LIMIT 1", [ uc($hw_address) ] );
    if($qres) {
        $entity = map_rs($self, $qres->{'sth'}->fetchrow_hashref() );
    }
    $self->{'dbm'}->clean($qres);
    #
    return $entity;
}

# internal use only
sub update_template {
    my ($self, $old_name, $new_name) = @_;
    my $qres = $self->{'dbm'}->do_query(undef, 'UPDATE ' . TABLE_NAME . " SET template=? WHERE template=?", [ $new_name, $old_name ] );
    $self->{'dbm'}->clean($qres);    
    return 1;
}

sub update_ip {
    my ($self, $entity_id, $ip, $date) = @_;
    my $qres = $self->{'dbm'}->do_query(undef, 'UPDATE ' . TABLE_NAME . " SET ipAddress=?, lastActiveDate=?  WHERE id=?", [ $ip, $date, int($entity_id) ] );
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
    my $qo = $self->{'dbm'}->do_query(undef, 'SELECT id FROM ' . TABLE_NAME . " WHERE hwAddress=? LIMIT 1", [ uc( $entity->hwAddress() )]);
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
    return entity_map(SwitchAdmin::Models::SipDevice->new(), $rs);
}

1;
