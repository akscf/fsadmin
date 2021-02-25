# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Models::SwitchCallInfo;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (
                class           => CLASS_NAME,
                id              => undef,
                direction       => undef,
                created         => undef,
                caller          => undef,
                callee          => undef,
                status          => undef
        );
        my $self= {%t, %args};
        bless( $self, $class );
}

sub get_class_name {
        my ($self) = @_;
        return $self->{class};
}

sub id {
        my ($self, $val) = @_;
        return $self->{id} unless(defined($val));
        $self->{id} = $val;
}

sub direction {
        my ($self, $val) = @_;
        return $self->{direction} unless(defined($val));
        $self->{direction} = $val;
}

sub created {
        my ($self, $val) = @_;
        return $self->{created} unless(defined($val));
        $self->{created} = $val;
}

sub caller {
        my ($self, $val) = @_;
        return $self->{caller} unless(defined($val));
        $self->{caller} = $val;
}

sub callee {
        my ($self, $val) = @_;
        return $self->{callee} unless(defined($val));
        $self->{callee} = $val;
}

sub status {
        my ($self, $val) = @_;
        return $self->{status} unless(defined($val));
        $self->{status} = $val;
}

1;

