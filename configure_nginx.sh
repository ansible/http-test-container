#!/usr/bin/env sh

set -eux

apk add \
    ca-certificates \
    krb5-libs \
    krb5-server \
    --no-cache

update-ca-certificates

mkdir /usr/share/nginx/html/

cp /usr/src/krb5.conf /etc/krb5.conf

cp /root/ca/cacert.pem /usr/share/nginx/html/cacert.pem
cp /root/ca2/cacert.pem /usr/share/nginx/html/ca2cert.pem
cp /root/ca/client.ansible.http.tests-cert.pem /usr/share/nginx/html/client.pem
cp /root/ca/private/client.ansible.http.tests-key.pem /usr/share/nginx/html/client.key

chmod 644 /usr/share/nginx/html/*

echo "Microsoft Rulz" > /usr/share/nginx/html/gssapi

python3 -c "import secrets; password = secrets.token_hex(30); print(password); print(password);" | /usr/sbin/kdb5_util create -r HTTP.TESTS
python3 -c "print('*/admin@HTTP.TESTS\t*')" > /var/lib/krb5kdc/kadm5.acl

kadmin.local -q "addprinc -randkey HTTP/ansible@HTTP.TESTS"
kadmin.local -q "addprinc -randkey HTTP/ansible.http.tests@HTTP.TESTS"
kadmin.local -q "ktadd -k /etc/nginx.keytab HTTP/ansible@HTTP.TESTS"
kadmin.local -q "ktadd -k /etc/nginx.keytab HTTP/ansible.http.tests@HTTP.TESTS"

chmod 660 /etc/nginx.keytab
chown root:nginx /etc/nginx.keytab
