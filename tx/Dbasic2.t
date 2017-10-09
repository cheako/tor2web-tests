use common::sense;

use Test::More tests => 9;
use IPC::Run qw(start);

my $tor2web =
  start( [ '/bin/sh', 't/bin/tor2web', '-c', 't/etc/conf/test.conf' ],
    undef, '>&2' );

use IO::Socket::SSL;

# create a connecting socket
my $socket;
my $ctr      = 0;
my @sockopts = (
    PeerHost     => '127.0.0.1',
    PeerPort     => '8444',
    Proto        => 'tcp',
    SSL_hostname => 'echooooooooooooo.onion.test',
    SSL_ca_file  => './t/etc/ssl/test-cert.pem',
);
do {
    diag "Connection attempt $ctr: $!"
      if ( $ctr != 0 );
    sleep( ( $ctr == 0 ) * 4 + $ctr );
    $socket = new IO::Socket::SSL(@sockopts);
  } while ( !$socket
    && $! == $!{ECONNREFUSED}
    && $ctr++ < 4 );
unless ($socket) {
    fail "Cannot connect to the server: $!";
    $tor2web->signal('INT');
    $tor2web->finish();
    die;
}
pass 'Connected to server';

$socket->autoflush(1);

system '/bin/sh', '-xc', '{ ps -ax; cat t/var/run/test/test.pid; } >&2';

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
    if ( 0 != $len && $response =~ m%^HTTP/1\.0% ) {
        while ( 0 != $len ) {
            my $b;
            $len = $sock->read( $b, $len );
            $response .= $b;
        }
        $sock->close();
        $sock = new IO::Socket::SSL(@sockopts);
        unless ($sock) {
            diag "Cannot connect to the server: $!";
            $tor2web->signal('INT');
            $tor2web->finish();
            die;
        }
    } elsif ( 0 == $len ) {
        fail 'Remote host closed connection';
        $tor2web->signal('INT');
        $tor2web->finish();
        die;
    }
    return ( $sock, $response );
}

my $resp;
ok $socket->print(
"GET /index.txt HTTP/1.0\r\nCookie: disclaimer_accepted=true\r\nHost: echooooooooooooo.onion.test\r\n\r\n"
  ),
  'host header sent';
( $socket, $resp ) = one_response($socket);
is $resp,
"HTTP/1.0 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 81\r\n\r\nGET /index.txt HTTP/1.1\r\nCookie: disclaimer_accepted=true\r\nHost: echooooooooooooo.onion\r\n\r\n",
  'host header read';

SKIP: {
skip 'tor2web python not support http proxy', 2 if ($ENV{TTWLANG} eq 'python');
ok $socket->print(
"GET https://echooooooooooooo.onion.test/index.txt HTTP/1.1\r\nCookie: disclaimer_accepted=true\r\n\r\n"
  ),
  'empty headers sent';
( $socket, $resp ) = one_response($socket);
is $resp,
"HTTP/1.0 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 81\r\n\r\nGET https://echooooooooooooo.onion/index.txt HTTP/1.1\r\nCookie: disclaimer_accepted=true\r\n\r\n",
  'empty headers read';
}

ok $socket->print(
"GET /index.txt HTTP/1.0\r\nCookie: disclaimer_accepted=true\r\nHost: echooooooooooooo.onion.test\r\nContent-Length: 3\r\n\r\nok\n"
  ),
  'ok content sent';
( $socket, $resp ) = one_response($socket);
is $resp,
"HTTP/1.0 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 98\r\n\r\nGET /index.txt HTTP/1.1\r\nCookie: disclaimer_accepted=true\r\nHost: echooooooooooooo.onion\r\nContent-Length: 3\r\n\r\nok\n",
  'ok content read';

ok $socket->close(), 'closed';

$tor2web->signal('INT');
$tor2web->finish();
is $tor2web->result(0), 0, 'valgrind ok';

exit 0;

1;
