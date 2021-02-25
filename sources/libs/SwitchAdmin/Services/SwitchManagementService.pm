# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Services::SwitchManagementService;

use strict;

use ReadBackwards;
use Log::Log4perl;
use Wstk::Boolean;
use Wstk::WstkDefs qw(:ALL);
use Wstk::SearchFilterHelper;
use SwitchAdmin::Defs qw(:ALL);
use SwitchAdmin::Models::ServerStatus;
use SwitchAdmin::EslClient;

sub new ($$;$) {
	my ( $class, $pmod ) = @_;
	my $self = {
		logger          => Log::Log4perl::get_logger(__PACKAGE__),
		class_name      => $class,
		fsadmin         => $pmod,
        sec_mgr         => $pmod->{sec_mgr},
        esl_client      => SwitchAdmin::EslClient->new($pmod)
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
sub rpc_switchModuleLoad {
    my ($self, $sec_ctx, $mod_name) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    unless($mod_name) {
        die Wstk::WstkException->new("mod_name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    $self->{esl_client}->connect();
    my $res = $self->{esl_client}->exec_api('load '.$mod_name, 1);
    my $err = $self->{esl_client}->parse_error($res);
    if($err) {
        die Wstk::WstkException->new("Error: ".$err);
    }
    return Wstk::Boolean::TRUE;
}

sub rpc_switchModuleUnload {
    my ($self, $sec_ctx, $mod_name) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    unless($mod_name) {
        die Wstk::WstkException->new("mod_name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    $self->{esl_client}->connect();
    my $res = $self->{esl_client}->exec_api('unload '.$mod_name, 1);
    my $err = $self->{esl_client}->parse_error($res);
    if($err) {
        die Wstk::WstkException->new("Error: ".$err);
    }
    return Wstk::Boolean::TRUE;
}

sub rpc_switchModuleReload {
    my ($self, $sec_ctx, $mod_name) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    unless($mod_name) {
        die Wstk::WstkException->new("mod_name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    $self->{esl_client}->connect();
    my $res = $self->{esl_client}->exec_api('reload '.$mod_name, 1);
    my $err = $self->{esl_client}->parse_error($res);
    if($err) {
        die Wstk::WstkException->new("Error: ".$err);
    }
    return Wstk::Boolean::TRUE;
}

# -----------------------------------------------------------------------------------------
# server control
# -----------------------------------------------------------------------------------------
sub rpc_switchStart {
    my ($self, $sec_ctx) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    return $self->switch_do_cmd('start');
}
    
sub rpc_switchStop {
    my ($self, $sec_ctx) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    return $self->switch_do_cmd('stop');
}

sub rpc_switchReload {
    my ($self, $sec_ctx) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    return $self->switch_do_cmd('reload');
}
    
sub rpc_switchGetStatus {
    my ($self, $sec_ctx) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    my $status = SwitchAdmin::Models::ServerStatus->new(pid => 0, state => 'unknown', version => 'unknown');
    my $cmd = $self->{fsadmin}->get_config('freeswitch','cmd_status');
    unless($cmd) { 
    	die Wstk::WstkException->new('Missing configuration property: freeswitch.cmd_status', RPC_ERR_CODE_INTERNAL_ERROR); 
    }
    my $st  = `$cmd`;
    my @tt  = split('\n', $st);
    foreach my $l (@tt) {
        if($l =~ /Active:\s(.*)$/) { $status->{state} = $1; next; }
        if($l =~ /(\d+)\s.*\/sbin\/master$/) {
            $status->{pid} = $1;
            $status->{state}='active' unless($status->{state});
            last;
        }
    }
    return $status;
}

sub rpc_logRead {
    my ($self, $sec_ctx, $filter) = @_;
    #
    check_permissions($self, $sec_ctx, [ROLE_ADMIN]);
    #
    my ($result, $ftext, $fstart, $fcount) = ([], undef, 0, 250);
    my $log_file = $self->{fsadmin}->get_config('freeswitch','log_file');    
    unless($log_file) {
        die Wstk::WstkException->new('Missing configuration property: freeswitch.log_file', RPC_ERR_CODE_INTERNAL_ERROR);
    }
    unless(-e $log_file) {
        die Wstk::WstkException->new('File not found: '.$log_file, RPC_ERR_CODE_NOT_FOUND);
    }
    my $bw = File::ReadBackwards->new( $log_file ) || die Wstk::WstkException->new( "Couldn't read logfile: $!", RPC_ERR_CODE_NOT_FOUND);
    if($filter) {
        $ftext  = filter_get_text($filter);
        $fstart = filter_get_offset($filter);
        $fcount = filter_get_limit($filter);
        $fcount = 350 unless($fcount);
    }
    while(defined(my $l = $bw->readline())) {
        $fcount-- if($fcount >= 0);
        last unless($fcount);
        unless($ftext) { push(@{$result}, $l); } 
        else { push(@{$result}, $l) if($l =~ m/\Q$ftext/); } 
    }
    return $result;
}

# ---------------------------------------------------------------------------------------------------------------------------------
# private methods
# ---------------------------------------------------------------------------------------------------------------------------------
sub check_permissions {
    my ($self, $ctx, $roles) = @_;
    my $ident = $self->{sec_mgr}->identify($ctx);
    $self->{sec_mgr}->pass($ident, $roles);    
}

sub lock {
    my ($self, $action) = @_;
    my $wstk = $self->{fsadmin}->{wstk};
    if($action == 1) {
        my $v = $wstk->sdb_get('lock_swithd');
        if($v) { die Wstk::WstkException->new('Resource is locked, try again later', RPC_ERR_CODE_INTERNAL_ERROR); }
        $wstk->sdb_put('lock_swithd', 1);
    } else {
        $wstk->sdb_put('lock_swithd', undef);
    }
}

sub switch_do_cmd {
    my ( $self, $cmd_name) = @_;
    my $cmd = $self->{fsadmin}->get_config('freeswitch','cmd_'.$cmd_name);
    unless($cmd) {
        die Wstk::WstkException->new('Missing configuration property: freeswitch.cmd_'.$cmd_name, RPC_ERR_CODE_INTERNAL_ERROR);
    }
    lock($self, 1);
    system($cmd);
    my $res = $?;
    lock($self, 0);
    if ($res == -1) {
        my $err = $!;
        $self->{logger}->error("Couldn't perform: '.$cmd_name.', error: ".$err." (".$cmd.")");
        die Wstk::WstkException->new( "Couldn't perform: '.$cmd_name.', error: ".$err, RPC_ERR_CODE_INTERNAL_ERROR);
    }
    return 1;
}

1;
