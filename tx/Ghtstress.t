use common::sense;

use Test::More tests => 1;

use IPC::Run qw(start);

my $tor2web =
  start( [ '/bin/sh', 't/bin/tor2web', '-c', 't/etc/conf/test.conf' ],
    undef, '>&2' );

system 't/htstress/build.sh';
system 't/htstress/htstress -n 5000 -c 50 -t 4 http://127.0.0.1:8444/';

$tor2web->kill_kill;
is $tor2web->result(0), 0, 'valgrind ok';

exit 0;

1;
