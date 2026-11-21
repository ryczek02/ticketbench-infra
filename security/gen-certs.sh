#!/bin/sh
# Generates the benchmark CA, one server certificate for all databases and
# the MongoDB replica set key file. Runs once in the "certs" container.
set -eu
cd /certs
if [ -f server.crt ]; then echo "certificates already present"; exit 0; fi
apk add --no-cache openssl >/dev/null
openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj "/CN=ticketbench CA" \
  -keyout ca.key -out ca.crt 2>/dev/null
cat > san.cnf <<CNF
[req]
distinguished_name = dn
[dn]
[ext]
subjectAltName = DNS:postgres,DNS:mariadb,DNS:mongo,DNS:valkey,DNS:localhost,IP:127.0.0.1
extendedKeyUsage = serverAuth
CNF
openssl req -newkey rsa:2048 -nodes -subj "/CN=ticketbench" -keyout server.key -out server.csr 2>/dev/null
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 365 \
  -extfile san.cnf -extensions ext -out server.crt 2>/dev/null
cat server.crt server.key > server.pem
openssl rand -base64 756 > mongo.key
rm -f server.csr san.cnf ca.srl
# Database images run as uid 999; store services (nonroot) only need ca.crt.
chown 999:999 server.key server.pem mongo.key server.crt
chmod 600 server.key server.pem
chmod 400 mongo.key
chmod 644 ca.crt server.crt
rm -f ca.key
echo "certificates generated"
