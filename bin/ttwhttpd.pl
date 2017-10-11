#!/usr/bin/env perl
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use common::sense;

$SIG{'HUP'} = 'IGNORE';

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
require HTTP::Request;

my @keep;

my @personalities = (
    {
        name  => 'echo',
        class => 'HTTP',
        cb    => sub {
            $_[0]->push_write(
qq~HTTP/1.1 200 Success\r
Content-Type: text/plain\r
Content-Length: ${[length $_[0]->{____}->{raw_request}]}->[0]\r
\r
$_[0]->{____}->{raw_request}~);
        },
    },
);

sub HTTP_start {
    my $self = shift;
    $self->push_read(
        line => sub {
            $_[0]->{____}->{raw_request} = "$_[1]$_[2]";
            $_[1]                        = '';
            $_[2]                        = '';
        }
    );
    $self->push_read( line => \&HTTP_hdr_read );
}

sub HTTP_have_hdr {
    my $self = shift;
    my $r               = HTTP::Request->parse( $self->{____}->{raw_request} );
    my @content_lengths = $r->header('Content-Length');
    my $content_length;
    until ( $content_length // $#content_lengths == 0 ) {
        $_              = pop @content_lengths;
        $content_length = $1
          if (/^(\d+)$/);
    }
    $content_length //= 0;
    if ( $content_length != 0 ) {
        $self->unshift_read(
            chunk => $content_length,
            sub {
                my $self = shift;
                $self->{____}->{raw_request} .= $_[0];
                $self->{____}->{request} =
                  HTTP::Request->parse( $self->{____}->{raw_request} );
                $self->{____}->{personality}->{cb}($self);
                HTTP_start($self);
            }
        );
    } else {
        $self->{____}->{request} = $r;
        $self->{____}->{personality}->{cb}($self);
        HTTP_start($self);
    }
}

sub HTTP_hdr_read {
    my $self = shift;

    $self->{____}->{raw_request} .= "$_[0]$_[1]";
    if ( length $_[0] == 0 ) {
        HTTP_have_hdr($self);
    } else {
        $self->unshift_read( line => \&HTTP_hdr_read );
    }
    $_[0] = '';
    $_[1] = '';
}

foreach my $personality (@personalities) {

    $personality->{name} .=
      ( 'o' x ( ( 16 + 1 + 5 ) - length $personality->{name} ) ) . '.onion'
      if ( $personality->{name} !~ /\.onion$/ );

    tcp_server 'unix/', '/var/tmp/' . $personality->{name}, sub {
        my $fh = shift;
        push @keep, new AnyEvent::Handle
          fh       => $fh,
          on_error => $personality->{on_error} // sub {
            my ( $hdl, $fatal, $msg ) = @_;
            warn $msg;
            $keep[ $hdl->{____}->{keepid} ] = undef;
            $hdl->destroy();
          },
	  timeout    => $personality->{timeout}    // 5,
          on_timeout => $personality->{on_timeout} // sub {
            my $hdl = shift;
            $keep[ $hdl->{____}->{keepid} ] = undef;
            $hdl->destroy();
          },
          ;
        $keep[-1]->{____}->{keepid}      = $#keep;
        $keep[-1]->{____}->{personality} = $personality;
        die
          unless ( exists $personality->{cb} );
        if ( $personality->{class} eq 'HTTP' ) {
            HTTP_start( $keep[-1] );
        } else {
            $personality->{cb}( $keep[-1] );
        }
    };
}

my $exit = AnyEvent->condvar;
AnyEvent->signal( signal => 'INT',  cb => $exit );
AnyEvent->signal( signal => 'TERM', cb => $exit );
$exit->recv;
exit(0);

1;
