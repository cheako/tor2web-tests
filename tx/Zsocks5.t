use v5.10.1;
use common::sense;

unless ( $ENV{TTW_TARGET} ~~ [ 'python', 'c' ] ) {
    use Test::More;
    plan tests => 1;
  SKIP: { skip 'Not needed for remote testing', 1; }
    exit 0;
}

use IO::Socket::Socks;

my $s = IO::Socket::Socks->new(
    ProxyAddr   => '127.0.0.1',
    ProxyPort   => 9051,
    ConnectAddr => 'exit',
    ConnectPort => '25',
) or die $IO::Socket::Socks::SOCKS_ERROR;

$\ = undef;
print <$s>;

$s->close();

exit 0;

1;
