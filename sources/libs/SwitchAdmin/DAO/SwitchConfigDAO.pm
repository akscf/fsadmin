# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::DAO::SwitchConfigDAO;

use strict;

use File::Basename;
use File::Slurp;
use Log::Log4perl;
use Wstk::Boolean;
use Wstk::WstkException;
use Wstk::WstkDefs qw(:ALL);
use Wstk::EntityHelper;
use Wstk::SearchFilterHelper;
use Wstk::Models::SearchFilter;
use SwitchAdmin::FilenameHelper;
use SwitchAdmin::Models::SwitchConfig;

use constant ENTITY_CLASS_NAME => SwitchAdmin::Models::SwitchConfig::CLASS_NAME;
use constant TABLE_NAME => 'switch_configs';

sub new ($$;$) {
    my ($class, $pmod) = @_;
    my $self = {
        logger       => Log::Log4perl::get_logger(__PACKAGE__),
        class_name   => $class,
        fsadmin      => $pmod,
        dbm          => $pmod->{'dbm'},
        system_dao   => $pmod->dao_lookup('SystemDAO'),        
        base_path    => $pmod->get_config('freeswitch', 'configs_path')
    };
    bless($self, $class);
    #
    unless($self->{base_path}) {
        die Wstk::WstkException->new("Missing property: freeswitch.configs_path", RPC_ERR_CODE_INTERNAL_ERROR);
    }
    #
    $self->{logger}->debug('switch configs: '.$self->{base_path});
    #
    unless($self->{'dbm'}->table_exists(TABLE_NAME)) {       
        $self->{'logger'}->debug('creating table: ' .TABLE_NAME);        
        my $qres = $self->{'dbm'}->do_query(undef, 'CREATE TABLE '. TABLE_NAME .' '
            .'(id INTEGER PRIMARY KEY, name TEXT(255), fileName TEXT(255), description TEXT(255))'
        );
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx0 ON '.TABLE_NAME.' (id)');
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx1 ON '.TABLE_NAME.' (name)');
        $self->{'dbm'}->clean($qres);
        sync_db($self);
    }
    return $self;
}

sub get_class_name {
    my ($self) = @_;
    return $self->{class_name};
}

# ---------------------------------------------------------------------------------------------------------------------------------
sub sync_db {
    my ($self) = @_;
    #
    $self->{logger}->debug("importing configurations...(don't break the script! it might takes a few seconds)");
    #
    list_files($self, $self->{base_path}, sub { 
        my $path = shift;        
        my $fname = basename($path);        
        if($fname eq 'modules.conf.xml') { next; }
        if($fname =~ /^(\S+)\.xml$/) {
            my $cfg_name = $1;
            #
            $self->{logger}->debug("processing: ".$cfg_name);
            #
            unless(exists_name($self, $cfg_name)) {
                my $i = 2;
                my $description = undef;   
                my $body = read_file($path);
                while($body =~ /([^\n]+)\n?/g) {
                    my $l = $1;
                    if($l =~ /description="(.*)"/) { $description = $1; last; }
                    last unless($i); $i--;
                }   
                my $obj = SwitchAdmin::Models::SwitchConfig->new(name => $cfg_name, fileName => undef, description => $description);             
                add($self, $obj, 1);
            }
        }
    });
    $self->{logger}->debug('importing configurations...done');
    return 1;
}

sub add {
    my ($self, $entity, $pass_checks) = @_;
    unless (defined($entity)) {
        die Wstk::WstkException->new("entity", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    #
    $entity->id(0);    
    validate_entity($self, $entity);
    #
    $entity->id(assign_id($self)); 
    $entity->fileName($entity->name().'.xml');
    #
    unless ($pass_checks) {
        unless(is_valid_filename($entity->fileName())) {
            die Wstk::WstkException->new("Invalid fileName", RPC_ERR_CODE_VALIDATION_FAIL);
        }
        if(is_duplicate($self, $entity)) {
            die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_ALREADY_EXISTS);
        }    
    }
    #
    my $qres = $self->{'dbm'}->do_query(undef, 
        'INSERT INTO '. TABLE_NAME . ' (id, name, fileName, description) VALUES(?, ?, ?, ?)',
        [ $entity->id(), $entity->name(), $entity->fileName(), $entity->description() ]
    );
    $self->{'dbm'}->clean($qres);
    # create file if needed
    my $path = $self->{base_path} .'/'. $entity->fileName();
    unless(-e $path) {
        open(my $ofile, '>', $path);
        print($ofile "<configuration name=\"".$entity->name()."\" description=\"\">\n\n\n</configuration>\n");
        close($ofile);
    }
    return $entity;
}

sub update {
    my ( $self, $entity ) = @_;
    my $old_name;
    validate_entity($self, $entity);
    #       
    my $_entity = get($self, $entity->id());
    unless($_entity) {
        die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_NOT_FOUND);
    }
    if( lc($_entity->name()) ne lc($entity->name()) ) {        
        if(is_duplicate($self, $entity)) {
            die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_ALREADY_EXISTS);
        }
        $entity->fileName( $entity->name() .'.xml' );
        unless(is_valid_filename($entity->fileName())) {
            die Wstk::WstkException->new("Invalid fileName", RPC_ERR_CODE_VALIDATION_FAIL);
        }
        my $path = $self->{base_path} .'/'. $entity->fileName();
        if(-e $path) {
            die Wstk::WstkException->new($entity->fileName(), RPC_ERR_CODE_ALREADY_EXISTS);
        }
        $old_name = $_entity->fileName();
    }
    #
    entity_copy_by_fields($_entity, $entity, ['name', 'fileName', 'description']);
    my $qres = $self->{'dbm'}->do_query(undef, 
        'UPDATE ' . TABLE_NAME . ' SET name=?, fileName=?, description=? WHERE id=?',
        [ $_entity->name(), $_entity->fileName(), $_entity->description(), $_entity->id() ]
    );
    $self->{'dbm'}->clean($qres);
    # rename file
    if($old_name) {
        my $old_path = $self->{base_path} .'/'. $old_name;
        my $new_path = $self->{base_path} .'/'. $entity->fileName();
        rename($old_path, $new_path);
    }
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
    # delete file
    my $path = $self->{base_path} .'/'. $entity->fileName();
    unlink($path.".deleted");
    rename($path, $path.".deleted");
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

sub lookup {
    my ($self, $name) = @_;
    my $entity = undef;
    #
    unless (defined($name) ) {
        die Wstk::WstkException->new("name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $qres = $self->{'dbm'}->do_query(undef,'SELECT * FROM ' . TABLE_NAME . " WHERE lower(name)=? LIMIT 1", [ lc($name) ] );
    if($qres) {
        $entity = map_rs($self, $qres->{'sth'}->fetchrow_hashref() );
    }
    $self->{'dbm'}->clean($qres);
    #
    return $entity;
}

sub get_abs_path {
    my ($self, $path) = @_;
    my $entity = undef;
    #
    unless (is_valid_path($path)) {
        die Wstk::WstkException->new("path", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    return $self->{base_path} .'/'. $path;
}

sub read_body {
    my ($self, $config_id) = @_;
    my $entity = undef;
    #
    unless (defined($config_id) ) {
        die Wstk::WstkException->new("config_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    unless(is_digit($config_id)) {
        $entity = lookup($self, $config_id);
    } else {
        $entity = get($self, $config_id);
    }
    unless ($entity) {
        die Wstk::WstkException->new($config_id, RPC_ERR_CODE_NOT_FOUND);
    }
    my $path = $self->{base_path} .'/'. $entity->fileName();
    unless(-d $path || -e $path ) {
        die Wstk::WstkException->new('File '.$entity->fileName(), RPC_ERR_CODE_NOT_FOUND);
    }
    return read_file($path);
}

sub write_body {
    my ($self, $config_id, $body) = @_;
    my $entity = undef;
    #
    unless (defined($config_id) ) {
        die Wstk::WstkException->new("config_id", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    unless(is_digit($config_id)) {
        $entity = lookup($self, $config_id);
    } else {
        $entity = get($self, $config_id);
    }    
    unless ($entity) {
        die Wstk::WstkException->new('Context: '.$config_id, RPC_ERR_CODE_NOT_FOUND);
    }
    my $path = $self->{base_path} .'/'. $entity->fileName();
    write_file($path, $body);
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

sub exists_name {
    my($self, $name) = @_;
    my $result = undef;
    my $qo = $self->{'dbm'}->do_query(undef, 'SELECT name FROM '.TABLE_NAME." WHERE lower(name)=? LIMIT 1", [ lc($name) ]);
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
    return entity_map(SwitchAdmin::Models::SwitchConfig->new(), $rs);
}

sub list_files {
    my ( $self, $base, $cb ) = @_;
    #
    opendir( DIR, $base ) || die Wstk::WstkException->new("Couldn't read directory: $!");
    while ( my $file = readdir(DIR) ) {
        my $cfile = "$base/$file";
        $cb->($cfile) if ( -f $cfile );
    }
    closedir(DIR);
}

sub io_lock {
    my ($self, $name, $action) = @_;
    my $wstk = $self->{fsadmin}->{wstk};
    if($action == 1) {
        my $v = $wstk->sdb_get('lock_'.$name);
        if($v) { die Wstk::WstkException->new('Resource is locked, try again later', RPC_ERR_CODE_INTERNAL_ERROR); }
        $wstk->sdb_put('lock_'.$name, 1);
    } else {
        $wstk->sdb_put('lock_'.$name, undef);
    }
}

# ---------------------------------------------------------------------------------------------------------------------------------
1;
