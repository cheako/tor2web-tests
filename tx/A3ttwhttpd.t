#!/usr/bin/env perl

use v5.10.1;
use common::sense;

use Test::More tests => 1;

unless ( $ENV{TTW_TARGET} ~~ [ 'python', 'c' ] ) {
  SKIP: { skip 'Not needed for remote testing', 1; }
    exit 0;
}

use IO::Socket;

sleep 2;
system '{ ps ax; netstat -plunt; cat /var/log/daemon.log; } >&2';

my $sock;
until ( $sock = IO::Socket::INET->new('127.0.0.1:3000') ) {
    diag "Connecting to ttwhttpd server: $!";
    sleep 2
}
pass 'Connected to ttwhttpd server';

1;
