# ******************************************************************************************
#
# (C)2018 aks
# https://github.com/akscf/
# ******************************************************************************************
package Wstk::EntityHelper;

use Exporter qw(import);
our @EXPORT = qw(entity_class_eq entity_instance_of entity_get_class entity_map entity_map2 entity_copy_by_fields is_empty is_digit entity_bless);

sub entity_class_eq {
	my ($e1, $e2) = @_;
	
	return 0 if(!$e1 || !$e2);
	return 0 if(!$e1->{'class'} || !$e2->{'class'});
	return ($e1->{'class'} eq $e2->{'class'});
}

#
sub entity_instance_of {
	my ($e1, $class) = @_;
	
	return 0 if(!$e1 || !$class);
	return ($e1->{'class'} eq $class);
}

sub entity_get_class {
	my ($e) = @_;
	
	return undef unless($e);
	return  $e->{'class'};
}

# for camelCase names
sub entity_map {
	my ($entity, $fmap) = @_;
	unless($fmap) {
		return $entity;
	}
	foreach $k (keys %{$fmap}) {
		next if($k eq 'class');
		my $ev = $k;
		$ev =~ s/\_(\w)/\u\L$1/g;
		$entity->{$ev} = $fmap->{$k};
	}
	return $entity;
}

# for '_' like names
sub entity_map2 {
	my ($entity, $fmap) = @_;
	unless($fmap) {
		return $entity;
	}
	foreach $k (keys %{$entity}) {
		next if($k eq 'class');
		$entity->{$k} = $fmap->{$k};
	}
	return $entity;
}

sub entity_copy_by_fields {
	my ($entity1, $entity2, $fields) = @_;
        
	foreach $f (@{$fields}) {
		#my $f=\&entity1->$f;
		#f($entity2->{$f});
		$entity1->{$f} = $entity2->{$f};
	}
	return $entity1;
}

sub is_empty {
	my ($str) = @_;
	if(!defined($str) || $str eq "") {
		return 1;
	}
	return undef;
}

sub is_digit {
    return(defined $_[0] && $_[0] =~ /^\d+$/);
}

sub entity_bless {
	my($hash, $class) = @_;
	if (ref($hash) eq 'HASH') {
		return bless($hash, $class);
	}
	return $hash;       
}

1;
