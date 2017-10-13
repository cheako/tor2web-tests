#!/bin/sh
daemon --name=ttwhttpd --respawn --output=/tmp/ttwhttpd.log -- /usr/src/github/tor2web/t/bin/ttwhttpd.pl daemon
daemon --name=socatssl --respawn -- socat UNIX-LISTEN:/var/tmp/tor2web.sock,fork OPENSSL:127.0.0.1:8444
