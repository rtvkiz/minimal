# Minimal nginx - Zero CVE Target
# Build from source with only essential modules
ARG NGINX_VERSION=1.27.3
ARG ALPINE_VERSION=3.20

# Build stage
FROM alpine:${ALPINE_VERSION} AS builder

ARG NGINX_VERSION

RUN apk add --no-cache \
    build-base \
    pcre2-dev \
    zlib-dev \
    linux-headers \
    curl

# Download and build nginx with minimal modules
RUN curl -fsSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar xz && \
    cd nginx-${NGINX_VERSION} && \
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --with-threads \
        --with-http_v2_module \
        --without-http_autoindex_module \
        --without-http_browser_module \
        --without-http_empty_gif_module \
        --without-http_geo_module \
        --without-http_memcached_module \
        --without-http_mirror_module \
        --without-http_referer_module \
        --without-http_scgi_module \
        --without-http_split_clients_module \
        --without-http_ssi_module \
        --without-http_userid_module \
        --without-http_uwsgi_module \
        --without-mail_imap_module \
        --without-mail_pop3_module \
        --without-mail_smtp_module \
        --without-stream_geo_module \
        --without-stream_map_module \
        --without-stream_return_module \
        --without-stream_split_clients_module \
        --without-stream_upstream_hash_module \
        --without-stream_upstream_least_conn_module \
        --without-stream_upstream_zone_module && \
    make -j$(nproc) && \
    make install && \
    strip /usr/sbin/nginx

# Prepare runtime files
RUN mkdir -p /rootfs/etc/nginx /rootfs/var/log/nginx /rootfs/var/run /rootfs/var/cache/nginx /rootfs/usr/share/nginx/html && \
    cp -a /etc/nginx/* /rootfs/etc/nginx/ && \
    adduser -D -u 10001 -g "" nginx && \
    echo "nginx:x:10001:10001::/nonexistent:/sbin/nologin" > /rootfs/etc/passwd && \
    echo "nginx:x:10001:" > /rootfs/etc/group

# Runtime stage - use distroless for zero CVE base
FROM gcr.io/distroless/cc-debian12:nonroot AS runtime

# Copy nginx binary and dependencies
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /rootfs/etc/nginx /etc/nginx
COPY --from=builder /rootfs/etc/passwd /etc/passwd
COPY --from=builder /rootfs/etc/group /etc/group

# Copy required shared libraries
COPY --from=builder /lib/ld-musl-*.so.1 /lib/
COPY --from=builder /usr/lib/libpcre2-8.so* /usr/lib/
COPY --from=builder /lib/libz.so* /lib/

# Create necessary directories (owned by nonroot user)
COPY --from=builder --chown=nonroot:nonroot /rootfs/var/log/nginx /var/log/nginx
COPY --from=builder --chown=nonroot:nonroot /rootfs/var/cache/nginx /var/cache/nginx

# Default config
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8080

USER nonroot

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/usr/sbin/nginx"]
CMD ["-g", "daemon off;"]
