# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Services::AuthenticationService;

use strict;

use Log::Log4perl;
use Digest::SHA::PurePerl qw(sha1_hex);
use Wstk::Boolean;
use Wstk::Models::AuthenticationResponse;
use SwitchAdmin::Defs qw(:ALL);

sub new ($$;$) {
	my ( $class, $pmod ) = @_;
	my $self = {
		logger          	=> Log::Log4perl::get_logger(__PACKAGE__),
		class_name      	=> $class,
		fsadmin           	=> $pmod,
        sec_mgr         	=> $pmod->{sec_mgr}
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
sub rpc_login {
	my ( $self, $sec_ctx, $login, $password, $captcha ) = @_;
	my $sec_mgr = $self->{sec_mgr};
    #	    
	unless(defined($login) || defined($password)) {
		return undef 	
	}
	my $admin_name = $self->{fsadmin}->get_config('users', 'admin_name');
	my $admin_pass = $self->{fsadmin}->get_config('users', 'admin_secret');
	my $admin_enable = $self->{fsadmin}->get_config('users', 'admin_enable');

	my $digest_type = 0;	
	my $remote_seed = undef;
	my $local_password = undef;
	my $remote_password = $password;
	
	if($password =~ /^DIGEST\s(.*)\:(.*)$/) {
		$remote_seed = $1; $remote_password = $2; $digest_type = 1;
	} elsif($password =~ /^DIGEST2\s(.*)\:(.*)$/) {		
		$remote_seed = $1; $remote_password = $2; $digest_type = 2;		
	} else {
		$self->{logger}->warn("Unsupported auth type: plain, client-ip: ".$sec_ctx->{remoteIp});
		return undef;		
	}
	
	if (($admin_enable eq 'true') && ($admin_name eq $login)) {
		if($digest_type == 1) {
			$local_password = sha1_hex($remote_seed . $admin_pass);
		} elsif($digest_type == 2) {
			$local_password = sha1_hex($remote_seed . sha1_hex($admin_pass));
		}
		if($local_password ne $remote_password) {
			$self->{logger}->warn("Password mismatch for user: ".$login.", client-ip: ".$sec_ctx->{remoteIp});
			return undef;
		}
		my $sid = $sec_mgr->session_create($login, 'Administrator',  ROLE_ADMIN);
		my $o = Wstk::Models::AuthenticationResponse->new(sessionId => $sid); 
		$o->properties('title', 'Administrator');
		$o->properties('workplace', ROLE_ADMIN);	
		#
		$self->{logger}->warn("User logged in: ".$login." / ".ROLE_ADMIN.", remote-ip: ".$sec_ctx->{remoteIp});
		return $o;
	}
	
	$self->{logger}->warn("Unknown user: ".$login.", remote-ip: ".$sec_ctx->{remoteIp});
	return undef;
}

sub rpc_lgout {
	my ( $self, $sec_ctx ) = @_;
	my $sec_mgr = $self->{sec_mgr};
	#
	my $ident = $self->{sec_mgr}->identify($sec_ctx);
	$self->{sec_mgr}->pass($ident, [ROLE_ADMIN]);
	#
    $sec_mgr->session_delete($ident->{sid});
}

sub rpc_ping {
	my ( $self, $sec_ctx ) = @_;	
    my $ident = $self->{sec_mgr}->identify($sec_ctx);
}

1;
