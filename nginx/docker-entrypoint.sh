#!/bin/sh
set -e

# Generate matrix.conf from template
envsubst '${SYNAPSE_SERVER_NAME} ${SSL_CERT_DOMAIN}' < /etc/nginx/templates/matrix.conf.template > /etc/nginx/conf.d/matrix.conf

# Test nginx configuration
nginx -t

# Start nginx
exec nginx -g 'daemon off;'
