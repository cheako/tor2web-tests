#!/usr/bin/env perl

use Mojolicious::Lite;
use Class::Method::Modifiers 'after';
use Scalar::Util 'weaken';

after 'Mojo::Message::parse' => sub {
    my ($m, $chunk) = @_;
    $m->emit(read_bytes => $chunk);
};

hook after_build_tx => sub {
    my $tx = shift;
    weaken(my $res = $tx->res);
    $tx->req->on(read_bytes => sub {
        $res->content->asset->add_chunk($_[1]);
    });
};

any '/1.0/*' => sub {
    my $c = shift;
    $c->res->headers->content_type('text/plain');
    $c->res->version('1.0');
    $c->rendered(200);
};

any '/1.0/' => sub {
    my $c = shift;
    $c->res->headers->content_type('text/plain');
    $c->res->version('1.0');
    $c->rendered(200);
};

any '/*' => sub {
    my $c = shift;
    $c->res->headers->content_type('text/plain');
    $c->rendered(200);
};

any '/' => sub {
    my $c = shift;
    $c->res->headers->content_type('text/plain');
    $c->rendered(200);
};

app->start;
