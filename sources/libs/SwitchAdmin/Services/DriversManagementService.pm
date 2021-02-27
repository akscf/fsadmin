# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Services::DriversManagementService;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use SwitchAdmin::Defs qw(:ALL);
use Wstk::WstkDefs qw(:ALL);

sub new ($$;$) {
	my ( $class, $pmod ) = @_;
	my $self = {
		logger          => Log::Log4perl::get_logger(__PACKAGE__),
		class_name      => $class,
		fsadmin         => $pmod,
        sec_mgr         => $pmod->{sec_mgr}
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
sub rpc_showDrivers {
    my ($self, $sec_ctx) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{fsadmin}->drivers_list();
}

sub rpc_getPropertiesDict {
    my ($self, $sec_ctx, $drv_name) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    unless(defined($drv_name)) {
        die Wstk::WstkException->new("Invalid argument: drv_name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $driver = $self->{fsadmin}->driver_lookup($drv_name);
    unless ($driver) {
        die Wstk::WstkException->new("Unknown driver:".$drv_name, RPC_ERR_CODE_NOT_FOUND);
    }
    unless($driver->can('get_properties_dict')) {
        die Wstk::WstkException->new("driver unsupported this method", RPC_ERR_CODE_INTERNAL_ERROR);
    }
    return $driver->get_properties_dict();   
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
