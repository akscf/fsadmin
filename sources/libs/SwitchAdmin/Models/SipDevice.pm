# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Models::SipDevice;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (
                class                   => CLASS_NAME,
                id                      => undef,
                enabled                 => undef,
                hwAddress               => undef,
                ipAddress               => undef,
                model                   => undef,
                driver                  => undef,
                secret                  => undef, # acceess to config
                template                => undef, # config template ref
                description             => undef,
                lastActiveDate          => undef,
                driverProperties        => undef            

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

sub enabled {
        my ($self, $val) = @_;
        return $self->{enabled} unless(defined($val));
        $self->{enabled} = $val;
}

sub hwAddress {
        my ($self, $val) = @_;
        return $self->{hwAddress} unless(defined($val));
        $self->{hwAddress} = $val;
}

sub ipAddress {
        my ($self, $val) = @_;
        return $self->{ipAddress} unless(defined($val));
        $self->{ipAddress} = $val;
}

sub model {
        my ($self, $val) = @_;
        return $self->{model} unless(defined($val));
        $self->{model} = $val;
}

sub secret {
        my ($self, $val) = @_;
        return $self->{secret} unless(defined($val));
        $self->{secret} = $val;
}

sub driver {
        my ($self, $val) = @_;
        return $self->{driver} unless(defined($val));
        $self->{driver} = $val;
}

sub template {
        my ($self, $val) = @_;
        return $self->{template} unless(defined($val));
        $self->{template} = $val;
}

sub description {
        my ($self, $val) = @_;
        return $self->{description} unless(defined($val));
        $self->{description} = $val;
}

sub lastActiveDate {
        my ($self, $val) = @_;
        return $self->{lastActiveDate} unless(defined($val));
        $self->{lastActiveDate} = $val;
}

sub driverProperties {
        my ($self, $val) = @_;
        return $self->{driverProperties} unless(defined($val));
        $self->{driverProperties} = $val;
}

sub export {
        return undef;
}

1;
