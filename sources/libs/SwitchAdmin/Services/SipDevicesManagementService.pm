# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Services::SipDevicesManagementService;

use strict;

use JSON;
use Log::Log4perl;
use Wstk::Boolean;
use Wstk::WstkDefs qw(:ALL);
use SwitchAdmin::Defs qw(:ALL);
use Wstk::EntityHelper qw(is_empty);

sub new ($$;$) {
	my ( $class, $pmod ) = @_;
	my $self = {
		logger          => Log::Log4perl::get_logger(__PACKAGE__),
		class_name      => $class,
		fsadmin         => $pmod,
        sec_mgr         => $pmod->{sec_mgr},
        device_dao		=> $pmod->dao_lookup('SipDeviceDAO')
	};
	bless( $self, $class );
	return $self;
}

sub get_class_name {
	my ($self) = @_;
	return $self->{class_name};
}

# ---------------------------------------------------------------------------------------------------------------------------------
# public methods
# ---------------------------------------------------------------------------------------------------------------------------------
sub rpc_add {
	my ($self, $sec_ctx, $entity) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
	return $self->{device_dao}->add($entity);
}

sub rpc_update {
	my ($self, $sec_ctx, $entity) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
	return $self->{device_dao}->update($entity);
}
        
sub rpc_delete {
	my ($self, $sec_ctx, $entity_id) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return ($self->{device_dao}->delete($entity_id) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
}
    
sub rpc_get {
	my ($self, $sctx, $entity_id) = @_;
    #
    check_permissions($self, $sctx, [ROLE_ADMIN]);
    return $self->{device_dao}->get($entity_id);
}
    
sub rpc_list {
	my ($self, $sec_ctx, $filter) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    return $self->{device_dao}->list($filter);
}

sub rpc_reprovision {
    my ($self, $sec_ctx, $mac) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    unless(defined($mac)) {
        die Wstk::WstkException->new("Invalid argument: mac", RPC_ERR_CODE_INVALID_ARGUMENT);
    }  
    my $device = $self->{device_dao}->lookup($mac);
    unless($device) {
        die Wstk::WstkException->new('Device: '.$mac, RPC_ERR_CODE_NOT_FOUND);
    }
    if(is_empty($device->driver())) {
        die Wstk::WstkException->new('No driver defined for device', RPC_ERR_CODE_INTERNAL_ERROR);
    }
    my $driver = $self->{fsadmin}->driver_lookup($device->driver());
    unless ($driver) {
        die Wstk::WstkException->new('Device: '.$device->driver(), RPC_ERR_CODE_NOT_FOUND);
    }
    my $drv_props = {};
    if($device->driverProperties()) {
        my $t = from_json($device->driverProperties());
        foreach my $e (@{$t}) {
            $drv_props->{$e->{name}} = $e->{value};
        }       
    }
    $drv_props->{acs_url} = $self->{fsadmin}->get_config('acs', 'url');
    #
    $@ = "";
    eval { $driver->reprovision($device, $drv_props); 1; } || do {
        my $exc = $@;
        if($exc) {
            if(ref $exc eq 'Wstk::WstkException') { die $exc; } 
            else { die Wstk::WstkException->new($exc, RPC_ERR_CODE_INTERNAL_ERROR); }        
        }
    };
    return Wstk::Boolean::TRUE;
}

sub rpc_reboot {
    my ($self, $sec_ctx, $mac) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    unless(defined($mac)) {
        die Wstk::WstkException->new("Invalid argument: mac", RPC_ERR_CODE_INVALID_ARGUMENT);
    }  
    my $device = $self->{device_dao}->lookup($mac);
    unless($device) {
        die Wstk::WstkException->new('Device: '.$mac, RPC_ERR_CODE_NOT_FOUND);
    }
    if(is_empty($device->driver())) {
        die Wstk::WstkException->new('No driver defined for device', RPC_ERR_CODE_INTERNAL_ERROR);
    }
    my $driver = $self->{fsadmin}->driver_lookup($device->driver());
    unless ($driver) {
        die Wstk::WstkException->new('Device: '.$device->driver(), RPC_ERR_CODE_NOT_FOUND);
    }
    my $drv_props = {};
    if($device->driverProperties()) {
        my $t = from_json($device->driverProperties());
        foreach my $e (@{$t}) {
            $drv_props->{$e->{name}} = $e->{value};
        }       
    }
    $drv_props->{acs_url} = $self->{fsadmin}->get_config('acs', 'url');
    #
    $@ = "";
    eval { $driver->reboot($device, $drv_props); 1; } || do {
        my $exc = $@;
        if($exc) {
            if(ref $exc eq 'Wstk::WstkException') { die $exc; } 
            else { die Wstk::WstkException->new($exc, RPC_ERR_CODE_INTERNAL_ERROR); }        
        }
    };
    return Wstk::Boolean::TRUE;
}

# ---------------------------------------------------------------------------------------------------------------------------------
# private methods
# ---------------------------------------------------------------------------------------------------------------------------------
sub check_permissions {
    my ($self, $ctx, $roles) = @_;
    #
    my $ident = $self->{sec_mgr}->identify($ctx);
    $self->{sec_mgr}->pass($ident, $roles);    
}

1;
