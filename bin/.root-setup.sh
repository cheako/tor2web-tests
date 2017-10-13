#!/bin/sh

apt-get -yq update &&
	apt-get -yq --no-install-suggests --no-install-recommends \
	--allow-downgrades --allow-remove-essential \
	--allow-change-held-packages install \
	daemon socat libmojolicious-perl \
	ltrace \
	libclass-method-modifiers-perl

