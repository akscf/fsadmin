# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::DAO::SwitchModuleDAO;

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
use SwitchAdmin::Models::SwitchModule;

use constant ENTITY_CLASS_NAME => SwitchAdmin::Models::SwitchModule::CLASS_NAME;
use constant TABLE_NAME => 'switch_modules';

sub new ($$;$) {
    my ($class, $pmod) = @_;
    my $self = {
        logger       => Log::Log4perl::get_logger(__PACKAGE__),
        class_name   => $class,
        fsadmin      => $pmod,
        dbm          => $pmod->{'dbm'},
        system_dao   => $pmod->dao_lookup('SystemDAO'),
        base_path    => $pmod->get_config('freeswitch', 'modules_path')
    };
    bless($self, $class);
    #
    unless($self->{base_path}) {
        die Wstk::WstkException->new("Missing property: freeswitch.modules_path", RPC_ERR_CODE_INTERNAL_ERROR);
    }
    # 
    $self->{logger}->debug('switch modules: '.$self->{base_path});
    #
    unless($self->{'dbm'}->table_exists(TABLE_NAME)) {       
        $self->{'logger'}->debug('creating table: ' .TABLE_NAME);        
        my $qres = $self->{'dbm'}->do_query(undef, 'CREATE TABLE '. TABLE_NAME .' '
            .'(id INTEGER PRIMARY KEY, autoload TEXT(5) NOT NULL, name TEXT(255), fileName TEXT(255), configName TEXT(255), description TEXT(255))'
        );
        $self->{'dbm'}->do_query($qres->{'dbh'}, 'CREATE UNIQUE INDEX '.TABLE_NAME.'_idx0 ON '.TABLE_NAME.' (id)');
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
sub sync_config_file {
    my ($self) = @_;
    my $ld_conf = $self->{fsadmin}->get_config('freeswitch', 'configs_path') . '/modules.conf.xml';
    my $wstk = $self->{fsadmin}->{wstk};
    unless(-e $ld_conf) {
        die Wstk::WstkException->new("File: ".$ld_conf, RPC_ERR_CODE_NOT_FOUND);
    }
    #
    my $body = "<configuration name=\"modules.conf\" description=\"\">\n<!-- generated at: ".localtime()." -->\n <modules>\n";
    my $mods = list($self, undef);
    foreach my $mod (@{$mods}) {
        if(is_true($mod->{autoload})) {
            $body .= "  <load module=\"".$mod->fileName()."\" />\n";
        }
    }
    $body .= " </modules>\n</configuration>\n";
    #
    if($wstk->sdb_get('lock_swithd')) {
        die Wstk::WstkException->new('Resource is locked, try again later', RPC_ERR_CODE_INTERNAL_ERROR);
    }
    $wstk->sdb_put('lock_modules.conf.xml', 1);
    write_file($ld_conf, $body);
    $wstk->sdb_put('lock_modules.conf.xml', undef);
    return 1;
}

sub sync_db {
    my ($self) = @_;
    my $lmap = {};
    #
    $self->{logger}->debug("importing modules...(don't break the script! it might takes a few seconds)");
    #
    my $ld_conf = $self->{fsadmin}->get_config('freeswitch', 'configs_path') . '/modules.conf.xml';    
    if(-e $ld_conf) {
		open(my $ff, $ld_conf) or die("Coudn't open file ($ld_conf): $!");
		while (<$ff>) {
			if($_ =~ /\<\!\-\-/) { next; }
			if($_ =~ /\<load module\=\"(\S+)"/) { $lmap->{$1} = 1; }
		}
		close($ff);
    } else {
    	$self->{logger}->warn('missing file: '.$ld_conf);
    }    
    list_files($self, $self->{base_path}, sub { 
        my $path = shift;        
        my $fname = basename($path);        
        if($fname =~ /^(\S+)\.so$/) {
            my $mod_name = $1;
            #
            $self->{logger}->debug("processing: ".$fname);
            #
            unless(exists_name($self, $mod_name)) {
                my $obj = SwitchAdmin::Models::SwitchModule->new(name => $mod_name, configName => undef, autoload => ($lmap->{$mod_name} ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE));
                add($self, $obj, 1);
            }
        }
    });
    $self->{logger}->debug('importing modules...done');
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
    $entity->autoload(is_true($entity->autoload()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    $entity->fileName($entity->name().'.so');
    #
    unless ($pass_checks) {
    	unless(is_valid_filename($entity->fileName())) {
			die Wstk::WstkException->new("Invalid fileName", RPC_ERR_CODE_VALIDATION_FAIL);
		}
		if(is_duplicate($self, $entity)) {
			die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_ALREADY_EXISTS);
		}
		my $path = $self->{base_path} .'/'. $entity->fileName();
		unless(-e $path) {
			die Wstk::WstkException->new($entity->fileName(), RPC_ERR_CODE_NOT_FOUND);
		}
    }
    my $qres = $self->{'dbm'}->do_query(undef, 
        'INSERT INTO '. TABLE_NAME . ' (id, autoload, name, fileName, configName, description) VALUES(?, ?, ?, ?, ?, ?)',
        [ $entity->id(), $entity->autoload(), $entity->name(), $entity->fileName(), $entity->configName(), $entity->description() ]
    );
    $self->{'dbm'}->clean($qres);
    #
    return $entity;
}

sub update {
    my ( $self, $entity ) = @_;
    my $old_name = undef;
    validate_entity($self, $entity);
    #       
    my $_entity = get($self, $entity->id());
    unless($_entity) {
        die Wstk::WstkException->new($entity->name(), RPC_ERR_CODE_NOT_FOUND);
    }
    #
    $entity->autoload(is_true($entity->autoload()) ? Wstk::Boolean::TRUE : Wstk::Boolean::FALSE);
    #
    entity_copy_by_fields($_entity, $entity, ['autoload', 'configName', 'description']);
    my $qres = $self->{'dbm'}->do_query(undef, 
        'UPDATE ' . TABLE_NAME . ' SET autoload=?, configName=?, description=? WHERE id=?',
        [ $_entity->autoload(), $_entity->configName(), $_entity->description(), $_entity->id() ]
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
    # 
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
        	my $obj = map_rs($self, $res);
            push(@{$result}, $obj);
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
    return entity_map(SwitchAdmin::Models::SwitchModule->new(), $rs);
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

# ---------------------------------------------------------------------------------------------------------------------------------
1;
