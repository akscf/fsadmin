# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::DAO::SipProfileDAO;

use strict;

use Log::Log4perl;
use Wstk::Boolean;
use Wstk::EntityHelper;
use Wstk::WstkException;
use Wstk::WstkDefs qw(:ALL);
use Wstk::SearchFilterHelper;
use Wstk::Models::SearchFilter;
use SwitchAdmin::Models::SipProfile;

use constant TABLE_NAME => 'sip_profiles';
use constant ENTITY_CLASS_NAME => SwitchAdmin::Models::SipProfile::CLASS_NAME;

sub new ($$;$) {
    my ($class, $pmod) = @_;
    my $self = {
        logger          => Log::Log4perl::get_logger(__PACKAGE__),
        class_name      => $class,
        fsadmin         => $pmod,
        dbm             => $pmod->{'dbm'},
        system_dao      => $pmod->dao_lookup('SystemDAO')        
    };
    bless($self, $class);
    #
    unless($self->{'dbm'}->table_exists(TABLE_NAME)) {       
        $self->{'logger'}->debug('creating table: ' .TABLE_NAME);
        my $qres = $self->{'dbm'}->do_query(undef, 
            'CREATE TABLE '. TABLE_NAME .' (id INTEGER PRIMARY KEY, enabled TEXT(5) NOT NULL, tlsEnabled TEXT(5) NOT NULL, name TEXT(255) NOT NULL, codecIn TEXT(255), codecOut TEXT(255), '.
            'ipaddress TEXT(128), sipPort INTEGER(2), tlsPort INTEGER(2), context TEXT(255) NOT NULL, description TEXT(255), variables TEXT)'
        );
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx0 ON '.TABLE_NAME.' (id)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx1 ON '.TABLE_NAME.' (name)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE INDEX '.TABLE_NAME.'_idx3 ON '.TABLE_NAME.' (context)');
        #
        $self->{'dbm'}->clean($qres);
    }
    #        
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
    $entity->variables($entity->variables() ? $entity->variables() : '[]');
    validate_entity($self, $entity);
    #
    if($entity->context()) {
        $entity->context( lc($entity->context()) );
        unless($self->{fsadmin}->dao_lookup('SipContextDAO')->lookup($entity->context())) {
            die Wstk::WstkException->new('Context: '.$entity->context(), RPC_ERR_CODE_NOT_FOUND);
        }
    }
    #
    $entity->id(assign_id($self)); 
    $entity->name(lc($entity->name()));
    #    
    if(is_duplicate($self, $entity)) {
        die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_ALREADY_EXISTS);
    }
    my $qres = $self->{'dbm'}->do_query(undef, 
        'INSERT INTO '. TABLE_NAME . ' (id, enabled, tlsEnabled, name, context, codecIn, codecOut, ipaddress, sipPort, tlsPort, description, variables) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [ $entity->id(), $entity->enabled(), $entity->tlsEnabled(), $entity->name(), $entity->context(), $entity->codecIn(), $entity->codecOut(), 
          $entity->ipaddress(), $entity->sipPort(), $entity->tlsPort(), $entity->description(), $entity->variables() 
        ]
    );
    $self->{'dbm'}->clean($qres);
    #
    return $entity;
}

sub update {
    my ( $self, $entity ) = @_;
    validate_entity($self, $entity);
    #       
    my $_entity = get($self, $entity->id());
    unless($_entity) {
        die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_NOT_FOUND);
    }
    if($_entity->context() ne $entity->context()) {
        if($entity->context()) {
            $entity->context( lc($entity->context()) );        
            unless($self->{fsadmin}->dao_lookup('SipContextDAO')->lookup($entity->context())) {
                die Wstk::WstkException->new('Context: '.$entity->context(), RPC_ERR_CODE_NOT_FOUND);
            }
        }
    }
    if($_entity->name() ne $entity->name()) {
        $entity->name(lc(entity->name()));
        if(is_duplicate($self, $entity)) {
            die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_ALREADY_EXISTS);
        }
    }    
    $entity->enabled(is_true($entity->enabled()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->variables($entity->variables() ? $entity->variables() : '[]');
    #
    entity_copy_by_fields($_entity, $entity, ['name', 'enabled', 'tlsEnabled', 'context', 'codecIn', 'codecOut', 'ipaddress', 'sipPort', 'tlsPort', 'description', 'variables']);
    my $qres = $self->{'dbm'}->do_query(undef, 
        'UPDATE ' . TABLE_NAME . ' SET name=?, enabled=?, tlsEnabled=?, context=?, codecIn=?, codecOut=?, ipaddress=?, sipPort=?, tlsPort=?, description=?, variables=? WHERE id=?',
        [ $_entity->name(), $_entity->enabled(), $_entity->tlsEnabled(), $_entity->context(), $_entity->codecIn(), $_entity->codecOut(), 
          $_entity->ipaddress(), $_entity->sipPort(), $_entity->tlsPort(), $_entity->description(), $_entity->variables(), $_entity->id()
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
    my $entity = get($self, $entity_id);
    unless($entity) { return undef; }
    #
    my $qres = $self->{'dbm'}->do_query(undef, 'DELETE FROM ' . TABLE_NAME . " WHERE id=?", [ int($entity_id)] );
    $self->{'dbm'}->clean($qres);
    # related objects
    $self->{fsadmin}->dao_lookup('SipGatewayDAO')->delete_by_profile($entity_id);
    #
    return $entity;
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

sub list {
    my ($self, $filter) = @_;
    my $result = [];
    #
    my $fofs = filter_get_offset($filter);
    my $flimit = filter_get_limit($filter);
    my $fsortColumn = filter_get_sort_column($filter);
    my $fsortDir = filter_get_sort_direction($filter);
    my $ftext = $self->{'dbm'}->format_like(filter_get_text($filter), 1);
    #
    my $query = "SELECT * FROM ".TABLE_NAME." WHERE id > $fofs";
    $query.=" AND (name LIKE '$ftext' OR description LIKE '$ftext')" if($ftext);
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
    if(is_empty($entity->name())) {
        die Wstk::WstkException->new("Invalid property: name", RPC_ERR_CODE_VALIDATION_FAIL);
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
    my $qo = $self->{'dbm'}->do_query(undef, 'SELECT id FROM ' . TABLE_NAME . " WHERE lower(name)=? LIMIT 1", [ lc( $entity->name() )]);
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
    return entity_map(SwitchAdmin::Models::SipProfile->new(), $rs);
}

1;
