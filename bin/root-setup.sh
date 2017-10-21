#!/bin/sh -ex

apt-get -yq update &&
	apt-get -yq --no-install-suggests --no-install-recommends \
	--allow-downgrades --allow-remove-essential \
	--allow-change-held-packages install \
	daemon socat libmojolicious-perl \
	ltrace \
	libssl-dev \
	libclass-method-modifiers-perl

cd t/httperf
autoreconf -i
./configure
make
