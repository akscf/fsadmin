# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Models::FileItem;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (
                class           => CLASS_NAME,
                name            => undef,
                path            => undef,
                size            => undef,
                date            => undef,
                directory       => undef
        );
        my $self= {%t, %args};
        bless( $self, $class );
}

sub get_class_name {
        my ($self) = @_;
        return $self->{class};
}

sub name {
        my ($self, $val) = @_;
        return $self->{name} unless(defined($val));
        $self->{name} = $val;
}

sub path {
        my ($self, $val) = @_;
        return $self->{path} unless(defined($val));
        $self->{path} = $val;
}

sub size {
        my ($self, $val) = @_;
        return $self->{size} + 0 unless(defined($val));
        $self->{size} = $val + 0;
}

sub date {
        my ($self, $val) = @_;
        return $self->{date} unless(defined($val));
        $self->{date} = $val;
}

sub directory {
        my ($self, $val) = @_;
        return $self->{directory} unless(defined($val));
        $self->{directory} = $val;
}

1;
