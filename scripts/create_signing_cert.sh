#!/bin/bash
set -e
set -x

CERT_NAME="DexDictate Development"
BUNDLE_ID="com.westkitty.dexdictate.macos"

# Check if certificate exists
if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo "✅ Certificate exists: $CERT_NAME"
    exit 0
fi

echo "Creating self-signed certificate for code signing..."

# Create temporary config for certificate generation
cat > /tmp/cert_config.cfg <<EOF
[ req ]
default_bits = 2048
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[ req_distinguished_name ]
CN = $CERT_NAME
O = WestKitty
OU = Development

[ v3_req ]
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
basicConstraints = critical,CA:false
EOF

# Generate certificate using OpenSSL
openssl req -x509 -newkey rsa:2048 -keyout /tmp/dev_key.pem -out /tmp/dev_cert.pem \
    -days 3650 -nodes -config /tmp/cert_config.cfg

# Convert to P12 format for keychain import
openssl pkcs12 -export -out /tmp/dev_cert.p12 \
    -inkey /tmp/dev_key.pem -in /tmp/dev_cert.pem -password pass:1234 -legacy

# Import to login keychain
security import /tmp/dev_cert.p12 -k ~/Library/Keychains/login.keychain-db \
    -P "1234" -T /usr/bin/codesign -T /usr/bin/productbuild

# Trust the certificate
security add-trusted-cert -d -r trustRoot \
    -k ~/Library/Keychains/login.keychain-db /tmp/dev_cert.pem

# Cleanup temporary files
rm /tmp/cert_config.cfg /tmp/dev_key.pem /tmp/dev_cert.pem /tmp/dev_cert.p12

echo "✅ Certificate created and trusted: $CERT_NAME"
echo "CDHash will now remain stable across rebuilds"
