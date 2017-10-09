use common::sense;

use Test::More tests => 9;
use IPC::Run qw(start);

my $tor2web =
  start( [ '/bin/sh', 't/bin/tor2web', '-c', 't/etc/conf/test.conf' ],
    undef, '>&2' );

use IO::Socket::SSL;

# create a connecting socket
my $socket;
my $ctr = 0;
do {
    diag "Connection attempt $ctr: $!"
      if ( $ctr != 0 );
    sleep( ( $ctr == 0 ) * 4 + $ctr );
    $socket = new IO::Socket::SSL(
        PeerHost     => '127.0.0.1',
        PeerPort     => '8444',
        Proto        => 'tcp',
        SSL_hostname => 'echooooooooooooo.onion.test',
        SSL_ca_file  => './t/etc/ssl/test-cert.pem',
    );
  } while ( !$socket
    && $! == $!{ECONNREFUSED}
    && $ctr++ < 4 );
unless ($socket) {
    fail "Cannot connect to the server: $!";
    kill 'TERM', `cat t/var/run/test/test.pid`;
    $tor2web->finish();
    die;
}
pass 'Connected to server';

$socket->autoflush(1);

system '/bin/sh', '-c', '{ netstat -plunt; ps -ax; } >&2';
diag "tor2web pid: ".  `cat t/var/run/test/test.pid`;

sub one_response {
    my $sock = shift;
    my $len;
    my $response;
    do {
        my $b;
        $len = $sock->read( $b, 1 );
        $response .= $b;
    } while ( 0 < $len && $response !~ /\n\r?\n/m );
    if ( 0 < $len && $response =~ /^Content-Length:\s*([1-9][0-9]*)/mi ) {
        my ( $b, $clen ) = ( undef, $1 );
        while ( 0 < $clen ) {
            $len = $sock->read( $b, $clen );
            $response .= $b;
            $clen -= $len;
        }
    }
    if ( 0 == $len ) {
        fail 'Remote host closed connection';
        kill 'TERM', `cat t/var/run/test/test.pid`;
        $tor2web->finish();
        die;
    }
    return $response;
}

SKIP: {
    skip 'Temp for testing.', 4 if $ENV{TTWLANG} eq 'python';

    ok $socket->print(
"GET /index.txt HTTP/1.1\r\nConnection: keep-alive\r\nHost: echooooooooooooo.onion.test\r\n\r\n"
      ),
      'host header sent';
    is one_response($socket),
"HTTP/1.1 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 81\r\n\r\nGET /index.txt HTTP/1.1\r\nConnection: keep-alive\r\nHost: echooooooooooooo.onion\r\n\r\n",
      'host header read';

    ok $socket->print(
"GET https://echooooooooooooo.onion.test/index.txt HTTP/1.1\r\nConnection: keep-alive\r\n\r\n"
      ),
      'empty headers sent';
    is one_response($socket),
"HTTP/1.1 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 81\r\n\r\nGET https://echooooooooooooo.onion/index.txt HTTP/1.1\r\nConnection: keep-alive\r\n\r\n",
      'empty headers read';

}

ok $socket->print(
"GET /index.txt HTTP/1.1\r\nConnection: close\r\nHost: echooooooooooooo.onion.test\r\nContent-Length: 3\r\n\r\nok\n"
  ),
  'ok content sent';
is one_response($socket),
"HTTP/1.1 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 98\r\n\r\nGET /index.txt HTTP/1.1\r\nConnection: close\r\nHost: echooooooooooooo.onion\r\nContent-Length: 3\r\n\r\nok\n",
  'ok content read';

SKIP: {
    skip 'Does not support: "Connection: close"', 4 if $ENV{TTWLANG} eq 'c';
    my $b;
    is $socket->read( $b, 1 ), 0, 'Closed connection';
}
ok $socket->close(), 'closed';

kill 'TERM', `cat t/var/run/test/test.pid`;
$tor2web->finish();
is $tor2web->result(0), 0, 'valgrind ok';

exit 0;

1;
