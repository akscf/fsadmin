# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::Models::SystemStatus;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (        
                class  			=> CLASS_NAME,
                productName     => undef,
                productVersion  => undef,
                instanceName    => undef,
                uptime          => undef,
                vmInfo          => undef,
                osInfo          => undef
        );
        my $self= {%t, %args};
        bless( $self, $class );
        return $self;
}

sub get_class_name {
        my ($self) = @_;
        return $self->{class};
}

sub productName {
	my ($self, $val) = @_;
	return $self->{productName} unless(defined($val));
	$self->{productName} = $val;
}

sub productVersion {
	my ($self, $val) = @_;
	return $self->{productVersion} unless(defined($val));
	$self->{productVersion} = $val;
}

sub instanceName {
	my ($self, $val) = @_;
	return $self->{instanceName} unless(defined($val));
	$self->{instanceName} = $val;
}

sub uptime {
	my ($self, $val) = @_;
	return $self->{uptime} + 0 unless(defined($val));
	$self->{uptime} = $val + 0;
}

sub vmInfo {
        my ($self, $val) = @_;
        return $self->{vmInfo} unless(defined($val));
        $self->{vmInfo} = $val;
}

sub osInfo {
        my ($self, $val) = @_;
        return $self->{osInfo} unless(defined($val));
        $self->{osInfo} = $val;
}

# -------------------------------------------------------------------------------------------
1;
