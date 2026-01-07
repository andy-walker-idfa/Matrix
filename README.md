# Matrix Server with Element Web, MAS & LiveKit

Self-hosted Matrix homeserver with Matrix Authentication Service (MAS), Element Web, Element Call, Synapse Admin console, and LiveKit video calling.

**Features:**
- ✅ Element X mobile client support via MAS (Matrix Authentication Service)
- ✅ Web-based admin console for server management
- ✅ Audio/Video calls from Element X mobile clients via LiveKit
- ✅ Modern OIDC/OAuth2 authentication
- ✅ Full federation support

## Quick Start (Production Deployment)

### Prerequisites

- Docker and Docker Compose installed
- SSL certificates (Let's Encrypt recommended)
- Domain name pointing to your server
- Ports 80, 443, 8448 (Matrix federation), 7880-7881, 3478, 5349, 50000-50200 open

### 1. One-Command Initialization

Run the comprehensive initialization script:
```bash
chmod +x init.sh
./init.sh
```

This automated script will:
- ✓ Check all prerequisites (Docker, Docker Compose, OpenSSL, envsubst)
- ✓ Create `.env` file with all required secrets auto-generated
- ✓ Prompt for your domain name and server IP
- ✓ Generate all configuration files from templates (including MAS)
- ✓ Generate Synapse signing key automatically
- ✓ Generate MAS secrets for Element X authentication
- ✓ Validate SSL certificates (if present)
- ✓ Prepare Docker volumes with correct permissions
- ✓ Provide next steps summary

**That's it!** The script handles everything needed for production deployment, including MAS setup for Element X mobile clients.

### 2. Obtain SSL Certificates (if not already done)

```bash
sudo apt-get install certbot
sudo certbot certonly --standalone -d your-domain.com
```

### 3. Start Services

```bash
docker-compose up -d
```

### 4. Access Web Admin Console

Open your browser and navigate to:
```
https://your-domain.com/admin
```

Login with your admin credentials to manage your Matrix server.

### 5. Connect with Element X Mobile

Element X mobile clients can connect using your server domain. The MAS integration handles authentication automatically via OIDC.

**Download Element X:**
- iOS: [App Store](https://apps.apple.com/app/element-x/id6451119338)
- Android: [Google Play](https://play.google.com/store/apps/details?id=io.element.android.x)

**Setup:**
1. Open Element X
2. Select "Use other homeserver"
3. Enter your server domain: `your-domain.com`
4. Register or login - MAS handles authentication
5. Audio/Video calls work automatically via LiveKit

## Manual Setup (Alternative)

If you prefer manual configuration:

### 1. Configure Environment

```bash
cp .env.example .env
# Edit .env and set your values
```

### 2. Run Setup Script

```bash
./setup.sh
```

This will generate configuration files from templates.

### 3. Generate Synapse Signing Key

```bash
docker run --rm -v $PWD/synapse:/config \
  matrixdotorg/synapse:latest generate_signing_key \
  -o /config/matrix.signing.key
```

### 4. Start Services

```bash
docker-compose up -d
```

## Project Structure

```
.
├── init.sh                       # 🆕 One-command initialization script
├── setup.sh                      # Interactive configuration generator
├── docker-compose.yml            # Service definitions
├── .env.example                  # 🆕 Example environment variables
├── .env                          # Generated secrets (not in git)
│
├── synapse/                      # Matrix Synapse homeserver
│   ├── homeserver.yaml.template  # Synapse config template
│   ├── docker-entrypoint.sh      # Synapse startup script
│   ├── log.config                # Logging configuration
│   └── matrix.signing.key        # Generated signing key (not in git)
│
├── element-web/                  # Element Web UI
│   ├── config.json.template      # Element Web config template
│   └── config.json               # Generated config (not in git)
│
├── element-call/                 # Element Call (Video/Voice)
│   ├── config.json.template      # Element Call config template
│   └── config.json               # Generated config (not in git)
│
├── mas/                          # Matrix Authentication Service
│   ├── config.yaml.template      # MAS config template
│   └── docker-entrypoint.sh      # MAS startup script (processes template)
│
├── nginx/                        # Reverse proxy & SSL termination
│   ├── nginx.conf                # Main nginx config
│   ├── matrix.conf.template      # Matrix routes template
│   └── docker-entrypoint.sh      # Nginx startup script
│
└── livekit/                      # LiveKit SFU (WebRTC)
    └── livekit.yaml              # LiveKit config (uses env vars)
```

## Configuration

All secrets and environment-specific settings are stored in `.env` file (not committed to git).

### Key Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SYNAPSE_SERVER_NAME` | Your Matrix server domain | `matrix.example.com` |
| `SSL_CERT_DOMAIN` | SSL certificate domain | `matrix.example.com` |
| `NODE_IP` | External IP for WebRTC | `1.2.3.4` |
| `ADMIN_EMAIL` | Administrator email | `admin@example.com` |
| `REGISTRATION_SHARED_SECRET` | Synapse registration secret | Auto-generated |
| `MACAROON_SECRET_KEY` | Synapse auth token secret | Auto-generated |
| `FORM_SECRET` | Synapse form security secret | Auto-generated |
| `APIKey` | LiveKit API key | Auto-generated |
| `LIVEKIT_SECRET` | LiveKit API secret | Auto-generated |
| `MAS_ENCRYPTION_SECRET` | MAS database encryption | Auto-generated |
| `MAS_SIGNING_KEY` | MAS JWT signing key | Auto-generated |
| `MAS_SYNAPSE_SECRET` | MAS-Synapse shared secret | Auto-generated |
| `MAS_ADMIN_TOKEN` | MAS admin token | Auto-generated |

All secrets are automatically generated by `init.sh` using cryptographically secure random values.

## Services

The deployment includes eight Docker containers:

1. **synapse** - Matrix homeserver (core messaging)
2. **mas** - Matrix Authentication Service (OIDC/OAuth2 for Element X)
3. **synapse-admin** - Web-based admin console
4. **element-web** - Web UI for Matrix
5. **element-call** - Standalone video calling app
6. **livekit** - WebRTC SFU for video/audio
7. **lk-jwt-service** - JWT token issuer for LiveKit
8. **nginx** - Reverse proxy and TLS termination

## Ports

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| 80 | TCP | nginx | HTTP (redirects to HTTPS) |
| 443 | TCP | nginx | HTTPS (main access) |
| 8448 | TCP | nginx | Matrix federation |
| 7880 | TCP | livekit | WebSocket |
| 7881 | TCP | livekit | RTC |
| 3478 | UDP | livekit | TURN (UDP) |
| 5349 | TCP | livekit | TURN (TLS) |
| 50000-50200 | UDP | livekit | RTP (media streams) |

## Updating Configuration

To update configuration:

1. Edit `.env` file with new values
2. Run `./init.sh` to regenerate configs (will preserve existing .env values)
3. Restart services: `docker-compose restart`

Or manually edit `.template` files and run `./setup.sh`.

## Troubleshooting

### Check service status
```bash
docker-compose ps
docker-compose logs -f
```

### Restart specific service
```bash
docker-compose restart synapse
```

### View Synapse logs
```bash
docker-compose logs -f synapse
```

### Test Matrix federation
```bash
curl https://federationtester.matrix.org/api/report?server_name=your-domain.com
```

## Security Notes

- Never commit `.env` file to version control
- Keep SSL certificates updated (Let's Encrypt auto-renewal recommended)
- Regularly update Docker images: `docker-compose pull && docker-compose up -d`
- Monitor Synapse logs for suspicious activity
- Consider enabling rate limiting in Synapse config

## License

MIT
