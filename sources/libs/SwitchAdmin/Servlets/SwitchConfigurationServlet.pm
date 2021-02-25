# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Servlets::SwitchConfigurationServlet;

use strict;

use JSON;
use MIME::Base64;
use Log::Log4perl;
use Digest::Perl::MD5 qw(md5_hex);
use Wstk::Boolean;
use Wstk::WstkException;
use Wstk::WstkDefs qw(:ALL);
use SwitchAdmin::Defs qw(:ALL);
use SwitchAdmin::SipGuard;

sub new ($$;$) {
	my ( $class, $pmod) = @_;
	my $self = {
		logger          	 => Log::Log4perl::get_logger(__PACKAGE__),
		class_name 			 => $class,
		fsadmin        		 => $pmod,
        sec_mgr         	 => $pmod->{sec_mgr},
        cache_mgr			 => $pmod->{cache_mgr},
        switch_config_dao    => $pmod->dao_lookup('SwitchConfigDAO'),
        cid_profile_dao		 => $pmod->dao_lookup('SipCidProfileDAO'),
        sip_domain_dao		 => $pmod->dao_lookup('SipDomainDAO'),
        sip_user_dao		 => $pmod->dao_lookup('SipUserDAO'),
        sip_user_home_dao	 => $pmod->dao_lookup('SipUserHomeDirDAO'),
        sip_user_group_dao 	 => $pmod->dao_lookup('SipUserGroupDAO'),
        sip_profile_dao		 => $pmod->dao_lookup('SipProfileDAO'),
        sip_gateway_dao		 => $pmod->dao_lookup('SipGatewayDAO'),
        sip_context_dao		 => $pmod->dao_lookup('SipContextDAO'),
		sip_context_body_dao => $pmod->dao_lookup('SipContextBodyDAO')
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
	my $aurhorized = undef;
	my $auth_hdr = $ENV{'HTTP_AUTHORIZATION'};
	my $remote_ip = $ENV{'REMOTE_ADDR'};
	my $secret = $cgi->param('secret');		
	#
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
	if(defined $secret) {
		if ('true' eq $self->{fsadmin}->get_config('users', 'freeswitch_enable')) {
			my $pass = $self->{fsadmin}->get_config('users', 'freeswitch_secret');
			$aurhorized = ($pass eq $secret) ? 1 : undef;
		}		
	}
	unless($aurhorized) {
		die Wstk::WstkException->new('Permission denied', 403);
	}
	my $section = $cgi->param('section');

	if($section eq 'configuration') {
		do_generate_configuration($self, $cgi);
	} elsif ($section eq 'dialplan') {
		do_generate_dialplan($self, $cgi);
	} elsif ($section eq 'directory') {
		do_generate_directory($self, $cgi);
	} else {
		xmlcurl_send_not_found();
	}	
	return 1;
}

# ---------------------------------------------------------------------------------------------------------------------------------
sub do_generate_configuration {
	my ($self, $cgi) = @_;
	my $config_name = $cgi->param('key_value');
	#
	unless (defined $config_name) { 
		send_xmlcurl_not_found(); 
		return;
	}
	#
	if($config_name eq 'sofia.conf') {
		my $profiles = $self->{sip_profile_dao}->list();
		my $body = "<configuration name=\"sofia.conf\" description=\"\">\n<global_settings>\n</global_settings>\n<profiles>\n";
		for my $profile (@{$profiles}) {
			if(is_true($profile->enabled())) {
				my $gateways = $self->{sip_gateway_dao}->list($profile->id());			
				$body .= do_build_sofia_profile($self, $profile, $gateways);
			}			
		}
		$body .= "</profiles>\n</configuration>\n";
		#
		xmlcurl_send_configuration($self, $body);
		return 1;
	}
	my $body = undef; $@ = "";
	eval { 
		$body = $self->{switch_config_dao}->read_body($config_name); 
	} || do {
		my $exc = $@;		
		if(ref $exc eq 'Wstk::WstkException') {			
			if($exc->{code} == RPC_ERR_CODE_NOT_FOUND) { 
				$self->{logger}->warn("Configuration not found: ".$config_name);
				xmlcurl_send_not_found();  
				return 1;
			}
		}
		$self->{logger}->warn("Coldn't send configuration '".$config_name."'. error: ".$exc);
		die Wstk::WstkException->new('Internal error', 500);
	};
	xmlcurl_send_configuration($self, $body);
	return 1;
}

sub do_build_sofia_profile {
	my ($self, $profile, $gateways) = @_;
	my $out = "\n<profile name=\"".$profile->name()."\">\n";
	$out .= "<aliases></aliases>\n";
	$out .= "<domains>\n<domain name=\"all\" alias=\"true\" parse=\"false\"/>\n</domains>\n";
	# gateways
	$out .= "<gateways>\n";
	for my $gw (@{$gateways}) {
		if(is_true($gw->enabled())) {
			$out .= "<gateway name=\"".$gw->name()."\">\n";
			$out .= xmlcurl_param('register', $gw->register());
			$out .= xmlcurl_param('proxy', $gw->proxy()) if($gw->proxy());
			$out .= xmlcurl_param('realm', $gw->realm()) if($gw->realm());
			$out .= xmlcurl_param('username', $gw->username()) if($gw->username());
			$out .= xmlcurl_param('password', $gw->password()) if($gw->password());
			#
			$out .= xmlcurl_gen_params_from_json($gw->variables());
			#
			$out .= "</gateway>\n";
		}
	}
	$out .= "</gateways>\n";
	# profile settings
	$out .= "<settings>\n";
	$out .= xmlcurl_param('context', $profile->context());
	$out .= xmlcurl_param('inbound-codec-prefs', $profile->codecIn());	
	$out .= xmlcurl_param('outbound-codec-prefs', $profile->codecOut());	
	$out .= xmlcurl_param('sip-port', $profile->sipPort());
	$out .= xmlcurl_param('sip-ip', $profile->ipaddress());
	$out .= xmlcurl_param('rtp-ip', $profile->ipaddress());
	$out .= xmlcurl_param('ext-sip-ip', $profile->ipaddress());
	$out .= xmlcurl_param('ext-rtp-ip', $profile->ipaddress());
	$out .= xmlcurl_param('tls', $profile->tlsEnabled);
	$out .= xmlcurl_param('tls-sip-port', $profile->tlsPort());
	#
	$out .= xmlcurl_gen_params_from_json($profile->variables()); 
	#
	$out .= "</settings>\n";
	$out .= "</profile>\n";
	#
	return $out;
}
# ---------------------------------------------------------------------------------------------------------------------------------
sub do_generate_dialplan {
	my ($self, $cgi) = @_;
	my $user_agent = $cgi->param("variable_sip_user_agent");
	my $user_ip = $cgi->param("Caller-Network-Addr");
	my $ctx_name = $cgi->param("Caller-Context");
	#
	$self->{logger}->debug("Context request: context=$ctx_name");
	#
	if(guard_is_bot_ua($user_agent)) {
		$self->{logger}->warn("Request rejected by cause: bot detected. [context=$ctx_name, user-ip=$user_ip, user-agent=$user_agent]");
		xmlcurl_send_not_found();
		return 1;
	}
	unless (defined $ctx_name) {
		xmlcurl_send_not_found();
		return 1;
	}
	my $context = $self->{sip_context_dao}->lookup($ctx_name);
	unless($context) {
		$self->{logger}->warn("Unknown context: ".$ctx_name);
		xmlcurl_send_not_found();
		return 1;
	}
	my $body = undef;
	my $ctx_body = $self->{sip_context_body_dao}->read_body($context->id());
	#
	$body  = "<context name=\"".lc($context->name())."\">\n";
	$body .= (defined $ctx_body ? $ctx_body : '');
	$body .= "</context>\n";
	xmlcurl_send_dialplan($self, $body);
	return 1;
}

# ---------------------------------------------------------------------------------------------------------------------------------
sub do_generate_directory {
	my ($self, $cgi) = @_;	
	my $user_agent = $cgi->param("sip_user_agent");
	my $user_ip = $cgi->param("ip");
	my $purpose = $cgi->param("purpose");
	my $profile = $cgi->param("profile");
	my $user_name = $cgi->param("user");
	my $domain_name = $cgi->param("domain");
	my $action = $cgi->param("action");
	#
	if(guard_is_bot_ua($user_agent)) {		
		$self->{logger}->warn("Request rejected by cause: bot detected. [action=$action, user-ip=$user_ip, user-agent=$user_agent]");
		xmlcurl_send_not_found();
		return 1;
	}
	#
	$self->{logger}->debug("Directory request: action=$action, user=$user_name, domain=$domain_name");
	#
	if($purpose eq 'gateway') {	
		my $body = '';
		my $domains = $self->{sip_domain_dao}->list();
		for my $domain (@{$domains}) {
			$body .= "<domain name=\"".lc($domain->name())."\">\n";
			$body .= "<params>\n";
			$body .= xmlcurl_param('dial-string', $domain->dialString());
			$body .= "</params>\n";
			$body .= "<variables>\n";
			$body .= xmlcurl_gen_variables_from_json($domain->variables());
        	$body .= "</variables>\n";
        	$body .= "<user id=\"default\" />\n";        	
			$body .= "</domain>\n";
		}
		xmlcurl_send_directory($self, $body);
		return 1;
	}
	if($action eq 'sip_auth' || $action eq 'user_call' || $action eq 'message-count') {
		my $body = '';
		my $dup_map = {};
		my $sip_id = $user_name .'@'. $domain_name;
		#
		my $domain = $self->{sip_domain_dao}->lookup($domain_name);
		unless($domain) {
			$self->{logger}->warn("Unknown domain: ".$domain_name. " [action=$action, user=$sip_id, ip=$user_ip]");
			xmlcurl_send_not_found(); 
			return 1;
		}
		my $user = $self->{sip_user_dao}->lookup($sip_id);
		unless($user || is_false($user->enabled())) { 
			$self->{logger}->warn("User not found or disabled: ".$sip_id);
			xmlcurl_send_not_found(); 
			return 1; 
		}
		my $group = $self->{sip_user_group_dao}->get($user->groupId());
		unless($group) {
			$self->{logger}->warn("Unknown group id: ".$user->groupId(). " [action=$action, user=$sip_id, ip=$user_ip]");
			xmlcurl_send_not_found(); 
			return 1;			
		}		
		my $cid_profile = (defined $user->cidProfile() ? $self->{cid_profile_dao}->lookup($user->cidProfile()) : undef);
		my $outbound_cid_name = (defined $user->outboundCidName() 
			? $user->outboundCidName() 
			: (defined $cid_profile && defined $cid_profile->cidName()) 
			? $cid_profile->cidName() : $user->name() );
		my $outbound_cid_number = (defined $user->outboundCidNumber() 
			? $user->outboundCidNumber() 
			: (defined $cid_profile && defined $cid_profile->cidNumber()) 
			? $cid_profile->cidNumber() : undef );
		my $user_home_abs_path = $self->{sip_user_home_dao}->get_abs_path($user);
		my $user_recordings_abs_path = $self->{sip_user_home_dao}->get_abs_path($user, SwitchAdmin::DAO::SipUserDAO::RECORDINGS_PATH_NAME);
		my $user_voicemails_abs_path = $self->{sip_user_home_dao}->get_abs_path($user, SwitchAdmin::DAO::SipUserDAO::VOICEMAILS_PATH_NAME);
		#---
		$body .= "<domain name=\"".lc($domain->name())."\">\n";
		$body .= "<params>\n";
		$body .= xmlcurl_param('dial-string', $domain->dialString());
		$body .= "</params>\n";
		$body .= "<groups>\n";
		$body .= "<group name=\"".lc($group->name())."\">\n";
		$body .= "<users>\n";
		$body .= "<user id=\"".$user->number()."\" cacheable=\"60000\">\n"; # 60sec
		$body .= "<params>\n";
		#$body .= xmlcurl_param('password', $user->sipPassword());
		$body .= xmlcurl_param('a1-hash', md5_hex($user_name.':'.$domain_name.':'.$user->sipPassword()));
		$body .= xmlcurl_param('vm-password', $user->vmPassword);
		$body .= "</params>\n";
		$body .= "<variables>\n";
		# basic
		$body .= xmlcurl_variable('accountcode', $user->accountCode(), $dup_map);
		$body .= xmlcurl_variable('user_context', $user->context(), $dup_map);
		$body .= xmlcurl_variable('effective_caller_id_name', (defined $user->effectiveCidName() ? $user->effectiveCidName() : $user->name()), $dup_map);  
		$body .= xmlcurl_variable('effective_caller_id_number', (defined $user->effectiveCidNumber() ? $user->effectiveCidNumber() : $user->number()), $dup_map);  
  		$body .= xmlcurl_variable('outbound_caller_id_name', $outbound_cid_name, $dup_map);  
  		$body .= xmlcurl_variable('outbound_caller_id_number', $outbound_cid_number, $dup_map);  
		# extended
		$body .= xmlcurl_variable('x_user_id', $user->id(), $dup_map);
		$body .= xmlcurl_variable('x_user_name', $user->name() , $dup_map);
		$body .= xmlcurl_variable('x_user_domain', $domain->name() , $dup_map);
		$body .= xmlcurl_variable('x_user_script', $user->script(), $dup_map);
		$body .= xmlcurl_variable('x_user_language', $user->language() , $dup_map);
		$body .= xmlcurl_variable('x_user_fwd_number', $user->fwdNumber() , $dup_map);		
		$body .= xmlcurl_variable('x_user_home', $user_home_abs_path, $dup_map);
		$body .= xmlcurl_variable('x_user_recordings_path', $user_recordings_abs_path, $dup_map);
		$body .= xmlcurl_variable('x_user_voicemails_path', $user_voicemails_abs_path, $dup_map);
		$body .= xmlcurl_variable('x_user_allow_longdistance_calls', $user->allowLongDistanceCalls(), $dup_map);
		$body .= xmlcurl_variable('x_user_allow_international_calls', $user->allowInternationalCalls(), $dup_map);
		$body .= xmlcurl_variable('x_user_allow_local_calls', $user->allowLocalCalls(), $dup_map);
		#
		$body .= xmlcurl_gen_variables_from_json($user->variables(), $dup_map);
		$body .= xmlcurl_gen_variables_from_json($group->variables(), $dup_map);
		#
		$body .= "</variables>\n";
		$body .= "</user>\n</users>\n</group>\n</groups>\n</domain>";
		xmlcurl_send_directory($self, $body);
		#
		$dup_map = undef;
		return 1;
	}
	xmlcurl_send_not_found();
	return 1;
}

# ---------------------------------------------------------------------------------------------------------------------------------
# helper methods
# ---------------------------------------------------------------------------------------------------------------------------------
sub send_response {
	my ($self, $body ) = @_;
	print "Content-type: text/xml; charset=UTF-8\n";
	print "Date: " . localtime(time()) . "\n\n";
	print $body;
}

sub xmlcurl_send_not_found {
	print "Content-type: text/xml; charset=UTF-8\n";
	print "Date: " . localtime(time()) . "\n\n";
	print '<?xml version="1.0" encoding="UTF-8" standalone="no" ?>' . "\n\n";
	print "<document type=\"freeswitch/xml\">\n<section name=\"result\">\n<result status=\"not found\"/>\n</section>\n</document>\n";	
}

sub xmlcurl_send_configuration {
	my ($self, $body) = @_;
	print "Content-type: text/xml; charset=UTF-8\n";
	print "Date: " . localtime(time()) . "\n\n";
	print '<?xml version="1.0" encoding="UTF-8" standalone="no" ?>' . "\n\n";
	print "<document type=\"freeswitch/xml\">\n<section name=\"configuration\">\n";
	print $body;
	print "\n</section>\n</document>\n";
}

sub xmlcurl_send_dialplan {
	my ($self, $body) = @_;
	print "Content-type: text/xml; charset=UTF-8\n";
	print "Date: " . localtime(time()) . "\n\n";
	print '<?xml version="1.0" encoding="UTF-8" standalone="no" ?>' . "\n\n";
	print "<document type=\"freeswitch/xml\">\n<section name=\"dialplan\">\n";
	print $body;
	print "\n</section>\n</document>\n";
}

sub xmlcurl_send_directory {
	my ($self, $body) = @_;
	print "Content-type: text/xml; charset=UTF-8\n";
	print "Date: " . localtime(time()) . "\n\n";
	print '<?xml version="1.0" encoding="UTF-8" standalone="no" ?>' . "\n\n";
	print "<document type=\"freeswitch/xml\">\n<section name=\"directory\">\n";
	print $body;
	print "\n</section>\n</document>\n";
}

sub xmlcurl_param {
	my ($name, $val, $dup_map) = @_;
	if(defined $dup_map && $dup_map->{$name}) {
		return '';
	}
	my $out = "<param name=\"".xml_escape($name)."\" value=\"".(defined $val ? xml_escape($val) : '')."\" />\n";
	if(defined $dup_map) { $dup_map->{$name} = 1; }
	return $out;	
}

sub xmlcurl_variable {
	my ($name, $val, $dup_map) = @_;
	if(defined $dup_map && $dup_map->{$name}) {
		return '';
	}
	my $out = "<variable name=\"".xml_escape($name)."\" value=\"".(defined $val ? xml_escape($val) : '')."\" />\n";
	if(defined $dup_map) { $dup_map->{$name} = 1; }
	return $out;
}

sub xmlcurl_gen_params_from_json {
	my ($vars_json, $dup_map) = @_;
	unless($vars_json) { 
		return ''; 
	}
	my $out = '';	
	my $vars = from_json($vars_json);
	foreach my $var (@{$vars}) {
		if(is_true($var->{enabled})) {
			$out .= xmlcurl_param($var->{name}, $var->{value}, $dup_map);
		}
	}
	return $out;
}

sub xmlcurl_gen_variables_from_json {
	my ($vars_json, $dup_map) = @_;
	unless($vars_json) { 
		return ''; 
	}
	my $out = '';
	my $vars = from_json($vars_json);	
	foreach my $var (@{$vars}) {
		if(is_true($var->{enabled})) {
			$out .= xmlcurl_variable($var->{name}, $var->{value}, $dup_map);
		}
	}
	return $out;
}

sub xml_escape {
	my ($val) = @_;
	unless (defined $val) {
		return $val;
	}
	#$val =~ s/&/&amp;/sg;
	#$val =~ s/</&lt;/sg;
	#$val =~ s/>/&gt;/sg;
	$val =~ s/"/&quot;/sg;
	return $val;
}


1;