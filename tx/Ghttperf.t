use common::sense;

use Test::More tests => 1;

chdir 't/httperf/src';
my $sys;
if (
    0 == (
        $sys = system './httperf',
        '--hog',
        '--add-header=Cookie: disclaimer_accepted=true\n',
        '--ssl',
        '--ssl-ca-file=../etc/ssl/test-cert.pem',
        '--server-name=echooooooooooooo.onion',
        '--port=8081',
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
