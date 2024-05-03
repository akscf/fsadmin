# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::Models::SipProfile;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (
                class           => CLASS_NAME,
                id              => undef,
                enabled         => undef,
                tlsEnabled      => undef,
                name            => undef,
                context         => undef,
                codecIn         => undef,
                codecOut        => undef,
                ipaddress       => undef,
                sipPort         => undef,
                tlsPort         => undef,
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

sub enabled {
        my ($self, $val) = @_;
        return $self->{enabled} unless(defined($val));
        $self->{enabled} = $val;
}

sub tlsEnabled {
        my ($self, $val) = @_;
        return $self->{tlsEnabled} unless(defined($val));
        $self->{tlsEnabled} = $val;
}

sub context {
        my ($self, $val) = @_;
        return $self->{context} unless(defined($val));
        $self->{context} = $val;
}

sub codecIn {
        my ($self, $val) = @_;
        return $self->{codecIn} unless(defined($val));
        $self->{codecIn} = $val;
}

sub codecOut {
        my ($self, $val) = @_;
        return $self->{codecOut} unless(defined($val));
        $self->{codecOut} = $val;
}

sub ipaddress {
        my ($self, $val) = @_;
        return $self->{ipaddress} unless(defined($val));
        $self->{ipaddress} = $val;
}

sub sipPort {
        my ($self, $val) = @_;
        return $self->{sipPort} unless(defined($val));
        $self->{sipPort} = $val;
}

sub tlsPort {
        my ($self, $val) = @_;
        return $self->{tlsPort} unless(defined($val));
        $self->{tlsPort} = $val;
}

sub name {
        my ($self, $val) = @_;
        return $self->{name} unless(defined($val));
        $self->{name} = $val;
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
