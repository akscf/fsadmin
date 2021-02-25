#!/usr/bin/perl
# *****************************************************************************************
# bootstrap script
#
# Copyright (C) AlexandrinKS
# https://akscf.me/
# *****************************************************************************************
$| = 1;
use POSIX;
use Getopt::Std;
use Config::INI::Simple;
use UUID::Tiny ':std';
use Wstk::WstkDaemon;

# -------------------------------------------------------------------------------------
my $WSTKD     = undef;
my $RET_CODE = 0;
my $CONFIG   = undef;
my $GHOME    = undef;

# -------------------------------------------------------------------------------------
# INIT
# -------------------------------------------------------------------------------------
getopt( 'ha', \%opts );
$GHOME = $opts{'h'};
if ( !defined( $opts{'h'} ) || !defined( $opts{'a'} ) ) {
	main_usage();
	exit(1);
}
if ( $opts{'a'} eq 'start' ) {
	main_start();
	exit($RET_CODE);	
}
elsif ( $opts{'a'} eq 'stop' ) {
	main_stop();
	exit($RET_CODE);
}
print STDERR "FATAL: unsupported action '" . $opts->{'a'} . "'\n";
exit(1);

# -------------------------------------------------------------------------------------
# FUNCTIONS
# -------------------------------------------------------------------------------------
sub hlp_ldconfig {
	my $cfname = $GHOME . '/configs/wstkd.conf';
	$CONFIG = Config::INI::Simple->new($cfname);
	unless(keys(%$CONFIG) ) {
		# default settings		
		$CONFIG->{'server'}->{'id'}  			= create_uuid_as_string(UUID_V4);
		$CONFIG->{'server'}->{'address'}  		= "127.0.0.1";
		$CONFIG->{'server'}->{'port'}     		= "8080";
		$CONFIG->{'server'}->{'workers'}		= "10";
		$CONFIG->{'server'}->{'welcome_file'} 	= 'index.html';
		$CONFIG->{'server'}->{'www_root'} 		= 'default';
		$CONFIG->{'server'}->{'www_enable'} 	= 'false';
		$CONFIG->{'server'}->{'gid'} 			= 'undef';
		$CONFIG->{'server'}->{'uid'} 			= 'undef';
		#
		$CONFIG->write($cfname);
		print STDERR "WARN: Configuration file not found, default configuration was created: configs/wstkd.cfg\n";
		return (0);
	}
	return 1;
}

# -------------------------------------------------------------------------------------
# MAIN
# -------------------------------------------------------------------------------------
sub main_usage {
	print STDERR "usage: wstkd.pl -h app_home -a [start|stop]\n";
}

sub main_start {
	return unless(hlp_ldconfig());
	$WSTKD = Wstk::WstkDaemon->new($GHOME, $CONFIG);
	eval {
			$WSTKD->start();
			$WSTKD->loop();
			} || do {
			my $exc = $@;
			print STDERR $exc . "\n";
			}
}

sub main_stop {
	return unless ( hlp_ldconfig() );
	$WSTKD = WSP::WspCore->new($GHOME, $CONFIG);
	$WSTKD->stop();
}
