# MAS Deployment Steps - MSC3861 OAuth Delegation

## What Changed

1. **Fixed MAS config structure** - Based on `mas-cli config generate` output
2. **Database migrations run automatically** - MAS handles migrations on startup
3. **Fixed secrets section** - Proper format that MAS expects
4. **Added MSC3861 configuration to Synapse** - Delegates authentication to MAS
5. **Added /assets/ location to nginx** - Fixes registration page CSS/JS loading
6. **Added MAS_POSTGRES_PASSWORD** - Required environment variable
7. **Added assets resource to MAS HTTP listener** - Required for serving static CSS/JS files

## MSC3861 4-Step Setup (Now Automated)

The deployment now includes all 4 steps required for MSC3861 OAuth delegation:

1. ✅ **PostgreSQL + Database Migration** - MAS runs migrations automatically on startup
2. ✅ **Client Registration** - Synapse client auto-registered in MAS database on first run
3. ✅ **MAS → Synapse Configuration** - Configured in mas/config.yaml.template
4. ✅ **Synapse → MAS Delegation** - Configured in synapse/homeserver.yaml.template

All configuration is now included in the templates and migrations happen automatically.

## For EXISTING Deployment (Updating)

### Step 1: Pull Latest Changes
```bash
cd /path/to/Matrix
git pull
```

### Step 2: Stop MAS (Keep Others Running)
```bash
docker-compose stop mas
```

### Step 3: Ensure postgres-mas is Running
```bash
docker-compose up -d postgres-mas
# Wait for it to be healthy
docker ps | grep postgres-mas
```

### Step 4: Run init.sh (Regenerate Configs)
```bash
./init.sh
```

The script will generate new MAS config with proper structure.

### Step 5: Start MAS
```bash
docker-compose up -d mas
```

MAS will automatically run database migrations on startup.

## For FRESH Installation (New Server)

### Step 1: Clone and Initialize
```bash
git clone https://github.com/your-repo/Matrix.git
cd Matrix
./init.sh
```

The init.sh will generate all configuration files.

### Step 2: Start All Services
```bash
docker-compose up -d
```

MAS will automatically run database migrations on first startup.

### Step 3: Verify MAS Started Successfully
```bash
docker logs matrix-auth-service -f
```

You should see:
- Database migrations running automatically
- No "missing field" errors
- Successful startup messages

### Step 4: Test Registration
Navigate to: `https://messaging.idfa.cc/account/`

Should now see a working registration page.

## Troubleshooting

### If Migration Fails
Run migration manually:
```bash
docker run --rm \
  --network matrix_matrix-network \
  -v $(pwd)/mas/config.yaml:/config.yaml:ro \
  ghcr.io/element-hq/matrix-authentication-service:latest \
  database migrate -c /config.yaml
```

### If MAS Still Fails
Check logs for specific errors:
```bash
docker logs matrix-auth-service 2>&1 | tail -50
```

### If You Need to Rollback
```bash
git reset --hard 6d28ea7
git push --force
# On server:
git pull --force
./init.sh
docker-compose restart mas
```

## What Should Work After This

✅ MAS starts without config errors
✅ Database schema created (users, sessions, oauth2_clients tables)
✅ User registration at `/account/` works
✅ Element Web can discover OIDC authentication
✅ Complete authentication flow via MAS

## Verification Commands

### Verify All Services Running
```bash
docker ps
# Should show 9 containers all healthy:
# - synapse, element-web, element-call, synapse-admin
# - mas, postgres-mas
# - livekit, lk-jwt-service
# - nginx
```

### Verify MSC3861 Configuration (4-Step Verification)

**Step 1: Verify PostgreSQL & Database Migration**
```bash
# Check postgres-mas is healthy
docker ps | grep postgres-mas

# Check database tables exist
docker exec postgres-mas psql -U mas -d mas -c "\dt"
# Should show: oauth2_clients, users, sessions, etc.
```

**Step 2: Verify Synapse Client Registration**
```bash
# Check Synapse client exists in MAS database
docker exec postgres-mas psql -U mas -d mas -c "SELECT client_id FROM oauth2_clients WHERE client_id = '0000000000000000000000synapse';"
# Should return: 0000000000000000000000synapse
```

**Step 3: Verify MAS → Synapse Configuration**
```bash
# Check MAS config has correct Synapse endpoint
docker exec matrix-auth-service cat /config.yaml | grep -A 5 "^matrix:"
# Should show:
#   kind: synapse
#   homeserver: messaging.idfa.cc
#   endpoint: http://synapse:8008
```

**Step 4: Verify Synapse → MAS Delegation**
```bash
# Check Synapse config has msc3861 section
docker exec synapse cat /config/homeserver.yaml | grep -A 10 "msc3861:"
# Should show:
#   msc3861:
#     enabled: true
#     issuer: https://messaging.idfa.cc/
#     client_id: 0000000000000000000000synapse
```

### Verify OIDC Discovery
```bash
# Check .well-known/matrix/client
curl -s https://messaging.idfa.cc/.well-known/matrix/client | jq .
```

Expected response:
```json
{
  "m.homeserver": {"base_url": "https://messaging.idfa.cc"},
  "m.authentication": {
    "issuer": "https://messaging.idfa.cc/",
    "account": "https://messaging.idfa.cc/account"
  },
  "org.matrix.msc4143.rtc_foci": [...]
}
```

### Test User Registration
Navigate to: `https://messaging.idfa.cc/register`

**Expected**:
- Registration page loads with full form (username, password fields visible)
- CSS and JavaScript load correctly (no 404 errors in browser console)
- Can create a new account successfully
