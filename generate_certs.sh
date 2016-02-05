#!/bin/bash

# This script is a monolithic single file for simple portability -> this is most
# certainly not a good example of a clean bash script.

function usage {
   echo "This script is used to create sample SSL certificates, including support"
   echo "for intermediate certificate chains.  Do not treat this script as a means"
   echo "to generate your production SSL certificates."
}

function generateRootCertConf {
cat <<EOF
[ ca ]
default_ca      = local_ca
[ local_ca ]
dir             = ./.ssl
certificate     = $dir/cacert.pem
database        = $dir/index.txt
new_certs_dir   = $dir/signedcerts
private_key     = $dir/private/cakey.pem
serial          = $dir/serial
default_crl_days        = 730
default_days            = 1825
default_md              = sha1
policy          = local_ca_policy
[ local_ca_policy ]
commonName              = supplied
stateOrProvinceName     = supplied
countryName             = supplied
emailAddress            = supplied
organizationName        = supplied
organizationalUnitName  = supplied
[ local_ca_extensions ]
extendedKeyUsage        = serverAuth,clientAuth,codeSigning,msCodeInd,msCodeCom
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
basicConstraints        = CA:true
[ req ]
default_bits    = 2048
default_keyfile = ./ssl/private/cakey.pem
default_md      = sha1
prompt                  = no
distinguished_name      = root_ca_distinguished_name
[ root_ca_distinguished_name ]
commonName              = single-root-ssl.$DOMAIN
stateOrProvinceName     = TX
countryName             = US
emailAddress            = IT_SSL@$DOMAIN
organizationName        = $COMPANY
organizationalUnitName  = dev
[ root_ca_extensions ]
extendedKeyUsage        = serverAuth,clientAuth,codeSigning,msCodeInd,msCodeCom
basicConstraints        = CA:true
EOF
}
function generateSingleCertConf {
cat <<EOF
[ req ]
prompt                  = no
distinguished_name      = server_distinguished_name
x509_extensions         = local_extensions

[ server_distinguished_name ]
commonName              = $SERVER
stateOrProvinceName     = Texas
countryName             = US
emailAddress            = test@$DOMAIN
organizationName        = $COMPANY
organizationalUnitName  = dev

[ local_extensions ]
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
basicConstraints        = CA:true
EOF
}
mkdir ./.ssl
generateRootCertConf > ./.ssl/root.cnf
generateSingleCertConf > ./.ssl/server.cnf
