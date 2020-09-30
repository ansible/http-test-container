FROM nginx:1.19.2-alpine

ADD constraints.txt /root/constraints.txt

ENV PYTHONDONTWRITEBYTECODE=1

# The following packages are required to get httpbin/brotlipy/cffi installed
#     openssl-dev python3-dev libffi-dev gcc libstdc++ make musl-dev
# Symlinking /usr/lib/libstdc++.so.6 to /usr/lib/libstdc++.so is specifically required for brotlipy
RUN set -x && \
    apk add --no-cache openssl ca-certificates py3-pip py3-setuptools py3-wheel openssl-dev python3-dev libffi-dev gcc libstdc++ make musl-dev && \
    update-ca-certificates && \
    ln -s /usr/lib/libstdc++.so.6 /usr/lib/libstdc++.so && \
    mkdir -p /root/ca/certs /root/ca/private /root/ca/newcerts && \
    echo 1000 > /root/ca/serial && \
    touch /root/ca/index.txt && \
    sed -i 's/\.\/demoCA/\/root\/ca/g' /etc/ssl/openssl.cnf && \
    openssl req -new -x509 -days 3650 -nodes -extensions v3_ca -keyout /root/ca/private/cakey.pem -out /root/ca/cacert.pem \
        -subj "/C=US/ST=North Carolina/L=Durham/O=Ansible/CN=ansible.http.tests" && \
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
    cp /root/ca/cacert.pem /usr/share/nginx/html/cacert.pem && \
    cp /root/ca/client.ansible.http.tests-cert.pem /usr/share/nginx/html/client.pem && \
    cp /root/ca/private/client.ansible.http.tests-key.pem /usr/share/nginx/html/client.key && \
    chmod 644 /usr/share/nginx/html/* && \
    pip3 install --no-cache-dir --no-compile -c /root/constraints.txt gunicorn httpbin && \
    apk del openssl-dev py3-pip py3-wheel python3-dev libffi-dev gcc libstdc++ make musl-dev && \
    rm -rf /root/.cache/pip && \
    find /usr/lib/python3.8 -type f -regex ".*\.py[co]" -delete && \
    find /usr/lib/python3.8 -type d -name "__pycache__" -delete

ADD services.sh /services.sh
ADD nginx.sites.conf /etc/nginx/conf.d/default.conf

EXPOSE 80 443

CMD ["/services.sh"]
