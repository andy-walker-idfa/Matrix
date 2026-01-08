# MAS Deployment Steps - Proper Database Initialization

## What Changed

1. **Fixed MAS config structure** - Based on `mas-cli config generate` output
2. **Added automatic database migration** - Creates schema tables
3. **Fixed secrets section** - Proper format that MAS expects

## Deployment on Target Server

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
