#!/bin/bash
daemon --name=ttwhttpd --respawn -- bin/ttwhttpd.pl daemon
sleep 2
