# ******************************************************************************************
#
# (C)2018 aks
# https://github.com/akscf/
# ******************************************************************************************
package Wstk::Models::SearchFilter;

use strict;
use constant CLASS_NAME => __PACKAGE__;

sub new ($$) {
        my ($class, %args) = @_;
        my %t = (        
                class  				=> CLASS_NAME,
				text				=> undef,
                sortColumn			=> undef,
                sortCondition   	=> undef, # =|>|< or regex (not used)
				sortDirection   	=> undef, # 1=ASC, 0=DESC
				sortCaseSensitive	=> undef, # true/false - 1/0
				resultsStart   		=> undef,
                resultsLimit  		=> undef
        );
        my $self= {%t, %args};        
        bless( $self, $class );
}

sub get_class_name {
        my ($self) = @_;
        return $self->{class};
}

sub text {
	my ($self, $val) = @_;
	return $self->{text} unless(defined($val));
	$self->{text} = $val;
}

sub sortColumn {
	my ($self, $val) = @_;
	return $self->{sortColumn} unless(defined($val));
	$self->{sortColumn} = $val;
}

sub sortCondition {
	my ($self, $val) = @_;
	return $self->{sortCondition} unless(defined($val));
	$self->{sortCondition} = $val;
}

sub sortDirection {
	my ($self, $val) = @_;
	return $self->{sortDirection} unless(defined($val));
	$self->{sortDirection} = $val;
}

sub sortCaseSensitive {
	my ($self, $val) = @_;
	return $self->{sortCaseSensitive} + 0 unless(defined($val));
	$self->{sortCaseSensitive} = $val + 0;
}

sub resultsStart {
	my ($self, $val) = @_;
	return $self->{resultsStart} + 0 unless(defined($val));
	$self->{resultsStart} = $val + 0;
}

sub resultsLimit {
	my ($self, $val) = @_;
	return $self->{resultsLimit} + 0 unless(defined($val));
	$self->{resultsLimit} = $val + 0;
}

1;
