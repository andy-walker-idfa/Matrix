FROM alpine:latest AS builder
# Install gettext for envsubst
RUN apk add --no-cache gettext

# Copy our entrypoint script
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Final stage - use LiveKit image
FROM livekit/livekit-server:latest

# Copy shell and minimal dependencies from alpine
COPY --from=builder /bin/sh /bin/sh
COPY --from=builder /bin/grep /bin/grep
COPY --from=builder /usr/bin/envsubst /usr/bin/envsubst
COPY --from=builder /lib/ld-musl-*.so.1 /lib/
COPY --from=builder /usr/lib/libintl.so* /usr/lib/
COPY --from=builder /entrypoint.sh /entrypoint.sh

# Set our custom entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["--config", "/etc/livekit.yaml"]
