#!/usr/bin/env perl

use common::sense;

use Test::More tests => 6;

use IO::Socket::SSL;

my $cafile = 't/etc/ssl/test-cert.pem';
if ( !-d 't' ) {
    if ( -d '../t' ) {
        $cafile = "../$cafile";
    } elsif ( -d '../../t' ) {
        $cafile = "../../$cafile";
    } else {
        die q(Can't find test folder.);
    }
}

# create a connecting socket
my $socket;
my $ctr      = 0;
my @sockopts = (
    PeerHost     => '127.0.0.1',
    PeerPort     => '8444',
    Proto        => 'tcp',
    SSL_hostname => 'echooooooooooooo.onion.test',
    SSL_ca_file  => $cafile,
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
    $response =~ s/^Date:[^\n]*\n//im;
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
            die;
        }
    } elsif ( 0 == $len ) {
        fail 'Remote host closed connection';
        die;
    }
    return ( $sock, $response );
}

use HTTP::Response ();

my $resp;
ok $socket->print(
    qq~GET /index.txt HTTP/1.0\r
Cookie: disclaimer_accepted=true\r
Host: echooooooooooooo.onion.test\r
\r
~
  ),
  'host header sent';
( $socket, $resp ) = one_response($socket);
my $got      = HTTP::Response->parse($resp);
my $expected = HTTP::Response->parse(
    $ENV{TTW_TARGET} eq 'python'
    ? qq~HTTP/1.0 200 OK\r
X-Check-Tor: false\r
Content-Security-Policy: upgrade-insecure-requests\r
Strict-Transport-Security: max-age=31536000; includeSubDomains\r
Server: Mojolicious (Perl)\r
Content-Type: text/plain\r
\r
GET /index.txt HTTP/1.1\r
Accept-Encoding: gzip, chunked\r
X-Forwarded-Host: echooooooooooooo.onion.test\r
Connection: keep-alive\r
X-Tor2web: 1\r
Host: echooooooooooooo.onion\r
X-Forwarded-Proto: https\r
Cookie: disclaimer_accepted=true\r
\r
~
    : qq~HTTP/1.1 200 OK\r
Content-Length: 91\r
Server: Mojolicious (Perl)\r
Content-Type: text/plain\r
\r
GET /index.txt HTTP/1.1\r
Cookie: disclaimer_accepted=true\r
Host: echooooooooooooo.onion\r
\r
~
);
is_deeply $got, $expected, 'host header read';

ok $socket->print(
    qq~GET /index.txt HTTP/1.0\r
Cookie: disclaimer_accepted=true\r
Host: echooooooooooooo.onion.test\r
Content-Length: 3\r
\r
ok
~
  ),
  'ok content sent';
( $socket, $resp ) = one_response($socket);
$got      = HTTP::Response->parse($resp);
$expected = HTTP::Response->parse(
    $ENV{TTW_TARGET} eq 'python'
    ? qq~HTTP/1.0 200 OK\r
X-Check-Tor: false\r
Content-Security-Policy: upgrade-insecure-requests\r
Strict-Transport-Security: max-age=31536000; includeSubDomains\r
Server: Mojolicious (Perl)\r
Content-Type: text/plain\r
\r
GET /index.txt HTTP/1.1\r
Content-Length: 3\r
Accept-Encoding: gzip, chunked\r
X-Forwarded-Host: echooooooooooooo.onion.test\r
Connection: keep-alive\r
X-Tor2web: 1\r
Host: echooooooooooooo.onion\r
X-Forwarded-Proto: https\r
Cookie: disclaimer_accepted=true\r
\r
ok
~
    : qq~HTTP/1.1 200 OK\r
Content-Type: text/plain\r
Server: Mojolicious (Perl)\r
Content-Length: 113\r
\r
GET /index.txt HTTP/1.1\r
Cookie: disclaimer_accepted=true\r
Host: echooooooooooooo.onion\r
Content-Length: 3\r
\r
ok
~
);
is_deeply $got, $expected, 'ok content read';

ok $socket->close(), 'closed';

exit 0;

1;
