use common::sense;

use Test::More tests => 12;

SKIP: {
    skip 'Temp for testing.', 12 if $ENV{TTWLANG} eq 'python';

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
            $tor2web->kill_kill;
            die;
        }
        return $response;
    }

    ok $socket->print(
        "GET https://echooooooooooooo.onion.test/index.txt HTTP/1.0\r\n\r\n"),
      'empty headers sent';
    is one_response($socket),
"HTTP/1.1 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 57\r\n\r\nGET https://echooooooooooooo.onion/index.txt HTTP/1.1\r\n\r\n",
      'empty headers read';

    ok $socket->print(
        "GET /index.txt HTTP/1.0\r\nHost: echooooooooooooo.onion.test\r\n\r\n"),
      'host header sent';
    is one_response($socket),
"HTTP/1.1 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 57\r\n\r\nGET /index.txt HTTP/1.1\r\nHost: echooooooooooooo.onion\r\n\r\n",
      'host header read';

    ok $socket->print(
"GET /index.txt HTTP/1.0\r\nHost: echooooooooooooo.onion.test\r\nContent-Length: 3\r\n\r\nok\n"
      ),
      'ok content sent';
    is one_response($socket),
"HTTP/1.1 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 79\r\n\r\nGET /index.txt HTTP/1.1\r\nHost: echooooooooooooo.onion\r\nContent-Length: 3\r\n\r\nok\n",
      'ok content read';

    ok $socket->print(
"GET /index.txt HTTP/1.1\r\nHost: echooooooooooooo.onion.test\r\nContent-Length: 3\r\n\r\nok\n"
      ),
      'ok 1.1 sent';
    is one_response($socket),
"HTTP/1.1 200 Success\r\nContent-Type: text/plain\r\nContent-Length: 79\r\n\r\nGET /index.txt HTTP/1.1\r\nHost: echooooooooooooo.onion\r\nContent-Length: 3\r\n\r\nok\n",
      'ok 1.1 read';

    ok $socket->close(), 'closed';

    $tor2web->kill_kill;
    is $tor2web->result(0), 0, 'valgrind ok';

}

exit 0;

1;