# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Models::SipUserGroup;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (
                class           => CLASS_NAME,
                id              => undef,
                domainId        => undef,
                name            => undef,
                variables       => undef

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
        return $self->{id} + 0 unless(defined($val));
        $self->{id} = $val + 0;
}

sub domainId {
        my ($self, $val) = @_;
        return $self->{domainId} + 0 unless(defined($val));
        $self->{domainId} = $val + 0;
}

sub name {
        my ($self, $val) = @_;
        return $self->{name} unless(defined($val));
        $self->{name} = $val;
}

sub variables {
        my ($self, $val) = @_;
        return $self->{variables} unless(defined($val));
        $self->{variables} = $val;
}

sub export {
        return undef;
}

1;
