# ******************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# ******************************************************************************************
package Wstk::SearchFilterHelper;

use Exporter qw(import);
our @EXPORT = qw(filter_get_offset filter_get_limit filter_get_sort_direction filter_get_sort_condition filter_get_sort_column filter_get_text filter_is_case_sensitive);

sub filter_get_offset {
	my ($filter) = @_;
	return 0 unless ($filter);
	return ($filter->resultsStart() ? $filter->resultsStart() : 0);    
}

sub filter_get_limit {
	my ($filter) = @_;
	return 0 unless ($filter);
	return ($filter->resultsLimit() ? $filter->resultsLimit() : 0);
}

sub filter_get_sort_direction {
	my ($filter) = @_;
	return 'ASC' unless ($filter);
	return ($filter->sortDirection() == 1 ? 'ASC' : 'DESC');
}

sub filter_get_sort_condition {
	my ($filter) = @_;
	return undef unless ($filter);
	return ($filter->sortCondition() ? $filter->sortCondition() : undef);
}

sub filter_get_sort_column {
	my ($filter) = @_;
	return undef unless ($filter);
	return $filter->sortColumn();
}

sub filter_get_text {
	my ($filter) = @_;
	return undef unless ($filter);
	return $filter->text();
}

sub filter_is_case_sensitive {
	my ($filter) = @_;
	return 0 unless ($filter);
	return ($filter->sortCaseSensitive() ? $filter->sortCaseSensitive() : 0);
}


1;
