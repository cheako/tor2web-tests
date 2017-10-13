use common::sense;

use Test::More tests => 1;

use IPC::Run qw(start);

my $tor2web =
  start( [ '/bin/sh', 't/bin/tor2web', '-c', 't/etc/conf/test.conf' ],
    undef, '>&2' );

sleep 4;
chdir 't/htstress';
system './build.sh; strace -s 800 ./htstress -n 5000 -c 50 -t 4 -h echooooooooooooo.onion http://127.0.0.1:8444/';

$tor2web->kill_kill;
is $tor2web->result(0), 0, 'valgrind ok';

exit 0;

1;

