# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::FilenameHelper;

use Exporter qw(import);
our @EXPORT = qw(is_valid_path is_valid_filename);

sub is_valid_path {
	my ($path) = @_;
	if(!defined($path) || $path eq "") {
		return undef;
	}
	return undef if($path =~ /(\.\.|\.\/)/);
	return 1;
}

sub is_valid_filename {
	my ($fname) = @_;
	if(!defined($fname) || $fname eq "") {
		return undef;
	}
	return 1 if($fname =~ /^([a-zA-Z0-9\s\-\.\_])+$/);
	return undef;
}

1;
