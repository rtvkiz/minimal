# Minimal Alpine - Zero CVE Target
ARG ALPINE_VERSION=3.20

FROM alpine:${ALPINE_VERSION} AS builder

# Update and remove known vulnerable packages
RUN apk update && apk upgrade --no-cache && \
    # Remove unnecessary packages that often have CVEs
    apk del --no-cache \
        apk-tools \
        alpine-keys \
        ca-certificates-bundle \
        libc-utils \
        2>/dev/null || true

# Create non-root user
RUN adduser -D -u 10001 -g "" appuser

# Final minimal image
FROM scratch

# Copy minimal filesystem
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
COPY --from=builder /lib/ld-musl-*.so.1 /lib/
COPY --from=builder /bin/busybox /bin/busybox
COPY --from=builder /bin/sh /bin/sh

# Security: Use non-root user
USER 10001

ENTRYPOINT ["/bin/sh"]
