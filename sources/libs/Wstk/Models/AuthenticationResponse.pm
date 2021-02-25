# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package Wstk::Models::AuthenticationResponse;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (        
                class  			=> CLASS_NAME,
                sessionId       => undef,
                properties      => {}
        );
        my $self= {%t, %args};
        bless( $self, $class );
        return $self;
}

sub get_class_name {
        my ($self) = @_;
        return $self->{class};
}

sub sessionId {
	my ($self, $val) = @_;
	return $self->{sessionId} unless(defined($val));
	$self->{sessionId} = $val;
}

sub properties {
	my ($self, $key, $val) = @_;
	return $self->{properties} unless(defined($key));
	$self->{properties}->{$key} = $val;
}

1;
