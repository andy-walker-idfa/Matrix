FROM alpine:latest AS builder
# Install gettext for envsubst
RUN apk add --no-cache gettext

# Create entrypoint wrapper script
RUN cat > /entrypoint.sh <<'EOF'
#!/bin/sh
set -e

# Substitute environment variables in the config template
if [ -f /config/config.yaml.template ]; then
    envsubst < /config/config.yaml.template > /tmp/config.yaml

    # Verify the config was generated
    if [ ! -s /tmp/config.yaml ]; then
        echo "ERROR: Failed to generate config file"
        exit 1
    fi

    if ! grep -q "encryption:" /tmp/config.yaml; then
        echo "ERROR: Config missing secrets - env vars not substituted"
        echo "Required: SYNAPSE_SERVER_NAME, MAS_ENCRYPTION_SECRET, MAS_SIGNING_KEY, MAS_SYNAPSE_SECRET"
        exit 1
    fi

    # Start MAS
    exec /usr/local/bin/mas-cli server -c /tmp/config.yaml "$@"
else
    echo "ERROR: Config template not found"
    exit 1
fi
EOF
RUN chmod +x /entrypoint.sh

# Final stage - use MAS image
FROM ghcr.io/element-hq/matrix-authentication-service:latest

# Copy shell and minimal dependencies from alpine
COPY --from=builder /bin/sh /bin/sh
COPY --from=builder /bin/grep /bin/grep
COPY --from=builder /usr/bin/envsubst /usr/bin/envsubst
COPY --from=builder /lib/ld-musl-*.so.1 /lib/
COPY --from=builder /usr/lib/libintl.so* /usr/lib/
COPY --from=builder /entrypoint.sh /entrypoint.sh

# Set our custom entrypoint
ENTRYPOINT ["/entrypoint.sh"]
