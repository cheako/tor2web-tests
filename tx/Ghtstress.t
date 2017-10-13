use common::sense;

use Test::More tests => 1;

use IPC::Run qw(start);

my $tor2web =
  start( [ '/bin/sh', 't/bin/tor2web', '-c', 't/etc/conf/test.conf' ],
    undef, '>&2' );

sleep 4;
chdir 't/htstress';
system './build.sh; ./htstress -n 5000 -c 50 -t 4 -u /var/tmp/tor2web.sock http://echooooooooooooo.onion/';

$tor2web->kill_kill;
is $tor2web->result(0), 0, 'valgrind ok';

exit 0;

1;

