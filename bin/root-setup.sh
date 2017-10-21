#!/bin/sh -x

apt-get -yq update &&
	apt-get -yq --no-install-suggests --no-install-recommends \
	--allow-downgrades --allow-remove-essential \
	--allow-change-held-packages install \
	daemon socat libmojolicious-perl \
	ltrace \
	libssl-dev \
	libtool \
	libclass-method-modifiers-perl

cd t/httperf
libtoolize --force
autoreconf -i
automake
./configure
make
find -name httperf
