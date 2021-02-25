# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::DAO::SipUserDAO;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use Wstk::EntityHelper;
use Wstk::WstkException;
use Wstk::WstkDefs qw(:ALL);
use Wstk::SearchFilterHelper;
use Wstk::Models::SearchFilter;
use SwitchAdmin::FilenameHelper;
use SwitchAdmin::Models::SipUser;

use constant TABLE_NAME => 'sip_users';
use constant ENTITY_CLASS_NAME => SwitchAdmin::Models::SipUser::CLASS_NAME;
use constant RECORDINGS_PATH_NAME => 'recordings';
use constant VOICEMAILS_PATH_NAME => 'voicemails';

sub new ($$;$) {
    my ($class, $pmod) = @_;
    my $self = {
        logger          => Log::Log4perl::get_logger(__PACKAGE__),
        class_name      => $class,
        fsadmin         => $pmod,
        dbm             => $pmod->{'dbm'},
        system_dao      => $pmod->dao_lookup('SystemDAO'),
        base_path       => $pmod->get_config('freeswitch', 'users_path')
    };
    bless( $self, $class );
    #
    unless($self->{'dbm'}->table_exists(TABLE_NAME)) {       
        $self->{'logger'}->debug('creating table: ' .TABLE_NAME);
        my $qres = $self->{'dbm'}->do_query(undef, 'CREATE TABLE '. TABLE_NAME .' '
            .'(id INTEGER PRIMARY KEY, domainId INTEGER NOT NULL, groupId INTEGER NOT NULL, enabled TEXT(5) NOT NULL, '
            .'allowSipAccess TEXT(5) NOT NULL, allowWebAccess TEXT(5) NOT NULL, allowInternationalCalls TEXT(5) NOT NULL, allowLongDistanceCalls TEXT(5) NOT NULL, allowLocalCalls TEXT(5) NOT NULL, '
            .'name TEXT(255), number TEXT(32) NOT NULL, sipId TEXT(128) NOT NULL, context TEXT(255) NOT NULL, groups TEXT(255), language TEXT(8), fwdNumber TEXT(255), accountCode TEXT(32),'
            .'effectiveCidName TEXT(255), effectiveCidNumber TEXT(32), outboundCidName TEXT(255), outboundCidNumber TEXT(32), vmPassword TEXT(128), sipPassword TEXT(128), webPassword TEXT(128),'
            .'cidProfile TEXT(255), script TEXT(255), description TEXT(255), homePath TEXT(255) NOT NULL, variables TEXT)'
        );
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx0 ON '.TABLE_NAME.' (id)');        
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx1 ON '.TABLE_NAME.' (sipId)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx2 ON '.TABLE_NAME.' (domainId)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx3 ON '.TABLE_NAME.' (number)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx4 ON '.TABLE_NAME.' (context)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx5 ON '.TABLE_NAME.' (cidProfile)');
        #
        $self->{'dbm'}->clean($qres);
    }
    unless($self->{base_path}) {
        die Wstk::WstkException->new("Missing property: freeswitch.users_path");
    }
    unless(-d $self->{base_path}) { 
        die Wstk::WstkException->new("Directory not found: ". $self->{base_path});
    }
    return $self;
}

sub get_class_name {
    my ($self) = @_;
    return $self->{class_name};
}

# ---------------------------------------------------------------------------------------------------------------------------------
sub add {
    my ($self, $entity) = @_;
    unless (defined($entity)) {
        die Wstk::WstkException->new("entity", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    #
    $entity->id(0);    
    $entity->enabled(is_true($entity->enabled()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->allowSipAccess(is_true($entity->allowSipAccess()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->allowWebAccess(is_true($entity->allowWebAccess()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->allowInternationalCalls(is_true($entity->allowInternationalCalls()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->allowLongDistanceCalls(is_true($entity->allowLongDistanceCalls()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);    
    $entity->allowLocalCalls(is_true($entity->allowLocalCalls()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);    
    $entity->accountCode($entity->accountCode() ? $entity->accountCode() : $entity->number());
    $entity->variables($entity->variables() ? $entity->variables() : '[]');
    validate_entity($self, $entity);
    # 
    my $domain = $self->{fsadmin}->dao_lookup('SipDomainDAO')->get($entity->domainId());
    my $group = $self->{fsadmin}->dao_lookup('SipUserGroupDAO')->get($entity->groupId());
    unless($domain) {
        die Wstk::WstkException->new("Domain #".$entity->domainId(), RPC_ERR_CODE_NOT_FOUND);
    }    
    unless($group) {
        die Wstk::WstkException->new("Group #".$entity->groupId(), RPC_ERR_CODE_NOT_FOUND);
    }
    if($entity->context()) {
        $entity->context( lc($entity->context()) );
        unless($self->{fsadmin}->dao_lookup('SipContextDAO')->lookup($entity->context())) {
            die Wstk::WstkException->new('Context: '.$entity->context(), RPC_ERR_CODE_NOT_FOUND);
        }
    }
    if($entity->cidProfile()) {
        unless($self->{fsadmin}->dao_lookup('SipCidProfileDAO')->lookup($entity->cidProfile())) {
            die Wstk::WstkException->new('CID profile: '.$entity->context(), RPC_ERR_CODE_NOT_FOUND);
        }        
    }
    if($entity->script()) {
        unless(is_valid_path($entity->script())) {
            die Wstk::WstkException->new('Malformed script name', RPC_ERR_CODE_VALIDATION_FAIL);   
        }
    }
    #
    if(is_duplicate($self, $entity)) {
        die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_ALREADY_EXISTS);
    }
    #
    $entity->id(assign_id($self));
    $entity->number(lc($entity->number()));
    $entity->sipId(lc($entity->number().'@'.$domain->name()));
    $entity->language(uc($entity->language()));
    $entity->homePath($domain->name().'/'.$entity->sipId());
    #
    my $qres = $self->{'dbm'}->do_query(undef, 'INSERT INTO '. TABLE_NAME .' '.
        '(id, domainId, groupId, sipId, enabled, allowSipAccess, allowWebAccess, allowInternationalCalls, allowLongDistanceCalls, allowLocalCalls, '.
        'name, number, context, groups, language, fwdNumber, accountCode, effectiveCidName, effectiveCidNumber, outboundCidName, outboundCidNumber, vmPassword, sipPassword, '.
        'webPassword, cidProfile, script, description, homePath, variables) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [ $entity->id(), $entity->domainId(), $entity->groupId(), $entity->sipId(), $entity->enabled(), $entity->allowSipAccess(), $entity->allowWebAccess(), $entity->allowInternationalCalls(), 
          $entity->allowLongDistanceCalls(), $entity->allowLocalCalls(), $entity->name(), $entity->number(), $entity->context(), $entity->groups(), $entity->language(), $entity->fwdNumber(),
          $entity->accountCode(), $entity->effectiveCidName(), $entity->effectiveCidNumber(), $entity->outboundCidName(), $entity->outboundCidNumber(), $entity->vmPassword(), $entity->sipPassword(), 
          $entity->webPassword(), $entity->cidProfile(), $entity->script(), $entity->description(), $entity->homePath(), $entity->variables()
        ]
    );
    $self->{'dbm'}->clean($qres);
    # create home dir
    my $path = ($self->{base_path} .'/'. $entity->homePath());
    unless(-d $path) {
        mkdir($path);
        mkdir($path.'/'.RECORDINGS_PATH_NAME);
        mkdir($path.'/'.VOICEMAILS_PATH_NAME);
    }    
    return $entity;
}

sub update {
    my ($self, $entity) = @_;
    my $_updSipId = 0;
    validate_entity($self, $entity);
    #    
    my $_entity = get($self, $entity->id());
    unless($_entity) {
        die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_NOT_FOUND);
    }
    #
    if($_entity->groupId() ne $entity->groupId()) {
        unless($self->{fsadmin}->dao_lookup('SipUserGroupDAO')->exists_id($entity->groupId())) {
            die Wstk::WstkException->new('Group #'.$entity->groupId(), RPC_ERR_CODE_NOT_FOUND);
        }
    }
    if($_entity->number() ne $entity->number()) {
        if(is_duplicate($self, $entity)) {
            die Wstk::WstkException->new($entity->number(), RPC_ERR_CODE_ALREADY_EXISTS);
        }
        (my $sid = $entity->sipId()) =~ s/$_entity->number()/$entity->number()/g;
        $entity->sipId($sid);
    } else {
        $entity->sipId($_entity->sipId());    
    }
    if($_entity->context() ne $entity->context()) {
        if($entity->context()) {
            $entity->context( lc($entity->context()) );        
            unless($self->{fsadmin}->dao_lookup('SipContextDAO')->lookup($entity->context())) {
                die Wstk::WstkException->new('Context: '.$entity->context(), RPC_ERR_CODE_NOT_FOUND);
            }
        }
    }
    if($entity->cidProfile() && lc($_entity->cidProfile()) ne lc($entity->cidProfile()) )  {
        unless($self->{fsadmin}->dao_lookup('SipCidProfileDAO')->lookup($entity->cidProfile())) {
            die Wstk::WstkException->new('CID profile: '.$entity->context(), RPC_ERR_CODE_NOT_FOUND);
        }        
    }   
    if($entity->script()) {
        unless(is_valid_path($entity->script())) {
            die Wstk::WstkException->new('Malformed script name', RPC_ERR_CODE_VALIDATION_FAIL);   
        }        
    }
    #
    $entity->enabled(is_true($entity->enabled()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->allowSipAccess(is_true($entity->allowSipAccess()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->allowWebAccess(is_true($entity->allowWebAccess()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->allowInternationalCalls(is_true($entity->allowInternationalCalls()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->allowLongDistanceCalls(is_true($entity->allowLongDistanceCalls()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);    
    $entity->allowLocalCalls(is_true($entity->allowLocalCalls()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);    
    $entity->accountCode($entity->accountCode() ? $entity->accountCode() : $entity->number());    
    $entity->sipId(lc($entity->sipId()));
    $entity->language(uc($entity->language()));
    $entity->variables($entity->variables() ? $entity->variables() : '[]');
    #
    entity_copy_by_fields($_entity, $entity, 
        [ 'groupId', 'enabled', 'allowSipAccess', 'allowWebAccess', 'allowInternationalCalls', 'allowLongDistanceCalls', 'allowLocalCalls', 
          'name', 'number', 'sipId', 'context', 'groups', 'language', 'fwdNumber', 'accountCode', 'effectiveCidName', 'effectiveCidNumber', 'outboundCidName', 'outboundCidNumber', 
          'vmPassword', 'sipPassword', 'webPassword', 'cidProfile', 'script', 'description', 'variables'
        ]
    );
    my $qres = $self->{'dbm'}->do_query(undef, 'UPDATE ' . TABLE_NAME .' SET '.
        'groupId=?, enabled=?, allowSipAccess=?, allowWebAccess=?, allowInternationalCalls=?, allowLongDistanceCalls=?, allowLocalCalls=?, name=?, '.
        'number=?, sipId=?, context=?, groups=?, language=?, fwdNumber=?, accountCode=?, effectiveCidName=?, effectiveCidNumber=?, outboundCidName=?, outboundCidNumber=?, vmPassword=?, sipPassword=?, '.
        'webPassword=?, cidProfile=?, script=?, description=?, variables=? WHERE id=?', 
        [ $_entity->groupId(), $_entity->enabled(), $_entity->allowSipAccess(), $_entity->allowWebAccess(), $_entity->allowInternationalCalls(), $_entity->allowLongDistanceCalls(),
          $_entity->allowLocalCalls(), $_entity->name(), $_entity->number(), $_entity->sipId(), $_entity->context(), $_entity->groups(), $_entity->language(), $_entity->fwdNumber(), $_entity->accountCode(), 
          $_entity->effectiveCidName(), $_entity->effectiveCidNumber(), $_entity->outboundCidName(), $_entity->outboundCidNumber(), $_entity->vmPassword(), $_entity->sipPassword(), 
          $_entity->webPassword(), $_entity->cidProfile(), $_entity->script(), $_entity->description(), $_entity->variables(), $_entity->id()
        ]
    );
    $self->{'dbm'}->clean($qres);
    #
    return $_entity;
}

sub delete {
    my ($self, $entity_id) = @_;
    unless(defined($entity_id)) {
        die Wstk::WstkException->new("entity_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    #
    my $entity = get($self, $entity_id);
    unless($entity) { return undef; }
    #
    my $qres = $self->{'dbm'}->do_query(undef, 'DELETE FROM ' . TABLE_NAME . " WHERE id=?", [ int($entity_id)] );
    $self->{'dbm'}->clean($qres);   
    # related objects
    $self->{fsadmin}->dao_lookup('SipDeviceLineDAO')->clean_refs_by_user($entity_id);     
    # delete home dir
    my $path = ($self->{base_path} .'/'. $entity->homePath());
    if(-d $path) {
        system("rm -rf ".$path);
    }        
    return $entity;
}

sub delete_by_domain {
    my ($self, $domain_id) = @_;
    unless(defined($domain_id)) {
        die Wstk::WstkException->new("domain_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 'DELETE FROM ' . TABLE_NAME . " WHERE domainId=?", [ int($domain_id)] );
    $self->{'dbm'}->clean($qres);    
    #
    return 1;
}

sub delete_by_group {
    my ($self, $group_id) = @_;
    unless(defined($group_id)) {
        die Wstk::WstkException->new("group_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 'DELETE FROM ' . TABLE_NAME . " WHERE groupId=?", [ int($group_id)] );
    $self->{'dbm'}->clean($qres);    
    #
    return 1;
}

sub update_cid_profile {
    my ($self, $old_name, $new_name) = @_;
    if(is_empty($old_name)) {
        die Wstk::WstkException->new("old_name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 'UPDATE ' . TABLE_NAME . " SET cidProfile=? WHERE lower(cidProfile)=?", [ $new_name, lc($old_name) ]);
    $self->{'dbm'}->clean($qres);    
    #
    return 1;
}

sub get {
    my ($self, $entity_id) = @_;
    my $entity = undef;
    #
    unless (defined($entity_id) ) {
        die Wstk::WstkException->new("entity_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef,'SELECT * FROM ' . TABLE_NAME . " WHERE id=? LIMIT 1", [ int($entity_id)] );
    if($qres) {
        $entity = map_rs($self, $qres->{'sth'}->fetchrow_hashref() );
    }
    $self->{'dbm'}->clean($qres);
    #
    return $entity;
}

sub lookup {
    my ($self, $sipId) = @_;
    my $entity = undef;
    #
    if(is_empty($sipId)) {
        die Wstk::WstkException->new("sipId", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef,'SELECT * FROM ' . TABLE_NAME . " WHERE sipId=? LIMIT 1", [ lc($sipId) ] );
    if($qres) {
        $entity = map_rs($self, $qres->{'sth'}->fetchrow_hashref() );
    }
    $self->{'dbm'}->clean($qres);
    #
    return $entity;
}

sub list {
    my ($self, $domain_id, $group_id, $filter) = @_;
    my $result = [];
    #
    my $fofs = filter_get_offset($filter);
    my $flimit = filter_get_limit($filter);
    my $fsortColumn = filter_get_sort_column($filter);
    my $fsortDir = filter_get_sort_direction($filter);
    my $ftext = $self->{'dbm'}->format_like(filter_get_text($filter), 1);
    #
    my $query = "SELECT * FROM ".TABLE_NAME." WHERE id > $fofs";
    $query.=" AND domainId=".int($domain_id) if(defined($domain_id));
    $query.=" AND groupId=".int($group_id) if(defined($group_id));
    $query.=" AND (name LIKE '$ftext' OR sipId LIKE '$ftext' OR fwdNumber LIKE '$ftext' OR description LIKE '$ftext')" if($ftext);
    $query.=" ORDER BY id ASC";
    $query.=' LIMIT '.$flimit if ($flimit);
    #
    my $qres = $self->{'dbm'}->do_query(undef, $query);
    if($qres) {
        while(my $res = $qres->{sth}->fetchrow_hashref()) {            
            push(@{$result}, map_rs($self, $res));   
        }
    }
    $self->{'dbm'}->clean($qres);
    #
    return $result;
}

# internal use only
sub update_context {
    my ($self, $old_name, $new_name) = @_;
    my $qres = $self->{'dbm'}->do_query(undef, 'UPDATE ' . TABLE_NAME . " SET context=? WHERE context=?", [ $new_name, $old_name ] );
    $self->{'dbm'}->clean($qres);    
    return 1;
}

# ---------------------------------------------------------------------------------------------------------------------------------
sub validate_entity {
    my ($self, $entity) = @_;
    unless ($entity) {
        die Wstk::WstkException->new("entity", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    unless(entity_instance_of($entity, ENTITY_CLASS_NAME)) {
        die Wstk::WstkException->new("Type mismatch: " . entity_get_class($entity) . ", require: " . ENTITY_CLASS_NAME);
    }
    unless(defined($entity->id())) {
        die Wstk::WstkException->new("Invalid property: id", RPC_ERR_CODE_VALIDATION_FAIL);
    }
    unless(defined($entity->domainId())) {
        die Wstk::WstkException->new("Invalid property: domainId", RPC_ERR_CODE_VALIDATION_FAIL);
    }
    unless(defined($entity->groupId())) {
        die Wstk::WstkException->new("Invalid property: groupId", RPC_ERR_CODE_VALIDATION_FAIL);
    }
    if(is_empty($entity->number())) {
        die Wstk::WstkException->new("Invalid property: number", RPC_ERR_CODE_VALIDATION_FAIL);
    }
    if($entity->number() !~ /^([0-9])+$/) {
        die Wstk::WstkException->new("Invalid property: number", RPC_ERR_CODE_VALIDATION_FAIL);
    }
    if(is_empty($entity->context())) {
        die Wstk::WstkException->new("Invalid property: context", RPC_ERR_CODE_VALIDATION_FAIL);
    }
}

sub exists_id {
    my($self, $id) = @_;
    my $result = undef;
    my $qo = $self->{'dbm'}->do_query(undef, 'SELECT id FROM '.TABLE_NAME." WHERE id=? LIMIT 1", [int($id)]);
    if($qo) { $result = (defined($qo->{sth}->fetchrow_array()) ? 1 : undef); }
    $self->{'dbm'}->clean($qo);
    return $result;
}

sub is_duplicate {
    my ($self, $entity ) = @_;
    my $result = undef;
    my $qo = $self->{'dbm'}->do_query(undef, 'SELECT id FROM ' . TABLE_NAME . " WHERE lower(number)=? AND domainId=? LIMIT 1", [ lc($entity->number()), int($entity->domainId()) ]);
    if($qo) { $result = (defined($qo->{sth}->fetchrow_array()) ? 1 : undef); }
    $self->{'dbm'}->clean($qo);
    return $result;
}

sub assign_id {
    my($self) = @_;
    return $self->{system_dao}->sequence_get(TABLE_NAME);
}
sub map_rs {
    my ($self, $rs) = @_;        
    unless (defined $rs) { return undef; }
    return entity_map(SwitchAdmin::Models::SipUser->new(), $rs);
}

1;
