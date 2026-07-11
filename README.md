# Personal Infrastructure — Multi-Cloud k3s Cluster

A production-grade [k3s](https://k3s.io/) Kubernetes cluster spanning two cloud
providers, stitched together over a self-hosted WireGuard mesh. It runs my personal
services — a SvelteKit site, an internal tools app, a self-hosted LLM gateway, chat,
and DNS — on infrastructure I provision, secure, and operate end to end.

This repo holds the cluster manifests, Helm values, and the full engineering
decision log. It's a **learning-in-public** project: the goal isn't just "it works,"
it's being able to stand up any of it again, unaided, and explain *why* every choice
was made.

> **k3s, not k8s.** A single ~70 MB binary with an embedded SQLite/kine datastore (no
> external etcd). The control plane idles around ~512 MB, which is what makes a 2 GB
> VPS a viable control-plane node. Same Kubernetes API as vanilla k8s — just sized for
> a budget, multi-cloud homelab.

---

## Why this exists

My personal services used to be a hand-rolled `docker-compose` sprawl across three
VPSes, each a snowflake. This project consolidates them onto one declarative
Kubernetes cluster to get:

- **Real, CV-grade cluster operations experience** — ingress, TLS automation, storage,
  secrets, monitoring, backups — on infrastructure I own and can break.
- **Reliability that survives client-facing scrutiny** — reproducible manifests instead
  of undocumented SSH sessions.
- **A single mesh** carrying both cluster traffic and my personal devices (laptop,
  phone, Macs), with no public control-plane exposure.

---

## Architecture

Three VPSes across two providers form the cluster; every node — and every one of my
personal devices — sits on a self-hosted [Headscale](https://headscale.net/)
(open-source Tailscale control server) WireGuard mesh. Cluster traffic rides that
existing mesh via `flannel --flannel-iface=tailscale0`, so the Kubernetes API binds to
a tailnet address and **`:6443` is never exposed publicly**.

```
                Internet
                   │
        *.kolchurin.dev (DNS)
                   │
                   ▼
   ┌───────────────────────────────┐
   │  ovh-s1 (4 GB) · worker        │  ← public :80/:443
   │  Traefik (hostNetwork)         │    ingress for the whole cluster
   │  frontend · LLM · Pi-hole      │
   └───────────────────────────────┘
                   │  Headscale WireGuard mesh (tailscale0)
   ┌───────────────┴───────────────┐
   │                               │
   ▼                               ▼
┌────────────────────┐   ┌────────────────────┐
│ ovh-s0 (2 GB)      │   │ hetzner-s0 (4 GB)  │
│ k3s control plane  │   │ worker             │
│ (tainted)          │   │ RocketChat + Mongo │
│                    │   │ internal tools     │
└────────────────────┘   └────────────────────┘

External: Neon (Postgres) · Cloudflare R2 (backups) · Cloudflare DNS
```

| Node | Role | RAM | Notes |
|---|---|---|---|
| **ovh-s0** | k3s control plane | 2 GB | Tainted `CriticalAddonsOnly` — no workloads |
| **ovh-s1** | worker | 4 GB | Public ingress node; frontend, LLM stack, Pi-hole |
| **hetzner-s0** | worker | 4 GB | RocketChat + MongoDB, internal tools |
| Neon | external Postgres | — | LiteLLM database (free tier) |
| Cloudflare R2 | external object store | — | Off-site `restic` backups |

---

## What's in this repo

```
infra/
  traefik/          Traefik ingress via Helm — hostNetwork, pinned to the public node
  cert-manager/     cert-manager + Let's Encrypt DNS-01 ClusterIssuer + wildcard cert
  web-prod/         kolchurin.dev SvelteKit SSR frontend (Deployment/Service/Ingress)
  tools-prod/       Internal tools app — stateful, local-path PVC, secret refs
docs/
  migration-plan.md      The full phased plan + decision log (the heart of the project)
  ovh-s1-decommission.md As-built record of the legacy stack being replaced
  vps-best-value.md      Research: best-value EU VPS for a k3s/Talos learning cluster
flake.nix             Nix dev shell — pinned helm/k9s/cmctl/restic/openbao/talosctl
```

Manifests are committed per phase. Secrets are **never** in git — they're created
imperatively and referenced by name (see `.gitignore` and the header comments in each
manifest explaining exactly which Secret backs it).

---

## Engineering highlights

A few decisions that show the level this is being done at (the full reasoning lives in
[`docs/migration-plan.md`](docs/migration-plan.md)):

- **Wildcard TLS via DNS-01, not HTTP-01.** cert-manager solves an ACME DNS-01 challenge
  through the Cloudflare API to issue a single `*.kolchurin.dev` (+ `*.preview…`)
  wildcard. Traefik serves it from a default `TLSStore`, so every host gets valid TLS
  with zero per-Ingress config — something HTTP-01 fundamentally can't do.
- **Ingress on `hostNetwork`, not a LoadBalancer.** k3s' bundled ServiceLB is disabled;
  a `LoadBalancer` Service would hang at `<pending>` forever. Traefik runs with
  `hostNetwork: true`, pinned via `nodeSelector` to the one node public DNS points at,
  binding its real `:80/:443`.
- **The privileged-port capability trap.** Binding `:443` as non-root with
  `NET_BIND_SERVICE` fails: on the setuid transition the kernel clears the cap from the
  effective set (k8s can't grant *ambient* caps). Documented and solved in
  [`infra/traefik/values.yaml`](infra/traefik/values.yaml) — the kind of subtle,
  hard-won detail this project is about.
- **Cluster traffic over the existing WireGuard mesh** — `--flannel-iface=tailscale0`
  rather than `--flannel-backend=wireguard-native`, to avoid double-encrypting
  (WireGuard-in-WireGuard). No public API exposure.
- **Right-sized topology.** The 2 GB box is the control plane precisely *because* it's
  the spare, dedicated, non-workload node — corrected mid-project after diagnosing an
  earlier OOM as a sizing mismatch, not flaky hardware.

---

## Tech stack

**Orchestration** k3s · Helm · Traefik · cert-manager
**Networking / mesh** Headscale · Tailscale · WireGuard · flannel
**TLS / DNS** Let's Encrypt (ACME DNS-01) · Cloudflare
**Storage / data** local-path-provisioner · Neon Postgres · MongoDB
**Backups** restic → Cloudflare R2 (S3-compatible, off-site)
**Tooling** Nix flake dev shell · k9s · kubectx · nushell
**Roadmap** OpenBao (dynamic secrets) · External Secrets Operator · kube-prometheus-stack · Talos · Pulumi (IaC)

---

## Status & roadmap

Live in the cluster today: **ingress + wildcard TLS**, the **`kolchurin.dev` frontend**,
and a **stateful internal-tools app** (`icp.kolchurin.dev`). The remaining phases are
sequenced deliberately as a learning progression:

| Phase | Focus | State |
|---|---|---|
| 0–5 | Preflight, Headscale mesh, k3s bootstrap | ✅ Done |
| 6 | Traefik ingress + cert-manager wildcard TLS | ✅ Done |
| 7 | SvelteKit frontend + PR preview environments | ✅ Done (previews WIP) |
| 8 | LiteLLM + OpenWebUI (self-hosted LLM gateway) | ⬜ Planned |
| 9 | Monitoring — kube-prometheus-stack + Uptime Kuma | ⬜ Planned |
| 10 | Pi-hole into the cluster as DNS authority | ⬜ Planned |
| 11 | OpenBao + ESO — static → **dynamic** secrets; Mongo + restic→R2 | ⬜ Planned |
| 12 | Modernize RocketChat (WhatsApp Business, LiveKit video) | ⬜ Planned |

The static-Secrets-then-OpenBao ordering is intentional: learn the primitive first, then
graduate to a real dynamic-secrets platform (DB/PKI engines, JIT-leased credentials).
Longer term: rebuild on [Talos Linux](https://www.talos.dev/) and codify the whole
provision step (Cloudflare + Hetzner + k8s) in [Pulumi](https://www.pulumi.com/).

---

## Local dev shell

The repo ships a Nix flake that pins the exact toolchain and isolates `KUBECONFIG` to the
lab cluster so work clusters are never touched:

```bash
nix develop   # helm, k9s, kubectx, cmctl, restic, openbao, talosctl, dig, …
```

---

*Built and operated by [Vladimir Kolchurin](https://kolchurin.dev). This is a live
personal cluster — the manifests here are the real thing, secrets excluded.*
