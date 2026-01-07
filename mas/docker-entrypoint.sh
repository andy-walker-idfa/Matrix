#!/bin/sh
set -e

# Function to manually substitute environment variables
substitute_vars() {
    sed -e "s|\${SYNAPSE_SERVER_NAME}|${SYNAPSE_SERVER_NAME}|g" \
        -e "s|\${MAS_ENCRYPTION_SECRET}|${MAS_ENCRYPTION_SECRET}|g" \
        -e "s|\${MAS_SIGNING_KEY}|${MAS_SIGNING_KEY}|g" \
        -e "s|\${MAS_SYNAPSE_SECRET}|${MAS_SYNAPSE_SECRET}|g" \
        /config/config.yaml.template > /tmp/config.yaml
}

# Substitute environment variables in the config template
if command -v envsubst >/dev/null 2>&1; then
    envsubst < /config/config.yaml.template > /tmp/config.yaml
else
    substitute_vars
fi

# Verify the config file was created and has secrets
if [ ! -s /tmp/config.yaml ]; then
    echo "ERROR: Failed to generate config file"
    exit 1
fi

if ! grep -q "encryption:" /tmp/config.yaml; then
    echo "ERROR: Config file missing secrets - environment variables not substituted"
    echo "Required env vars: SYNAPSE_SERVER_NAME, MAS_ENCRYPTION_SECRET, MAS_SIGNING_KEY, MAS_SYNAPSE_SECRET"
    exit 1
fi

# Start MAS with the processed config
exec /usr/local/bin/mas-cli server -c /tmp/config.yaml "$@"
