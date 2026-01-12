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
- Implemented: per-session UDP token generated on login (UUID), bound to `peer_id` and stored server-side.
- Implemented: UDP `register_udp` and `player_input` must include `{ peer_id, token }`; server validates before applying input.
- Planned: rotate token on reconnect or interval; invalidate on disconnect.
- Planned: simple replay protection (nonce/sequence) and short token TTL if running over WAN.

## 4) Transport security
- For LAN dev: optional; for WAN/hostile networks: wrap TCP in TLS (stunnel/NGINX sidecar or native TLS) or use QUIC/DTLS/ENet.
- If staying TCP+JSON, terminate TLS at a proxy to avoid code churn.
- Pin server certificate fingerprint on clients to reduce MITM risk.

## 5) Integrity and replay protection (planned)
- Add `seq` per client and drop out-of-order/duplicate UDP inputs beyond a small window.
- Add lightweight HMAC (e.g., HMAC-SHA256) over UDP payload using the session token as key to detect tampering.

## Optional extras
- Observability: per-client rate/latency/error metrics with alerts.
- Anti-cheat heuristics: flag outlier DPS/movement for review.



## Other pending
~~Add drag-and-drop between slots~~ ✅ Done
~~Add item tooltips on hover to show specs of item~~ ✅ Done
~~Drag-and-drop: Can drag items between inventory grid slots or swap them~~ ✅ Done
~~Tooltips: Hover over any item to see name, type, damage, defense, rarity~~ ✅ Done