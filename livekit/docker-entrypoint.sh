#!/bin/sh
set -e

# Substitute environment variables in the config template
if [ -f /etc/livekit.yaml.template ]; then
    envsubst < /etc/livekit.yaml.template > /etc/livekit.yaml

    # Verify the config was generated
    if [ ! -s /etc/livekit.yaml ]; then
        echo "ERROR: Failed to generate LiveKit config file"
        exit 1
    fi

    # Debug: show if variables were substituted
    if grep -q '\${' /etc/livekit.yaml; then
        echo "WARNING: LiveKit config still contains unsubstituted variables"
        echo "Required env vars: NODE_IP, SYNAPSE_SERVER_NAME, SSL_CERT_DOMAIN, APIKey, LIVEKIT_SECRET"
    fi
fi

# Start LiveKit with the processed config
exec /livekit-server "$@"
