FROM openresty/openresty:1.25.3.1-1-jammy

RUN \
    apt-get update && apt-get install -y vim logrotate jq && \
    rm -rf /var/lib/apt/lists/*

COPY nginx-logrotate.conf /etc/logrotate.d/nginx

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
