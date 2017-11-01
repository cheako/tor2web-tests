#!/usr/bin/env perl

use common::sense;

use Test::More tests => 1;

my $httperfdir = 't/httperf/src';
if ( !-d 't' ) {
    if ( -d '../t' ) {
        $httperfdir = "../$httperfdir ";
    } elsif ( -d '../../t' ) {
        $httperfdir = "../../$httperfdir ";
    } else {
        die q(Can't find test folder.);
    }
}
warn $httperfdir;
warn chdir $httperfdir;
system 'find';
my $sys;
if (
    0 == (
        $sys = system 'strace', '-s', '200', './httperf',
        '--hog',
        '--add-header=Cookie: disclaimer_accepted=true\n',
        '--ssl',
        '--ssl-ca-file=../../etc/ssl/test-cert.pem',
        '--server-name=echooooooooooooo.onion',
        '--port=8444',
        '--num-conn=100',
        '--timeout=5',
        '--burst-length=5',
        '--num-calls=50',
        '--verbose',
    )
  )
{
    pass 'httperf';
} else {
    is $sys, 0, $?;
}

exit 0;

1;
