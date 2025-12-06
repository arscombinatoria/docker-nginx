# syntax=docker/dockerfile:1

FROM nginx:1.27.0 AS nginx-base

# Capture the upstream nginx version from the base image so the builder can match it exactly.
RUN nginx -v 2>&1 | sed -E 's|^nginx version: nginx/||' > /tmp/nginx-version

FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /tmp/build

# Copy the upstream nginx version detected from the base image.
COPY --from=nginx-base /tmp/nginx-version /tmp/nginx-version

RUN set -eux; \
    NGINX_VERSION=$(cat /tmp/nginx-version); \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        git \
        libbrotli-dev \
        libpcre3-dev \
        libssl-dev \
        wget \
        zlib1g-dev; \
    rm -rf /var/lib/apt/lists/*; \
    wget "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"; \
    tar -zxf "nginx-${NGINX_VERSION}.tar.gz"; \
    git clone --recurse-submodules https://github.com/google/ngx_brotli.git; \
    cd "nginx-${NGINX_VERSION}"; \
    ./configure --with-compat --add-dynamic-module=../ngx_brotli; \
    make modules

FROM nginx-base

# Copy compiled Brotli dynamic modules from the builder image.
COPY --from=builder /tmp/build/nginx-*/objs/ngx_http_brotli_*.so /etc/nginx/modules/

# Load the Brotli modules at startup.
RUN sed -i '1iload_module modules/ngx_http_brotli_filter_module.so;\nload_module modules/ngx_http_brotli_static_module.so;\n' /etc/nginx/nginx.conf

# Default Brotli configuration.
COPY <<'EOF_CONF' /etc/nginx/conf.d/brotli.conf
brotli on;
brotli_static on;
brotli_comp_level 6;
brotli_types application/atom+xml application/javascript application/json application/vnd.api+json application/rss+xml
    application/vnd.ms-fontobject application/x-font-opentype application/x-font-truetype
    application/x-font-ttf application/x-javascript application/xhtml+xml application/xml
    font/eot font/opentype font/otf font/truetype image/svg+xml image/vnd.microsoft.icon
    image/x-icon image/x-win-bitmap text/css text/javascript text/plain text/xml;
EOF_CONF

# Keep the upstream entrypoint and default command from the nginx base image.
