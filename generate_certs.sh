#!/bin/bash

# This script is a monolithic single file for simple portability -> this is most
# certainly not a good example of a clean bash script.

# Constant variables for SSL generation
KEYSTORE_PASS=changeit

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
        if $2 ; then
            #we are in the .ssl directory, pop directory out
            popd > /dev/null 2>&1
        fi
        echo "$1"
        exit 1
    fi
}

# Configuration local environment variables
# SERVER
# COMPANY
# SUPPORT_EMAIL
# DOMAIN

function generateRootCertConf {
cat <<EOF
[ ca ]
default_ca      = local_ca
[ local_ca ]
dir             = ./rca
certificate     = rca/cacert.pem
database        = rca/index.txt
new_certs_dir   = rca/signedcerts
private_key     = rca/private/cakey.pem
serial          = rca/serial
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
default_keyfile = ./rca/private/cakey.pem
default_md      = sha1
prompt                  = no
distinguished_name      = root_ca_distinguished_name
[ root_ca_distinguished_name ]
commonName              = root-rca.$DOMAIN
stateOrProvinceName     = TX
countryName             = US
emailAddress            = $SUPPORT_EMAIL
organizationName        = $COMPANY
organizationalUnitName  = dev
[ root_ca_extensions ]
extendedKeyUsage        = serverAuth,clientAuth,codeSigning,msCodeInd,msCodeCom
basicConstraints        = CA:true
EOF
}

function generateSerialOutput {
cat <<EOF
01

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
emailAddress            = $SUPPORT_EMAIL
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
    if [ "" == "$1" ]; then
        usage
    fi
    if [ "single" != "$1" ] && [ "intermediate" != "$1" ] && [ "clean" != "$1" ] ; then
        usage
    fi

    if [ "clean" != "$1" ]; then
        if [ "" == "$2" ]; then
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
        echo "Company domain: $DOMAIN"
        echo "Server target: $SERVER"
        echo "Company: $COMPANY"
        echo "Support contact email: $SUPPORT_EMAIL"
    fi
}

function createFolderIfNotExist {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        exitOnFailure "Could not create local .ssl directory"
    fi
}

function createSslFolderIfNotExist {
    createFolderIfNotExist "./.ssl"
}

function createRootCertIfNotExist {
    if [ ! -e ./root.cnf ]; then
        generateRootCertConf > ./root.cnf
        exitOnFailure "Couldn't create root configuration" true
        # we know we have permissions, create the serial and index files
        mkdir -p "./rca/private"
        mkdir -p "./rca/signedcerts"
        exitOnFailure "Couldn't create root configuration folder" true
        generateSerialOutput > ./rca/serial
        touch ./rca/index.txt
        export OPENSSL_CONF=`pwd`/root.cnf
        echo "$KEYSTORE_PASS" > ./pass.txt

        # Create our root certificate authority.
        # The key will go where the root.cnf directs it, and the public cert
        # will go to cacert.pem
        openssl req -x509 -newkey rsa:2048 -passout file:./pass.txt -out ./rca/cacert.pem -outform PEM -days 1825 > /dev/null 2>&1
        exitOnFailure "Couldn't generate Root Certificate Authority" true
    else
        echo "Using existing root certificate configuration"
    fi
}

function createSingleConfiguration {
    # always stomp, as this is a new signature
    export OPENSSL_CONF=`pwd`/server.cnf
    generateSingleCertConf > ./server.cnf
    exitOnFailure "Couldn't create server configuration" true
}

function processSingleSignature {
    openssl req -newkey rsa:1024 -passout file:./pass.txt -keyout ./tempkey.pem -keyform PEM -out ./tempreq.pem -outform PEM > /dev/null 2>&1
    exitOnFailure "Couldn't generate signature request" true

    # Switch back to root configuration
    export OPENSSL_CONF=`pwd`/root.cnf

    # Sign the request; signature will be based off of the key location which is configured inside the root.cnf
    openssl ca -batch -passin file:./pass.txt -in ./tempreq.pem -out ./server_crt.pem > /dev/null 2>&1
    exitOnFailure "Could not sign the server signature request" true

    # Strip meta information from our request, leaving only the certificate
    openssl x509 -in ./server_crt.pem -out ./server_crt.pem > /dev/null 2>&1
    exitOnFailure "Could not clean up the signature" true

    # Copy the root certificate authority certificate to the output directory
    cp ./rca/cacert.pem ../root_ca-single.crt
    exitOnFailure "Could not copy the root certificate" true

    # strip the server key's password
    openssl rsa -passin file:./pass.txt < ./tempkey.pem > ./server_key.pem > /dev/null 2>&1
    exitOnFailure "Could not strip the server key password" true

    # The server key and certificate appended into a file
    cat ./server_crt.pem ./server_key.pem > ../server.pem
    exitOnFailure "Could not build the concatenated server certificate" true

    # Transfer the server certificate to the CRT format (easy installation in Windows)
    mv ./server_crt.pem ../server_crt.crt
    exitOnFailure "Could not move server certificate" true
}

function executeProcess {
    if [ "clean" == "$1" ]; then
        rm -rf ./.ssl
        exitOnFailure "Couldn't delete .ssl directory"
        echo "Removed .ssl directory"
    elif [ "single" == "$1" ]; then
        pushd ./.ssl > /dev/null 2>&1
        exitOnFailure "Could not read ./.ssl directory"
        createRootCertIfNotExist
        createSingleConfiguration
        processSingleSignature
        popd > /dev/null 2>&1
    elif [ "intermediate" == "$1" ]; then
        pushd ./.ssl > /dev/null 2>&1
        exitOnFailure "Could not read ./.ssl directory"
        createRootCertIfNotExist
        popd > /dev/null 2>&1
    else
        echo "Did not understand command $1"
        exit 1
    fi
}

testOpenSsl
validateInput $1 $2
createSslFolderIfNotExist
executeProcess $1
exit 0
