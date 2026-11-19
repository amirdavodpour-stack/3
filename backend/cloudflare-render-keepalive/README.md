# HOPEv2 Render Staging Keepalive (Optional, Disabled by Default)

This Worker contains a bounded HTTPS probe helper for a future Render Staging warm-up. Its Wrangler config has no Cron Trigger by default, no public Workers.dev endpoint, and no preview URL. It must not be deployed or scheduled for the strict $0 Staging setup.

Render Free spins down after 15 minutes without inbound traffic and takes about one minute to wake. Letting it sleep preserves workspace Free instance-hours; the first Staging request may therefore have a cold start. The normal application workers run only while the Render process is active.

Only enable a 12-minute Cron after explicitly reviewing Render's workspace-wide 750 Free instance-hours and other outbound/bandwidth/build limits, and only when always-warm Staging is required. A 12-minute trigger would consume almost all 750 hours for one web service and leave very little headroom for other services.

After creating Render Staging, set RENDER_STAGING_HEALTH_URL to the exact https://<service>.onrender.com/live endpoint before enabling any schedule. The Worker rejects all other hosts, paths, schemes, redirects, and non-200 responses.
