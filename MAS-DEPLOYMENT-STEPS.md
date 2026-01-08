# MAS Deployment Steps - Proper Database Initialization

## What Changed

1. **Fixed MAS config structure** - Based on `mas-cli config generate` output
2. **Added automatic database migration** - Creates schema tables
3. **Fixed secrets section** - Proper format that MAS expects

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

### Step 4: Run init.sh (Regenerate Configs + Migrate DB)
```bash
./init.sh
```

The script will:
- Generate new MAS config with proper structure
- Automatically run database migration if postgres-mas is running
- Show success/failure messages

### Step 5: Start MAS
```bash
docker-compose up -d mas
```

## For FRESH Installation (New Server)

### Step 1: Clone and Initialize
```bash
git clone https://github.com/your-repo/Matrix.git
cd Matrix
./init.sh
```

The init.sh will generate configs but SKIP database migration (postgres not running yet).

### Step 2: Start PostgreSQL First
```bash
docker-compose up -d postgres-mas
```

Wait 15-30 seconds for PostgreSQL to initialize and become healthy:
```bash
docker-compose ps postgres-mas
# Should show "healthy"
```

### Step 3: Run Database Migration

First, find your Docker network name:
```bash
docker network ls | grep matrix
```

The network name will be `<directory>_matrix-network`. For example:
- If in `/opt/matrix` directory: `matrix_matrix-network`
- If in `/opt/matrix_new` directory: `matrix_new_matrix-network`

Then run the migration with your network name:
```bash
# Replace NETWORK_NAME with your actual network from above
docker run --rm \
  --network NETWORK_NAME \
  -v $(pwd)/mas/config.yaml:/config.yaml:ro \
  ghcr.io/element-hq/matrix-authentication-service:latest \
  database migrate -c /config.yaml
```

Example for `/opt/matrix_new`:
```bash
docker run --rm \
  --network matrix_new_matrix-network \
  -v $(pwd)/mas/config.yaml:/config.yaml:ro \
  ghcr.io/element-hq/matrix-authentication-service:latest \
  database migrate -c /config.yaml
```

Expected output:
```
INFO sqlx::postgres::notice: relation "_sqlx_migrations" already exists, skipping
```
Or on first run:
```
Running migrations...
Applied migration: xxx
Applied migration: yyy
Migration complete.
```

### Step 4: Start All Services
```bash
docker-compose up -d
```

### Step 5: Verify MAS Started Successfully
```bash
docker logs matrix-auth-service -f
```

Should see no "missing field" errors.

### Step 6: Check MAS Logs
```bash
docker logs matrix-auth-service -f
```

**Expected**: No more "missing field `secrets`" errors. Should see successful startup.

### Step 7: Test Registration
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

```bash
# Check MAS is healthy
docker ps | grep matrix-auth-service

# Check database tables exist
docker exec postgres-mas psql -U mas -d mas -c "\dt"

# Check MAS health endpoint
curl -f http://localhost:8081/health || echo "Health check failed"

# Check OIDC discovery
curl -s https://messaging.idfa.cc/.well-known/matrix/client | jq .
```

Expected in `.well-known/matrix/client`:
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
