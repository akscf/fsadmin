package Config::INI::Simple;
BEGIN {
	$Config::INI::Simple::VERSION = '1.00';
}
use strict;
use warnings;
use File::Slurp;

sub new {
	my ($pkg, $path) = @_;
	die unless defined($pkg);
	$path = "" unless defined($path);
	my @cont;
	@cont = read_file($path) if (-e $path);
	my $self = {};
	my $sec = "_";
	for (@cont) {
		$sec = $1, next if(/^\[([\w\._\-]+)\]\s*$/);
		$self->{$sec}->{$1} = $2 if(/^([\w\.\/:_\-]+)=(.*?)\s*$/);
	}
	undef(@cont);
	bless($self, $pkg);
	return $self;
}

sub __push_contents__ {
	my ($href, $aref) = @_;
	push @$aref, $_ . "=" . $href->{$_} . "\n" for(keys %$href);
	push @$aref, "\n";
}

sub write {
	my ($self, $path) = @_;
	die "need path" unless defined $path;
	my @out;
	__push_contents__($self->{_}, \@out) if(defined($self->{_}));
	for(keys %$self) {
		if($_ ne "_") {
			push @out, "[" . $_ . "]\n";
			__push_contents__($self->{$_}, \@out);
		}
	} 
	write_file $path, \@out;
}

1;

=pod

=head1 NAME

Config::INI::Simple - provides quick access to the contents of .ini files

Only dependency is File::Slurp.

=head1 SYNOPSIS

--------------- INI ---------------

test=blah

[section]

section-entry=lol

--------------- Code --------------

#read ini

my $ini = Config::INI::Simple->new("test.ini");

print $ini->{_}->{test}, "\n";

print $ini->{section}->{"section-entry"}, "\n";


#write ini

$ini = Config::INI::Simple->new();

$ini->{section1}->{key1} = "value1";

$ini->{section1}->{key2} = "value2";

$ini->write("test.ini");

=head1 DESCRIPTION

Config::INI::Simple parses the .ini file at construction time and returns a hashref
to the sections, which themselves are hashrefs to the sections' key value pairs.

the top section, unless named is called "_" like in L<Config::INI::Reader>.

if no path is passed to new(), and empty object is returned which can be used to
construct an ini and then write() it to a specific file.


=head1 RATIONAL

L<Config::INI::Reader> depends on some uncommon packages, which themselves depend on other uncommon packages.
Since my CPAN installer was somehow broken, I ended up installing its dozen of dependencies by hand.
After wasting half an hour with manual package handling, i wrote my own little parser instead.
This one only uses File::Slurp, which i consider a standard module.


=head1 AUTHOR

Torsten Geyer

=head1 SEE ALSO

L<Config::INI::Reader>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Torsten Geyer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl5 itself.

=cut
