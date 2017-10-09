use common::sense;

use Test::More;

use IO::Socket::Socks;

my $s = IO::Socket::Socks->new(
    ProxyAddr   => '127.0.0.1',
    ProxyPort   => 9051,
    ConnectAddr => 'exit',
    ConnectPort => '25',
) or die $IO::Socket::Socks::SOCKS_ERROR;

$\ = undef;
print <$s>;

exit 0;

1;
