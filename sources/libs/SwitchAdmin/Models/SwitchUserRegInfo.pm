# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::Models::SwitchUserRegInfo;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (
                class           => CLASS_NAME,
                profile         => undef,
                callId          => undef,
                user            => undef,
                agent           => undef,
                contact         => undef,
                status          => undef,
                pingStatus      => undef,
                pingTime        => undef,
                networkIp       => undef,
                networkPort     => undef
        );
        my $self= {%t, %args};
        bless( $self, $class );
}

sub get_class_name {
        my ($self) = @_;
        return $self->{class};
}

sub profile {
        my ($self, $val) = @_;
        return $self->{profile} unless(defined($val));
        $self->{profile} = $val;
}

sub callId {
        my ($self, $val) = @_;
        return $self->{callId} unless(defined($val));
        $self->{callId} = $val;
}

sub user {
        my ($self, $val) = @_;
        return $self->{user} unless(defined($val));
        $self->{user} = $val;
}

sub contact {
        my ($self, $val) = @_;
        return $self->{contact} unless(defined($val));
        $self->{contact} = $val;
}

sub agent {
        my ($self, $val) = @_;
        return $self->{agent} unless(defined($val));
        $self->{agent} = $val;
}

sub status {
        my ($self, $val) = @_;
        return $self->{status} unless(defined($val));
        $self->{status} = $val;
}

sub pingStatus {
        my ($self, $val) = @_;
        return $self->{pingStatus} unless(defined($val));
        $self->{pingStatus} = $val;
}

sub pingTime {
        my ($self, $val) = @_;
        return $self->{pingTime} unless(defined($val));
        $self->{pingTime} = $val;
}

sub networkIp {
        my ($self, $val) = @_;
        return $self->{networkIp} unless(defined($val));
        $self->{networkIp} = $val;
}

sub networkPort {
        my ($self, $val) = @_;
        return $self->{networkPort} unless(defined($val));
        $self->{networkPort} = $val;
}

1;
