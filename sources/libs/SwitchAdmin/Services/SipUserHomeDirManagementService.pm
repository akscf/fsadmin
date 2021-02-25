# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Services::SipUserHomeDirManagementService;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use Wstk::WstkDefs qw(:ALL);
use Wstk::EntityHelper qw(is_digit);
use SwitchAdmin::Defs qw(:ALL);

sub new ($$;$) {
	my ( $class, $pmod ) = @_;
	my $self = {
		logger          => Log::Log4perl::get_logger(__PACKAGE__),
		class_name      => $class,
		fsadmin         => $pmod,
        sec_mgr         => $pmod->{sec_mgr},
        user_dao        => $pmod->dao_lookup('SipUserDAO'),
        userdir_dao	    => $pmod->dao_lookup('SipUserHomeDirDAO')
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
	my ($self, $sec_ctx, $userId, $file_item) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    my $user = undef;
    if(is_digit($userId)) { $user = $self->{user_dao}->get($userId); }
    else { $user = $self->{user_dao}->lookup($userId); }
    unless($user) { 
        die Wstk::WstkException->new('User '.$userId, RPC_ERR_CODE_NOT_FOUND); 
    }
    return $self->{userdir_dao}->mkdir($user, $file_item);
}

sub rpc_mkfile {
	my ($self, $sec_ctx, $userId, $file_item) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    my $user = undef;
    if(is_digit($userId)) { $user = $self->{user_dao}->get($userId); }
    else { $user = $self->{user_dao}->lookup($userId); }
    unless($user) { 
        die Wstk::WstkException->new('User '.$userId, RPC_ERR_CODE_NOT_FOUND); 
    }
	return $self->{userdir_dao}->mkfile($user, $file_item);
}
        
sub rpc_rename {
	my ($self, $sec_ctx, $userId, $new_name, $file_item) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    my $user = undef;
    if(is_digit($userId)) { $user = $self->{user_dao}->get($userId); }
    else { $user = $self->{user_dao}->lookup($userId); }
    unless($user) { 
        die Wstk::WstkException->new('User '.$userId, RPC_ERR_CODE_NOT_FOUND); 
    }
    return $self->{userdir_dao}->rename($user, $new_name, $file_item);
}
    
sub rpc_move {
	my ($self, $sec_ctx, $userId, $from, $to) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    my $user = undef;
    if(is_digit($userId)) { $user = $self->{user_dao}->get($userId); }
    else { $user = $self->{user_dao}->lookup($userId); }
    unless($user) { 
        die Wstk::WstkException->new('User '.$userId, RPC_ERR_CODE_NOT_FOUND); 
    }
    return $self->{userdir_dao}->move($user, $from, $to);
}
    
sub rpc_delete {
    my ($self, $sec_ctx, $userId, $path) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    my $user = undef;
    if(is_digit($userId)) { $user = $self->{user_dao}->get($userId); }
    else { $user = $self->{user_dao}->lookup($userId); }
    unless($user) { 
        die Wstk::WstkException->new('User '.$userId, RPC_ERR_CODE_NOT_FOUND); 
    }
    return ($self->{userdir_dao}->delete($user, $path) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
}

sub rpc_getMeta {
    my ($self, $sec_ctx, $userId, $path) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    my $user = undef;
    if(is_digit($userId)) { $user = $self->{user_dao}->get($userId); }
    else { $user = $self->{user_dao}->lookup($userId); }
    unless($user) { 
        die Wstk::WstkException->new('User '.$userId, RPC_ERR_CODE_NOT_FOUND); 
    }
    return $self->{userdir_dao}->get_meta($user, $path);
}

sub rpc_browse {
	my ($self, $sec_ctx, $userId, $path, $filter) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    my $user = undef;
    if(is_digit($userId)) { $user = $self->{user_dao}->get($userId); }
    else { $user = $self->{user_dao}->lookup($userId); }
    unless($user) { 
        die Wstk::WstkException->new('User '.$userId, RPC_ERR_CODE_NOT_FOUND); 
    }
    return $self->{userdir_dao}->browse($user, $path, $filter);
}

sub rpc_readBody {
    my ($self, $sec_ctx, $userId, $path) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    my $user = undef;
    if(is_digit($userId)) { $user = $self->{user_dao}->get($userId); }
    else { $user = $self->{user_dao}->lookup($userId); }
    unless($user) { 
        die Wstk::WstkException->new('User '.$userId, RPC_ERR_CODE_NOT_FOUND); 
    }
    return $self->{scrip_dao}->read_body($user, $path);
}

sub rpc_writeBody {
    my ($self, $sec_ctx, $userId, $path, $data) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    my $user = undef;
    if(is_digit($userId)) { $user = $self->{user_dao}->get($userId); }
    else { $user = $self->{user_dao}->lookup($userId); }
    unless($user) { 
        die Wstk::WstkException->new('User '.$userId, RPC_ERR_CODE_NOT_FOUND); 
    }
    return ($self->{scrip_dao}->write_body($user, $path, $data) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
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
