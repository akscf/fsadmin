# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::Models::ServerStatus;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (
                class           => CLASS_NAME,
                pid             => undef,
                state           => undef,
                version         => undef,
        );
        my $self= {%t, %args};
        bless( $self, $class );
}

sub get_class_name {
        my ($self) = @_;
        return $self->{class};
}

sub pid {
        my ($self, $val) = @_;
        return $self->{pid} unless(defined($val));
        $self->{pid} = $val + 0;
}

sub state {
        my ($self, $val) = @_;
        return $self->{state} unless(defined($val));
        $self->{state} = $val;
}

sub version {
        my ($self, $val) = @_;
        return $self->{version} unless(defined($val));
        $self->{version} = $val;
}


1;
