# H2: SWUpdate Web UI Unauthenticated

**Severity:** High  
**Category:** Security  
**Created:** 2026-06-08

## Problem

SWUpdate web UI authentication is not enabled by default. The Mongoose web server on port 8080 allows anyone on the network to push updates without credentials.

## Evidence

### Files
- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/swupdate.cfg`
- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/swupdate-start.sh`
- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/swupdate-webui-auth-init.sh`

### Issues
1. **swupdate.cfg lines 1-21**: Has no authentication configuration - only `globals`, `identify`, and `download` sections.

2. **swupdate-start.sh lines 19-22**: Only enables auth if passwd file exists:
   ```bash
   if [ -f /etc/swupdate/webui.passwd ]; then
       # Enable auth
   fi
   ```
   But if the file doesn't exist (first boot), auth is NOT enabled.

3. **swupdate-webui-auth-init.service**: Runs `Before=swupdate.service` (line 5) which should be correct for first-boot generation, but:
   - Only runs if `webui.passwd` doesn't exist (idempotent check)
   - May race with swupdate.service startup

4. **No HTTPS/TLS**: Web UI listens on port 8080 over plain HTTP.

## Impact

Anyone on the network can push updates without credentials. This is a severe security vulnerability that could allow complete device compromise.

## Recommendation

1. **Ensure swupdate-webui-auth-init.sh runs before swupdate.service**:
   - Current: `Before=swupdate.service` (correct)
   - Verify: `systemctl cat swupdate-webui-auth-init.service`

2. **Add authentication configuration to swupdate.cfg**:
   ```
   download: {
       auth_user = "admin";
       auth_domain = "acadia";
       # ... 
   }
   ```

3. **Add HTTPS/TLS support** for web UI:
   - Generate self-signed cert or use Let's Encrypt
   - Configure Mongoose with SSL options

4. **Consider network isolation** requirements for production:
   - Document that web UI should be behind firewall or VPN
   - Consider disabling web UI and using CLI only for production

5. **Fail securely**: If no auth file exists, disable upload or require explicit opt-in

## References

- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/swupdate.cfg`
- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/swupdate-start.sh:19-22`
- `meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/swupdate-webui-auth-init.sh`
