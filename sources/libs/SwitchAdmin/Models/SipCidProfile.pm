# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::Models::SipCidProfile;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (
                class           => CLASS_NAME,
                id              => undef,
                name            => undef,
                cidName         => undef,
                cidNumber       => undef
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

sub name {
        my ($self, $val) = @_;
        return $self->{name} unless(defined($val));
        $self->{name} = $val;
}

sub cidName {
        my ($self, $val) = @_;
        return $self->{cidName} unless(defined($val));
        $self->{cidName} = $val;
}

sub cidNumber {
        my ($self, $val) = @_;
        return $self->{cidNumber} unless(defined($val));
        $self->{cidNumber} = $val;
}

sub export {
        return undef;
}

1;
