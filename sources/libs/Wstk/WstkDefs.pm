# *****************************************************************************************
#
# (C)2018 aks
# https://github.com/akscf/
# *****************************************************************************************
package Wstk::WstkDefs;

#
# JSON-RPC constants
#
use constant RPC_ORIGIN_SERVER				    => 1;
use constant RPC_ORIGIN_METHOD				    => 2;
use constant RPC_ORIGIN_TRANSPORT			    => 3;
use constant RPC_ORIGIN_CLIENT				    => 4;

use constant RPC_ERROR_ILLEGAL_SERVICE			=> 1;
use constant RPC_ERROR_SERVICE_NOT_FOUND		=> 2;
use constant RPC_ERROR_CLASS_NOT_FOUND			=> 3;
use constant RPC_ERROR_METHOD_NOT_FOUND			=> 4;
use constant RPC_ERROR_PARAMETR_MISMATCH		=> 5;
use constant RPC_ERROR_PERMISSION_DENIED		=> 6;

use constant RPC_ERR_CODE_INTERNAL_ERROR		=> 1000;
use constant RPC_ERR_CODE_INVALID_ARGUMENT		=> 1001;
use constant RPC_ERR_CODE_ALREADY_EXISTS		=> 1002;
use constant RPC_ERR_CODE_NOT_FOUND			    => 1003;
use constant RPC_ERR_CODE_OUT_OF_DATE			=> 1004;
use constant RPC_ERR_CODE_PERMISSION_DENIED		=> 1005;
use constant RPC_ERR_CODE_UNAUTHORIZED_ACCESS	=> 1006;
use constant RPC_ERR_CODE_VALIDATION_FAIL       => 1007;


use Exporter qw(import);
our @EXPORT_OK = qw(
    RPC_ERROR_ILLEGAL_SERVICE
    RPC_ERROR_SERVICE_NOT_FOUND
    RPC_ERROR_CLASS_NOT_FOUND
    RPC_ERROR_METHOD_NOT_FOUND
    RPC_ERROR_PARAMETR_MISMATCH
    RPC_ERROR_PERMISSION_DENIED
    RPC_ERR_CODE_INTERNAL_ERROR
    RPC_ERR_CODE_INVALID_ARGUMENT
    RPC_ERR_CODE_ALREADY_EXISTS
    RPC_ERR_CODE_NOT_FOUND
    RPC_ERR_CODE_OUT_OF_DATE
    RPC_ERR_CODE_PERMISSION_DENIED
    RPC_ERR_CODE_UNAUTHORIZED_ACCESS
    RPC_ERR_CODE_VALIDATION_FAIL
);
our %EXPORT_TAGS = ( 'ALL' => \@EXPORT_OK );


1;



