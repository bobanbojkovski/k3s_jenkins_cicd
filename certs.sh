#!/bin/bash

vault write -format=json pki/issue/example-dot-com \
        common_name="jenkins.example.com" > /tmp/certs.json

cat /tmp/certs.json | jq '.data.certificate' > /tmp/tls.crt
cat /tmp/certs.json | jq '.data.private_key' > /tmp/tls.key

sed -i 's/\\n/\n/g' /tmp/tls.crt /tmp/tls.key
sed -i 's/\"//g' /tmp/tls.crt /tmp/tls.key

