# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Services::SwitchSoundsManagementService;

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
        sound_dao	    => $pmod->dao_lookup('SwitchSoundDAO')
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
    return $self->{sound_dao}->mkdir($file_item);
}
     
sub rpc_rename {
	my ($self, $sec_ctx, $new_name, $file_item) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{sound_dao}->rename($new_name, $file_item);
}
    
sub rpc_move {
	my ($self, $sec_ctx, $from, $to) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{sound_dao}->move($from, $to);
}
    
sub rpc_copy {
    my ($self, $sec_ctx, $from, $to) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{sound_dao}->copy($from, $to);
}

sub rpc_delete {
    my ($self, $sec_ctx, $path) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return ($self->{sound_dao}->delete($path) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
}

sub rpc_getMeta {
    my ($self, $sec_ctx, $path) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{sound_dao}->get_meta($path);
}

sub rpc_browse {
	my ($self, $sec_ctx, $path, $filter) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    return $self->{sound_dao}->browse($path, $filter);
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
