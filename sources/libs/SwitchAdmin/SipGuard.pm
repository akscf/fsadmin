package SwitchAdmin::SipGuard;

use Exporter qw(import);
our @EXPORT = qw(guard_is_bot_ua);
our @EXPORT_OK = qw();

sub guard_is_bot_ua {
	my ($ua) = @_;
	unless ($ua) {
		return 0;
	}
	if($ua =~ /^(sipcli\/|vaxsipuseragent\/)/i) {
		return 1;
	}
}

1;