#!/bin/sh

opensslcmd() {
    LD_LIBRARY_PATH=../.. ../../apps/openssl $@
}

OPENSSL_CONF=../../apps/openssl.cnf
export OPENSSL_CONF

opensslcmd version

# Root CA: create certificate directly
CN="Test Root CA" opensslcmd req -config ca.cnf -x509 -nodes \
	-keyout root.pem -out root.pem -newkey rsa:2048 -days 3650
# Intermediate CA: request first
CN="Test Intermediate CA" opensslcmd req -config ca.cnf -nodes \
	-keyout intkey.pem -out intreq.pem -newkey rsa:2048
# Sign request: CA extensions
opensslcmd x509 -req -in intreq.pem -CA root.pem -days 3600 \
	-extfile ca.cnf -extensions v3_ca -CAcreateserial -out intca.pem

# Server certificate: create request first
CN="Test Server Cert" opensslcmd req -config ca.cnf -nodes \
	-keyout skey.pem -out req.pem -newkey rsa:1024
# Sign request: end entity extensions
opensslcmd x509 -req -in req.pem -CA intca.pem -CAkey intkey.pem -days 3600 \
	-extfile ca.cnf -extensions usr_cert -CAcreateserial -out server.pem

# Client certificate: request first
CN="Test Client Cert" opensslcmd req -config ca.cnf -nodes \
	-keyout ckey.pem -out creq.pem -newkey rsa:1024
# Sign using intermediate CA
opensslcmd x509 -req -in creq.pem -CA intca.pem -CAkey intkey.pem -days 3600 \
	-extfile ca.cnf -extensions usr_cert -CAcreateserial -out client.pem

# Revoked certificate: request first
CN="Test Revoked Cert" opensslcmd req -config ca.cnf -nodes \
	-keyout revkey.pem -out rreq.pem -newkey rsa:1024
# Sign using intermediate CA
opensslcmd x509 -req -in rreq.pem -CA intca.pem -CAkey intkey.pem -days 3600 \
	-extfile ca.cnf -extensions usr_cert -CAcreateserial -out rev.pem

# OCSP responder certificate: request first
CN="Test OCSP Responder Cert" opensslcmd req -config ca.cnf -nodes \
	-keyout respkey.pem -out respreq.pem -newkey rsa:1024
# Sign using intermediate CA and responder extensions
opensslcmd x509 -req -in respreq.pem -CA intca.pem -CAkey intkey.pem -days 3600 \
	-extfile ca.cnf -extensions ocsp_cert -CAcreateserial -out resp.pem

# Example creating a PKCS#3 DH certificate.

# First DH parameters

[ -f dhp.pem ] || opensslcmd genpkey -genparam -algorithm DH -pkeyopt dh_paramgen_prime_len:1024 -out dhp.pem

# Now a DH private key
opensslcmd genpkey -paramfile dhp.pem -out dhskey.pem
# Create DH public key file
opensslcmd pkey -in dhskey.pem -pubout -out dhspub.pem
# Certificate request, key just reuses old one as it is ignored when the
# request is signed.
CN="Test Server DH Cert" opensslcmd req -config ca.cnf -new \
	-key skey.pem -out dhsreq.pem
# Sign request: end entity DH extensions
opensslcmd x509 -req -in dhsreq.pem -CA root.pem -days 3600 \
	-force_pubkey dhspub.pem \
	-extfile ca.cnf -extensions dh_cert -CAcreateserial -out dhserver.pem

# DH client certificate

opensslcmd genpkey -paramfile dhp.pem -out dhckey.pem
opensslcmd pkey -in dhckey.pem -pubout -out dhcpub.pem
CN="Test Client DH Cert" opensslcmd req -config ca.cnf -new \
	-key skey.pem -out dhcreq.pem
opensslcmd x509 -req -in dhcreq.pem -CA root.pem -days 3600 \
	-force_pubkey dhcpub.pem \
	-extfile ca.cnf -extensions dh_cert -CAcreateserial -out dhclient.pem

# Examples of CRL generation without the need to use 'ca' to issue
# certificates.
# Create zero length index file
>index.txt
# Create initial crl number file
echo 01 >crlnum.txt
# Add entries for server and client certs
opensslcmd ca -valid server.pem -keyfile root.pem -cert root.pem \
		-config ca.cnf -md sha1
opensslcmd ca -valid client.pem -keyfile root.pem -cert root.pem \
		-config ca.cnf -md sha1
opensslcmd ca -valid rev.pem -keyfile root.pem -cert root.pem \
		-config ca.cnf -md sha1
# Generate a CRL.
opensslcmd ca -gencrl -keyfile root.pem -cert root.pem -config ca.cnf \
		-md sha1 -crldays 1 -out crl1.pem
# Revoke a certificate
openssl ca -revoke rev.pem -crl_reason superseded \
		-keyfile root.pem -cert root.pem -config ca.cnf -md sha1
# Generate another CRL
opensslcmd ca -gencrl -keyfile root.pem -cert root.pem -config ca.cnf \
		-md sha1 -crldays 1 -out crl2.pem

