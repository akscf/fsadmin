# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::Services::SwitchConfigsManagementService;

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
        config_dao      => $pmod->dao_lookup('SwitchConfigDAO')
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
    return $self->{config_dao}->add($entity);
}

sub rpc_update {
    my ($self, $sec_ctx, $entity) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    return $self->{config_dao}->update($entity);
}
        
sub rpc_delete {
    my ($self, $sec_ctx, $entity_id) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    return ($self->{config_dao}->delete($entity_id) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
}
    
sub rpc_get {
    my ($self, $sctx, $entity_id) = @_;
    #
    check_permissions($self, $sctx, [ROLE_ADMIN]);
    return $self->{config_dao}->get($entity_id);
}
    
sub rpc_lookup {
    my ($self, $sctx, $name) = @_;
    #
    check_permissions($self, $sctx, [ROLE_ADMIN]);    
    return $self->{config_dao}->lookup($name);
}

sub rpc_list {
    my ($self, $sec_ctx, $filter) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    return $self->{config_dao}->list($filter);
}

sub rpc_readBody {
    my ($self, $sec_ctx, $config_id) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    return $self->{config_dao}->read_body($config_id);    
}

sub rpc_writeBody {
    my ($self, $sec_ctx, $config_id, $data) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    return ($self->{config_dao}->write_body($config_id, $data) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
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
