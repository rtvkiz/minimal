# Minimal BusyBox - Zero CVE Target
# Uses musl variant for smaller attack surface
FROM busybox:stable-musl AS base

# Create non-root user
RUN adduser -D -u 10001 -g "" appuser

# Final stage - copy only essentials
FROM scratch

# Copy busybox binary and required files
COPY --from=base /bin/busybox /bin/busybox
COPY --from=base /etc/passwd /etc/passwd
COPY --from=base /etc/group /etc/group

# Create symlinks for common commands
RUN ["/bin/busybox", "ln", "-s", "/bin/busybox", "/bin/sh"]

# Use non-root user
USER 10001

ENTRYPOINT ["/bin/sh"]
