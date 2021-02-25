package SwitchAdmin::VarDictionaries;
# --------------------------------------------------------------------------------------------------------------------------------
use constant SIP_GATEWAY_VARS => [
	{enabled=>'true',  name => 'expire-seconds',  		value => '60', 		description => 'expire in seconds: *optional* 3600, if blank'},
	{enabled=>'true',  name => 'retry-seconds', 		value => '30', 		description => 'How many seconds before a retry when a failure or timeout occurs'},
	{enabled=>'true',  name => 'ping',					value => '25', 		description => 'send an options ping every x seconds, failure will unregister and/or mark it down'},
	{enabled=>'false', name => 'register-transport',	value => 'udp', 	description => 'username to use in from: *optional* same as  username, if blank'},
	{enabled=>'false', name => 'cid-type',				value => 'rpid', 	description => ''},
	{enabled=>'false', name => 'rfc-5626',				value => 'true', 	description => ''},
	{enabled=>'false', name => 'register-proxy',  		value => '', 		description => 'send register to this proxy: *optional* same as proxy, if blank'},
	{enabled=>'false', name => 'from-user',   			value => '', 		description => 'username to use in from: *optional* same as  username, if blank'},
	{enabled=>'false', name => 'from-domain', 			value => '', 		description => 'domain to use in from: *optional* same as  realm, if blank'},
	{enabled=>'false', name => 'extension',   			value => '', 		description => 'extension for inbound calls: *optional* same as username, if blank'},
	{enabled=>'false', name => 'contact-params', 		value => '', 		description => 'extra sip params to send in the contact'},
	{enabled=>'false', name => 'caller-id-in-from', 	value => 'false',	description => 'Use the callerid of an inbound call in the from field on outbound calls via this gateway'},
	{enabled=>'false', name => 'extension-in-contact',	value => 'true', 	description => 'Put the extension in the contact'},
	{enabled=>'false', name => 'reg-id',				value => '1', 		description => ''}
];

use constant SIP_PROFILE_VARS => [
	{enabled=>'true', name => 'debug',  					value => '0', 				description => ''},
	{enabled=>'true', name => 'sip-trace',  				value => 'no', 				description => ''},
	{enabled=>'true', name => 'sip-capture',  				value => 'no', 				description => ''},
	{enabled=>'true', name => 'rfc2833-pt',  				value => '101', 			description => ''},	
	{enabled=>'true', name => 'dialplan',  					value => 'XML', 			description => ''},
	{enabled=>'true', name => 'dtmf-duration',  			value => '2000', 			description => ''},
	{enabled=>'true', name => 'hold-music',  				value => '$${hold_music}', 	description => ''},
	{enabled=>'true', name => 'rtp-timer-name',  			value => 'soft', 			description => ''},
	{enabled=>'true', name => 'local-network-acl',  		value => 'localnet.auto', 	description => ''},
	{enabled=>'true', name => 'apply-nat-acl', 				value => 'nat.auto',		description => ''},
	{enabled=>'true', name => 'auth-calls', 				value => 'true', 			description => ''},
	{enabled=>'true', name => 'manage-presence',  			value => 'true', 			description => ''},
	{enabled=>'true', name => 'presence-privacy', 			value => 'false', 			description => ''},
	{enabled=>'true', name => 'inbound-codec-negotiation', 	value => 'generous', 		description => ''},
	{enabled=>'true', name => 'nonce-ttl', 					value => '60', 				description => ''},		
	{enabled=>'true', name => 'inbound-late-negotiation', 	value => 'true', 			description => ''},
	{enabled=>'true', name => 'inbound-zrtp-passthru', 		value => 'true', 			description => ''},
	{enabled=>'true', name => 'rtp-timeout-sec', 			value => '300', 			description => ''},
	{enabled=>'true', name => 'rtp-hold-timeout-sec', 		value => '1800', 			description => ''},
	{enabled=>'true', name => 'log-auth-failures', 			value => 'false', 			description => ''},
	{enabled=>'true', name => 'forward-unsolicited-mwi-notify', value => 'false',		description => ''},	
	{enabled=>'true', name => 'record-path', 				value => '$${recordings_dir}',description => ''},
	{enabled=>'true', name => 'record-template', 			value => '${caller_id_number}.${target_domain}.${strftime(%Y-%m-%d-%H-%M-%S)}.wav',description => ''},
	{enabled=>'true', name => 'watchdog-enabled', 			value => 'no',				description => ''},	
	{enabled=>'true', name => 'watchdog-step-timeout', 		value => '30000',			description => ''},
	{enabled=>'true', name => 'watchdog-event-timeout', 	value => '30000',			description => ''},
	# should be disabled for fmulti-tenant mode
	{enabled=>'false', name => 'apply-inbound-acl', 		value => 'domains',			description => ''},	
	{enabled=>'false', name => 'presence-hosts', 			value => '$${domain},$${local_ip_v4}', description => ''},
	{enabled=>'false', name => 'force-register-domain', 	value => '$${domain}', 		description => ''},		
	{enabled=>'false', name => 'force-subscription-domain', value => '$${domain}', 		description => ''},	
	{enabled=>'false', name => 'force-register-db-domain',	value => '$${domain}', 		description => ''},	
	# other
	{enabled=>'false', name => 'inimum-session-expires', 	value => '120', 			description => ''},	
	{enabled=>'false', name => 'aggressive-nat-detection', 	value => 'false', 			description => ''},	
	{enabled=>'false', name => 'tls-only', 					value => 'false', 			description => ''},
	{enabled=>'false', name => 'tls-bind-params', 			value => 'transport=tls', 	description => ''},
	{enabled=>'false', name => 'tls-passphrase', 			value => '', 				description => ''},
	{enabled=>'false', name => 'tls-verify-date', 			value => 'true', 			description => ''},
	{enabled=>'false', name => 'tls-verify-policy', 		value => 'none', 			description => ''},
	{enabled=>'false', name => 'tls-verify-depth', 			value => '2', 				description => ''},
	{enabled=>'false', name => 'tls-verify-in-subjects',	value => '', 				description => ''},
	{enabled=>'false', name => 'tls-version',				value => 'tlsv1,tlsv1.1,tlsv1.2', 	description => ''}
];

use constant SIP_DOMAIN_VARS => [];

use constant SIP_USER_GROUP_VARS => [];

use constant SIP_USER_VARS => [];

use constant VARS_MAP => {
	'SipGateway' 	=> SIP_GATEWAY_VARS,
	'SipProfile'	=> SIP_PROFILE_VARS,
	'SipDomain'  	=> SIP_DOMAIN_VARS,
	'SipUserGroup' 	=> SIP_USER_GROUP_VARS,
	'SipUser' 	 	=> SIP_USER_VARS
};

# --------------------------------------------------------------------------------------------------------------------------------
1;