use common::sense;

use Test::More tests => 1;

use IO::Socket;
use IO::Socket::Socks;

sleep 2;

my $sock;
until ( $sock = IO::Socket::INET->new('127.0.0.1:9051') ) {
    diag "Connecting to socks server: $!";
    sleep 59 if ( $! == $!{ECONNREFUSED} );
    sleep 2;
}
$sock = IO::Socket::Socks->start_SOCKS(
    $sock,
    ConnectAddr => 'nulloooooooooooo.onion',
    ConnectPort => 25
) or fail $IO::Socket::Socks::SOCKS_ERROR;
pass 'Connected through socks server';

1;
