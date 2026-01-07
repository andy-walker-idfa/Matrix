# Matrix Server with Element Web & LiveKit

Self-hosted Matrix homeserver with Element Web, Element Call, and LiveKit video calling.

## Quick Start

### 1. Initial Setup

Run the interactive setup script:
```bash
./setup.sh
```

This will:
- Prompt for your server domain name
- Generate `.env` file with random secrets
- Generate configuration files from templates

### 2. Generate Synapse Signing Key
```bash
docker run --rm -v $PWD/synapse:/config \
  matrixdotorg/synapse:latest generate_signing_key \
  -o /config/YOUR_DOMAIN.signing.key
```

### 3. Start Services
```bash
docker-compose up -d
```

## Structure
```
.
├── setup.sh                      # Interactive setup script
├── docker-compose.yml            # Service definitions
├── .env.example                  # Example environment variables
├── synapse/
│   ├── homeserver.yaml.template  # Synapse config template
│   └── docker-entrypoint.sh      # Synapse startup script
├── element-web/
│   └── config.json.template      # Element Web config template
├── element-call/
│   └── config.json.template      # Element Call config template
├── nginx/
│   ├── nginx.conf                # Main nginx config
│   ├── matrix.conf.template      # Matrix routes template
│   └── docker-entrypoint.sh      # Nginx startup script
└── livekit/
    └── livekit.yaml              # LiveKit config (uses env vars)
```

## Configuration

All secrets are stored in `.env` file (not committed to git).

Key environment variables:
- `SYNAPSE_SERVER_NAME` - Your Matrix server domain
- `SSL_CERT_DOMAIN` - SSL certificate domain  
- `REGISTRATION_SHARED_SECRET` - Synapse registration secret
- `LIVEKIT_API_KEY` - LiveKit API key
- `LIVEKIT_API_SECRET` - LiveKit API secret

## Updating

To update configuration, modify the `.template` files and re-run `./setup.sh`.

## License

MIT
