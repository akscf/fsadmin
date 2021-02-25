# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Models::SipDeviceLine;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (
                class                   => CLASS_NAME,
                id                      => undef,
                deviceId                => undef,
                domainId                => undef, # dep. from user
                userId                  => undef, # 
                lineId                  => undef, # 1,2,...
                number                  => undef, # number
                realm                   => undef, # 
                proxy                   => undef,
                password                => undef,
                enabled                 => undef,                
                description             => undef,
                variables               => undef

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

sub deviceId {
        my ($self, $val) = @_;
        return $self->{deviceId} + 0 unless(defined($val));
        $self->{deviceId} = $val + 0;
}

sub domainId {
        my ($self, $val) = @_;
        return $self->{domainId} + 0 unless(defined($val));
        $self->{domainId} = $val + 0;
}

sub userId {
        my ($self, $val) = @_;
        return $self->{userId} + 0 unless(defined($val));
        $self->{userId} = $val + 0;
}

sub lineId {
        my ($self, $val) = @_;
        return $self->{lineId} + 0 unless(defined($val));
        $self->{lineId} = $val + 0;
}

sub number {
        my ($self, $val) = @_;
        return $self->{number} unless(defined($val));
        $self->{number} = $val;
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

sub password {
        my ($self, $val) = @_;
        return $self->{password} unless(defined($val));
        $self->{password} = $val;
}

sub enabled {
        my ($self, $val) = @_;
        return $self->{enabled} unless(defined($val));
        $self->{enabled} = $val;
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
