# ******************************************************************************************
#
# (C)2021 aks
# https://github.com/akscf/
# ******************************************************************************************
package SwitchAdmin::CacheManager;

use DBI;
use Wstk::WstkException;

sub new ($$;$) {
    my ($class, $pmod, $db_name) = @_;
    my $self = {
        logger          => Log::Log4perl::get_logger(__PACKAGE__),
        class_name      => $class,
        fsadmin         => $pmod,
    };
    bless( $self, $class );
    return $self;
}

sub get_class_name {
    my ($self) = @_;
    return $self->{class_name};
}
# ----------------------------------------------------------------------------------------

#
# TODO
#

# ----------------------------------------------------------------------------------------
1;
