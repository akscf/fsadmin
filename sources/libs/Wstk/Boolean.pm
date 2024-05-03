# *****************************************************************************************
#
# (C)2018 aks
# https://github.com/akscf/
# *****************************************************************************************
package Wstk::Boolean;

use constant TRUE  => 'true';
use constant FALSE => 'false';

sub is_true {
    return 1 if($_[0] eq TRUE);
    return undef;
}

sub is_false {
    return 1 if($_[0] eq FALSE);
    return undef;
}

use Exporter qw(import);
our @EXPORT = qw(is_true is_false TRUE FALSE);
our @EXPORT_OK = qw();

1;



