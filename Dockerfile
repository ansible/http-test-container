ARG CONTAINER_VERSION=1.19.2-alpine

# builder used to create a dynamic spnego auth module
# https://gist.github.com/hermanbanken/96f0ff298c162a522ddbba44cad31081
FROM nginx:${CONTAINER_VERSION} AS builder

ENV SPNEGO_AUTH_COMMIT_ID=72c8ee04c81f929ec84d5a6d126f789b77781a8c

RUN set -x && \
    NGINX_VERSION="$( nginx -v 2>&1 | awk -F/ '{print $2}' )" && \
    NGINX_CONFIG="$( nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p' )" && \
    wget "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -O nginx.tar.gz && \
    wget https://github.com/stnoonan/spnego-http-auth-nginx-module/archive/${SPNEGO_AUTH_COMMIT_ID}.tar.gz -O spnego-http-auth.tar.gz && \
    apk add --no-cache --virtual .build-deps \
        gcc \
        libc-dev \
        make \
        pcre-dev \
        zlib-dev \
        krb5-dev \
        && \
    mkdir /usr/src && \
    tar -xzC /usr/src -f nginx.tar.gz && \
    tar -xzvf spnego-http-auth.tar.gz && \
    SPNEGO_AUTH_DIR="$( pwd )/spnego-http-auth-nginx-module-${SPNEGO_AUTH_COMMIT_ID}" && \
    cd "/usr/src/nginx-${NGINX_VERSION}" && \
    ./configure --with-compat "${NGINX_CONFIG}" --add-dynamic-module="${SPNEGO_AUTH_DIR}" && \
    make modules && \
    cp objs/ngx_*_module.so /usr/lib

# Create the actual httptester container
FROM nginx:${CONTAINER_VERSION}

ADD constraints.txt /root/constraints.txt
ADD krb5.conf /root/krb5.conf
COPY --from=builder /usr/lib/ngx_*_module.so /usr/lib/nginx/modules/

ENV PYTHONDONTWRITEBYTECODE=1

# The following packages are required to get httpbin/brotlipy/cffi installed
#     openssl-dev python3-dev libffi-dev gcc libstdc++ make musl-dev
# Symlinking /usr/lib/libstdc++.so.6 to /usr/lib/libstdc++.so is specifically required for brotlipy
RUN set -x && \
    apk add --no-cache \
        ca-certificates \
        gcc \
        krb5-libs \
        krb5-server \
        libffi-dev \
        libstdc++ \
        make \
        musl-dev \
        openssl \
        openssl-dev \
        py3-pip \
        py3-setuptools \
        py3-wheel \
        python3-dev \
        && \
    update-ca-certificates && \
    ln -s /usr/lib/libstdc++.so.6 /usr/lib/libstdc++.so && \
    mkdir -p /root/ca/certs /root/ca/private /root/ca/newcerts && \
    mkdir -p /root/ca2/certs /root/ca2/private /root/ca2/newcerts && \
    echo 1000 > /root/ca/serial && \
    echo 1000 > /root/ca2/serial && \
    touch /root/ca/index.txt && \
    touch /root/ca2/index.txt && \
    cp /etc/ssl/openssl.cnf /etc/ssl/openssl_ca2.cnf && \
    sed -i 's/\.\/demoCA/\/root\/ca/g' /etc/ssl/openssl.cnf && \
    sed -i 's/\.\/demoCA/\/root\/ca2/g' /etc/ssl/openssl_ca2.cnf && \
    openssl req -new -x509 -days 3650 -nodes -extensions v3_ca -keyout /root/ca/private/cakey.pem -out /root/ca/cacert.pem \
        -subj "/C=US/ST=North Carolina/L=Durham/O=Ansible/CN=ansible.http.tests" && \
    openssl req -new -x509 -days 3650 -nodes -extensions v3_ca -keyout /root/ca2/private/cakey.pem -out /root/ca2/cacert.pem \
        -subj "/C=US/ST=North Carolina/L=Durham/O=Ansible/CN=ca2.ansible.http.tests" && \
    openssl req -new -nodes -out /root/ca/ansible.http.tests-req.pem -keyout /root/ca/private/ansible.http.tests-key.pem \
        -subj "/C=US/ST=North Carolina/L=Durham/O=Ansible/CN=ansible.http.tests" && \
    yes | openssl ca -config /etc/ssl/openssl.cnf -days 3650 -out /root/ca/ansible.http.tests-cert.pem -infiles /root/ca/ansible.http.tests-req.pem && \
    openssl req -new -nodes -out /root/ca/sni1.ansible.http.tests-req.pem -keyout /root/ca/private/sni1.ansible.http.tests-key.pem -config /etc/ssl/openssl.cnf \
        -subj "/C=US/ST=North Carolina/L=Durham/O=Ansible/CN=sni1.ansible.http.tests" && \
    yes | openssl ca -config /etc/ssl/openssl.cnf -days 3650 -out /root/ca/sni1.ansible.http.tests-cert.pem -infiles /root/ca/sni1.ansible.http.tests-req.pem && \
    openssl req -new -nodes -out /root/ca/sni2.ansible.http.tests-req.pem -keyout /root/ca/private/sni2.ansible.http.tests-key.pem -config /etc/ssl/openssl.cnf \
        -subj "/C=US/ST=North Carolina/L=Durham/O=Ansible/CN=sni2.ansible.http.tests" && \
    yes | openssl ca -config /etc/ssl/openssl.cnf -days 3650 -out /root/ca/sni2.ansible.http.tests-cert.pem -infiles /root/ca/sni2.ansible.http.tests-req.pem && \
    openssl req -new -nodes -out /root/ca/client.ansible.http.tests-req.pem -keyout /root/ca/private/client.ansible.http.tests-key.pem -config /etc/ssl/openssl.cnf \
        -subj "/C=US/ST=North Carolina/L=Durham/O=Ansible/CN=client.ansible.http.tests" && \
    yes | openssl ca -config /etc/ssl/openssl.cnf -days 3650 -out /root/ca/client.ansible.http.tests-cert.pem -infiles /root/ca/client.ansible.http.tests-req.pem && \
    openssl req -new -nodes -out /root/ca2/self-signed.ansible.http.tests-req.pem -keyout /root/ca2/private/self-signed.ansible.http.tests-key.pem -config /etc/ssl/openssl_ca2.cnf \
        -subj "/C=US/ST=North Carolina/L=Durham/O=Ansible/CN=self-signed.ansible.http.tests" && \
    yes | openssl ca -config /etc/ssl/openssl_ca2.cnf -days 3650 -out /root/ca2/self-signed.ansible.http.tests-cert.pem -infiles /root/ca2/self-signed.ansible.http.tests-req.pem && \
    cp /root/ca/cacert.pem /usr/share/nginx/html/cacert.pem && \
    cp /root/ca2/cacert.pem /usr/share/nginx/html/ca2cert.pem && \
    cp /root/ca/client.ansible.http.tests-cert.pem /usr/share/nginx/html/client.pem && \
    cp /root/ca/private/client.ansible.http.tests-key.pem /usr/share/nginx/html/client.key && \
    chmod 644 /usr/share/nginx/html/* && \
    pip3 install --no-cache-dir --no-compile -c /root/constraints.txt gunicorn httpbin && \
    apk del openssl-dev py3-pip py3-wheel python3-dev libffi-dev gcc libstdc++ make musl-dev && \
    rm -rf /root/.cache/pip && \
    find /usr/lib/python3.8 -type f -regex ".*\.py[co]" -delete && \
    find /usr/lib/python3.8 -type d -name "__pycache__" -delete && \
    echo "Microsoft Rulz" > /usr/share/nginx/html/gssapi && \
    echo -e "load_module /usr/lib/nginx/modules/ngx_http_auth_spnego_module.so;\n$( cat /etc/nginx/nginx.conf )" > /etc/nginx/nginx.conf && \
    cp /root/krb5.conf /etc/krb5.conf && \
    PASSWORD="$( < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c30 )" && \
    echo -e "${PASSWORD}\n${PASSWORD}" | /usr/sbin/kdb5_util create -r HTTP.TESTS && \
    echo -e "*/admin@HTTP.TESTS\t*" > /var/lib/krb5kdc/kadm5.acl && \
    kadmin.local -q "addprinc -randkey HTTP/ansible@HTTP.TESTS" && \
    kadmin.local -q "addprinc -randkey HTTP/ansible.http.tests@HTTP.TESTS" && \
    kadmin.local -q "ktadd -k /etc/nginx.keytab HTTP/ansible@HTTP.TESTS" && \
    kadmin.local -q "ktadd -k /etc/nginx.keytab HTTP/ansible.http.tests@HTTP.TESTS" && \
    chmod 660 /etc/nginx.keytab && \
    chown root:nginx /etc/nginx.keytab

ADD services.sh /services.sh
ADD nginx.sites.conf /etc/nginx/conf.d/default.conf

EXPOSE 80 88 443 749

CMD ["/services.sh"]
