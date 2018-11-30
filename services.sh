#!/bin/sh
/usr/bin/gunicorn -D httpbin:app
/usr/sbin/nginx -g "daemon off;"
