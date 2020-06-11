#!/bin/bash
cp "/shared/loadbalancer/haproxy.cfg" "/etc/haproxy/haproxy.cfg"

service haproxy restart
