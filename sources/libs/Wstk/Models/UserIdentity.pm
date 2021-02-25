# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package Wstk::Models::UserIdentity;

use strict;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (        
                class   => $class,
                id      => undef,
                role    => undef,
                title   => undef,
                usrObj  => undef
        );
        my $self= {%t, %args};
        bless( $self, $class );
        return $self;
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

sub role {
	my ($self, $val) = @_;
	return $self->{role} unless(defined($val));
	$self->{role} = $val;
}

sub title {
	my ($self, $val) = @_;
	return $self->{title} unless(defined($val));
	$self->{title} = $val;
}

sub usrObj {
        my ($self, $val) = @_;
        return $self->{usrObj} unless(defined($val));
        $self->{usrObj} = $val;
}

1;
