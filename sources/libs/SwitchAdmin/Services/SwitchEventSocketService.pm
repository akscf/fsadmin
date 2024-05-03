# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::Services::SwitchEventSocketService;

use strict;

use Log::Log4perl;
use Wstk::WstkDefs qw(:ALL);
use SwitchAdmin::Defs qw(:ALL);
use SwitchAdmin::EslClient;

sub new ($$;$) {
	my ( $class, $pmod ) = @_;
	my $self = {
		logger          => Log::Log4perl::get_logger(__PACKAGE__),
		class_name      => $class,
		pfadmin         => $pmod,
        sec_mgr         => $pmod->{sec_mgr},
        esl_client      => SwitchAdmin::EslClient->new($pmod)
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
sub rpc_execApi {
    my ($self, $sec_ctx, $cmd) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    $self->{esl_client}->connect();    
    return $self->{esl_client}->exec_api($cmd, 1);
}

sub rpc_execBgapi {
    my ($self, $sec_ctx, $cmd) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    $self->{esl_client}->connect();    
    return $self->{esl_client}->exec_bgapi($cmd, 1);
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
