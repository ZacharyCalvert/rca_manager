#!/bin/bash

# This script is a monolithic single file for simple portability -> this is most
# certainly not a good example of a clean bash script.

function usage {
   echo "This script is used to create sample SSL certificates, including support"
   echo "for intermediate certificate chains.  Do not treat this script as a means"
   echo "to generate or manage your production SSL certificates."
   echo "Usage: ./<script.sh> [clean|single|intermediate] [site.company.TLD]"
   echo "   clean:        cleans (deletes) the ./.ssl directory"
   echo "   single:       Generates a root certificate and a single site SSL cert"
   echo "   intermediate: Generates a root certificate, an intermediate certificate, "
   echo "                 and a site SSL cert."
   echo "   site:         target deploy such as devlocal.mycompany.com.  The "
   echo "                 values are split up to define the company name and "
   echo "                 the domain <company.tld> for the admin email address."
   exit 1
}

function exitOnFailure {
    if [ $? -ne 0 ]; then
        echo "$1"
        exit 1
    fi
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
commonName              = root-ssl.$DOMAIN
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

function testOpenSsl {
    command -v openssl >/dev/null 2>&1 || { echo "Openssl is not on the path.  Please install openssl.  Aborting." >&2; exit 1; }
}

function validateInput {
    if [ "" == "$1" ] || [ "" == "$2" ] ; then
        usage
    fi
    if [ "single" != "$1" ] && [ "intermediate" != "$1" ] && [ "clean" != "$1" ] ; then
        usage
    fi
    export SERVER=$2
    export COMPANY=`echo "$2" | awk -F '.' '{print $(NF-1)}'`
    export TLD=`echo "$2" | awk -F '.' '{print $(NF)}'`
    export DOMAIN=${COMPANY}.${TLD}
    export SUPPORT_EMAIL="ssl-admin@$DOMAIN"

    if [ "" == "$COMPANY" ]; then
        usage
    fi
    echo "Server target: $SERVER"
    echo "Company: $COMPANY"
    echo "Support contact email: $SUPPORT_EMAIL"
}

function createSslFolderIfNotExist {
  if [ ! -d "./.ssl" ]; then
    mkdir ./.ssl
    exitOnFailure "Could not create local .ssl directory"
  fi
}

testOpenSsl
validateInput $1 $2
createSslFolderIfNotExist
exit 0

generateRootCertConf > ./.ssl/root.cnf
generateSingleCertConf > ./.ssl/server.cnf
