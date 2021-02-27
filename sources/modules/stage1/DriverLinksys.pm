# *********************************************************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# *********************************************************************************************************************************
package DriverLinksys;

use Log::Log4perl;
use Wstk::WstkDefs qw(:ALL);
use Wstk::WstkException;
use SwitchAdmin::Models::DriverInfo;

use constant DRIVER_NAME => 'Linksys';

sub new ($$;$) {
        my ($class) = @_;
        my $self = {
                logger      	=> Log::Log4perl::get_logger(__PACKAGE__),
                class_name  	=> $class,
                version     	=> 1.0,
                description 	=> "",
                wstk         	=> undef
        };
        bless( $self, $class );
        return $self;
}

sub get_class_name {
	my ($self) = @_;
	return $self->{class_name};
}

#---------------------------------------------------------------------------------------------------------------------------------
sub init {
	my ($self, $wstk) = @_;
	$self->{'wstk'} = $wstk;
}

sub start {
	my ($self) = @_;

	my $fsapi = $self->{'wstk'}->mapi_lookup('SwitchAdmin');
	unless ($fsapi) {
		die Wstk::WstkException->new("Missing module: SwitchAdmin");		
	}	
	$fsapi->driver_register(
		SwitchAdmin::Models::DriverInfo->new(name => DRIVER_NAME, description => 'Suitable for any SPA/PAP models'), 
		DriverLinksys::API->new()
	);
}

sub stop {
	my ($self) = @_;	
}

#---------------------------------------------------------------------------------------------------------------------------------
sub get_config {
	my ($self, $section, $property) = @_;
	my $wstk = $self->{wstk}; 
	return $wstk->cfg_get(CONFIG_NAME, $section, $property);	
}

#---------------------------------------------------------------------------------------------------------------------------------
{
	package DriverLinksys::API;
	use Wstk::WstkDefs qw(:ALL);
	use Wstk::EntityHelper qw(is_empty);	
	use Wstk::WstkException;
	use HTTP::Request::Common;
	use LWP::UserAgent;	
	use JSON;

	sub new ($$;$) {
        my ($class) = @_;
        my $self = {
			logger     => Log::Log4perl::get_logger('DriverLinksys'),
            class_name => $class,
        };
        bless( $self, $class );
        return $self;
	}

	sub get_class_name {
		my ($self) = @_;
		return $self->{class_name};
	}

	#------------------------------------------------------------------------------------------------------------------------------------------
	# Driver api
	#------------------------------------------------------------------------------------------------------------------------------------------
	sub get_properties_dict {
		my ($self) = @_;
		return [
			{enabled=>'true', name => 'admin_password', value => '', description => 'it may necessary for reboot/sync commands'}
		];
	}

	sub bool_to_linksys {
		my ($self, $val) = @_;
		return 'Yes' if(lc($val) eq 'true');
		return 'No'  if(lc($val) eq 'false');
		return $val;
	}

	# called from ACS servlet
	sub build_config {
		my ($self, $template, $drv_props, $vars) = @_;
		my $config = $template;
		unless ($vars) {
			die Wstk::WstkException->new("vars", RPC_ERR_CODE_INVALID_ARGUMENT);
		}
		if(is_empty($template)) {
			die Wstk::WstkException->new("Template is empty", RPC_ERR_CODE_INTERNAL_ERROR);
		}		
		for my $key (%{$vars}) {
			my $val = bool_to_linksys($self, $vars->{$key});
			$config =~ s/\%$key\%/$val/g;
		}
		$config =~ s/\%line\d+\_enabled\%/No/g;
		$config =~ s/\%(\S+)\%//g;
		return $config;
	}
	
	sub reprovision {
		my ($self, $device, $drv_props) = @_;
		unless ($device) {
			die Wstk::WstkException->new("device", RPC_ERR_CODE_INVALID_ARGUMENT);
		}
		unless ($drv_props) {
			die Wstk::WstkException->new("drv_props", RPC_ERR_CODE_INVALID_ARGUMENT);
		}
		if(is_empty($device->ipAddress())) {
			die Wstk::WstkException->new("Device doesn't have IP", RPC_ERR_CODE_INTERNAL_ERROR);
		}
		#		
		my $url = 'http://'.$device->ipAddress().'/admin/resync?'.$drv_props->{acs_url}.'/?mac=$MAC&secret='.$device->secret();
		my $ua = LWP::UserAgent->new(timeout => 5);
		my $req = GET $url;
		if($drv_props->{admin_password}) { 
			$req->authorization_basic('admin', $drv_props->{admin_password}); 
		}
		my $resp = $ua->request($req);
		if($resp->is_success) { return 1; }
		#
		die Wstk::WstkException->new("Reprovision fail! Device response: ".$resp->status_line, RPC_ERR_CODE_INTERNAL_ERROR);
	}
	
	sub reboot {
		my ($self, $device, $drv_props) = @_;
		unless ($device) {
			die Wstk::WstkException->new("device", RPC_ERR_CODE_INVALID_ARGUMENT);
		}
		unless ($drv_props) {
			die Wstk::WstkException->new("drv_props", RPC_ERR_CODE_INVALID_ARGUMENT);
		}
		if(is_empty($device->ipAddress())) {
			die Wstk::WstkException->new("Device doesn't have IP", RPC_ERR_CODE_INTERNAL_ERROR);
		}
		#
		my $url = 'http://'.$device->ipAddress().'/admin/reboot';
		my $ua = LWP::UserAgent->new(timeout => 5);
		my $req = GET $url;
		if($drv_props->{admin_password}) { 
			$req->authorization_basic('admin', $drv_props->{admin_password}); 
		}
		my $resp = $ua->request($req);
		if($resp->is_success) { return 1; }
		#
		die Wstk::WstkException->new("Reboot fail! Device response: ".$resp->status_line, RPC_ERR_CODE_INTERNAL_ERROR);
	}	
}

#---------------------------------------------------------------------------------------------------------------------------------
return DriverLinksys->new();

