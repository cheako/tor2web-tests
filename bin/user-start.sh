#!/bin/sh
daemon --name=ttwhttpd --respawn -- bin/ttwhttpd.pl daemon
sleep 4
