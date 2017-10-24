use v5.10.1;
use common::sense;

use Test::More;

unless ( $ENV{TTW_TARGET} ~~ [ 'python', 'c' ] ) {
    plan tests => 1;
  SKIP: { skip 'Not needed for remote testing', 1; }
    exit 0;
}

use Proc::Daemon;
use constant PIDFILE => '/tmp/socksserver.pid';

my $d = Proc::Daemon->new(
    pid_file      => PIDFILE,
    work_dir      => '.',
    dont_close_fh => ['STDERR'],
);
die 'Already running' unless ( 0 == ( -r PIDFILE ? $d->Status(PIDFILE) : 0 ) );

use Fcntl;

my $k = $d->Init();
unless ( 0 == $k ) {
    plan tests => 1;
    ok $k, "Started Daemon at $k";
    exit 0;
}

my $output;
my $builder = Test::More->builder;
$builder->output( \$output );
$builder->failure_output( \$output );
$builder->todo_output( \$output );

my $tor2web;
if ( $ENV{TTW_TARGET} ~~ [ 'python', 'c' ] ) {
    use IPC::Run qw(start);
    $tor2web =
      start( [ '/bin/sh', 't/bin/tor2web', '-c', 't/etc/conf/test.conf' ],
        '/dev/null', \*STDERR, \*STDERR );
}

my $tests = 0;

my %tree = (
    'manualhttpdooooo.onion:80' => sub {
        my $client = shift;
        use HTTP::Headers;
        my $h = HTTP::Headers->new;
        my ( $hname, $hdata );
        while ( ( $_ = <$client> ) =~ /^[\r]?$/ ) {
            if ( $hname != undef ) {
                if (/^[ \t]/) {
                    $hdata .= $_;
                } else {
                    $h->push_header( $hname => $hdata );
                    /^([^:]*):?(.*)$/;
                    $hname = $1;
                    $hdata = $2;
                }
            } else {
                /^([^:]*):?(.*)$/;
                $hname = $1;
                $hdata = $2;
            }
        }
        $h->push_header( $hname => $hdata );
        $client->close();
    },
    'perlhttpdooooooo.onion:80' => sub {
        my $client = shift;
        use HTTP::Daemon();

        # This should not work.
        HTTP::Daemon::ClientConn::get_request($client);
        $client->close();
    },
    'chunkedooooooooo.onion:80' => sub {
        my $client = shift;
        my $len    = 1;
        while ( 0 != $len ) {
            my $request = '';
            while ( 0 < $len && $request !~ /\n/m ) {
                $len = $client->read( my $b, 1 );
                $request .= $b;
            }
            if ( 0 < $len ) {
                $tests++;
                ok $request =~ m%HTTP/1.1\r?\n%im, 'Have HTTP 1.1';
                if ( $request =~ m%//[a-z2-7]{16}\\.onion%i ) {
                    $tests++;
                    ok $request =~ m%//[a-z2-7]{16}\\.onion/%i,
                      'Correct hostname in request line';
                }
            }
            while ( 0 < $len && $request !~ /\n\r?\n/m ) {
                $len = $client->read( my $b, 1 );
                $request .= $b;
            }
            if ( 0 < $len ) {
                if ( $request =~ /^Host:\s*([a-z2-7]{16}\\.onion[^\r\n]*)/mi ) {
                    $tests++;
                    my $h = $1;
                    ok $request =~ m%^Host:\s*[a-z2-7]{16}\\.onion\r?\n/%i,
                      "Correct hostname in host header: $h";
                }
                if ( $request =~ /^Cookie:([^\r\n]*)/mi ) {
                    $tests++;
                    my $h = $1;
                    fail "Correct cookie domain: $h";
                }
                if ( $request =~ /^Content-Length:\s*([1-9][0-9]*)/mi ) {
                    my ( $b, $clen ) = ( undef, $1 );
                    while ( 0 < $clen ) {
                        $len = $client->read( $b, $clen );
                        $request .= $b;
                        $clen -= $len;
                    }
                }
            }
            if ( 0 < $len ) {
                $client->print(
"HTTP/1.1 200 Success\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\n\r\n"
                );
                my $off = 0;
                do {
                    my $len = int( rand(4) ) + 1;
                    $len-- while ( $off + $len > length $request );
                    $client->print(
                        sprintf "%x\r\n%s\r\n",
                        $len, substr $request,
                        $off, $len
                    );
                    $off += $len;
                } while ( $off < length $request );
                $client->print("0\r\n\r\n");
            }
        }
        $client->close();
    },
    'echooooooooooooo.onion:80' => sub {
        my $client = shift;

        my $pid = fork();

        if ( not defined $pid ) {
            diag "Failed to fork for echo: $!";
        } elsif ( $pid == 0 ) {
            my $flags = $client->fcntl( F_GETFD, 0 ) or die "fcntl F_GETFD: $!";
            $client->fcntl( F_SETFD, $flags & ~FD_CLOEXEC )
              or die "fcntl F_SETFD: $!";
            exec "socat FD:${[$client->fileno()]}[0] TCP:127.0.0.1:3000";
        } else {
            $client->close();
        }
    },
    'proxy2httpdooooo.onion:80' => sub {
        my $client = shift;

        # Open connection to httpd and enter bi-directional pass-through.
        # Ends when socket closes.
        $client->close();
    },
    'nulloooooooooooo.onion:25' => sub {
        my $client = shift;
        $client->close();
    },
    'exit:25' => sub {
        my $client = shift;

        $tests++;
      SKIP: {
            skip 'Not needed for remote targets', 1 unless ($tor2web);
            sleep 3;
            $tor2web->kill_kill();
            $tor2web->finish();
            is $tor2web->result(0), 0, 'valgrind ok';
        }

        done_testing($tests);
        $client->print($output);
        exit 0;
    },
);

use IO::Socket::Socks ':constants';

$IO::Socket::Socks::SOCKS4_RESOLVE = 1;
$IO::Socket::Socks::SOCKS5_RESOLVE = 0;
my $s;
until (
    $s = IO::Socket::Socks->new(
        SocksVersion => [ 4, 5 ],
        ProxyAddr    => '127.0.0.1',
        ProxyPort    => 9051,
        Listen       => 1,
    )
  )
{
    diag $IO::Socket::Socks::SOCKS_ERROR;
    sleep 3;
}

ok $s, 'Have socks server';
$tests++;

while (1) {
    my $client = $s->accept();

    unless ($client) {
        fail $IO::Socket::Socks::SOCKS_ERROR;
        $tests++;
        next;
    }

    my $command = $client->command();
    if ( $command->[0] == CMD_CONNECT ) {
        my $host = $client->version == 4 ? "0.0.0.1" : $command->[1];
        if ( exists $tree{"$command->[1]:$command->[2]"} ) {

            # Handle the CONNECT
            $client->command_reply(
                $client->version == 4 ? REQUEST_GRANTED : REPLY_SUCCESS,
                $host, $command->[2] );
            $client->autoflush(1);
            $tree{"$command->[1]:$command->[2]"}($client);
        } else {
            diag "Not found in tree: $command->[1]:$command->[2]";
            diag $client->command_reply(
                $client->version == 4
                ? REQUEST_FAILED
                : REPLY_ADDR_NOT_SUPPORTED,
                $host, $command->[2]
            );
        }
    } else {
        diag 'Unknowen command from socks:';
        use Data::Dumper;
        diag Dumper $command;
        $client->command_reply( $client->version == 4
            ? REQUEST_FAILED
            : REPLY_CMD_NOT_SUPPORTED,
            $command->[1], $command->[2] );
    }

    sleep 2;
    $client->close();
}

1;

exit 0;

1;
