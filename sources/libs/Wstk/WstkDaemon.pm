# *****************************************************************************************
#
# (C)2018 aks
# https://github.com/akscf/
# *****************************************************************************************
package Wstk::WstkDaemon;

use strict;

use Wstk::WstkException;
use Wstk::WstkDefs;
use Wstk::JSON;
use Wstk::Models::SearchFilter;
use Wstk::Models::AuthenticationResponse;
use Log::Log4perl;
use Shared::Hash;
use Config::INI::Simple;

use constant RPC_PATH => '/rpc/';
use constant WEBSOCK_PATH => '/ws/';

# --------------------------------------------------------------------------------------------------------------------------------------------------------------
# constructior
# --------------------------------------------------------------------------------------------------------------------------------------------------------------
sub new ($$;$) {
	my ( $class, $home, $config ) = @_;
	my $self = {
		class_name  => $class,
		version     => 1.8,
		home        => $home,
		config      => $config,
		config_path => $home . '/configs',
		tmp_path    => $home . '/tmp',
		var_path    => $home . '/var',
		log_path    => $home . '/log',
		www_path    => $home . '/www',                	  # default
		www_enable  => 0,
		ws_enable	=> 0,
		pid_file    => $home . '/var/wstkd.pid',
		modules     => [],                                # list of instances
		servlets    => {},                                # path => instance
		services    => {},
		cfgmgr      => {},
		mapi		=> {},
		dhash       => undef,
		mapper		=> undef, 								# json mapper
		flags       => { running => 0, shutdown => 0 },
	};
	bless( $self, $class );
	#
	Log::Log4perl::init( $home . '/configs/log4perl.conf' );
	$self->{logger} = Log::Log4perl::get_logger("Wstk::WstkDaemon");
	$self->{mapper} = Wstk::JSON->new(auto_bless => 1, use_aliases => 1);
	#
	if($self->{mapper}->{use_aliases}) {
		$self->{mapper}->alias_register('SearchFilter', Wstk::Models::SearchFilter::CLASS_NAME);
		$self->{mapper}->alias_register('AuthenticationResponse', Wstk::Models::AuthenticationResponse::CLASS_NAME);
	}
	#
	return $self;
}

sub get_class_name {
	my ($self) = @_;
	return $self->{class_name};
}

# --------------------------------------------------------------------------------------------------------------------------------------------------------------
# CTL METHODS
# --------------------------------------------------------------------------------------------------------------------------------------------------------------
# start instance
sub start {
	my ($self) = @_;

	# setup sinal hanlers
	foreach my $key ( keys %SIG ) {
		$SIG{$key} = 'IGNORE';
	}
	$SIG{HUP} = sub { _signal_hndler_instance_reload_cfg($self); };
	$SIG{TERM} = $SIG{INT} = sub { stop($self); };

	# required dirs
	my $var_path = $self->{'var_path'};
	my $tmp_path = $self->{'tmp_path'};
	my $log_path = $self->{'log_path'};
	mkdir($var_path) unless ( -d $var_path );
	mkdir($tmp_path) unless ( -d $tmp_path );
	mkdir($log_path) unless ( -d $log_path );

	# www root
	my $www_path = _get_configuration( $self, 'server', 'www_root' );
	$self->{'ws_enable'} = ( _get_configuration( $self, 'server', 'ed_enable' ) eq 'true' ? 1 : 0 );
	$self->{'www_enable'} = ( _get_configuration( $self, 'server', 'www_enable' ) eq 'true' ? 1 : 0 );
	if ( $self->{'www_enable'} ) {
		$www_path = ( $www_path eq 'default' ? $self->{'www_path'} : $www_path );
		$self->{'www_path'} = $www_path;
		mkdir($www_path) unless ( -d $www_path );
		$self->{logger}->debug( "www home: " . $www_path);
	} 
	# check on other instance is running
	my $pid = _pid_read($self);
	if($pid > 0) {
		if(_pid_is_alive( $self, $pid )) {
			die Wstk::WstkException->new("Instance already running, pid=$pid");
		}
		_pid_delete($self);
	}
	_pid_write($self);

	# init hash
	$self->{dhash} = Shared::Hash->new(
		persist => 0,
		path    => $var_path . "/ipc_default.data"
	  ),

	# init and start http server
	$self->{httpd} = Wstk::Core::HttpServerSimple->new($self);
	$self->servlet_register(RPC_PATH, Wstk::Core::RpcServlet->new($self));
	# websocket
	if($self->{'ws_enable'}) {
		$self->servlet_register(WEBSOCK_PATH, Wstk::Core::WebsocketServlet->new($self));
	}

	# load modules
	my $mdirs = [];
	_list_dirs($self, $self->{home} . '/modules', sub { push(@{$mdirs}, shift ); } );
	$mdirs = [ sort { $a cmp $b } @{$mdirs} ];

	for my $dir (@$mdirs) {
		_list_files($self, $dir,
			sub {
				my $mfile = shift;
				next if ( $mfile !~ /\.pm$/ );

				# load
				$@ = "";
				my $minst = eval("require(\"$mfile\")");
				unless ($minst) {
					die Wstk::WstkException->new("Couldn't load module: $@");
				}
				if ( !exists( $minst->{class_name} ) ) {
					die Wstk::WstkException->new("Couldn't identify class: $mfile");
				}

				# init
				$@ = "";
				eval { $minst->init($self); 1; } || do {
					my $exc = $@;
					die Wstk::WstkException->new( "Couldn't init module: " . $minst->get_class_name() . ", error: " . $exc );
				};
				my $class_name = $minst->get_class_name();
				push( @{ $self->{modules} }, $minst );

				#
				$self->{'logger'}->debug("Module loaded: $class_name");
			}
		);
	}

	# start modules
	my $modules = $self->{modules};
	foreach my $minst (@$modules) {
		$@ = "";
		eval { $minst->start(); 1;} || do {
			my $exc = $@;
			die Wstk::WstkException->new( "Couldn't start module: " . $minst->get_class_name() . ", error: " . $exc );
		}
	}

	# set flags
	$self->{flag}->{running} = 1;
}

#
# stop instance
#
sub stop {
	my ($self) = @_;
	#
	if ( $self->{flag}->{running} ) {
		$self->{flag}->{shutdown} = 1;
	}
	else {
		my $pid = _pid_read($self);
		if ( $pid < 0 ) {
			$self->{logger}->warn("Instance is not running!");
		}
		else {
			_pid_terminate( $self, $pid );
		}
	}
}

#
# main loop
#
sub loop {
	my ($self) = @_;
	my $group = _get_configuration( $self, 'server', 'group' );
	my $user  = _get_configuration( $self, 'server', 'user' );
	$self->{httpd}
	  ->run(
		# see details: https://metacpan.org/pod/Net::Server::Fork
		server_revision => "Apache/2.1.0",
		server_type => 'Fork', 	# 'PreFork'
		port => _get_configuration( $self, 'server', 'port' ),
		host => _get_configuration( $self, 'server', 'address' ),
		group => ( $group eq 'undef' ? undef : $group ),
		user  => ( $user eq 'undef'  ? undef : $user ),
		max_servers    => _get_configuration( $self, 'server', 'workers' ),
		min_servers    => 1,
		check_for_dead => 30 # sec
	  );
}

# --------------------------------------------------------------------------------------------------------------------------------------------------------------
# PUBLIC API
# --------------------------------------------------------------------------------------------------------------------------------------------------------------
sub rpc_service_register {
	my ( $self, $service_name, $instance ) = @_;
	#
	unless ($service_name) {
		die Wstk::WstkException->new("Invalid argument: service_name");
	}
	unless ($instance) {
		die Wstk::WstkException->new("Invalid argument: instance");
	}
	#
	my $services = $self->{'services'};
	#
	if ( exists( $services->{$service_name} ) ) {
		$self->{logger}->warn("Service has overwritten: $service_name");
	}
	$services->{$service_name} = $instance;
}

sub rpc_service_unregister {
	my ( $self, $service_name ) = @_;
	#
	unless ($service_name) {
		die Wstk::WstkException->new("Invalid argument: service_name");
	}
	my $services = $self->{'services'};
	delete( $services->{$service_name} );
}

sub rpc_service_lookup {
	my ( $self, $service_name ) = @_;
	#
	unless ($service_name) {
		return undef;
	}
	my $services = $self->{'services'};
	unless ( exists( $services->{$service_name}) ) {
		return undef;
	}
	return $services->{$service_name};
}

sub servlet_register {
	my ( $self, $path, $instance ) = @_;
	#
	unless ($path) {
		die Wstk::WstkException->new("Invalid argument: path");
	}
	unless ($instance) {
		die Wstk::WstkException->new("Invalid argument: instance");
	}
	#
	my $servlets = $self->{'servlets'};
	my $wilcard = ($path =~ /\*$/ ? 1 : 0);
	$path = lc($path);
	$path =~ s/\*|\s//g;
	#
	if (exists($servlets->{$path})) {
		$self->{logger}->warn("Servlet has been overwritten: $path");
	}
	$servlets->{$path} = { instance => $instance, wilcard => $wilcard };
}

sub servlet_unregister {
	my ( $self, $path ) = @_;
	#
	unless ($path) {
		die Wstk::WstkException->new("Invalid argument: path");
	}
	#
	my $servlets = $self->{'servlets'};
	$path = lc($path);
	$path =~ s/\*|\s//g;
	delete( $servlets->{$path} );
}

sub servlet_lookup {
	my ( $self, $uri ) = @_;
	#
	unless ($uri) {
		return undef;
	}
	my $path     = lc($uri);
	my $servlets = $self->{'servlets'};
	my $e = $servlets->{$path};	
	unless ($e) { 
		# by wilcard
		return undef; 
	}
	return $e->{instance};
}

sub mapper_alias_register {
	my ($self, $alias, $type) = @_;
	$self->{mapper}->alias_register($alias, $type);
}

sub mapper_alias_unregister {
	my ($self, $alias) = @_;
	$self->{mapper}->alias_unregister($alias);
}

sub mapper_alias_lookup {
	my ($self, $alias) = @_;
	return $self->{mapper}->alias_lookupa($alias);
}

sub mapi_register {
	my ($self, $module_name, $api) = @_;
	#
	unless ($module_name) {
		die Wstk::WstkException->new("Invalid argument: module_name");
	}
	unless ($api) {
		die Wstk::WstkException->new("Invalid argument: api");
	}
	#
	my $mapi = $self->{'mapi'};
	if (exists($mapi->{$module_name})) {
		die Wstk::WstkException->new("API already exists: $module_name");
	}
	$mapi->{$module_name} = $api;
}

sub mapi_unregister {
	my ($self, $module_name) = @_;
	#
	unless ($module_name) {
		die Wstk::WstkException->new("Invalid argument: module_name");
	}
	my $mapi = $self->{'mapi'};
	delete($mapi->{$module_name});
}

sub mapi_lookup {
	my ($self, $module_name) = @_;
	#
	unless ($module_name) {
		return undef;
	}
	my $mapi = $self->{'mapi'};
	unless(exists($mapi->{$module_name})) {
		return undef;
	}
	return $mapi->{$module_name};
}

sub sdb_put {
	my ( $self, $key, $value ) = @_;
	my $h = $self->{dhash};
	$h->set( $key => $value );
}

sub sdb_get {
	my ( $self, $key ) = @_;
	my $h = $self->{dhash};
	return $h->get($key);
}

sub cfg_exists {
	my ( $self, $cfg_name ) = @_;
	my $cfg_id = lc($cfg_name);
	my $cfg_file = _cfg_make_file_name( $self, $cfg_id );
	#
	return 1 if ( -e $cfg_file );
}

sub cfg_load {
	my ( $self, $cfg_name, $callback_fill_default ) = @_;
	my $cfg_id   = lc($cfg_name);
	my $cfg_file = _cfg_make_file_name( $self, $cfg_id );
	my $cfgmgr   = $self->{cfgmgr};
	my $cfg      = Config::INI::Simple->new($cfg_file);
	#
	unless ( keys(%$cfg) ) {
		if ($callback_fill_default) {
			$callback_fill_default->($cfg);
			$cfg->write($cfg_file);
		}
	}
	$cfgmgr->{$cfg_id} = $cfg;
	return $cfg;
}

sub cfg_save {
	my ( $self, $cfg_name ) = @_;
	my $cfg_id   = lc($cfg_name);
	my $cfg_file = _cfg_make_file_name( $self, $cfg_id );
	my $cfgmgr   = $self->{cfgmgr};
	my $cfg      = $cfgmgr->{$cfg_id};
	#
	return undef unless ($cfg);
	$cfg->write($cfg_file);
	#
	return 1;
}

sub cfg_get {
	my ( $self, $cfg_name, $section, $property ) = @_;
	my $cfg_id = lc($cfg_name);
	my $cfgmgr = $self->{cfgmgr};
	my $cfg    = $cfgmgr->{$cfg_id};
	#
	return undef unless ($cfg);
	return $cfg unless ( $section || $property );    # all config
	                                                 #
	$section = 'default' unless ( defined($section) );
	return $cfg->{$section}->{$property};
}

sub cfg_set {
	my ( $self, $cfg_name, $section, $property, $value ) = @_;
	my $cfg_id = lc($cfg_name);
	my $cfgmgr = $self->{cfgmgr};
	my $cfg    = $cfgmgr->{$cfg_id};
	#
	return undef unless ($cfg);
	$section = 'default' unless ( defined($section) );
	$cfg->{$section}->{$property} = $value;
	return 1;
}

sub get_path {
	my ( $self, $name ) = @_;
	return $self->{'home'}        if ( $name eq 'home' );
	return $self->{'var_path'}    if ( $name eq 'var' );
	return $self->{'tmp_path'}    if ( $name eq 'tmp' );
	return $self->{'log_path'}    if ( $name eq 'log' );
	return $self->{'www_path'}    if ( $name eq 'www' );
	return $self->{'config_path'} if ( $name eq 'cfg' );
	#
	return undef;
}

# --------------------------------------------------------------------------------------------------------------------------------------------------------------
# PRIVATE
# --------------------------------------------------------------------------------------------------------------------------------------------------------------
# get a path with home prefix
sub _cfg_make_file_name {
	my ( $self, $cfg_id ) = @_;
	if ( $cfg_id !~ /\.conf$/ ) {
		$cfg_id .= '.conf';
	}
	return $self->{config_path} . '/' . $cfg_id;
}

sub _get_configuration {
	my ( $self, $section, $property ) = @_;

	unless ( $section || $property ) {
		return $self->{config};
	}
	my $cfg = $self->{config};

	unless ( exists( $cfg->{$section} ) ) {
		return undef;
	}
	return $cfg->{$section}->{$property};
}

sub _list_dirs {
	my ( $self, $base, $cb ) = @_;
	#
	opendir( DIR, $base ) || die Wstk::WstkException->new("Couldn't read directory: $!");
	while( my $file = readdir(DIR) ) {
		my $cdir = "$base/$file";
		$cb->($cdir) if ( -d $cdir && ( $file ne "." && $file ne ".." ) );
	}
	closedir(DIR);
}

sub _list_files {
	my ( $self, $base, $cb ) = @_;
	#
	opendir( DIR, $base ) || die Wstk::WstkException->new("Couldn't read directory: $!");
	while ( my $file = readdir(DIR) ) {
		my $cfile = "$base/$file";
		$cb->($cfile) if ( -f $cfile );
	}
	closedir(DIR);
}

sub _pid_read {
	my ($self) = @_;
	#
	return -1 unless ( -e $self->{pid_file} );
	#
	open( my $x, "<" . $self->{pid_file} ) || die Wstk::WstkException->new("Couldn't read pid file: $! (" . $self->{pid_file} . ")" );
	my $lpid = <$x>;
	close($x);
	chomp($lpid);
	#
	return $lpid;
}

sub _pid_write {
	my ($self) = @_;
	#
	open( my $x, ">" . $self->{pid_file} ) || die Wstk::WstkException->new("Couldn't write pid file: $! (" . $self->{pid_file} . ")" );
	print( $x "$$\n" );
	close($x);
}

sub _pid_delete {
	my ($self) = @_;
	#
	unlink( $self->{pid_file} );
}

sub _pid_terminate {
	my ( $self, $pid ) = @_;
	#
	kill 'TERM', $pid;
}

sub _pid_is_alive {
	my ( $self, $pid ) = @_;
	#
	return 0 unless ( kill( 0, $pid ) );
	return 1;
}

sub _signal_hndler_instance_reload_cfg {
	#	
}

# --------------------------------------------------------------------------------------------------------------------------------------------------------------
# Helper
# --------------------------------------------------------------------------------------------------------------------------------------------------------------
{
	package Wstk::Core::WebsocketServlet;
	sub new ($$;$) {
		my ( $class, $wstk ) = @_;
		my $self = {
			class_name => $class,
			wstk        => $wstk,
			json        => $wstk->{mapper},
			
		};
		bless( $self, $class );
		$self->{'logger'} = Log::Log4perl::get_logger("Wstk::Core::WebsocketServlet");
		return $self;
	}

	sub get_class_name {
		my ($self) = @_;
		return $self->{class_name};
	}

	sub execute_request {
		my ( $self, $cgi ) = @_;
		#
		# todo
		#
		die Wstk::WstkException->new("Not implemented", 501);
	}
}

# --------------------------------------------------------------------------------------------------------------------------------------------------------------
{
	package Wstk::Core::RpcServlet;
	use MIME::Base64;	
	
	sub new ($$;$) {
		my ( $class, $wstk ) = @_;
		my $self = {
			class_name => $class,
			wstk        => $wstk,
			json        => $wstk->{mapper},
			
		};
		bless( $self, $class );
		$self->{'logger'} = Log::Log4perl::get_logger("Wstk::Core::RpcServlet");
		return $self;
	}

	sub get_class_name {
		my ($self) = @_;
		return $self->{class_name};
	}

	sub execute_request {
		my ( $self, $cgi ) = @_;
		my $rpcrq = undef;
		#
		eval {			
			$rpcrq = $self->{json}->decode( $cgi->param('POSTDATA') );
			unless ( exists( $rpcrq->{id} )
				|| exists( $rpcrq->{service} )
				|| exists( $rpcrq->{method} )
				|| exists( $rpcrq->{params} ) )
			{
				die Wstk::WstkException->new( "Bad request", 400 );
			}
		} or do {
			my $exc = $@;
			if ( ref $exc eq 'Wstk::WstkException' ) {
				die $exc;
			}
			$self->{'logger'}->error( "Couldn't decode json data: " . $exc );
			die Wstk::WstkException->new( "Internal Server Error", 500 );
		};
		my $service = $self->{'wstk'}->rpc_service_lookup( $rpcrq->{'service'} );
		unless ($service) {
			$self->send_response(
				{
					id     => $rpcrq->{'id'},
					result => undef,
					error  => {
						origin  => Wstk::WstkDefs::RPC_ORIGIN_SERVER,
						code    => Wstk::WstkDefs::RPC_ERROR_SERVICE_NOT_FOUND,
						message => 'Service not found'
					}
				}
			);
			return 1;
		}
		if ( $rpcrq->{'method'} !~ /^[_.a-zA-Z0-9]+$/ ) {
			$self->send_response(
				{
					id     => $rpcrq->{'id'},
					result => undef,
					error  => {
						origin  => Wstk::WstkDefs::RPC_ORIGIN_SERVER,
						code    => Wstk::WstkDefs::RPC_ERROR_ILLEGAL_SERVICE,
						message => 'Illegal service'
					}
				}
			);
			return 1;
		}

		#
		my $method = 'rpc_' . $rpcrq->{'method'};
		my $mtst   = $service->get_class_name() . '::' . $method;
		unless ( defined( &{$mtst} ) ) {
			$self->send_response(
				{
					id     => $rpcrq->{'id'},
					result => undef,
					error  => {
						origin  => Wstk::WstkDefs::RPC_ORIGIN_SERVER,
						code    => Wstk::WstkDefs::RPC_ERROR_METHOD_NOT_FOUND,
						message => $rpcrq->{'method'}
					}
				}
			);
			return 1;
		}

		# decode header if pesent
		my $credentials = undef;
		my $auth_hdr    = $ENV{'HTTP_AUTHORIZATION'};
		if ($auth_hdr) {
			my ( $basic, $ucred ) = split( ' ', $auth_hdr );
			if ($basic) {
				my ( $user, $pass ) = split( ':', decode_base64($ucred) );
				if ( defined($user) && defined($pass) ) {
					$credentials =
					  { method => $basic, user => $user, password => $pass };
				}
			}
		}
		my $crealip = $cgi->http('X-REAL-IP');
		my $security_context = {
			time       	=> time(),
			sessionId 	=> $cgi->http("X-SESSION-ID"),
			userData	=> $cgi->http("X-USER-DATA"),
			userAgent	=> $cgi->http("HTTP_USER_AGENT"),
			remoteIp   	=> ($crealip ? $crealip : $ENV{'REMOTE_ADDR'}),
			credentials => $credentials
		};
		#
		my $result;
		$@ = '';
		eval {
			$result = $service->$method( $security_context, @{ $rpcrq->{'params'} } );
		};
		if ($@) {
			my $exc = $@;
			if ( ref $exc eq 'Wstk::WstkException' ) {
				$self->send_response(
					{
						id     => $rpcrq->{'id'},
						result => undef,
						error  => {
							origin  => Wstk::WstkDefs::RPC_ORIGIN_METHOD,
							code    => $exc->{'code'},
							message => $exc->{'message'}
						}
					}
				);
			}
			else {
				$self->send_response(
					{
						id     => $rpcrq->{'id'},
						result => undef,
						error  => {
							origin => Wstk::WstkDefs::RPC_ORIGIN_METHOD,
							code   => Wstk::WstkDefs::RPC_ERR_CODE_INTERNAL_ERROR,
							message => 'See log for details'
						}
					}
				);
			}
			$self->{logger}->error( "Exception on call method ($mtst) :  " . $exc );
		}
		else {
			$self->send_response({ id => $rpcrq->{'id'}, result => $result, error => undef } );
		}
		return 1;
	}

	sub send_response {
		my ( $self, $response ) = @_;
		print "Content-type: application/json; charset=UTF-8\n";
		print "Date: " . localtime( time() ) . "\n\n";
		print $self->{json}->encode($response);
	}
};

# ------------------------------------------------------------------------------------------------------------------------------------------------------
{
	package Wstk::Core::HttpServerSimple;
	use CGI;
	use base qw(Net::Server::HTTP);

	sub new {
		my ( $class, @args ) = @_;
		my $self = $class->SUPER::new(@args);
		#
		$self->{logger} = Log::Log4perl::get_logger("Wstk::Core::HttpServerSimple");
		$self->{'server'}->{'no_exit_on_close'} = 0;
		$self->{'server'}->{logger}             = $self->{logger};
		$self->{'server'}->{'wstk'}             = $args[0];
		#
		return $self;
	}

	sub pre_server_close_hook {
		my ($self) = @_;
		my $modules = $self->{'server'}->{'modules'};
		foreach my $minst ( reverse(@$modules) ) {
			$@ = "";
			eval { $minst->stop(); 1; } || do {
				my $exc = $@;
				$self->{logger}->warn( "Exception on trying to stop module: "
					  . $minst->get_class_name()
					  . ", error: "
					  . $exc );
			  }
		}
		$self->{'server'}->{'wstk'}->_pid_delete();
	}

	# only for modified PreFork.pm !!!
	sub idle_loop_hook2 {
		my ($self) = @_;
		return
		  if ( $self->{'server'}->{'flag'}->{'shutdown'} );

	}

	sub process_http_request {
		my ($self)   = @_;
		my $cgi      = CGI->new;
		my $wstk     = $self->{'server'}->{'wstk'};
		my $www_root = $wstk->get_path('www');
		my $servlet  = $wstk->servlet_lookup( $cgi->path_info() );

		unless ($servlet) {
			if ( $wstk->{'www_enable'} ) {
				if ( $ENV{'REQUEST_METHOD'} eq 'GET' ) {
					my $fname = $cgi->path_info();
					$fname =~ s/\.\.|\%|\\|\||\>|\<//g;
					if ( $fname eq '/' ) {
						$fname = '/' . $wstk->_get_configuration( 'server', 'welcome_file' ) if ( $fname eq '/' );
					}
					my $ep = $www_root . $fname;
					my $r = open( my $fh, '<', $ep );
					if ($r) {
						print $cgi->header;
						while ( my $line = <$fh> ) { print $line; }
						close($fh);
						return;
					}
				}
			}
			print "Status: 404 Not Found\n";
			print "Content-Type: text/html; charset=UTF-8\n";
			print "Date: " . localtime( time() ) . "\n\n";
			print "<title>404 Not Found</title>\n";
			print "<h1>404 Not Found</h1>\n";
			return;
		}
		$@ = "";
		eval { $servlet->execute_request($cgi); } || do {
			my $exc = $@;
			if ($exc) {
				if ( ref $exc eq 'Wstk::WstkException' ) {
					if ( $exc->{'code'} < 1000 && $exc->{'code'} > 0) {
						$self->{logger}->warn( "Failed to execute servlet: " . $servlet->get_class_name() . ", error: " . $exc );
						print "Status: " . $exc->{'code'} . ' ' . $exc->{'message'} . "\n";
						print "Content-Type: text/html; charset=UTF-8\n";
						print "Date: " . localtime( time() ) . "\n\n";
						print "<title>" . $exc->{'code'} . ' ' . $exc->{'message'} . "</title>\n";
						print "<h1>" . $exc->{'code'} . ' ' . $exc->{'message'} . "</h1>\n";
						return;
					}
				}
				$self->{logger}->warn( "Failed to execute servlet: " . $servlet->get_class_name() . ", error: " . $exc || $cgi->cgi_error );
				print "Status: 500 Internal Server Error\n";
				print "Content-Type: text/html; charset=UTF-8\n";
				print "Date: " . localtime( time() ) . "\n\n";
				print "\n";
				print "<title>500 Internal Server Error</title>\n";
				print "<h1>500 Internal Server Error</h1>\n";
				return;
			}
		}
	}
}
#
1;
