
#!/bin/bash

# COPIED/MODIFIED from the redis server gen-certs util
# https://github.com/redis/redis/blob/cc0091f0f9fe321948c544911b3ea71837cf86e3/utils/gen-test-certs.sh

# Generate some test certificates which are used by the regression test suite:
#
#   ca.{crt,key}          Self signed CA certificate.
#   redis.{crt,key}       A certificate with no key usage/policy restrictions.
#   client.{crt,key}      A certificate restricted for SSL client usage.
#   server.{crt,key}      A certificate restricted for SSL server usage.
#   redis.dh              DH Params file.

generate_cert() {
    local name=$1
    local cn="$2"
    local opts="$3"

    local keyfile=${name}.key
    local certfile=${name}.crt

    [ -f $keyfile ] || openssl genrsa -out $keyfile 2048
    openssl req \
        -new -sha256 \
        -subj "/O=Redis Test/CN=$cn" \
        -key $keyfile | \
        openssl x509 \
            -req -sha256 \
            -CA ca.crt \
            -CAkey ca.key \
            -CAserial ca.txt \
            -CAcreateserial \
            -days 999999 \
            $opts \
            -out $certfile
}

[ -f ca.key ] || openssl genrsa -out ca.key 4096
openssl req \
    -x509 -new -nodes -sha256 \
    -key ca.key \
    -days 3650 \
    -subj '/O=Redis Test/CN=Certificate Authority' \
    -out ca.crt

cat > openssl.cnf <<_END_
[ server_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = server
[ client_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = client
_END_

generate_cert server "Server-only" "-extfile openssl.cnf -extensions server_cert"
generate_cert client "Client-only" "-extfile openssl.cnf -extensions client_cert"
generate_cert redis "Generic-cert"

[ -f redis.dh ] || openssl dhparam -out redis.dh 2048
