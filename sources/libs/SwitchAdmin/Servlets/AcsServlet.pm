# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::Servlets::AcsServlet;

use strict;

use JSON;
use Log::Log4perl;
use MIME::Base64;
use Wstk::Boolean;
use Wstk::WstkException;
use Wstk::WstkDefs qw(:ALL);
use SwitchAdmin::Defs qw(:ALL);
use Wstk::EntityHelper qw(is_empty);
use SwitchAdmin::DateHelper qw(iso_datetime_now);

sub new ($$;$) {
	my ( $class, $pmod) = @_;
	my $self = {
		logger          	=> Log::Log4perl::get_logger(__PACKAGE__),
		class_name 			=> $class,
		fsadmin        		=> $pmod,
        sec_mgr         	=> $pmod->{sec_mgr},
        cache_mgr			=> $pmod->{cache_mgr},
        user_dao			=> $pmod->dao_lookup('SipUserDAO'),
        device_dao			=> $pmod->dao_lookup('SipDeviceDAO'),
        device_line_dao		=> $pmod->dao_lookup('SipDeviceLineDAO'),
        template_dao		=> $pmod->dao_lookup('DocTemplateDAO'),
        template_body_dao	=> $pmod->dao_lookup('DocTemplateBodyDAO')
	};
	bless( $self, $class );
	return $self;
}

sub get_class_name {
	my ($self) = @_;
	return $self->{class_name};
}

sub execute_request {
	my ( $self, $cgi ) = @_;
	my $auth_hdr = $ENV{'HTTP_AUTHORIZATION'};
	my $remote_ip = $ENV{'REMOTE_ADDR'};
	my $mac = $cgi->param('mac');
	my $secret = $cgi->param('secret');	
	#
	unless(defined($mac)) {
		die Wstk::WstkException->new('Missing parameter: mac', 400);
	}
	unless(defined($secret)) {
		if ($auth_hdr) {
			my ($basic, $ucred) = split(' ', $auth_hdr);
			if ($basic) {
				my ( $user, $pass ) = split( ':', decode_base64($ucred) );
				if ( defined($user) && defined($pass) ) {
					$secret = $pass;
				}
			}
		}
	}
	unless($secret) {
		die Wstk::WstkException->new('Missing parameter: secret', 400);
	}	
	my $device = $self->{device_dao}->lookup($mac);
	if(!$device || is_false($device->enabled())) {
		die Wstk::WstkException->new('Device not found or disabled', 404);
	}
	if(is_empty($device->secret()) || $secret ne $device->secret()) {
		die Wstk::WstkException->new('Permission denied', 403);
	}
	my $lines = $self->{device_line_dao}->get_lines_by_device($device->id());
	# update ip and access date
	$self->{device_dao}->update_ip($device->id(), $remote_ip, iso_datetime_now());
	# 
	if(is_empty($device->driver())) {
		$self->{logger}->warn("No driver defined for device '".$mac."'");
		die Wstk::WstkException->new("No driver defined", 503);
	}
	if(is_empty($device->template())) {
		$self->{logger}->warn("No template defined for device '".$mac."'");
		die Wstk::WstkException->new("No template defined", 503);
	}
	my $driver = $self->{fsadmin}->driver_lookup($device->driver());
	unless ($driver) {
		$self->{logger}->error("Driver not found: ".$device->driver()." (".$mac.")");
		die Wstk::WstkException->new("Driver not found", 500);
	}
	my $template = $self->{template_dao}->lookup($device->template());
	unless ($template) {
		$self->{logger}->error("Template not found: ".$device->template()." (".$mac.")");
		die Wstk::WstkException->new("Template not found", 500);
	}
	my $tbody = $self->{template_body_dao}->read_body($template->id());
	if(is_empty($tbody)) {
		$self->{logger}->error("Template '".$device->template()."' has a mpty body!");
		die Wstk::WstkException->new("Malformed template", 500);
	}
	# fill-in the vars map
	my $vars = {
		acs_url	  => $self->{fsadmin}->get_config('acs', 'url'),
		id 		  => $device->id(),
		model	  => $device->model(),
		hwAddress => $device->hwAddress(),
		ipAddress => ($device->ipAddress() ? $device->ipAddress() : '')
	};
	if($lines) {
		foreach my $l (@{$lines}) {
			my $prefix = 'line'.$l->lineId().'_';
			$vars->{$prefix.'enabled'} = ($l->enabled() == 1 ? 'true' : 'false');
			$vars->{$prefix.'password'} = ($l->password() ? $l->password() : '');
			$vars->{$prefix.'number'} = ($l->number() ? $l->number() : '');
			$vars->{$prefix.'realm'} = ($l->realm() ? $l->realm() : '');
			$vars->{$prefix.'proxy'} = ($l->proxy() ? $l->proxy() : '');
			if($l->variables()) {
				my $vmap = from_json($l->variables());
				foreach my $var (@{$vmap}) {
					if(is_true($var->{enabled})) {
						$vars->{$prefix.$var->{name}} = (!defined $var->{value} ? '' : $var->{value});
					}					
				}
			}
		}		
	}
	# fill-in driver props
	my $drv_props = {};
	if($device->driverProperties()) {
		my $vmap = from_json($device->driverProperties());
		foreach my $var (@{$vmap}) {
			if(is_true($var->{enabled})) {
				$drv_props->{$var->{name}} = $var->{value};
			}
		}
	}
	#
	my $config = undef;
	$@ = "";
	eval { $config = $driver->build_config($tbody, $drv_props, $vars); 1; } || do {
		my $exc = $@;
		$self->{logger}->error("Fail to build config! Device=".$mac.", driver=".$device->driver().", error=".$exc);
		die Wstk::WstkException->new("Internal error, see logs", 500);
	};
	send_response($self, $config);
	return 1;
}

# ---------------------------------------------------------------------------------------------------------------------------------
# helper methods
# ---------------------------------------------------------------------------------------------------------------------------------
sub send_response {
	my ($self, $response ) = @_;
	print "Content-type: text/plain; charset=UTF-8\n";
	print "Date: " . localtime( time() ) . "\n\n";
	print $response;
}

1;
