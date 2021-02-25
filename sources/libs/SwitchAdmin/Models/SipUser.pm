# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package SwitchAdmin::Models::SipUser;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (
                class                   => CLASS_NAME,
                id                      => undef,
                domainId                => undef,
                groupId                 => undef, # primary group
                sipId                   => undef, # number@domain (auto)
                enabled                 => undef,
                allowSipAccess          => undef,
                allowWebAccess          => undef,
                allowInternationalCalls => undef, # international calls
                allowLongDistanceCalls  => undef, # long distance calls
                allowLocalCalls         => undef, # local calls
                name                    => undef,
                number                  => undef,                
                context                 => undef,
                groups                  => undef, # additional groups (not uses)
                language                => undef, # preferred language
                fwdNumber               => undef, # fwd call to number
                accountCode             => undef,
                effectiveCidName        => undef, # auto/manual
                effectiveCidNumber      => undef, # auto/manual
                outboundCidName         => undef, # auto/manual
                outboundCidNumber       => undef, #
                vmPassword              => undef,
                sipPassword             => undef,
                webPassword             => undef,
                cidProfile              => undef, # outboud callerID profile
                script                  => undef, # will perform on inbound calls
                description             => undef,
                homePath                => undef, # auto
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

sub domainId {
        my ($self, $val) = @_;
        return $self->{domainId} + 0 unless(defined($val));
        $self->{domainId} = $val + 0;
}

sub groupId {
        my ($self, $val) = @_;
        return $self->{groupId} + 0 unless(defined($val));
        $self->{groupId} = $val + 0;
}

sub enabled {
        my ($self, $val) = @_;
        return $self->{enabled} unless(defined($val));
        $self->{enabled} = $val;
}

sub allowSipAccess {
        my ($self, $val) = @_;
        return $self->{allowSipAccess} unless(defined($val));
        $self->{allowSipAccess} = $val;
}

sub allowWebAccess {
        my ($self, $val) = @_;
        return $self->{allowWebAccess} unless(defined($val));
        $self->{allowWebAccess} = $val;
}

sub allowInternationalCalls {
        my ($self, $val) = @_;
        return $self->{allowInternationalCalls} unless(defined($val));
        $self->{allowInternationalCalls} = $val;
}

sub allowLongDistanceCalls {
        my ($self, $val) = @_;
        return $self->{allowLongDistanceCalls} unless(defined($val));
        $self->{allowLongDistanceCalls} = $val;
}

sub allowLocalCalls {
        my ($self, $val) = @_;
        return $self->{allowLocalCalls} unless(defined($val));
        $self->{allowLocalCalls} = $val;
}

sub name {
        my ($self, $val) = @_;
        return $self->{name} unless(defined($val));
        $self->{name} = $val;
}

sub sipId {
        my ($self, $val) = @_;
        return $self->{sipId} unless(defined($val));
        $self->{sipId} = $val;
}

sub number {
        my ($self, $val) = @_;
        return $self->{number} unless(defined($val));
        $self->{number} = $val;
}

sub groups {
        my ($self, $val) = @_;
        return $self->{groups} unless(defined($val));
        $self->{groups} = $val;
}

sub language {
        my ($self, $val) = @_;
        return $self->{language} unless(defined($val));
        $self->{language} = $val;
}

sub fwdNumber {
        my ($self, $val) = @_;
        return $self->{fwdNumber} unless(defined($val));
        $self->{fwdNumber} = $val;
}

sub context {
        my ($self, $val) = @_;
        return $self->{context} unless(defined($val));
        $self->{context} = $val;
}

sub accountCode {
        my ($self, $val) = @_;
        return $self->{accountCode} unless(defined($val));
        $self->{accountCode} = $val;
}

sub effectiveCidName {
        my ($self, $val) = @_;
        return $self->{effectiveCidName} unless(defined($val));
        $self->{effectiveCidName} = $val;
}

sub effectiveCidNumber {
        my ($self, $val) = @_;
        return $self->{effectiveCidNumber} unless(defined($val));
        $self->{effectiveCidNumber} = $val;
}

sub outboundCidName {
        my ($self, $val) = @_;
        return $self->{outboundCidName} unless(defined($val));
        $self->{outboundCidName} = $val;
}

sub outboundCidNumber {
        my ($self, $val) = @_;
        return $self->{outboundCidNumber} unless(defined($val));
        $self->{outboundCidNumber} = $val;
}

sub vmPassword {
        my ($self, $val) = @_;
        return $self->{vmPassword} unless(defined($val));
        $self->{vmPassword} = $val;
}

sub sipPassword {
        my ($self, $val) = @_;
        return $self->{sipPassword} unless(defined($val));
        $self->{sipPassword} = $val;
}

sub webPassword {
        my ($self, $val) = @_;
        return $self->{webPassword} unless(defined($val));
        $self->{webPassword} = $val;
}

sub cidProfile {
        my ($self, $val) = @_;
        return $self->{cidProfile} unless(defined($val));
        $self->{cidProfile} = $val;
}

sub script {
        my ($self, $val) = @_;
        return $self->{script} unless(defined($val));
        $self->{script} = $val;
}

sub homePath {
        my ($self, $val) = @_;
        return $self->{homePath} unless(defined($val));
        $self->{homePath} = $val;
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
