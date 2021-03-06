# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::DAO::SipUserHomeDirDAO;

use strict;

use Log::Log4perl;
use File::Basename;
use File::Copy;
use File::Copy::Recursive qw(dircopy);
use Wstk::Boolean;
use Wstk::WstkException;
use Wstk::WstkDefs qw(:ALL);
use Wstk::EntityHelper;
use Wstk::SearchFilterHelper;
use Wstk::Models::SearchFilter;
use SwitchAdmin::DateHelper;
use SwitchAdmin::FilenameHelper;
use SwitchAdmin::IOHelper;
use SwitchAdmin::Models::FileItem;

use constant ENTITY_CLASS_NAME => SwitchAdmin::Models::FileItem::CLASS_NAME;

sub new ($$;$) {
    my ($class, $pmod) = @_;
    my $self = {
        logger       => Log::Log4perl::get_logger(__PACKAGE__),
        class_name   => $class,
        fsadmin      => $pmod,
        base_path    => $pmod->get_config('freeswitch', 'users_path')
    };
    bless($self, $class);
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
sub mkdir {
    my ($self, $user, $file_item) = @_;
    unless($user) {
        die Wstk::WstkException->new("user", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    validate_entity($self, $file_item);
    #
    my $user_home = ($self->{base_path} .'/'. $user->homePath());
    my $dir_name = $file_item->name();
    unless (is_valid_filename($dir_name)) {
        die Wstk::WstkException->new("Malformed file name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    unless(is_empty($file_item->path())) {
        unless (is_valid_path($file_item->path())) {
            die Wstk::WstkException->new("Malformed path", RPC_ERR_CODE_INVALID_ARGUMENT);
        }
        $dir_name = ($file_item->path() .'/'. $file_item->name());
        $file_item->path($dir_name);
    } else {
        $file_item->path($dir_name);
    }    
    $file_item->size(0);
    $file_item->directory(Wstk::Boolean::TRUE);
    $dir_name = $user_home .'/'. $dir_name;
    #
    if( -d $dir_name ) {
        die Wstk::WstkException->new($file_item->name(), RPC_ERR_CODE_ALREADY_EXISTS);
    }
    mkdir($dir_name);
    $file_item->date( iso_format_datetime(io_get_file_lastmod($dir_name)) );
    return $file_item;
}

sub mkfile {
    my ($self, $user, $file_item) = @_;
    unless($user) {
        die Wstk::WstkException->new("user", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    validate_entity($self, $file_item);
    #
    my $user_home = ($self->{base_path} .'/'. $user->homePath());
    my $file_name = $file_item->name();
    unless (is_valid_filename($file_name)) {
        die Wstk::WstkException->new("Malformed file name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    unless(is_empty($file_item->path())) {
        unless (is_valid_path($file_item->path())) {
            die Wstk::WstkException->new("Malformed path", RPC_ERR_CODE_INVALID_ARGUMENT);
        }
        $file_name = ($file_item->path() .'/'. $file_item->name());
        $file_item->path($file_name);
    } else {
        $file_item->path($file_name);
    }
    $file_item->size(0);
    $file_item->directory(Wstk::Boolean::FALSE);
    $file_name = $user_home .'/'. $file_name;
    #
    if( -e $file_name ) {
        die Wstk::WstkException->new($file_item->name(), RPC_ERR_CODE_ALREADY_EXISTS);
    }
    open(my $ofile, '>', $file_name); close($ofile);    
    $file_item->date( iso_format_datetime(io_get_file_lastmod($file_name)) );
    return $file_item;

}

sub rename {
    my ($self, $user, $new_name, $file_item) = @_;
    unless($user) {
        die Wstk::WstkException->new("user", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    validate_entity($self, $file_item);
    #    
    unless (is_valid_path($file_item->path())) {
        die Wstk::WstkException->new("Malformed path", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    unless (is_valid_filename($new_name)) {
        die Wstk::WstkException->new("new_name", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    #
    my $user_home = ($self->{base_path} .'/'. $user->homePath());
    my $old_path = $file_item->path();
    my $old_name = $user_home .'/'. $file_item->path();
    my $new_name_local = undef;

    if ($file_item->path() eq $file_item->name()) {
        $file_item->path($new_name);
        $file_item->name($new_name);
        $new_name_local = $user_home .'/'. $file_item->path();
    } else {
        my $tbase = dirname($file_item->path());
        $file_item->path($tbase .'/'. $new_name) ;
        $file_item->name($new_name);
        $new_name_local = $user_home .'/'. $file_item->path();
    }
    #
    if( -d $old_name ) {
        if( -d $new_name_local ) {
            die Wstk::WstkException->new($file_item->path(), RPC_ERR_CODE_ALREADY_EXISTS);
        }
        File::Copy::move($old_name, $new_name_local);
        return $file_item;
    }
    if( -e $old_name ) {
        if( -e $new_name_local ) {
            die Wstk::WstkException->new($file_item->path(), RPC_ERR_CODE_ALREADY_EXISTS);
        }
        File::Copy::move($old_name, $new_name_local);
        return $file_item;
    }
    die Wstk::WstkException->new($old_path, RPC_ERR_CODE_NOT_FOUND);
}

sub move {
    my ($self, $user, $from, $to) = @_;
    unless($user) {
        die Wstk::WstkException->new("user", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    validate_entity($self, $from);
    validate_entity($self, $to);
    #
    my $to_path_name = ($to ? $to->path() : undef);
    if($to_path_name && !is_valid_path($to_path_name)) {
        die Wstk::WstkException->new("Malformed path 'to'", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    unless (is_valid_path($from->path())) {
        die Wstk::WstkException->new("Malformed path 'from'", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $user_home = ($self->{base_path} .'/'. $user->homePath());
    my $from_fqname = $user_home .'/'. $from->path();
    my $to_fqname = ($to_path_name ? $user_home .'/'. $to_path_name : $user_home);
    #
    if( -d $from_fqname ) {
        $to_fqname .= ($from->name() ? '/' . $from->name() : '');
        File::Copy::move($from_fqname, $to_fqname);
        return SwitchAdmin::Models::FileItem->new(
            name => $from->name(), path => $to_path_name, size => $from->size(), date => $from->date(), directory => $from->directory()
        );
    }
    if( -e $from_fqname ) {
        unless(-d $to_fqname) {
            die Wstk::WstkException->new($to_path_name, RPC_ERR_CODE_NOT_FOUND);
        }
        File::Copy::move($from_fqname, $to_fqname);
        return SwitchAdmin::Models::FileItem->new(
            name => $from->name(), path => $to_path_name, size => $from->size(), date => $from->date(), directory => $from->directory()
        );
    }
    die Wstk::WstkException->new($from->path(), RPC_ERR_CODE_NOT_FOUND);
}

sub copy {
    my ($self, $user, $from, $to) = @_;
    unless($user) {
        die Wstk::WstkException->new("user", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    validate_entity($self, $from);
    validate_entity($self, $to);
    #
    my $to_path_name = ($to ? $to->path() : undef);
    if($to_path_name && !is_valid_path($to_path_name)) {
        die Wstk::WstkException->new("Malformed path 'to'", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    unless (is_valid_path($from->path())) {
        die Wstk::WstkException->new("Malformed path 'from'", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $user_home = ($self->{base_path} .'/'. $user->homePath());
    my $from_fqname = $user_home .'/'. $from->path(); 
    my $to_fqname = ($to_path_name ? $user_home .'/'. $to_path_name : $user_home);
    #
    if( -d $from_fqname ) {
        $to_fqname .= ($from->name() ? '/' . $from->name() : '');
        dircopy($from_fqname, $to_fqname);
        return SwitchAdmin::Models::FileItem->new(
            name => $from->name(), path => $to_path_name, size => $from->size(), date => $from->date(), directory => $from->directory()
        );
    }
    if( -e $from_fqname ) {
        unless(-d $to_fqname) {
            die Wstk::WstkException->new($to_path_name, RPC_ERR_CODE_NOT_FOUND);
        }
        File::Copy::copy($from_fqname, $to_fqname);
        return SwitchAdmin::Models::FileItem->new(
            name => $from->name(), path => $to_path_name, size => $from->size(), date => $from->date(), directory => $from->directory()
        );
    }
    die Wstk::WstkException->new($from->path(), RPC_ERR_CODE_NOT_FOUND);
}

sub delete {
    my ($self, $user, $path) = @_;
    unless($user) {
        die Wstk::WstkException->new("user", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    unless (is_valid_path($path)) {
        die Wstk::WstkException->new("Malformed path", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $user_home = ($self->{base_path} .'/'. $user->homePath());
    my $tname = $user_home .'/'. $path;
    #    
    if( -d $tname ) {
        system("rm -rf ".$tname);
    }
    if( -e $tname ) {
        unlink($tname);
    }
    return 1;
}

sub get_meta {
    my ($self, $user, $path) = @_;
    unless($user) {
        die Wstk::WstkException->new("user", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    unless (is_valid_path($path)) {
        die Wstk::WstkException->new("Malformed path", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $user_home = ($self->{base_path} .'/'. $user->homePath());
    my $tname = $user_home .'/'. $path;
    #
    if( -d $tname ) {
        return SwitchAdmin::Models::FileItem->new(
            name => basename($path), 
            path => $path, 
            date => iso_format_datetime( io_get_file_lastmod($tname) ),
            size => 0, 
            directory => Wstk::Boolean::TRUE
        );        
    }
    if( -e $tname ) {
        return SwitchAdmin::Models::FileItem->new(
            name => basename($path), 
            path => $path, 
            date => iso_format_datetime( io_get_file_lastmod($tname) ),
            size => io_get_file_size($tname), 
            directory => Wstk::Boolean::FALSE
        );        
    }
    return undef;
}

sub browse {
    my ($self, $user, $path, $filter) = @_;
    unless($user) {
        die Wstk::WstkException->new("user", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    #
    my $ep = undef;
    my $fmask = filter_get_text($filter); 
    my $user_home = ($self->{base_path} .'/'. $user->homePath());    
    my $base_path_lenght = length($user_home) + 1;
    #
    if(is_empty($path)) {
        $ep = $user_home;
    } else {
        unless (is_valid_path($path)) {
            die Wstk::WstkException->new("Malformed path", RPC_ERR_CODE_INVALID_ARGUMENT);
        }
        $ep = ($user_home .'/'. $path);
        unless (-d $ep) {
            die Wstk::WstkException->new($path, RPC_ERR_CODE_NOT_FOUND);
        }
    }
    #
    my $dirs = [];
    list_dirs($self, $ep, sub { 
        my $path = shift;
        my $fname = basename($path);
        #if($fmask) { }
        my $obj = SwitchAdmin::Models::FileItem->new(
            name => $fname,
            path => substr($path, $base_path_lenght),
            date => iso_format_datetime( io_get_file_lastmod($path) ),
            size => 0, 
            directory => Wstk::Boolean::TRUE
        );
        push(@{$dirs}, $obj); 
    });
    my $files = [];
    list_files($self, $ep, sub { 
        my $path = shift;
        my $fname = basename($path);
        #if($fmask) { }
        my $obj = SwitchAdmin::Models::FileItem->new(
            name => $fname,
            path => substr($path, $base_path_lenght),
            date => iso_format_datetime( io_get_file_lastmod($path) ),
            size => io_get_file_size($path), 
            directory => Wstk::Boolean::FALSE
        );
        push(@{$files}, $obj); 
    });
    $dirs = [ sort { $a->{name} cmp $b->{name} } @{$dirs} ];
    $files = [ sort { $a->{name} cmp $b->{name} } @{$files} ];
    push(@{$dirs}, @{$files});
    #
    return $dirs;
}

# home
sub get_abs_path {
    my ($self, $entity, $path) = @_;
    #
    unless(defined($entity)) {
        die Wstk::WstkException->new("entity", RPC_ERR_CODE_INVALID_ARGUMENT);
    }
    my $ep = $self->{base_path} .'/'. $entity->homePath();
    if(defined $path) { 
        unless (is_valid_path($path)) {
            die Wstk::WstkException->new("path", RPC_ERR_CODE_INVALID_ARGUMENT);
        }
        $ep .= '/'.$path; 
    }
    return $ep;
}

sub read_body {
    my ($self, $user, $path) = @_;
    my $entity = undef;
    #
    my $ep = get_abs_path($self, $user, $path);
    unless(-d $ep || -e $ep ) {
        die Wstk::WstkException->new($path, RPC_ERR_CODE_NOT_FOUND);        
    }
    return read_file($ep);
}

sub write_body {
    my ($self, $user, $path, $body) = @_;
    my $entity = undef;
    #
    my $ep = get_abs_path($self, $user, $path);
    if(-d $ep) {
        die Wstk::WstkException->new($path, RPC_ERR_CODE_NOT_FOUND);
    }
    write_file($ep, $body);
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
}

sub list_dirs {
    my ( $self, $base, $cb ) = @_;
    #
    opendir( DIR, $base ) || die Wstk::WstkException->new("Couldn't read directory: $!");
    while( my $file = readdir(DIR) ) {
        my $cdir = "$base/$file";
        $cb->($cdir) if ( -d $cdir && ( $file ne "." && $file ne ".." ) );
    }
    closedir(DIR);
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
