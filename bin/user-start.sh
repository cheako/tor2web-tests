#!/bin/sh
daemon --name=ttwhttpd --respawn -l daemon.crit -b daemon.err -E daemon.crit -O daemon.err -- bin/ttwhttpd.pl daemon
