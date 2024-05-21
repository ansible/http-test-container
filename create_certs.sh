#!/usr/bin/env sh

set -eux

subj="/C=US/ST=North Carolina/L=Durham/O=Ansible"
days=3650

ca1="/root/ca"
ca2="/root/ca2"

create_ca() {
    ca="$1"
    name="$2"

    mkdir -p "${ca}/certs" "${ca}/private" "${ca}/newcerts"
    echo 1000 > "${ca}/serial"
    touch "${ca}/index.txt"
    sed "s|\./demoCA|${ca}|g" /etc/ssl/openssl.cnf > "${ca}/openssl.cnf"
    openssl req -new -x509 -nodes -extensions v3_ca \
      -config "${ca}/openssl.cnf" -days "${days}" -subj "${subj}/CN=${name}" -out "${ca}/cacert.pem" -keyout "${ca}/private/cakey.pem"
}

create_cert() {
    ca="$1"
    name="$2"

    openssl req -new -nodes -config "${ca}/openssl.cnf" -subj "${subj}/CN=${name}" -out "${ca}/${name}-req.pem" -keyout "${ca}/private/${name}-key.pem"
    yes | openssl ca -config "${ca}/openssl.cnf" -days "${days}" -in "${ca}/${name}-req.pem" -out "${ca}/${name}-cert.pem"
}

create_ca "${ca1}" "ansible.http.tests"
create_ca "${ca2}" "ca2.ansible.http.tests"

create_cert "${ca1}" "ansible.http.tests"
create_cert "${ca1}" "sni1.ansible.http.tests"
create_cert "${ca1}" "sni2.ansible.http.tests"
create_cert "${ca1}" "client.ansible.http.tests"
create_cert "${ca1}" "no-tls13.ansible.http.tests"
create_cert "${ca1}" "no-tls13-weak.ansible.http.tests"
create_cert "${ca2}" "self-signed.ansible.http.tests"
