# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::Models::DocTemplateBody;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (
                class                   => CLASS_NAME,
                id                      => undef,
                templateId              => undef,
                body                    => undef
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

sub templateId {
        my ($self, $val) = @_;
        return $self->{templateId} + 0 unless(defined($val));
        $self->{templateId} = $val + 0;
}

sub body {
        my ($self, $val) = @_;
        return $self->{body} unless(defined($val));
        $self->{body} = $val;
}

sub export {
        return undef;
}

1;
