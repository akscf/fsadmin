# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::EslClient;

use POSIX;
use Fcntl;
use IO::Socket;
use Wstk::WstkException;

sub new ($$;$) {
    my ($class, $pmod) = @_;
    my $self = {
        logger          => Log::Log4perl::get_logger(__PACKAGE__),
        class_name      => $class,
        fsadmin         => $pmod,
        esl_ip			=> $pmod->get_config('esl', 'address'),
        esl_port		=> $pmod->get_config('esl', 'port'),
        esl_password	=> $pmod->get_config('esl', 'password'),
        els_enabled		=> ($pmod->get_config('esl', 'enabled') eq 'true' ? 1 : 0),
        con_timeout		=> 5
    };
    bless( $self, $class );
    return $self;
}

sub get_class_name {
    my ($self) = @_;
    return $self->{class_name};
}

# ---------------------------------------------------------------------------------------------------------------------------------
sub connect {
	my ($self) = @_;
	#
	unless($self->{els_enabled}) {
		return 0;
	}
	$self->{socket} = IO::Socket::INET->new(
		PeerAddr => $self->{esl_ip}, 
		PeerPort => $self->{esl_port}, 
		Proto => 'tcp', 
		Type => SOCK_STREAM, 
		Timeout => $self->{con_timeout}
	);
	unless($self->{socket}) {
		die Wstk::WstkException->new("Coldn't connect to the server: ".$@);
	}
	set_nonblock($self, $self->{socket});
	#
	my ($buf, $err, $st) = (undef, undef, 0);
	my $exp = (time() + 3);
	while($exp > time()) {
		$err = sysread($self->{socket}, $buf, 1024);		
		if($err > 0) {
			if($st == 0) {
				if($buf =~ /Content-Type: auth\/request/) {
					$err = $self->{socket}->send('auth '.$self->{esl_password}."\n\n");
					unless(defined $err) { 
						$self->{socket}->close();
						die Wstk::WstkException->new("Send fail"); 
					}
					$st = 1; $exp = (time() + 2); 
				}
			} elsif($st == 1) {
				if($buf =~ /Reply-Text: \-ERR invalid/) {
					$st = -1; last;
				} elsif ($buf =~ /Reply-Text: \+OK accepted/) {
					$st = 2; last;
				}
			}
		}
		select(undef, undef, undef, 0.1);
	}
	if($st != 2) {
		close($self);
		die Wstk::WstkException->new("Connect fail (auth error)");
	}
	return 1;
}      

sub destroy {
	my ($self) = @_;
	#
	unless($self->{els_enabled}) {
		return 0;
	}
	if(defined $self->{socket}) {
		$self->{socket}->shutdown(SHUT_WR);
		$self->{socket}->close();
	}
	return 1;
}      

sub exec_bgapi {
	my ($self, $cmd, $destroy_after) = @_;
	#
	unless($self->{els_enabled}) {
		die Wstk::WstkException->new("Event socket client is disabled");
	}
	unless(defined $self->{socket}) {
		die Wstk::WstkException->new("Event socket not connected");
	}
	if($cmd) {
		my $err = $self->{socket}->send('bgapi '.$cmd."\n\n");
		unless(defined $err) { 
			if($destroy_after) { destroy($self); }
			die Wstk::WstkException->new("Send fail"); 
		}
	}	
	my ($buffer, $err, $body) = (undef, undef, undef);
	my $exp = (time() + 5);	
	while($exp > time()) {
		$err = sysread($self->{socket}, $buffer, 1024);
		if($err > 0) {
			if(length($buffer) > 0) {
				if($buffer =~ /Reply-Text: \-ERR (.*)$/) {
					$body = '-ERR '.$1."\n"; 
					last LOUT;
				}
				while($buffer =~ /([^\n]+)\n?/g) {
					my $line = $1;
					if($line =~ /Reply-Text: (.*)$/) {
						$body = $1."\n"; 
						last;
					}
				}
				last if($body);
			}
		}
		select(undef, undef, undef, 0.1);
	}
	LOUT:
	if($destroy_after) { 
		destroy($self); 
	}
	unless($body) {
		die Wstk::WstkException->new("No response from server");
	}
	return $body;
}

sub exec_api {
	my ($self, $cmd, $destroy_after) = @_;
	#
	unless($self->{els_enabled}) {
		die Wstk::WstkException->new("Event socket client is disabled");
	}
	unless(defined $self->{socket}) {
		die Wstk::WstkException->new("Event socket not connected");
	}	
	if($cmd) {
		my $err = $self->{socket}->send('api '.$cmd."\n\n");
		unless(defined $err) { 
			if($destroy_after) { destroy($self); }
			die Wstk::WstkException->new("Send fail"); 
		}
	}	
	my ($buffer, $err, $body, $bread, $bsize, $bofs) = (undef, undef, undef, 0, 0, 0);
	my $exp = (time() + 10);
	while($exp > time()) {
		$err = sysread($self->{socket}, $buffer, 1024);
		if($err > 0) {
			if(length($buffer) > 0) {
				if($buffer =~ /Reply-Text: \-ERR (.*)$/) {
					$body = '-ERR '.$1."\n"; 
					last LOUT;
				}
				if($bsize == 0) {
					while($buffer =~ /([^\n]+)\n?/g) {
						my $line = $1; $bofs += (length($line) + 1);
						if ($line =~ /Content-Type\: (\S+)$/) {
							next;
						} elsif ($line =~ /Content-Length\: (\d+)$/) {
							$bsize = $1; $bofs += 1; # +1 is a content delimiter
							$buffer = substr($buffer, $bofs);
						}
					}
				}
				$body .= $buffer;
				$bread = length($body);
				$exp = (time() + 10); 
				last if($bread >= $bsize);
				next;
			}
		}
		select(undef, undef, undef, 0.1);
	}
	LOUT:
	if($destroy_after) { 
		destroy($self); 
	}
	unless($body) {
		die Wstk::WstkException->new("No response from server");
	}
	return $body;
}      

sub parse_error {
	my ($self, $buffer) = @_;
	my $err = undef;
	while($buffer =~ /([^\n]+)\n?/g) {
		if($buffer =~ /-ERR (.*)$/) {
			$err = $1; last;
		}
	}
	return $err;
}

# ---------------------------------------------------------------------------------------------------------------------------------
sub set_nonblock {
	my ($self, $soc) = @_;
	my $flags = fcntl($soc, F_GETFL, 0) || die WSTK::WstkException->new("fcntl: ".$!);
	fcntl($soc, F_SETFL, $flags | O_NONBLOCK) || die WSTK::WstkException->new("fcntl: ".$!);
	return 1;
}

1;
