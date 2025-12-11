# JustLayMe - Critical Fixes Deployment Checklist

**Date:** November 17, 2025
**Urgency:** HIGH - Security fixes included
**Impact:** All users must re-authenticate (sessions invalidated by new JWT_SECRET)

---

## PRE-DEPLOYMENT VERIFICATION

### 1. Verify New Secrets in Production .env
```bash
# Check that new secrets are in place
cd /home/fastl/JustLayMe
grep -E "JWT_SECRET|SESSION_SECRET|COOKIE_SECRET|ADMIN_PIN" .env

# Verify they're NOT the old weak values
grep -L "justlayme_super_secret" .env  # Should return filename
grep -L "12345678" .env  # Should return filename
```

**Expected Result:**
- JWT_SECRET: Long Base64 string (not "justlayme_super_secret...")
- SESSION_SECRET: Long Base64 string
- COOKIE_SECRET: Long Base64 string
- ADMIN_PIN: 6-digit number (not 12345678)

### 2. Verify Database Migration Completed
```bash
sqlite3 /home/fastl/JustLayMe/database/justlayme.db "PRAGMA foreign_keys;"
# Should return: 1

sqlite3 /home/fastl/JustLayMe/database/justlayme.db \
  "SELECT COUNT(*) FROM messages WHERE conversation_uuid NOT IN (SELECT id FROM conversations);"
# Should return: 0
```

### 3. Check File Permissions
```bash
# .env should NOT be world-readable (contains secrets)
ls -l /home/fastl/JustLayMe/.env
# Should show: -rw------- or -rw-r----- (not -rw-rw-rw-)

# If needed, fix permissions:
chmod 600 /home/fastl/JustLayMe/.env
```

---

## DEPLOYMENT STEPS

### Step 1: Backup Current State
```bash
# Backup database
cp /home/fastl/JustLayMe/database/justlayme.db \
   /home/fastl/JustLayMe/database/justlayme.db.backup-$(date +%Y%m%d-%H%M%S)

# Backup old .env (just in case)
cp /home/fastl/JustLayMe/.env \
   /home/fastl/JustLayMe/.env.backup-$(date +%Y%m%d-%H%M%S)

# Verify backups exist
ls -lh /home/fastl/JustLayMe/database/*.backup-*
```

### Step 2: Stop the Service
```bash
sudo systemctl stop justlayme
sudo systemctl status justlayme
# Should show: inactive (dead)
```

### Step 3: Verify Code Changes
```bash
# Check that fixes are in place
grep -A5 "SECURITY: Extract and validate" /home/fastl/JustLayMe/src/ai-server.js
grep "ARCHITECTURAL FIX" /home/fastl/JustLayMe/src/advanced-rag-memory-engine.js
grep "sender_type as role" /home/fastl/JustLayMe/src/conversations-api-bridge.js
```

### Step 4: Start the Service
```bash
sudo systemctl start justlayme

# Wait 5 seconds for startup
sleep 5

# Check status
sudo systemctl status justlayme
# Should show: active (running)
```

### Step 5: Monitor Startup Logs
```bash
# Watch for startup messages
tail -n 100 /home/fastl/JustLayMe/logs/startup.log

# Look for these SUCCESS indicators:
# ✅ Foreign keys ENABLED - Data integrity enforced
# ✅ Email Service configured (or disabled warning is OK)
# [Server] Server is running on port 3333
```

---

## POST-DEPLOYMENT TESTING

### Test 1: Authentication Security (Should FAIL without token)
```bash
# This should return 401 Unauthorized
curl -X POST http://localhost:3333/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "test",
    "character": "layme_v1"
  }'

# Expected response: {"error":"Authentication required", "code":"AUTH_REQUIRED"}
```

**✅ PASS:** Returns 401 Unauthorized
**❌ FAIL:** Returns 200 or allows access → CRITICAL SECURITY ISSUE

### Test 2: Service Health Check
```bash
# Check if server is responding
curl http://localhost:3333/health || curl http://localhost:3333/

# Should return something (not connection refused)
```

### Test 3: Database Foreign Keys
```bash
sqlite3 /home/fastl/JustLayMe/database/justlayme.db <<EOF
PRAGMA foreign_keys;
SELECT 'Total users:', COUNT(*) FROM users;
SELECT 'Total conversations:', COUNT(*) FROM conversations;
SELECT 'Total messages:', COUNT(*) FROM messages;
EOF

# Expected:
# 1
# Total users: 47
# Total conversations: 364
# Total messages: 1491
```

### Test 4: Log for Errors
```bash
# Check for any errors in last 50 lines
tail -n 50 /home/fastl/JustLayMe/logs/startup-error.log

# Should be empty or minimal warnings
```

---

## USER COMMUNICATION

**IMPORTANT:** All users will be logged out due to JWT_SECRET change.

### Recommended User Notice:
```
🔒 Security Update Deployed

We've upgraded our security systems. For your protection, all users
have been logged out and will need to sign in again.

What changed:
✅ Enhanced authentication security
✅ Improved data integrity
✅ Fixed message history ordering
✅ Performance improvements

Your data is safe and your experience will be better.

Thank you for your patience!
```

---

## ROLLBACK PLAN (If Something Goes Wrong)

### Quick Rollback:
```bash
# Stop service
sudo systemctl stop justlayme

# Restore old .env (WARNING: This restores weak secrets!)
cp /home/fastl/JustLayMe/.env.backup-YYYYMMDD-HHMMSS \
   /home/fastl/JustLayMe/.env

# Restore database if needed
cp /home/fastl/JustLayMe/database/justlayme.db.backup-YYYYMMDD-HHMMSS \
   /home/fastl/JustLayMe/database/justlayme.db

# Start service
sudo systemctl start justlayme
```

**NOTE:** Rollback restores security vulnerabilities. Only use in emergency.

---

## MONITORING (First 24 Hours)

### Critical Metrics to Watch:

1. **Service Uptime:**
   ```bash
   # Check every hour
   sudo systemctl status justlayme
   ```

2. **Error Rate:**
   ```bash
   # Check every 2 hours
   tail -n 100 /home/fastl/JustLayMe/logs/startup-error.log
   ```

3. **Authentication Errors:**
   ```bash
   # Should see 401 errors for unauthenticated requests (this is good)
   grep -c "AUTH_REQUIRED" /home/fastl/JustLayMe/logs/startup.log
   ```

4. **HNSW Lock Contention:**
   ```bash
   # Check for lock statistics in logs
   grep "lockedInserts" /home/fastl/JustLayMe/logs/startup.log
   ```

---

## SUCCESS CRITERIA

- ✅ Service starts without errors
- ✅ Foreign keys enabled (PRAGMA returns 1)
- ✅ Unauthenticated requests return 401
- ✅ Users can log in successfully
- ✅ Chat history displays in correct order
- ✅ No crashes in first 24 hours
- ✅ Memory engine functions without corruption

---

## CONTACTS & ESCALATION

**If Issues Arise:**

1. **Check logs first:**
   - `/home/fastl/JustLayMe/logs/startup.log`
   - `/home/fastl/JustLayMe/logs/startup-error.log`

2. **Service won't start:**
   - Check file permissions on .env
   - Check database file exists and is readable
   - Review systemd status: `sudo systemctl status justlayme`

3. **Authentication issues:**
   - Verify JWT_SECRET in .env is set
   - Check for typos in .env file
   - Confirm users are using new login

4. **Database errors:**
   - Check foreign keys: `PRAGMA foreign_keys;`
   - Verify database file not corrupted
   - Review migration results

---

## COMPLETION CHECKLIST

- [ ] Pre-deployment verification completed
- [ ] Backups created (database + .env)
- [ ] Service stopped cleanly
- [ ] Code changes verified in place
- [ ] Service started successfully
- [ ] Post-deployment tests passed
- [ ] Logs reviewed (no critical errors)
- [ ] User communication sent
- [ ] Monitoring plan activated
- [ ] This checklist saved for records

**Deployment Completed By:** _________________
**Date/Time:** _________________
**All Tests Passed:** YES / NO
**Issues Encountered:** _________________

---

**Next Review:** 24 hours after deployment
**Document Location:** `/home/fastl/JustLayMe/DEPLOYMENT_CHECKLIST.md`
**Related Docs:** `CRITICAL_FIXES_COMPLETE.md`
