#!/bin/bash
daemon --name=ttwhttpd --respawn -f -- strace -f -s 200 bin/ttwhttpd.pl daemon&
disown
