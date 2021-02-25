# *****************************************************************************************
# Generic exception
#
# Copyright (C) AlexandrinKS
# https://akscf.me/
# *****************************************************************************************
package Wstk::WstkException;
use Wstk::WstkDefs qw (RPC_ERR_CODE_INTERNAL_ERROR);
use overload
 '""'     => sub { $_[0]->to_string };
  
sub new ($$) {    
    my($class, $message, $code, $cause) = @_;
    my $self = {
	    class_name 	=> $class,
	    message	    => $message,
	    code	    => $code ? $code : RPC_ERR_CODE_INTERNAL_ERROR,
	    cause	    => $cause
      };
    bless($self, $class);
    return $self;    
}

sub get_code {
    my($self) = @_;
    return  $self->{code};
}

sub get_message {
    my($self) = @_;
    return  $self->{message};
}


sub get_cause {
    my($self) = @_;
    return  $self->{cause};
}

sub to_string {
    my($self) = @_;
    return  'WstkException: ' .$self->{message}. ($self->{code} ? ' (#'.$self->{code}.')' : '' );
}

1;
