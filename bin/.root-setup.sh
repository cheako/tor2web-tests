#!/bin/sh

apt-get -yq update &&
	apt-get -yq --no-install-suggests --no-install-recommends \
	--allow-downgrades --allow-remove-essential \
	--allow-change-held-packages install \
	libev-perl \
	libanyevent-perl \
	libhttp-message-perl \
	libstring-escape-perl \

