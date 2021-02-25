# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Models::SipGateway;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (
                class           => CLASS_NAME,
                id              => undef,                
                profileId       => undef,
                enabled         => undef,
                register        => undef,
                name            => undef,
                username        => undef, # req
                password        => undef, # req
                realm           => undef,
                proxy           => undef,
                description     => undef,
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

sub profileId {
        my ($self, $val) = @_;
        return $self->{profileId} + 0 unless(defined($val));
        $self->{profileId} = $val + 0;
}

sub enabled {
        my ($self, $val) = @_;
        return $self->{enabled} unless(defined($val));
        $self->{enabled} = $val;
}

sub register {
        my ($self, $val) = @_;
        return $self->{register} unless(defined($val));
        $self->{register} = $val;
}

sub name {
        my ($self, $val) = @_;
        return $self->{name} unless(defined($val));
        $self->{name} = $val;
}

sub username {
        my ($self, $val) = @_;
        return $self->{username} unless(defined($val));
        $self->{username} = $val;
}

sub password {
        my ($self, $val) = @_;
        return $self->{password} unless(defined($val));
        $self->{password} = $val;
}

sub realm {
        my ($self, $val) = @_;
        return $self->{realm} unless(defined($val));
        $self->{realm} = $val;
}

sub proxy {
        my ($self, $val) = @_;
        return $self->{proxy} unless(defined($val));
        $self->{proxy} = $val;
}

sub description {
        my ($self, $val) = @_;
        return $self->{description} unless(defined($val));
        $self->{description} = $val;
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
