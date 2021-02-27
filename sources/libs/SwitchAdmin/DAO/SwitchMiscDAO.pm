# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::DAO::SwitchMiscDAO;

use strict;

use Log::Log4perl;
use POSIX qw(strftime);
use Wstk::Boolean;
use Wstk::WstkDefs qw(:ALL);
use Wstk::EntityHelper qw(is_empty);
use Wstk::WstkException;
use Wstk::SearchFilterHelper;
use SwitchAdmin::EslClient;
use SwitchAdmin::Models::FileItem;
use SwitchAdmin::Models::SwitchCodecInfo;
use SwitchAdmin::Models::SwitchUserRegInfo;
use SwitchAdmin::Models::SwitchCallInfo;

sub new ($$;$) {
    my ($class, $pmod) = @_;
    my $self = {
        logger          => Log::Log4perl::get_logger(__PACKAGE__),
        class_name      => $class,
        fsadmin         => $pmod,        
        dbm             => $pmod->{'dbm'},
        esl_client      => SwitchAdmin::EslClient->new($pmod)
    };
    bless($self, $class);
    return $self;
}

sub get_class_name {
    my ($self) = @_;
    return $self->{class_name};
}

# ---------------------------------------------------------------------------------------------------------------------------------
sub switch_uuid_kill {
    my ($self, $session_id) = @_;
    unless(is_valid_uuid($session_id)) {
        die Wstk::WstkException->new("Malformed session_id", RPC_ERR_CODE_INVALID_ARGUMENT);   
    }
    #
    $self->{esl_client}->connect();
    my $res = $self->{esl_client}->exec_api('uuid_kill '.$session_id, 1);
    my $err = $self->{esl_client}->parse_error($res);
    if($err) {
        die Wstk::WstkException->new("Error: ".$err);
    }    
    return 1;
}

sub switch_uuid_record {
    my ($self, $session_id) = @_;
    unless(is_valid_uuid($session_id)) {
        die Wstk::WstkException->new("Malformed session_id", RPC_ERR_CODE_INVALID_ARGUMENT);   
    }
    #
    my $rec_ext = '.wav';
    my $shout_mod = $self->{fsadmin}->dao_lookup('SwitchModuleDAO')->lookup('mod_shout');
    if($shout_mod && is_true($shout_mod->autoload())) { $rec_ext = '.mp3'; }
    #
    my $cur_time = strftime("%H%M%S", gmtime());
    my $rec_dir = strftime("%d-%m-%Y", gmtime());
    my $rec_name = 'REC'.$cur_time.'-'.uc($session_id).$rec_ext;    
    my $rec_path = $rec_dir .'/'. $rec_name;
    #
    my $abs_rec_dir = $self->{fsadmin}->dao_lookup('SwitchRecordingDAO')->get_abs_path($rec_dir);
    my $abs_rec_path = $self->{fsadmin}->dao_lookup('SwitchRecordingDAO')->get_abs_path($rec_path);
    #
    unless (-d $abs_rec_dir) {
        mkdir($abs_rec_dir);
    }
    #
    $self->{esl_client}->connect();
    my $res = $self->{esl_client}->exec_api('uuid_record '.$session_id.' start '.$abs_rec_path, 1);
    my $err = $self->{esl_client}->parse_error($res);
    if($err) {
        die Wstk::WstkException->new("Error: ".$err);
    }    
    return SwitchAdmin::Models::FileItem->new( name => $rec_name, path => $rec_path, size => 0, directory => Wstk::Boolean::FALSE );
}

sub switch_show_codecs {
    my ($self) = @_;
    #
    $self->{esl_client}->connect();
    my $res = $self->{esl_client}->exec_api('show codecs', 1);
    my $err = $self->{esl_client}->parse_error($res);
    if($err) {
        die Wstk::WstkException->new("Error: ".$err);
    }
    my $cmap = {};
    my $codecs = [];
    while($res =~ /([^\n]+)\n?/g) {
        my $line = $1;        
        if($line =~ /ADPCM/)       { next; }
        if($line =~ /G\.711 ulaw/) { push(@{$codecs}, SwitchAdmin::Models::SwitchCodecInfo->new(name => 'PCMU')); next; }
        if($line =~ /G\.711 alaw/) { push(@{$codecs}, SwitchAdmin::Models::SwitchCodecInfo->new(name => 'PCMA')); next; }
        if($line =~ /^codec\,(\S+)\,(\S+)$/) {
            unless($cmap->{$1}) { $cmap->{$1} = 1; push(@{$codecs}, SwitchAdmin::Models::SwitchCodecInfo->new(name => $1)); }
            next;
        }        
        if($line =~ /^codec\,(\S+)\s.*/) {
            unless($cmap->{$1}) { $cmap->{$1} = 1; push(@{$codecs}, SwitchAdmin::Models::SwitchCodecInfo->new(name => $1)); }
            next;
        }        
    }        
    return $codecs;
}

# using sofia api
sub switch_show_registrations {
    my($self, $filter) = @_;
    #
    my $profiles = $self->{fsadmin}->dao_lookup('SipProfileDAO')->list();
    my $ftext = filter_get_text($filter);
    my $result= [];
    #
    $self->{esl_client}->connect();
    foreach my $profile (@{$profiles}) {            
        unless(is_true($profile->enabled())) { next; }
        #
        my ($obj, $rege) = (0, undef);
        my $buff = $self->{esl_client}->exec_api('sofia xmlstatus profile '.$profile->name().' reg');
        while($buff =~ /([^\n]+)\n?/g) {
            my $line = $1;
            if($line =~ /<registration>/ ) {
                $rege = 1; 
                $obj = SwitchAdmin::Models::SwitchUserRegInfo->new(profile => $profile->name());
                next;
            } elsif($line =~ /<\/registration>/ ) {
                $rege = 0;
                unless(is_empty($ftext)) {
                    if($obj->user() =~ /$ftext/ || $obj->contact() =~ /$ftext/ || $obj->agent() =~ /$ftext/) {
                        push(@{$result}, $obj);
                    }
                } else {
                    push(@{$result}, $obj); 
                }                
                next;
            }
            if($rege == 1 ) {
                if($line =~ /<call-id>(.*)<\/call-id>/) { $obj->callId($1); }
                elsif($line =~ /<user>(.*)<\/user>/) { $obj->user($1); }
                elsif($line =~ /<contact>(.*)<\/contact>/) { $obj->contact(xml_unescape($1)); }
                elsif($line =~ /<agent>(.*)<\/agent>/) { $obj->agent($1); }
                elsif($line =~ /<status>(.*)<\/status>/) { $obj->status($1); }
                elsif($line =~ /<ping-status>(.*)<\/ping-status>/) { $obj->pingStatus($1); }
                elsif($line =~ /<ping-time>(.*)<\/ping-time>/) { $obj->pingTime($1); }
                elsif($line =~ /<network-ip>(.*)<\/network-ip>/) { $obj->networkIp($1); }
                elsif($line =~ /<network-port>(.*)<\/network-port>/) { $obj->networkPort($1); }
            }
        }
    }
    $self->{esl_client}->destroy();
    return $result;
}

sub switch_show_calls {
    my($self, $filter) = @_;   
    #
    my $ftext = filter_get_text($filter);
    my $result= []; 
    #
    $self->{esl_client}->connect();
    my $buff = $self->{esl_client}->exec_api('show calls', 1);    
    while($buff =~ /([^\n]+)\n?/g) {
        my $line = $1;
        if($line =~ /^uuid,/ || $line =~ /^(\d+) total\./) { next; }
        # 10=presence_id, 13=callstate, 31=b_presence_id
        my ($id, $direction, $created, $caller, $callee, $status) = (split(',', $line))[0, 1, 2, 10, 31, 13]; 
        unless ($id) { next; }
        my $put = 1;
        unless(is_empty($ftext)) {
            if($caller =~ /$ftext/ || $callee =~ /$ftext/) { $put = 1; }
            else { $put = 0; }
        }
        if($put) {
            push(@{$result}, SwitchAdmin::Models::SwitchCallInfo->new(id => $id, direction => $direction, created => $created, caller => $caller, callee => $callee, status => $status));   
        }
    }
    return $result;
}

# ---------------------------------------------------------------------------------------------------------------------------------
sub xml_unescape {
    my ($val) = @_;
    unless (defined $val) {
        return $val;
    }
    $val =~ s/&amp;/&/sg;
    $val =~ s/&lt;/</sg;
    $val =~ s/&gt;/>/sg;
    $val =~ s/&quot;/"/sg;
    return $val;
}

sub is_valid_uuid {
    my ($uuid) = @_;
    if($uuid =~ /[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}/) {
        return 1;
    }
    return undef;
}
# ---------------------------------------------------------------------------------------------------------------------------------
1;
