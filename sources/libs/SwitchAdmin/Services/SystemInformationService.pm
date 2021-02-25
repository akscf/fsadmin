# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Services::SystemInformationService;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use SwitchAdmin::Defs qw(:ALL);
use SwitchAdmin::Models::SystemStatus;

sub new ($$;$) {
	my ( $class, $pmod ) = @_;
	my $self = {
		logger          => Log::Log4perl::get_logger(__PACKAGE__),
		class_name      => $class,
		fsadmin         => $pmod,        
        sec_mgr         => $pmod->{sec_mgr},
        info            => SwitchAdmin::Models::SystemStatus->new()
	};
	bless( $self, $class ); 
    #
    my $os_name = `uname`;
    $self->{info}->productName('Postfix admin');
    $self->{info}->productVersion('1.0.0');
    $self->{info}->instanceName('noname');
    $self->{info}->vmInfo('Perl '.$]);
    $self->{info}->osInfo($os_name);
    $self->{info}->uptime(0);
    #    
	return $self;
}

sub get_class_name {
	my ($self) = @_;
	return $self->{class_name};
}

# ---------------------------------------------------------------------------------------------------------------------------------
# public methods
# ---------------------------------------------------------------------------------------------------------------------------------
sub rpc_getStatus {
    my ( $self, $sec_ctx) = @_;
    #        
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    my $info = $self->{info};
    my $ts_start = $self->{fsadmin}->{start_time};
    my $ts_cur = time();
    $info->uptime(($ts_cur - $ts_start));
    #
    return $info;
}

# ---------------------------------------------------------------------------------------------------------------------------------
# private methods
# ---------------------------------------------------------------------------------------------------------------------------------
sub check_permissions {
    my ($self, $ctx, $roles) = @_;
    my $ident = $self->{sec_mgr}->identify($ctx);
    $self->{sec_mgr}->pass($ident, $roles);    
}

1;
