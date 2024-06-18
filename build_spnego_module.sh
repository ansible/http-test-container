#!/usr/bin/env sh

set -eux

SPNEGO_AUTH_COMMIT_ID="72c8ee04c81f929ec84d5a6d126f789b77781a8c"
NGINX_VERSION="$( nginx -v 2>&1 | awk -F/ '{print $2}' )"
NGINX_CONFIG="$( nginx -V 2>&1 | python3 /usr/src/extract_nginx_options.py )"
NGINX_TAR="nginx.tar.gz"
NGINX_SRC="/usr/src/nginx-${NGINX_VERSION}"
SPNEGO_TAR="spnego-http-auth.tar.gz"
SPNEGO_SRC="/usr/src/spnego-http-auth-nginx-module-${SPNEGO_AUTH_COMMIT_ID}"
MODULE_DIR="/usr/lib/nginx/modules/"
MODULE_NAME="ngx_http_auth_spnego_module.so"

wget "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -O "${NGINX_TAR}"
wget "https://github.com/stnoonan/spnego-http-auth-nginx-module/archive/${SPNEGO_AUTH_COMMIT_ID}.tar.gz" -O "${SPNEGO_TAR}"

tar -xzC /usr/src -f "${NGINX_TAR}"
tar -xzC /usr/src -f "${SPNEGO_TAR}"

cd "${NGINX_SRC}"

# Hack to ensure the module compile options match the server.
export CFLAGS=-DNGX_HTTP_HEADERS=1

# shellcheck disable=SC2086
./configure ${NGINX_CONFIG} --add-dynamic-module="${SPNEGO_SRC}"

make modules

MODULE_SIGNATURE="$(strings "objs/${MODULE_NAME}" | grep -E '[01]{30,}')"
SERVER_SIGNATURE="$(strings /usr/sbin/nginx | grep -E '[01]{30,}')"

if [ "${MODULE_SIGNATURE}" != "${SERVER_SIGNATURE}" ]; then
    echo "The configured module options do not match the server:"
    echo "Module: ${MODULE_SIGNATURE}"
    echo "Server: ${SERVER_SIGNATURE}"
    echo "See https://github.com/nginx/nginx/blob/release-${NGINX_VERSION}/src/core/ngx_module.h to decode the signature."
    echo "The mismatch could be due to configuration options or missing dependencies."
    exit 1
fi

cp "objs/${MODULE_NAME}" "${MODULE_DIR}"

echo "load_module ${MODULE_DIR}/${MODULE_NAME};" > /usr/src/nginx.conf

cat /etc/nginx/nginx.conf >> /usr/src/nginx.conf
