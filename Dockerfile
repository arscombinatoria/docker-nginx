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
        cmake \
        curl \
        git \
        libpcre3-dev \
        libssl-dev \
        zlib1g-dev; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p nginx-src; \
    curl -fSL "https://github.com/nginx/nginx/archive/refs/tags/release-${NGINX_VERSION}.tar.gz" \
        | tar zx --strip-components=1 -C nginx-src; \
    git clone --recursive https://github.com/google/ngx_brotli.git; \
    cmake -S ngx_brotli/deps/brotli -B ngx_brotli/deps/brotli/out \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON; \
    cmake --build ngx_brotli/deps/brotli/out --config Release; \
    cd nginx-src; \
    ./auto/configure --with-compat --add-dynamic-module=../ngx_brotli; \
    make modules

FROM nginx-base

# Copy compiled Brotli dynamic modules from the builder image.
COPY --from=builder /tmp/build/nginx-src/objs/ngx_http_brotli_*.so /etc/nginx/modules/

# Load the Brotli modules at startup.
RUN sed -i '1iload_module modules/ngx_http_brotli_filter_module.so;\nload_module modules/ngx_http_brotli_static_module.so;\n' /etc/nginx/nginx.conf

# Default Brotli configuration.
COPY <<'EOF_CONF' /etc/nginx/conf.d/brotli.conf
brotli on;
brotli_static on;
brotli_comp_level 6;
brotli_types text/plain text/css application/javascript application/json application/xml text/xml application/xml+rss text/javascript image/svg+xml application/font-woff2;
EOF_CONF

# Keep the upstream entrypoint and default command from the nginx base image.
