# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::IOHelper;

use Exporter qw(import);
our @EXPORT = qw(io_get_file_lastmod io_get_file_size);

sub io_get_file_lastmod {
	my ($file) = @_;
	return 0 unless(defined($file));
	open(my $t, "<".$file) || return 0;
	my $ts = (stat($t))[9];
	close($t);	
	return $ts;
}

sub io_get_file_size {
	my ($file) = @_;
	return 0 unless(defined($file));
	open(my $t, "<".$file) || return 0;
	my $sz = (stat($t))[7];
	close($t);	
	return $sz;
}

1;
