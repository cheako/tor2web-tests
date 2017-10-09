use common::sense;

use open ':std', ':encoding(utf8)';
use Test::More tests => 12;
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
        SSL_hostname => 'chunkedooooooooo.onion.test',
        SSL_ca_file  => './t/etc/ssl/test-cert.pem',
    );
  } while ( !$socket
    && $! == $!{ECONNREFUSED}
    && $ctr++ < 4 );
unless ($socket) {
    fail "Cannot connect to the server: $!";
    $tor2web->kill_kill;
    die;
}
pass 'Connected to server';

$socket->autoflush(1);

sub one_response {
    my $sock = shift;
    my $len;
    my $response;
    do {
        my $b;
        $len = $sock->read( $b, 1 );
        $response .= $b;

        #  $b =~ tr[\0-\x1F\x7F]
        #  [\x{2400}-\x{241F}\x{2421}];
    } while ( 0 < $len && $response !~ /\n\r?\n/m );
    if ( 0 < $len && $response =~ /^Content-Length:\s*([1-9][0-9]*)/mi ) {
        my ( $b, $clen ) = ( undef, $1 );
        while ( 0 < $clen ) {
            $len = $sock->read( $b, $clen );
            $response .= $b;
            $clen -= $len;

            #    $b =~ tr[\0-\x1F\x7F]
            #  [\x{2400}-\x{241F}\x{2421}];
        }
    }
    if ( 0 == $len ) {
        fail 'Remote host closed connection';
        $tor2web->kill_kill;
        die;
    }
    return $response;
}

ok $socket->print(
    "GET https://chunkedooooooooo.onion.test/index.txt HTTP/1.0\n\r\n"),
  'empty headers sent';
is one_response($socket),
"HTTP/1.1 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 56\r\n\r\nGET https://chunkedooooooooo.onion/index.txt HTTP/1.1\n\r\n",
  'empty headers read';

ok $socket->print(
    "GET /index.txt HTTP/1.0\r\nHost: chunkedooooooooo.onion.test\r\n\r\n"),
  'host header sent';
is one_response($socket),
"HTTP/1.1 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 57\r\n\r\nGET /index.txt HTTP/1.1\r\nHost: chunkedooooooooo.onion\r\n\r\n",
  'host header read';

ok $socket->print(
"GET /index.txt HTTP/1.0\nHost: chunkedooooooooo.onion.test\r\nContent-Length: 3\r\n\r\nok\n"
  ),
  'ok content sent';
is one_response($socket),
"HTTP/1.1 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 78\r\n\r\nGET /index.txt HTTP/1.1\nHost: chunkedooooooooo.onion\r\nContent-Length: 3\r\n\r\nok\n",
  'ok content read';

ok $socket->print(
"GET /index.txt HTTP/1.1\nHost: chunkedooooooooo.onion.test\r\nContent-Length: 3\r\n\r\nkk\n"
  ),
  'ok 1.1 sent';
is one_response($socket),
"HTTP/1.1 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 78\r\n\r\nGET /index.txt HTTP/1.1\nHost: chunkedooooooooo.onion\r\nContent-Length: 3\r\n\r\nkk\n",
  'ok 1.1 read';

ok $socket->close(), 'closed';

$tor2web->kill_kill;
$tor2web->finish();
is $tor2web->result(0), 0, 'valgrind ok';

exit 0;

1;
