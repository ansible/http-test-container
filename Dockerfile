FROM public.ecr.aws/docker/library/alpine:3.22.1 AS base

RUN apk add \
        nginx \
        python3 \
        --no-cache

FROM base AS builder

RUN apk add \
        gcc \
        gd-dev \
        geoip-dev \
        krb5-dev \
        libc-dev \
        libffi-dev \
        libmaxminddb-dev \
        libxslt-dev \
        linux-headers \
        make \
        openssl \
        openssl-dev \
        pcre-dev \
        perl-dev \
        python3-dev \
        zlib-dev \
        --no-cache

COPY extract_nginx_options.py /usr/src/extract_nginx_options.py
COPY build_spnego_module.sh /usr/src/build_spnego_module.sh

RUN /usr/src/build_spnego_module.sh

ADD requirements.txt /usr/src/requirements.txt
ADD constraints.txt /usr/src/constraints.txt

RUN python3 -m venv /usr/share/nginx/venv/
RUN /usr/share/nginx/venv/bin/pip install --no-cache-dir --no-compile -r /usr/src/requirements.txt -c /usr/src/constraints.txt
RUN /usr/share/nginx/venv/bin/pip freeze
RUN cd /usr/share/nginx/venv/lib/python*/site-packages/ && rm -rf pip pip-* setuptools setuptools-*

ADD create_certs.sh /usr/src/create_certs.sh
RUN /usr/src/create_certs.sh

FROM base AS output

COPY --from=builder /usr/lib/nginx/modules/ /usr/lib/nginx/modules/
COPY --from=builder /usr/share/nginx/venv/ /usr/share/nginx/venv/
COPY --from=builder /usr/src/nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /root/ca/ /root/ca/
COPY --from=builder /root/ca2/ /root/ca2/

ADD krb5.conf /usr/src/krb5.conf
ADD configure_nginx.sh /usr/src/configure_nginx.sh
RUN /usr/src/configure_nginx.sh

ADD services.sh /services.sh
ADD nginx.sites.conf /etc/nginx/http.d/default.conf

EXPOSE 80 88 443 749

CMD ["/services.sh"]
