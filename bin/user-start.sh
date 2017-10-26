#!/bin/sh
daemon --name=ttwhttpd --respawn --output=/tmp/ttwhttpd.log -- bin/ttwhttpd.pl daemon
daemon --name=socatssl --respawn -E /dev/stderr -- strace -f -s 200 socat TCP-LISTEN:8081,fork OPENSSL:127.0.0.1:8444,cafile=etc/ssl/test-cert.pem,verify=0
