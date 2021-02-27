# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Services::SwitchMiscellaneousService;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use Wstk::WstkDefs qw(:ALL);
use SwitchAdmin::Defs qw(:ALL);
use SwitchAdmin::Models::ServerStatus;

sub new ($$;$) {
	my ( $class, $pmod ) = @_;
	my $self = {
		logger          => Log::Log4perl::get_logger(__PACKAGE__),
		class_name      => $class,
		pfadmin         => $pmod,
        sec_mgr         => $pmod->{sec_mgr},
        misc_dao     	=> $pmod->dao_lookup('SwitchMiscDAO')
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
sub rpc_showCodecs {
    my ($self, $sec_ctx) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{misc_dao}->switch_show_codecs();
}

sub rpc_showRegistrations {
    my ($self, $sec_ctx, $filter) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{misc_dao}->switch_show_registrations($filter);
}

sub rpc_showCalls {
    my ($self, $sec_ctx, $filter) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{misc_dao}->switch_show_calls($filter);
}

sub rpc_killSession {
    my ($self, $sec_ctx, $sessionId) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return ($self->{misc_dao}->switch_uuid_kill($sessionId) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
}

sub rpc_recordSession {
    my ($self, $sec_ctx, $sessionId) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{misc_dao}->switch_uuid_record($sessionId);
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