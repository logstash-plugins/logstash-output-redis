#!/bin/sh

set -e

redis-server --tls-port $PORT --port 0 --tls-cert-file /certificates/redis.crt --tls-key-file /certificates/redis.key --tls-ca-cert-file /certificates/ca.crt