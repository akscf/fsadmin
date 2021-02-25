#
# https://github.com/skaji/Shared-Hash
#
package Shared::Hash;
use strict;
use warnings;
use Cwd qw(abs_path);
use Fcntl qw(:DEFAULT :flock);
use File::Temp qw(tempfile);
use Storable qw(nfreeze thaw);
use constant CHUNK_SIZE => 1024**2;

our $VERSION = "0.01";

{
    package Shared::Hash::Guard;
    sub new { bless $_[1], $_[0] }
    sub DESTROY { $_[0]->() }
}

sub new {
    my ($class, %option) = @_;
    my $path = $option{path};
    if (!$path) {
        (undef, $path) = tempfile OPEN => 0;
    }
    my $self = bless {
        path => $path,
        initial_pid => $$,
        use_existing_path => $option{path} ? 1 : 0,
        persist => $option{persist}
    }, $class;
    $self->_reopen;
    $self->{path} = abs_path($self->{path}); # XXX
    if (!$self->{use_existing_path} or ( -s $self->{path} == 0 )) {
        $self->_spew(+{});
    }
    $self;
}

sub path { shift->{path} }

sub _reopen {
    my $self = shift;
    delete $self->{fh}; # just delete, don't close!
    sysopen my $fh, $self->{path}, O_RDWR|O_CREAT or die "open $self->{path}: $!";
    $self->{fh} = $fh;
    $self->{owner_pid} = $$;
}

sub DESTROY {
    my $self = shift;
    return if $self->{initial_pid} != $$;
    if (!$self->{use_existing_path} || !$self->{persist}) {
        unlink $self->{path};
    }
}

sub fh {
    my $self = shift;
    if ($self->{owner_pid} != $$) {
        $self->_reopen;
    }
    $self->{fh};
}

sub _slurp {
    my $self = shift;
    my $guard = $self->_lock(LOCK_SH);
    my $fh = $self->fh;
    sysseek $fh, 0, 0;
    my $buffer = "";
    while (sysread $fh, my $buf, CHUNK_SIZE) {
        $buffer .= $buf;
    }
    thaw $buffer;
}

sub _spew {
    my ($self, $data) = @_;
    my $fh = $self->fh;
    sysseek $fh, 0, 0;
    truncate $fh, 0;
    syswrite $fh, nfreeze $data;
}

sub get {
    my ($self, $key) = @_;
    my $hash = $self->_slurp;
    $hash->{$key};
}

sub set {
    my ($self, $key, $value) = @_;
    my $guard = $self->_lock(LOCK_EX);
    local $self->{in_lock} = 1;
    my $hash = $self->_slurp;
    $hash->{$key} = $value;
    $self->_spew($hash);
}

sub keys :method {
    my ($self, $key) = @_;
    my $hash = $self->_slurp;
    keys %$hash;
}

sub values :method {
    my ($self, $key) = @_;
    my $hash = $self->_slurp;
    values %$hash;
}

sub as_hash {
    shift->_slurp;
}

sub lock :method {
    my ($self, $cb) = @_;
    my $guard = $self->_lock(LOCK_EX);
    local $self->{in_lock} = 1;
    $cb->($self);
}

sub _lock {
    my ($self, $kind) = @_;
    return if $self->{in_lock};
    my $fh = $self->fh;
    flock $fh, $kind or die "flock $self->{path}: $!";
    Shared::Hash::Guard->new(sub { flock $fh, LOCK_UN });
}

1;
__END__

=for stopwords tempfile

=encoding utf-8

=head1 NAME

Shared::Hash - hash-like object which is shared between processes

=head1 SYNOPSIS

    use Shared::Hash;

    my $hash = Shared::Hash->new;

    my $pid = fork // die;
    if ($pid == 0) {
        # child
        $hash->set(message => "from child!");
        exit;
    }

    sleep 1;
    print $hash->get("message"); # from child!

=head1 DESCRIPTION

Shared::Hash is a hash-like object which is shared between processes.
It uses a file for IPC.

=head2 FEATURES

=over 4

=item support lock

    $hash->lock(sub {
        # in this callback, your operations for $hash are atomic!
        my $i = $hash->get("foo");
        $i++;
        $hash->set(foo => $i);
    });

=item hash may contain arbitrary perl data type

    $hash->set(foo => { hash => "ref" });
    $hash->set(bar => [1..10]);

=back

=head2 CONSTRUCTOR

=head4 C<< my $hash = Shared::Hash->new(%option) >>

Create a new Shared::Hash object.
You can optionally specify C<path> option.
Then, you can also use it later:

    $ perl -MShared::Hash -e 'Shared::Hash->new(path => "foo.data")->set(foo => "bar")'

    $ perl -MShared::Hash -e 'print(Shared::Hash->new(path => "foo.data")->get("foo"))'
    bar

Default C<path> is a tempfile.

=head2 METHODS

=head4 C<< my $value = $hash->get($key) >>

Get the value for C<$key>.
If C<$hash> does not contain C<$key>, then it returns C<undef>.

=head4 C<< $hash->set($key, $value) >>

Set C<$value> for C<$key>.

=head4 C<< my $hash_ref = $hash->as_hash >>

Get a cloned hash reference.

=head4 C<< my @keys = $hash->keys >>

All keys of C<$hash>.

=head4 C<< my @values = $hash->values >>

All values of C<$hash>.

=head4 C<< $hash->lock($callback) >>

In C<$callback>, your operation for C<$hash> is atomic.

=head1 LICENSE

Copyright (C) Shoichi Kaji.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Shoichi Kaji E<lt>skaji@cpan.orgE<gt>

=cut

