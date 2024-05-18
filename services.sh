#!/usr/bin/env sh

if [ -z "${KRB5_PASSWORD}" ]; then
    echo "No KRB5_PASSWORD provided for the admin account."
    exit 1
fi

kadmin.local -q "addprinc -pw ${KRB5_PASSWORD} admin"

/usr/sbin/krb5kdc
/usr/share/nginx/venv/bin/gunicorn -D httpbin:app

nginx -g "daemon off;"
