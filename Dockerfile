FROM openresty/openresty:1.25.3.1-1-jammy

RUN apt-get update && apt-get install -y vim

CMD ["openresty", "-g", "daemon off;"]