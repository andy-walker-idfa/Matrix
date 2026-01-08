# Rollback Point - Before MAS Database Migration Implementation

**Date**: 2026-01-08
**Commit**: `6d28ea7` - Add MSC3861 OIDC authentication discovery to .well-known
**Status**: All containers running, but MAS has config errors

## Current State

### Working:
- ✅ All 9 containers running
- ✅ PostgreSQL database for MAS
- ✅ Simplified MAS config template (no static clients)
- ✅ MSC3861 OIDC discovery in .well-known
- ✅ Local data directories

### Issue:
- ❌ MAS logs show: "Error: missing field `secrets`"
- ❌ MAS database schema not created (missing `mas-cli database migrate`)
- ❌ User registration fails

## To Rollback

If the database migration changes don't work:

```bash
git reset --hard 6d28ea7
git push --force
```

Then on target server:
```bash
git pull --force
./init.sh
docker-compose restart mas
```

## What Changed After This Point

1. Updated `mas/config.yaml.template` to match `mas-cli config generate` structure
2. Added database migration step to `init.sh`
3. Fixed `secrets` section structure in MAS config

## Testing After Rollback

If you need to test the old configuration:
1. Navigate to: `https://messaging.idfa.cc/account/`
2. MAS will show config errors in logs but containers will run
3. Registration will not work until proper initialization is done
