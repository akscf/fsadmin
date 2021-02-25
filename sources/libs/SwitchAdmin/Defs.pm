# *****************************************************************************************
# Copyright (C) AlexandrinKS
# https://akscf.me/
# *****************************************************************************************
package SwitchAdmin::Defs;

use constant ROLE_ADMIN  	 => 'ADMIN';
use constant ROLE_SUBSCRIBER => 'USER';
use constant ROLE_ANONYMOUS  => 'ANONYMOUS';

use Exporter qw(import);
our @EXPORT_OK = qw(
    ROLE_ADMIN
    ROLE_USER
    ROLE_ANONYMOUS
    STORAGE_VERSION
);
our %EXPORT_TAGS = ( 'ALL' => \@EXPORT_OK );

1;
