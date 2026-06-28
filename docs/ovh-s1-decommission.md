# ovh-s1 legacy stack — decommission & rebuild blueprint

Captured 2026-06-28 before tearing down the pre-k3s bare-metal/docker stack on ovh-s1
so the k8s rebuild (Phases 7–10) has a faithful reference. See [[migration-plan]] Phase 6+.

## What was running (all OUTSIDE k8s, on ovh-s1)

| Service | Port(s) | Manager | Rebuilt in |
|---|---|---|---|
| bare Traefik (reverse proxy, LE HTTP-01) | 80, 443 | systemd `traefik.service` | replaced by k8s Traefik + cert-manager (Phase 6) |
| Pi-hole (`pihole-FTL`) | 53 (DNS), 31415 (web UI) | systemd `pihole-FTL` | Phase 10 |
| OpenWebUI | 8080 | docker `open-webui` | Phase 8 |
| LiteLLM | 4000 | docker `litellm_openwebui-litellm-1` | Phase 8 |
| Postgres (LiteLLM DB) | 5432 | docker `litellm_db` | replaced by Neon (Phase 4/8) |
| Prometheus | 9090 | docker `litellm_openwebui-prometheus-1` | Phase 9 (kube-prometheus-stack) |

## Routing (from /etc/traefik/routes.yml) — the Ingress blueprint

All HTTP→HTTPS redirect; TLS via Let's Encrypt **HTTP-01** (`certResolver: letsencrypt`, `acme.json`).

| Host | Backend | Notes |
|---|---|---|
| `pihole.kolchurin.dev` | `http://localhost:31415` | Pi-hole web admin |
| `owai.kolchurin.dev` | `http://localhost:8080` | OpenWebUI |
| `litellm.kolchurin.dev` | `http://localhost:4000` | + CORS middleware allowing `https://owai.kolchurin.dev` (GET/OPTIONS/PUT) |

**TLS change in k8s:** the old setup issues a cert per host via HTTP-01. The k8s rebuild
issues **one DNS-01 wildcard** `*.kolchurin.dev` (cert-manager + Cloudflare), covering all
of the above plus `kolchurin.dev`. Therefore `acme.json` is NOT backed up — cert-manager
re-issues. LE registration email currently `kolchurin@gmail.com`.

## Backup artifacts

What we actually keep (most of the old stack is intentionally dropped):

- `backups/ovh-s1/pi-hole_*_teleporter_*.tar.gz` — full Pi-hole export (config + gravity + adlists + custom DNS). The one new artifact worth taking.
- `backups/webui-2026-06-07.db` — OpenWebUI conversations. **Current** — nothing added since Jun 7, so no fresh dump needed.
- Traefik routing — captured in readable form in this doc (the "Routing" table above); raw `routes.yml`/`traefik.yml` not separately archived.
- `pihole.toml` — already at repo root (also inside the Teleporter export).

**Intentionally NOT backed up:**
- **LiteLLM Postgres** (`litellm_db`) — dropped. Held temp keys, AI-provider credentials, and users; the key was **compromised** and there was only one real user. Nothing of value to restore.
- `acme.json` (old per-host LE certs) — cert-manager re-issues a DNS-01 wildcard.

## ⚠️ Phase 8 rebuild security note

The old LiteLLM key/provider credentials were **compromised**. When rebuilding LiteLLM:
**rotate all AI-provider API keys** (revoke the old ones at the provider) and generate a
fresh LiteLLM master key. Do NOT restore the old credentials from anywhere.

## Teardown (only after the bundle is verified on the laptop)

```bash
# on ovh-s1
sudo systemctl disable --now traefik        # frees 80/443
docker stop litellm_openwebui-litellm-1 litellm_db \
            litellm_openwebui-prometheus-1 open-webui   # frees 4000/5432/8080/9090
sudo systemctl disable --now pihole-FTL      # frees 53 — Pi-hole goes dark until Phase 10
```

Consequence: `owai`, `litellm`, `pihole` hostnames stay down until Phases 8 & 10. Accepted —
today's goal is bringing the `kolchurin.dev` frontend up fresh on k8s.
