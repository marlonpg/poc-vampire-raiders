# Security Hardening Ideas (Pending)

## 1) Rate-limit input packets (server)
- Enforce max input messages per client per second (e.g., 10–20 Hz) to prevent spam/DoS.
- Drop or coalesce excess packets; log offenders and consider temporary mute/ban.
- Keep metrics to tune thresholds.

## 2) Server-side input sanity checks
- Clamp input vector magnitude to <=1 and ignore NaNs/Infs.
- Reject impossible deltas (e.g., teleport distance > speed * delta * safety_factor).
- Validate bounds (stay within world limits) before applying movement.

## 3) Authentication / authorization
- Add a lightweight token per session (pre-shared for now; later JWT/OAuth if needed).
- Bind token to peer_id; disconnect on mismatch.
- Consider simple replay protection (nonce or short-lived tokens) if running over WAN.

## 4) Transport security
- For LAN dev: optional; for WAN/hostile networks: wrap in TLS (Stunnel/NGINX sidecar or native TLS if available).
- If staying TCP+JSON, terminate TLS at a proxy to avoid code churn.
- Pin server certificate fingerprint on clients to reduce MITM risk.

## Optional extras
- Integrity: hash/sequence numbers on messages to detect tampering or replays.
- Observability: per-client rate/latency/error metrics with alerts.
- Anti-cheat heuristics: flag outlier DPS/movement for review.



## Other pending
~~Add drag-and-drop between slots~~ ✅ Done
~~Add item tooltips on hover to show specs of item~~ ✅ Done
~~Drag-and-drop: Can drag items between inventory grid slots or swap them~~ ✅ Done
~~Tooltips: Hover over any item to see name, type, damage, defense, rarity~~ ✅ Done