# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Services::SwitchScriptsManagementService;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use Wstk::WstkDefs qw(:ALL);
use SwitchAdmin::Defs qw(:ALL);

sub new ($$;$) {
	my ( $class, $pmod ) = @_;
	my $self = {
		logger          => Log::Log4perl::get_logger(__PACKAGE__),
		class_name      => $class,
		fsadmin         => $pmod,
        sec_mgr         => $pmod->{sec_mgr},
        scrip_dao	    => $pmod->dao_lookup('SwitchScriptDAO')
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
sub rpc_mkdir {
	my ($self, $sec_ctx, $file_item) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{scrip_dao}->mkdir($file_item);
}

sub rpc_mkfile {
	my ($self, $sec_ctx, $file_item) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
	return $self->{scrip_dao}->mkfile($file_item);
}
        
sub rpc_rename {
	my ($self, $sec_ctx, $new_name, $file_item) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{scrip_dao}->rename($new_name, $file_item);
}
    
sub rpc_move {
	my ($self, $sec_ctx, $from, $to) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{scrip_dao}->move($from, $to);
}
    
sub rpc_delete {
    my ($self, $sec_ctx, $path) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return ($self->{scrip_dao}->delete($path) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
}

sub rpc_getMeta {
    my ($self, $sec_ctx, $path) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{scrip_dao}->get_meta($path);
}

sub rpc_browse {
	my ($self, $sec_ctx, $path, $filter) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{scrip_dao}->browse($path, $filter);
}

sub rpc_readBody {
    my ($self, $sec_ctx, $path) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    return $self->{scrip_dao}->read_body($path);    
}

sub rpc_writeBody {
    my ($self, $sec_ctx, $path, $data) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return ($self->{scrip_dao}->write_body($path, $data) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
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
