# Personal Infrastructure: K3s Multi-Cloud Cluster — Phase 1 Plan

> **k3s, NOT k8s.** Single ~70 MB binary, SQLite/kine datastore (no external etcd),
> control plane idles ~512 MB. This is why a 2 GB box can be the control plane.

---

## 🎓 Learning mode (added 2026-06-28) — READ FIRST

Phases 6 and 7 were **speed-run on 2026-06-28**: the agent directed each step and I
executed, and `kolchurin.dev` went live — but I leaned on the agent to *understand* it.
Honest self-assessment: told "now do this again for a different front-end app, no help,"
I could not yet. **That unaided ability is the actual goal of this project.**

New working agreement from here:
- The **coding-teacher** sets concrete **tasks / exercises** (e.g. "write the Ingress for a
  new app from scratch", "issue a cert for a new subdomain", "diagnose this broken pod").
- The **main agent gives NO extra help** — no pastable commands, no writing my manifests,
  no step-by-step walkthroughs. It may verify my work, confirm correctness, and point me at
  docs — nothing more.
- **Done = I can stand up a new front-end app on this cluster end-to-end, unaided.**

**Checkpoint 2026-09-15 — progress.** Deployed the Bark push server and tix-watch
*almost* on my own: wrote `bark.yaml` (Deployment/Service/Ingress/PVC) and the DNS record
myself, and debugged by isolating layers (port-forward → Service works, `cf-dns list` →
record exists). Needed the teacher for: DNS negative caching (NXDOMAIN cached because I hit
the URL before creating the record), and a Go flag's CLI `Name` vs its `EnvVars` name
(`BARK_SERVER_DATA_DIR`). Remaining gap on tix-watch was a state-file path pointing outside
its volume on a read-only root filesystem.

## ⏯️ CURRENT STATUS — pick up here (last worked 2026-09-15)

**Done:**
- **Phase 0** — `webui.db` (159 MB, 109 chats) backed up to `~/backups/`. Pihole config inventoried: 2 adlists (StevenBlack + kboghdady youtube), no custom DNS/CNAMEs; `pihole.toml` saved.
- **Phase 1** — Headscale live on hetzner at `https://headscale.kolchurin.dev` (v0.28.0, Caddy auto-TLS, user `liminor` = id 1). `/health` returns `{"status":"pass"}`.
- **Phase 2** — All 6 nodes on the mesh (see IP table below).
- **Phase 3 (interim Pihole DNS) — SKIPPED.** Folded into the cluster-Pihole step.
- **ovh-s0 hardening** — confirmed the "DDoS" was OOM. Resolved structurally: ovh-s0 reinstalled fresh (Debian 13), RC moved off it entirely.
- **RC backup (Phase 5 prep)** — Mongo dump (`rc-mongo.archive.gz`, 4.3 MB = all data/history/SlackBridge), compose dir tar (183 KB incl. `.env`), env ref. On laptop at `~/Dev_Projects/k3s-migration/backups/rc-backup/`. Uploads were in GridFS (empty fs volume = expected). Restore targets: RocketChat 8.2.0, MongoDB 8.2.
- **Phase 5 — k3s CLUSTER UP ✅.** 3 nodes Ready (k3s v1.35.5+k3s1): ovh-s0 control-plane (Debian 13, tainted, 100.64.0.7), hetzner-s0 + ovh-s1 workers. flannel over tailscale0, no public :6443, traefik+servicelb disabled. kubectl-from-laptop works: `~/.kube/k3s-kolchurin-config` (context `k3s-lab`, server `https://100.64.0.7:6443`), nushell toggle `def --env k3s-lab []`. local-path-provisioner present (backs PVCs). **Decision: RC rebuild stays LAST (Phase 12)** — RC offline through buildout, accepted.
- **Phase 4 — Neon Postgres DONE ✅** (done early, out of order). Project created, `litellm` db, pooled connection string saved **local-only** (becomes a k8s Secret in Phase 8 — NOT in git). Neon Auth left OFF. Region eu-central-1. Free tier auto-suspends ~5 min idle (cold-start latency, harmless).
- **Tooling** — `~/.config/nushell/cf.nu` (native-`http` Cloudflare DNS: `cf-dns add/list/rm`). Token `~/.config/cloudflare/token` (Zone:DNS:Edit — reused by cert-manager + Pulumi).

**Phases 6 & 7 — DONE 2026-06-28** (Traefik ingress + cert-manager wildcard TLS; `kolchurin.dev` frontend live on k8s — commits `371e8e6` / `d839c0d`; manifests in `infra/traefik`, `infra/cert-manager`, `infra/web-prod`). Further work proceeds under **🎓 Learning mode** above. The steps below are kept as the as-built record of how Phase 6 was done:
1. Helm-install our own **Traefik** on **ovh-s1** (`hostNetwork: true`, nodeSelector ovh-s1) so it binds ovh-s1's public 80/443 — where `*.kolchurin.dev` points.
2. Install **cert-manager** + a Cloudflare **DNS-01 `ClusterIssuer`** (reuse the `cf.nu` token as a Secret).
3. Wildcard `Certificate` for `*.kolchurin.dev` (+ `*.preview.kolchurin.dev`).
4. Use the infra repo `~/Dev_Projects/k3s-migration/` (manifests under `infra/`), commit per phase.
   - Verify: `kubectl get certificate -A` Ready; `curl https://anything.kolchurin.dev` → Traefik 404 with a valid LE cert.

**ovh-s0 tailnet IP is now 100.64.0.7** (was .6 pre-reinstall) — used in all kubeconfig/k3s flags.

**Personal services — LIVE 2026-09-15** (namespace `personal-servises`, manifests in `infra/personal-servises/`, both pods on hetzner-s0):
- **Bark** (`bark.yaml`) — self-hosted iOS push server at `https://bark.kolchurin.dev`. Data on a local-path PVC mounted at `/bark-data`, selected with `BARK_SERVER_DATA_DIR` (image default is `/data`). TLS from the wildcard cert via the default TLSStore — no `tls:` block needed.
- **tix-watch** (`tix-watch/`, Kustomize; app repo `~/Dev_Projects/tix-watch`) — polls Cinema City every 5 min for 70mm IMAX seats and alerts through Bark. State in an `emptyDir` at `/data` (dedup cache, not durable). Device keys come from the imperatively created Secret `bark-device-token-list` (key `device-tokens`, comma-separated), mapped to `TIXWATCH_BARK_KEY` via `env.valueFrom`, which overrides the `envFrom` Secret. `tix-watch/secret.yaml` is gitignored — recreate it locally before `kubectl apply -k`. Verified end-to-end: `kubectl exec deploy/tix-watch -- /tix-watch -test-notify` reached both iPhones (batch `device_keys` push works on the self-hosted server).
- **Decision — Bark is the primary alert channel; ntfy stays on the roadmap** as an A/B comparison and backup channel. Reason: Bark's delivery felt more reliable for iOS notifications (time-sensitive level gets through Focus). `ntfy.yaml` is a draft, not deployed, and not yet valid.
- **Loose ends:** namespace name is misspelled and doesn't follow the `<app>-<env>` convention; PVC name `local-path-pvc` is generic (the ntfy draft reuses it); Bark image is unpinned (`ghcr.io/finb/bark-server`, no tag); stale `TIXWATCH_BARK_KEY` in the cluster `tix-watch` Secret until the next `apply -k`.

---

## Node topology (sized to specs)

| Node | Public IP | Tailnet IP | RAM | Role |
|---|---|---|---|---|
| **ovh-s0** | 57.128.218.230 | 100.64.0.7 | 2 GB | k3s **control plane** (tainted, ~512 MB) |
| **hetzner-s0** | 49.13.129.168 | 100.64.0.3 | 4 GB | worker: **RC + Mongo**, Headscale, Caddy |
| **ovh-s1** | 135.125.237.68 | 100.64.0.5 | 4 GB | worker: LLM, OpenWebUI, frontend, Pihole, monitoring |
| laptop (nixos) | — | 100.64.0.1 | — | admin / kubectl |
| iphone | — | 100.64.0.2 | — | mesh client |
| macbookair | — | 100.64.0.4 | — | admin (Tailscale brew formula, userspace mode) |
| **Neon** (external) | — | — | — | Postgres for LiteLLM (free tier) |
| **Cloudflare R2** (external) | — | — | — | restic backups of Mongo + PVCs (10 GB free, zero egress, reuses CF account) |

DNS topology (set up in Phase 10, not now): tailnet DNS → cluster Pihole's tailnet IP, with `1.1.1.1` fallback, so every device incl. iPhone-on-cellular resolves through Pihole.

---

## Context

Vladimir's personal infra was a hand-rolled docker-compose mix across three VPSes. Goal: consolidate onto a self-hosted **k3s cluster** over a **Headscale WireGuard mesh** (which also carries his laptop, iPhone, Mac, home machine). Motivations: (1) **CV-grade k3s operational experience**; (2) "client-facing scrutiny" reliability; (3) modernize the chat stack. This is a **self-directed learning plan** — the agent directs, the user executes, so each phase explains *why*, not just *how*.

vultr (1 GB) was replaced mid-project by a **Hetzner CX22** (2 vCPU / 4 GB / 40 GB, €4.83/mo, x86 Ubuntu) — better hardware/€ and native Talos boot support for the eventual Phase-2 Talos rebuild.

---

## Decision log (why things are the way they are)

- **k3s, not vanilla k8s or Talos (yet).** k3s fits the RAM budget; Talos needs an OS wipe (risky mid-learning) but is the **Phase-2** destination. Vanilla k8s = same API as k3s, heavier, no CV upside.
- **Control plane on ovh-s0 (2 GB), not hetzner.** Corrected mid-session: the ovh-s0 OOM history was a **sizing mismatch** (RC too big for 2 GB, zero swap), not flaky hardware. With RC gone, a ~512 MB k3s control plane on 2 GB + swap is rock-solid. "Weakest box = control plane" only ever meant "the spare, dedicated, non-workload box."
- **RC + Mongo move to hetzner (4 GB), its proper home.** Right-sizes RC to a box that fits it instead of cramming it on 2 GB. Mongo data migrates from ovh-s0's compose volume into a k8s StatefulSet+PVC on hetzner. Reinstalling ovh-s0 fresh means RC leaves entirely → ovh-s0 is a pure control plane from day one (no k3s+RC coexistence wrinkle).
- **Cluster traffic rides the existing Headscale mesh.** Use `--flannel-iface=tailscale0` + tailnet `--node-ip`, **NOT** `--flannel-backend=wireguard-native` (that would double-encrypt WireGuard-in-WireGuard). API binds to tailnet `:6443` — no public control-plane exposure.
- **LiteLLM Postgres → Neon free tier.** Removes a stateful piece + kills the old public 5432 exposure. Deferred to just before Phase 8 (not a cluster-bootstrap dependency).
- **Keep LiteLLM as the gateway; Fireworks.ai is the primary provider; the big-3 are $5 failover targets** (decided 2026-07-26). LiteLLM was re-evaluated against Fireworks (used at work — cheaper, and covers the *only* LiteLLM feature that was load-bearing here: aggregation). Verdict: Fireworks aggregates *models within one vendor*; LiteLLM aggregates *vendors* — different things. Fireworks is single-vendor, so its outage drops all its models at once. So: **Fireworks = primary** (cheap open-model volume, OpenAI-compatible), **LiteLLM stays** as the gateway for cross-vendor failover + virtual keys + spend governance (the enterprise-lab / CV value, consistent with the OpenBao rationale). Failover targets: **$5 parked in each of OpenAI, Anthropic, Google** as prepaid credit with **no card-on-file / no auto-recharge**, so $5 is a hard ceiling a failover loop can't breach. Caveat: **Google/Gemini bills against a GCP account (card), not clean prepaid** — use its free tier or a GCP budget cap instead. Fallbacks chained in explicit order (Fireworks → OpenAI → Anthropic → Google); a failover is a quality-/cost-*up* switch, not transparent. All 4 provider keys are static k8s Secrets in Phase 8 → migrate into OpenBao KV at Phase 11. **This keeps Neon in the stack** (LiteLLM still needs Postgres for keys/spend), so the "drop the stateful piece" simplification is off the table — accepted trade for the gateway skill + failover.
- **Deploy previews (apex site): GH Actions push model, runner joins the tailnet via the Tailscale GitHub Action** (decided 2026-07-26). The k3s API is tailnet-only (`100.64.0.7:6443`, no public :6443), so a cloud GH runner can't `kubectl apply` — the prior Phase-7 one-liner glossed over this. Now: the PR workflow joins an ephemeral node to the Headscale mesh via the Tailscale Action (`--login-server=https://headscale.kolchurin.dev`, ephemeral preauth key), runs kubectl against the tailnet API, drops off. Keeps the push model, reuses existing slug logic (`~/Dev_Projects/kolchurin.dev/preview-deployment/deployment/preview/deploy.sh`). Scheme `<pr-slug>.preview.kolchurin.dev`; TLS already covered by the wildcard cert's `*.preview.kolchurin.dev` SAN; prereq is the matching Cloudflare A/CNAME → ovh-s1. **Deferred GitOps upgrade:** replace with an **Argo CD ApplicationSet PR generator** (pull model, in-cluster, auto spin-up/teardown — canonical GitOps preview pattern + stronger CV) when the GitOps block lands; bigger commitment than "for now" warrants.
- **MongoDB stays in-cluster** (StatefulSet on hetzner, restic→**Cloudflare R2** nightly). IONOS Managed Mongo Playground evaluated + rejected: private-LAN-only access would force RC into IONOS Compute, defeating multi-cloud k3s.
- **Backups go to Cloudflare R2, not Backblaze B2** (decided 2026-06-09). Data is tiny (RC dump 4.3 MB) so both are free, but R2 reuses the existing CF account (one fewer vendor), gives zero egress fees (matters during restores), and is S3-compatible so restic config is identical to B2. Self-hosting rejected: a backup on a cluster node shares the blast radius it's meant to survive. Off-site object store is the point.
- **Secrets platform: OpenBao, introduced in Phase 11** (decided 2026-06-10). Goal is an enterprise-realistic lab that can eventually be monetized, so dynamic/JIT secrets are in-scope. Web-checked the market: Doppler's dynamic secrets are Enterprise-tier (SaaS-only); Infisical's are gated to a paid enterprise license **even when self-hosted** (its `ee/` dir is non-MIT). **OpenBao** (OSS Vault fork, MPL) is the only path where true dynamic secrets — DB/PKI/SSH engines, leasing, auto-revocation — are genuinely free. Sequenced at Phase 11 on purpose: phases 6–10 use static k8s Secrets (learn the primitive), then graduate to OpenBao + **External Secrets Operator** + dynamic Mongo creds (the headline demo). Static keys (R2, GitHub PAT, Neon, RESTIC_PASSWORD) migrate into OpenBao KV as the single source of truth; pods auth via k8s ServiceAccount (JIT bound tokens, no static Vault token in-cluster). Not stood up earlier because there's no dynamic backend to point it at until Mongo exists.
- **Chat: keep RocketChat, modernize in place.** RC has the official **WhatsApp Business Cloud App** (Meta API) — the user's primary WA use case is business. 50-seat push-limit fix: check guest-role first, else **matterbridge** single-bot relay. Jitsi → **LiveKit** marketplace app for video (video is essential). Matrix was evaluated and deferred (its WA bridge is personal-account-only/unofficial).
- **Pihole stays, moves into the cluster** as the universal DNS authority (Phase 10). Interim: no tailnet DNS (user accepts no ad-blocking until then).
- **IaC (Terraform/Pulumi): learn it as a greenfield block right after Phase 6 — pulled forward, NOT deferred to Talos** (decided 2026-06-13). User wants reproducible cluster stand-up for future projects (e.g. a CMS + Resend + Twilio stack). Split clarified during teaching: *app* reproducibility = Helm/manifests/GitOps (the workload-layer skill being learned now in Phase 6); *cluster/infra* reproducibility = IaC (provisioning layer). Guardrails: don't retrofit IaC onto the existing hand-built cluster (throwaway work) and don't run two unfamiliar declarative systems in parallel — so finish Phase 6 first, *then* provision a **throwaway cluster from zero on Hetzner Cloud** (first-class TF/Pulumi provider; already a Hetzner user) as a focused IaC learning exercise on a clean canvas. The real production IaC codification still lands at the Phase 2 Talos rebuild (Cloudflare + Hetzner + k8s in one program — a CV story). The hand-written `cf.nu` API calls map 1:1 onto future `cloudflare.Record` resources.
- **Only `webui.db` + RC's Mongo are worth preserving.** Everything else rebuilds fresh.

---

## Prerequisites

- ✅ **Cloudflare API token** (Zone:DNS:Edit on kolchurin.dev) — done, at `~/.config/cloudflare/token`. Reused by cert-manager (Phase 6) + Pulumi (later).
- ⬜ **Neon account** (free, no card) — do before Phase 8.
- ✅ **Cloudflare R2** bucket + R2 API token — DONE (2026-06-10). Bucket `k3s-lab-backups` (Standard storage), account ID `f9e371667244609d910373676cf12011`, S3 endpoint `https://f9e371667244609d910373676cf12011.r2.cloudflarestorage.com`. **Account** API token (not user), scoped *Object Read & Write* to that one bucket, no expiry. Access Key ID + Secret + restic `RESTIC_PASSWORD` (`openssl rand -base64 32`) saved in Bitwarden (3 entries) — NOT in git; separate token from the DNS one. restic repo URL: `s3:https://f9e371667244609d910373676cf12011.r2.cloudflarestorage.com/k3s-lab-backups`.
- ✅ **GitHub PAT** (`read:packages`) — DONE (2026-06-10). Classic PAT, `read:packages` scope only, saved in Bitwarden with the GitHub username. Becomes a k8s `dockerconfigjson` pull secret in Phase 7 (cluster pulls `ghcr.io/<you>/frontend`).
- ✅ **Tailscale** on iPhone + Mac + laptop + 3 servers — done.

---

## Phased execution plan

Each phase: **Goal / Why / Steps / Verify**. Proven commands from this session are inlined where we've run them.

### ✅ Phase 0 — Preflight — DONE
Backed up `webui.db`; inventoried Pihole (2 adlists, no custom DNS).

### ✅ Phase 1 — Headscale on hetzner — DONE
Headscale v0.28.0 + Caddy auto-TLS at `headscale.kolchurin.dev`. Caddyfile is *only* the site block (no `:80` wrapper, no nesting):
```
headscale.kolchurin.dev { reverse_proxy 127.0.0.1:8080 }
```
config.yaml: `server_url: https://headscale.kolchurin.dev`, `listen_addr: 127.0.0.1:8080`.

### ✅ Phase 2 — Onboard devices — DONE
All 6 nodes joined. NixOS = `services.tailscale.enable` + `tailscale up --login-server …`. iPhone = Tailscale app → custom coordination server → complete `headscale nodes register --user 1 --key …` on hetzner. Servers = install script + `tailscale up --login-server https://headscale.kolchurin.dev --auth-key <key>`. v0.28 preauth: `headscale preauthkeys create --reusable -e 48h --user 1` (numeric ID, not name).

### ⏭️ Phase 3 — Tailnet DNS → Pihole — SKIPPED (folded into Phase 10)

### ✅ Phase 4 — Provision Neon Postgres — DONE (2026-06-09, early)
`litellm` db created, pooled connection string saved **local-only** (k8s Secret in Phase 8, not git). Neon Auth OFF. Region eu-central-1. Free tier auto-suspends ~5 min idle.

### ✅ Phase 5 — k3s bootstrap — DONE (2026-06-09). As-built: ovh-s0 = 100.64.0.7, k3s v1.35.5+k3s1, 3 nodes Ready, kubectl from laptop via context `k3s-lab`. Commands below are the exact as-run record.

**RC extraction checklist** (ran on ovh-s0, env captured BEFORE stopping — backup verified on laptop at `~/Dev_Projects/k3s-migration/backups/rc-backup/`):
```bash
mkdir -p ~/rc-backup && cd ~/rc-backup
docker exec rocketchat-compose-rocketchat-1 env > rc-env.txt          # ⚠ secrets
docker exec rocketchat-compose-rocketchat-1 env | grep -iE "MONGO_URL|ROOT_URL|Storage|Upload"
docker inspect rocketchat-compose-rocketchat-1 --format '{{range .Mounts}}{{.Name}} -> {{.Destination}}{{println}}{{end}}' > rc-mounts.txt
docker stop rocketchat-compose-rocketchat-1                            # consistent dump
docker exec rocketchat-compose-mongodb-1 sh -c 'mongodump --db=rocketchat --archive --gzip' > rc-mongo.archive.gz
docker run --rm -v <uploads-vol>:/data -v ~/rc-backup:/backup alpine tar czf /backup/rc-uploads.tar.gz -C /data .
cp ~/rocket-chat/rocketchat-compose/{docker-compose.yml,.env,*.yml} . 2>/dev/null
# versions to match on restore: RocketChat 8.2.0, MongoDB community 8.2
# then from laptop:  scp -r ovh-s0:~/rc-backup ~/backups/rc-backup
```

**Then reinstall ovh-s0** (OVH panel, fresh Debian/Ubuntu) → re-onboard tailnet (delete stale node, note NEW tailnet IP) → optional swap for safety margin.

**5a — k3s server (control plane) on ovh-s0** (use ovh-s0's actual post-reinstall tailnet IP in place of 100.64.0.7):
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=100.64.0.7 --advertise-address=100.64.0.7 \
  --flannel-iface=tailscale0 \
  --node-taint CriticalAddonsOnly=true:NoExecute \
  --disable traefik --disable servicelb \
  --tls-san=100.64.0.7" sh -
```
(No OOM-protection step needed now — RC won't be on this box.)

**5b — token:** `sudo cat /var/lib/rancher/k3s/server/node-token`

**5c — agents:**
```bash
# hetzner-s0
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent --node-ip=100.64.0.3 --flannel-iface=tailscale0" \
  K3S_URL=https://100.64.0.7:6443 K3S_TOKEN=<token> sh -
# ovh-s1
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent --node-ip=100.64.0.5 --flannel-iface=tailscale0" \
  K3S_URL=https://100.64.0.7:6443 K3S_TOKEN=<token> sh -
```

**5d — kubectl from laptop (as built):** `scp ovh-s0:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-kolchurin-config`, then in nushell `str replace --all 'default' 'k3s-lab'` and `str replace 'https://127.0.0.1:6443' 'https://100.64.0.7:6443'`. Toggle command (note `--env`, else env change doesn't escape the `def`):
```nu
def --env k3s-lab [] { $env.KUBECONFIG = $"($env.HOME)/.kube/k3s-kolchurin-config" }
```
Kept fully separate from work `~/.kube/config` (never read/written). Workers labeled `node-role.kubernetes.io/worker=worker`.
**Verified:** 3 nodes Ready w/ tailnet INTERNAL-IPs; taint CriticalAddonsOnly on ovh-s0; CoreDNS + metrics-server + local-path-provisioner running.

### ▶️ Phase 6 — Ingress + cert-manager — NEXT
Helm-install **Traefik** (our own, k3s' bundled one disabled) on **ovh-s1** with `hostNetwork: true` so it binds ovh-s1's public 80/443 (where `*.kolchurin.dev` points). Install **cert-manager**, Cloudflare DNS-01 `ClusterIssuer` (reuse the token), wildcard `Certificate` for `*.kolchurin.dev` + `*.preview.kolchurin.dev`. Keep manifests in the existing `~/Dev_Projects/k3s-migration/` repo under `infra/`. Verify: `kubectl get certificate -A` Ready; `curl https://anything.kolchurin.dev` → Traefik 404 w/ valid LE cert.
**Open decision before starting:** Helm vs raw manifests for Traefik + cert-manager (lean Helm — canonical for these two, values files committed to the infra repo).

### Phase 7 — Migrate SvelteKit frontend (lowest-risk first)
Manifests: namespaces `kolchurin-prod`/`kolchurin-preview`, Deployment pulling `ghcr.io/<repo>/frontend`, Service, Ingress for `kolchurin.dev`, GHCR pull secret. Repoint `kolchurin.dev` DNS → ovh-s1. Decommission Dokploy (it died with vultr — verify nothing references it).

**Deploy previews (apex site) — `<pr-slug>.preview.kolchurin.dev`.** TLS is already covered — the wildcard cert carries a `*.preview.kolchurin.dev` SAN (`infra/cert-manager/wildcard-certificate.yaml`). GH Actions on PR open/close does `kubectl apply`/`delete` of a templated Deployment+Service+Ingress into `kolchurin-preview`, reusing the existing slug logic in `~/Dev_Projects/kolchurin.dev/preview-deployment/deployment/preview/deploy.sh`. **The catch (was unstated):** the API is tailnet-only (`100.64.0.7:6443`, no public :6443), so a cloud runner can't reach it — the workflow first joins the Headscale mesh via the **Tailscale GitHub Action** (ephemeral preauth key, `--login-server=https://headscale.kolchurin.dev`), runs kubectl, then drops off. **Prereq:** add `*.preview.kolchurin.dev` A/CNAME → ovh-s1 public IP in Cloudflare (DNS-01 issues the cert regardless, but routing needs the record). **Deferred GitOps upgrade:** swap this push model for an **Argo CD ApplicationSet PR generator** (pull model, in-cluster auto spin-up/teardown) when the GitOps block lands — see decision log.

### Phase 8 — LiteLLM + OpenWebUI (fresh, restore webui.db)
Namespace `llm`. Neon URL as Secret. LiteLLM Deployment (`ghcr.io/berriai/litellm:main-stable`, ConfigMap config.yaml, empty DB → re-add models via `/ui`). OpenWebUI Deployment + PVC; restore `webui.db` via `kubectl cp` into the PVC then start. **Screenshot the old LiteLLM model list before teardown.** Repoint `litellm`/`owai` DNS. Tear down ovh-s1's old compose stack + the stale `/home/liminor/litellm/` clone.

### Phase 9 — Monitoring: kube-prometheus-stack + Uptime Kuma + public "vitals" dashboard
Helm `kube-prometheus-stack` → `monitoring` ns, Grafana via Ingress (`grafana.kolchurin.dev`), small PVC. Uptime Kuma (Deployment+Svc+Ingress+PVC) probing all services + a public status page. Wire failure alerts (email/Telegram).

**Public showcase dashboard (decided 2026-07-26).** The whole cluster should be legible to *anyone*, not just a technical interviewer, and feel *alive* — not a binary up/down page. Vehicle: **Grafana's native public-dashboards feature** (GA since Grafana 10–11) — build ONE curated dashboard, flip it public (read-only, no login, e.g. `metrics.kolchurin.dev`), rest of Grafana stays locked. Set auto-refresh ~5–10s so gauges move. Panels chosen to *visibly move*: **ingress requests/sec** (ticks when the viewer loads the sites — the killer "alive" signal), **network throughput in/out**, **per-node CPU/mem gauges** labelled OVH/Hetzner (tells the multi-cloud story), and a **row of green "UP" stat tiles** per service (folds in the status-page legibility). Guardrails: curate panels ruthlessly (only hand-picked panels are reachable from the public link), audit legends/labels for internal hostnames/namespaces before shipping, and note a public dashboard = uncontrolled Prometheus query load (fine at this scale). **Dozzle is NOT this** — it's a log viewer; exposing it publicly = leaking logs. Dozzle stays private (tailnet-only) as the operator log/triage tool. Optionally add Dozzle v10 metric/event alerts → webhook → **ntfy** for phone push.

### Phase 10 — Pihole into the cluster (+ the deferred DNS push)
Pihole Deployment on ovh-s1, `hostNetwork: true` (port 53), nodeSelector, PVC for `/etc/pihole`+`/etc/dnsmasq.d`. Restore the 2 adlists (no custom DNS/CNAMEs). Stop bare-metal Pihole → cluster Pihole takes 53. **Then** the Phase-3 DNS push: Headscale `dns.nameservers.global = [ovh-s1 tailnet 100.64.0.5, 1.1.1.1]`, `override_local_dns: true`, restart. Point k8s CoreDNS upstream → Pihole. `apt purge` bare-metal Pihole. (⚠ open-resolver: ensure public 53 on ovh-s1 is firewalled.)

### Phase 11 — Secrets platform (OpenBao) + MongoDB StatefulSet + restic→R2 backups
This phase is also where the lab graduates from static k8s Secrets to a real **enterprise-grade secrets platform** — the deliberate progression (learn static Secrets in 6–10, then dynamic secrets here) is itself part of the CV/monetization story. Mongo is the first genuinely *dynamic* backend, so OpenBao lands alongside it.

**11a — OpenBao** (OSS Vault fork, MPL — dynamic secrets are free here, unlike Doppler/Infisical where they're paywalled even self-hosted). Helm-install into a `vault`/`openbao` ns, single node with a PVC (Raft/integrated storage), auto-unseal can come later — manual unseal is fine for the lab. Enable the **KV v2** engine and migrate the static keys (R2 creds, GitHub PAT, Neon URL, `RESTIC_PASSWORD`) into it as the single source of truth.
**11b — External Secrets Operator (ESO)** as the glue: ESO reads OpenBao and *materializes* native k8s Secrets, so workloads keep consuming plain Secrets while OpenBao owns the truth. `ClusterSecretStore` pointing at OpenBao (k8s-auth backend so pods authenticate by ServiceAccount — JIT bound tokens, no static Vault token in the cluster).
**11c — MongoDB StatefulSet** (RC's Mongo lives on **hetzner**, not ovh-s0): `mongo:8.x` (match RC 8.2's expectation) `--replSet rs0` (RC needs replica-set mode even single-node), PVC via local-path, nodeSelector hetzner. `rs.initiate()` to bootstrap.
**11d — Dynamic Mongo creds via OpenBao** (the headline enterprise demo): enable OpenBao's **database secrets engine** against Mongo, so RC (and backup jobs) request *short-lived, auto-revoked* Mongo users with a TTL instead of a static password. This is the genuine JIT/dynamic-secrets capability — the thing worth showing a client.
**11e — restic→R2 backups:** Backup CronJob `mongodump … | restic backup --stdin` nightly to **Cloudflare R2** (restic repo `s3:https://f9e371667244609d910373676cf12011.r2.cloudflarestorage.com/k3s-lab-backups`; R2 Access Key ID + Secret + `RESTIC_PASSWORD` sourced from OpenBao via ESO, not hand-created Secrets). Suggested path prefixes within the bucket: `mongo/`, `pvcs/`. `restic init` against the repo once before the first run. **Mandatory restore drill.**

Later (not gating this phase): retrofit Phase 8's Neon Postgres and Phase 6's Cloudflare token to source from OpenBao too; add OpenBao's **PKI engine** to issue short-lived internal TLS — both strengthen the "I run production secrets infra" story.

### Phase 12 — Modernize RC on hetzner
12a deploy RC fresh (pin hetzner, point at in-cluster Mongo, **restore the dump from Phase 5 backup** → preserves configs/users/SlackBridge/history). 12b seat-limit fix (guest-role check → matterbridge fallback). 12c WhatsApp Business Cloud App (Meta-side setup is the bulk). 12d LiveKit video replacing Jitsi. 12e decommission — RC already off ovh-s0 since the reinstall, so this is just verifying the hetzner deployment is solid. Set k8s mem limits on RC/Mongo.

---

## Parked — pending an always-on home-LAN box (decided 2026-06-10, cautious approach)
Rejected: putting Tailscale on the UniFi Express gateway (firmware updates wipe custom binaries; a flaky daemon on the router that serves the whole house = reliability risk). Instead, wait for a **dedicated always-on LAN box** (cheap Pi or N100 mini-PC) that fills two roles:
1. **House DNS resolver (thin caching forwarder, not a 2nd Pihole)** — the **clustered Pihole (Phase 10) stays the single filtering authority for the whole house**. This box is just a local caching forwarder that gives the LAN a stable resolver IP: it forwards to the cluster Pihole as **primary upstream**, and **fails over to `1.1.1.1` + `8.8.8.8` only when the cluster is unreachable**. Point UniFi DHCP DNS at this box's LAN IP. Covers the non-mesh LAN clients (TVs/IoT/guests) the Headscale DNS push can't reach. **Tradeoff:** during a cluster outage the house keeps *resolving* but loses *ad-filtering* (fallback queries go out unfiltered) until it recovers — accepted. **Impl note:** naive primary/secondary leaks queries to the public resolvers even when the cluster is up (stub resolvers don't honor order), defeating filtering — so use a forwarder with **strict ordering + health-checking** (dnsmasq `strict-order`, or CoreDNS `forward` with sequential policy + health checks), not two co-equal upstreams.
2. **Wake-on-LAN relay for the nixos workstation** — a mesh member reachable from anywhere; receives the trigger over the tailnet (SSH + `wakeonlan`/`etherwake`, or a tiny endpoint) and re-broadcasts the magic packet on the LAN. WoL is an L2 broadcast, so the relay **must sit on the same LAN segment/VLAN as the workstation** (can't be routed in from the internet/tailnet). Workflow: phone → wake box over mesh → box wakes nixos → SSH/launch agent on the now-awake workstation over the mesh.

Box requirements when buying: wired ethernet on the workstation's LAN segment, low idle power, Linux + Tailscale (arm64 or x86). An **N100 mini-PC** is the stretch pick — x86 headroom means it could later also join the k3s cluster as a 4th (home) node. Nixos side: enable WoL on the NIC (`networking.interfaces.<if>.wakeOnLan.enable = true;` + confirm BIOS/UEFI WoL on, wired). No action until the box exists.

## Post-Phase-1 (later, not now)
- Tailscale SSH ACLs → drop public port 22 on all nodes (write the Headscale policy with `ssh` rules).
- **Talos transition** (the Phase-2 CV goal) — likely relocate control plane to Talos-friendly hetzner then, or Talos-ify ovh-s0 via OVH ISO. Codify everything in **Pulumi**.
- Replace RC with Matrix only if seat/push pain returns.

## How to use this plan
**Work from the infra repo:** `cd ~/Dev_Projects/k3s-migration && nix develop` — flake dev shell provides helm/k9s/kubectx/cmctl/openbao(`bao`)/restic/talosctl/openssl/dig (system already has kubectl, mongodb-tools, git, gh; nushell covers jq/curl/http/yaml) and **auto-sets `KUBECONFIG` to the isolated k3s-lab config** (work clusters never touched). flake tracks `nixpkgs-unstable`.
One phase per session; run the Verify step before moving on. Keep cluster manifests in `~/Dev_Projects/k3s-migration/`, commit per phase. Stuck >60 min → bring the exact error back as a follow-up. The agent directs; the user executes (this is a learning project).

## Key files / locations
- App repo: `~/Dev_Projects/kolchurin.dev/preview-deployment/` (preview `deployment/preview/*` = basis for the k8s preview controller; `docs/todo-preview-deployment-setup.md`, `docs/todo-ultraplan-infra-plan.md`).
- Infra repo (existing, reused — local git, no remote): `~/Dev_Projects/k3s-migration/`. Cluster manifests under `infra/`; `backups/` + `pihole.toml` are gitignored (secrets). Has a Nix flake dev shell.
- Backups: `~/backups/webui-2026-06-07.db`, `~/backups/rc-backup/` (after extraction), `~/backups/` pihole files.
- Tooling: `~/.config/nushell/cf.nu`, `~/.config/cloudflare/token`.
- Memory: `project_infrastructure_topology.md`, `project_infra_migration_plan.md` (auto-loaded next session).
