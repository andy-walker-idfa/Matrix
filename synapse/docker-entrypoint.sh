#!/bin/bash
set -e

# Install envsubst (gettext package)
apt-get update -qq && apt-get install -y -qq gettext-base > /dev/null 2>&1

# Generate homeserver.yaml from template
envsubst < /config/homeserver.yaml.template > /config/homeserver.yaml

# Start Synapse
exec python -m synapse.app.homeserver -c /config/homeserver.yaml "$@"
