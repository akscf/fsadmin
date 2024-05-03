# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::Servlets::BlobsHelperServlet;

use strict;

use Log::Log4perl;
use MIME::Base64;
use Wstk::WstkException;
use Wstk::WstkDefs qw(:ALL);
use SwitchAdmin::Defs qw(:ALL);
use SwitchAdmin::IOHelper qw(io_get_file_size);

sub new ($$;$) {
	my ( $class, $pmod) = @_;
	my $self = {
		logger          	=> Log::Log4perl::get_logger(__PACKAGE__),
		class_name 			=> $class,
		fsadmin        		=> $pmod,
        sec_mgr         	=> $pmod->{sec_mgr},
        context_dao			=> $pmod->dao_lookup('SipContextDAO'),
        template_dao		=> $pmod->dao_lookup('DocTemplateDAO'),
        switch_config_dao	=> $pmod->dao_lookup('SwitchConfigDAO'),
        switch_script_dao	=> $pmod->dao_lookup('SwitchScriptDAO'),
        swith_sound_dao		=> $pmod->dao_lookup('SwitchSoundDAO'),
        swith_record_dao	=> $pmod->dao_lookup('SwitchRecordingDAO'),
        sip_user_dao		=> $pmod->dao_lookup('SipUserDAO'),
        sip_user_home_dao	=> $pmod->dao_lookup('SipUserHomeDirDAO')
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
	my $credentials = undef;
	my $auth_hdr = $ENV{'HTTP_AUTHORIZATION'};
	#
	if ($auth_hdr) {
		my ($basic, $ucred) = split(' ', $auth_hdr);
		if ($basic) {
			my ( $user, $pass ) = split( ':', decode_base64($ucred) );
			if ( defined($user) && defined($pass) ) {
				$credentials = { method => $basic, user => $user, password => $pass };
			}
		}
	}
	my $sessionId = $cgi->http("X-SESSION-ID");
	unless($sessionId) { $sessionId = $cgi->param('x-session-id'); }
	unless($sessionId) { $sessionId = $cgi->param('sid'); }
	my $ctx = {
		time       	=> time(),
		sessionId 	=> $sessionId,
		userAgent	=> $cgi->http("HTTP_USER_AGENT"),
		remoteIp   	=> $ENV{'REMOTE_ADDR'},
		credentials => $credentials
	};
	#
	$@ = "";	
	eval { 
		$self->{sec_mgr}->pass($self->{sec_mgr}->identify($ctx), [ROLE_ADMIN]); 
	} || do {
		die Wstk::WstkException->new('Permission denied', 403);
  	};
  	#
  	my $method = $ENV{REQUEST_METHOD};
  	my $id = $cgi->param('id');
  	my $refid = $cgi->param('refid');
  	my $type = $cgi->param('type');
  	my $data = $cgi->param('data');  	
	#
	if('GET' eq $method) {
		if($type eq 'dialplan') {
			my $body = $self->{context_dao}->read_body($id);
			send_response($self, $body);
			return 1;
		}
		if($type eq 'template') {
			my $body = $self->{template_dao}->read_body($id);
			send_response($self, $body);
			return 1;
		}
		if($type eq 'switch_config') {
			my $body = $self->{switch_config_dao}->read_body($id);
			send_response($self, $body);
			return 1;
		}
		if($type eq 'switch_script') {
			my $body = $self->{switch_script_dao}->read_body($id);
			send_response($self, $body);
			return 1;
		}
		if($type eq 'switch_sound') {
			my $abs_path = $self->{swith_sound_dao}->get_abs_path($id);
    		unless(-d $abs_path || -e $abs_path) { 
    			die Wstk::WstkException->new($id, 404);  
    		}
			my $ctype = get_content_type($self, $id);
			send_binary($self, $ctype, $abs_path, $id);
			return 1;
		}
		if($type eq 'switch_recording') {
			my $abs_path = $self->{swith_record_dao}->get_abs_path($id);
    		unless(-d $abs_path || -e $abs_path) { 
    			die Wstk::WstkException->new($id, 404);  
    		}
			my $ctype = get_content_type($self, $id);
			send_binary($self, $ctype, $abs_path, $id);
			return 1;
		}
		if($type eq 'switch_user_file') {
			my $entity = $self->{sip_user_dao}->get($refid);
			unless ($entity) { 
				die Wstk::WstkException->new($id, 404);  
			}
			my $abs_path = $self->{sip_user_home_dao}->get_abs_path($entity, $id);
			unless(-d $abs_path || -e $abs_path) { 
				die Wstk::WstkException->new($id, 404); 
			}
			my $ctype = get_content_type($self, $id);
			send_binary($self, $ctype, $abs_path, $id);
			return 1;
		}
		die Wstk::WstkException->new('Unsupported type: '.$type, 400);
	}
	if('PUT' eq $method) {
		unless(defined($data)) {
			die Wstk::WstkException->new('Missing parameter: data', 400);
		}	
		if($type eq 'dialplan') {
			$self->{context_dao}->write_body($id, $data);
			send_response($self, "+OK");
			return 1;
		}
		if($type eq 'template') {
			$self->{template_dao}->write_body($id, $data);
			send_response($self, "+OK");
			return 1;
		}
		if($type eq 'switch_config') {
			$self->{switch_config_dao}->write_body($id, $data);
			send_response($self, "+OK");
			return 1;
		}
		if($type eq 'switch_script') {
			$self->{switch_script_dao}->write_body($id, $data);
			send_response($self, "+OK");
			return 1;
		}
		die Wstk::WstkException->new('Unsupported type: '.$type, 400);
	}
	die Wstk::WstkException->new('Unsupported method: '.$method, 400);
	return 1;
}

# ---------------------------------------------------------------------------------------------------------------------------------
# helper methods
# ---------------------------------------------------------------------------------------------------------------------------------
sub get_content_type {
	my ($self, $fileName) = @_;
	
	if($fileName =~ /\.mp3\z/) {
		return "audio/mpeg";
	} elsif ($fileName =~ /\.wav\z/) {
		return "audio/x-wav";
	}

	return "application/octet-stream";
}

sub send_response {
	my ($self, $response ) = @_;
	print "Content-type: text/plain; charset=UTF-8\n";
	print "Date: " . localtime( time() ) . "\n\n";
	print $response;
}

sub send_binary {
	my ($self, $ctype, $abs_path, $rel_path) = @_;
	my $bsize = io_get_file_size($abs_path);
	my ($rd, $bread, $buffer) = (0, 0, undef);
	#
	unless($bsize) {
		print "Content-type: ".$ctype."\n";
		print "Content-length: ".$bsize."\n";
		print "Date: " . localtime(time())."\n\n";
		return;
	}	
	open(my $fio, "<".$abs_path) || die Wstk::WstkException->new("Couldn't open file: ".$rel_path, 500);
	#
	print "Content-type: ".$ctype."\n";
	print "Content-length: ".$bsize."\n";
	print "Date: " . localtime( time() ) . "\n\n";
	#
	while(1) {
		if($bread == $bsize) { last; }
		if($bread > $bsize) {
			$rd = $bsize - $bread;
			unless($rd) {last; }
		} else { 
			$rd = 1024; 
		}
		$rd = sysread($fio, $buffer, $rd);
		if($rd <= 0) { last; }
		$bread += $rd;			
		print $buffer;
	}
	close($fio);
	return 1;
}

1;
