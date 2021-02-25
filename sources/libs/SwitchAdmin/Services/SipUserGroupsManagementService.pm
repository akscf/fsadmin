# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Services::SipUserGroupsManagementService;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use SwitchAdmin::Defs qw(:ALL);

sub new ($$;$) {
	my ( $class, $pmod ) = @_;
	my $self = {
		logger          => Log::Log4perl::get_logger(__PACKAGE__),
		class_name      => $class,
		fsadmin         => $pmod,
        sec_mgr         => $pmod->{sec_mgr},
        user_group_dao	=> $pmod->dao_lookup('SipUserGroupDAO')
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
	return $self->{user_group_dao}->add($entity);
}

sub rpc_update {
	my ($self, $sec_ctx, $entity) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
	return $self->{user_group_dao}->update($entity);
}
        
sub rpc_delete {
	my ($self, $sec_ctx, $entity_id) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return ($self->{user_group_dao}->delete($entity_id) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
}
    
sub rpc_get {
	my ($self, $sctx, $entity_id) = @_;
    #
    check_permissions($self, $sctx, [ROLE_ADMIN]);
    #
    return $self->{user_group_dao}->get($entity_id);
}
    
sub rpc_list {
	my ($self, $sec_ctx, $domain_id, $filter) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{user_group_dao}->list($domain_id, $filter);
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
