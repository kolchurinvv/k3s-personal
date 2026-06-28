# Best-Value EU VPS at ~€6/Month for a Self-Hosted k3s/Talos Learning Cluster (2026)

## TL;DR
- **Buy the Hetzner Cloud CX33 (4 vCPU / 8 GB RAM / 80 GB NVMe / 20 TB traffic, €6.49/mo + €0.50 IPv4) as your primary new node** — it is the single best fit: 8× the RAM of the Vultr plan at roughly the same price, a first-class API/Terraform provider and private networks for realistic cluster-building, and **Hetzner Cloud now lists "Talos Linux" as a directly mountable ISO in the console** (Public ISO since 23 April 2025), so the Talos phase no longer needs Vultr.
- **Drop the $5 Vultr Regular plan.** Its only edge over Hetzner — custom-ISO support for Talos — has evaporated now that Hetzner ships a native Talos ISO and supports cloud-init. 1 GB RAM is genuinely too tight for Pi-hole + OpenWebUI + LiteLLM + a SvelteKit SSR site on a k3s node, and you can replace it with 4–8× the RAM for the same money.
- **Runner-up / wildcard picks:** Netcup VPS 1000 G12 (4 vCore / 8 GB / 256 GB NVMe, €8.41/mo) for more disk and dedicated-class hardware but with custom-ISO friction and a 12-month contract; Contabo Cloud VPS 20 (6 vCPU / 12 GB / 100 GB NVMe, €5.60/mo) for the absolute most RAM-per-euro plus native ISO/qcow2 upload, accepting performance variability; and Oracle Cloud Always Free (4 Arm OCPU / 24 GB RAM, €0) as a powerful free extra node if you can get capacity.

## Key Findings

**1. The RAM math is decisive, and it favors leaving Vultr.** Your current Vultr node is 1 vCPU / 1 GB / 25 GB. At essentially the same monthly spend, EU providers now give 4–12 GB of RAM. OpenWebUI + LiteLLM together are memory-hungry (a Python/Node stack plus a database and proxy), and k3s itself plus a SvelteKit SSR Node process and Pi-hole will routinely exceed 1 GB. 1 GB is workable only as a control-plane-only or lightweight agent node; for "real workloads" it is the binding constraint. Every recommendation below prioritizes RAM.

**2. The 2026 "RAMpocalypse" raised prices across the board — current prices are higher than older reviews show.** A global memory shortage drove the increases: per Tom's Hardware, DRAM prices "surged roughly 171% year-over-year through 2025 as AI infrastructure buildout drove high-bandwidth memory demand," and "Samsung raised server memory contract prices by up to 60%." Concrete effects:
- **Hetzner**: Tom's Hardware (Feb 24, 2026) reported "German data center giant hikes prices up to 37% starting April 1 — Hetzner cites rising hardware costs." Trackers detail cloud servers up roughly 30–43%, with the CPX11 (AMD shared vCPU) seeing the steepest cloud increase at +43%.
- **Netcup**: Per Netcup's official price-adjustment notice, "Prices for existing hosting contracts will increase by 18.51%, effective … from May 1, 2026. Prices for new orders from March 19 onwards will increase by 24.33%" (storage +21.52%). Coined "RAMpocalypse" by CEO Alexander Windbichler.
- **OVH**: CEO Octave Klaba "said that the company might have to raise its prices 5-10 percent in 2026 due to an increase in the costs of RAM and NVMe components" (Data Center Dynamics).

**3. Custom ISO / Talos support is no longer a Vultr-exclusive.** This was the user's central worry, and the picture has changed:
- **Hetzner Cloud:** Now lists **Talos Linux as a curated, console-mountable Public ISO** for all Cloud Servers. Per Sidero/Talos docs: "Hetzner Cloud provides Talos with the schematic id ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515 (Hetzner + qemu-guest-agent) as a Public ISO since 2025-04-23" (Hetzner changelog IDs 119702 x86 / 119703 arm), and it has been kept updated (e.g., Talos 1.11.2 added Oct 2025). It supports **cloud-init user-data** (extended to server rebuilds in Jan 2026). It does NOT offer free self-service upload of arbitrary ISOs — for a non-listed ISO you open a support ticket with a direct-download link, or use the rescue-mode/Packer snapshot method. For Talos specifically, the native ISO removes that friction entirely.
- **Vultr:** Full self-service custom ISO upload + custom startup scripts + Terraform. Still the most flexible for arbitrary ISOs, but you no longer need it for Talos.
- **Netcup:** Supports uploading your own ISOs via SCP (FTP upload to the DVD drive) and custom images (.qcow2/.raw), plus snapshots and an API. Caveat: a developer reproducibly reported Talos boot problems on a Netcup Root Server (UEFI installs but first boot fails to find the system disk; BIOS mode won't boot the Talos ISO) — so Talos-on-Netcup currently has rough edges.
- **Contabo:** Supports custom images (.iso and .qcow2) and cloud-init, but custom images require purchasing the "Custom Images" add-on at order time (or contacting support later), and images must be x86-64 with VirtIO drivers.
- **OVH:** VPS line supports a catalog of OS images and an API; it is less geared to arbitrary custom-ISO upload on the consumer VPS product than Vultr/Netcup/Contabo.

**4. Hetzner is the clear "learning value" winner for a Kubernetes career goal.** Hetzner Cloud has a mature REST API, official `hcloud` CLI, a well-maintained Terraform provider (`hetznercloud/hcloud`), private networks, a cloud controller manager and CSI driver, snapshots, and hourly billing with monthly caps. Building a multi-node k3s or Talos cluster with Terraform + cloud-init on Hetzner is itself a portfolio-grade, job-relevant exercise, and Sidero/Talos publish first-class Hetzner guides. This infra-as-code ecosystem is exactly the skill set that leads to better DevOps/platform jobs.

## Details

### Concrete spec & price comparison (post-2026-increase, EU locations, monthly, ex-VAT unless noted)

| Provider / Plan | vCPU | RAM | Disk | Transfer | IPv4 | EU locations | ~€/mo | Custom ISO / Talos | CPU type |
|---|---|---|---|---|---|---|---|---|---|
| **Hetzner CX23** | 2 (shared) | 4 GB | 40 GB NVMe | 20 TB | +€0.50 | DE (Nuremberg, Falkenstein), FI (Helsinki) | €3.99 | Native Talos ISO; cloud-init; ticket for other ISOs | x86 shared |
| **Hetzner CAX11 (ARM)** | 2 (Ampere) | 4 GB | 40 GB NVMe | 20 TB | +€0.50 | DE, FI | €4.49 | Native Talos ISO (arm); cloud-init | ARM64 shared |
| **Hetzner CX33** ⭐ | 4 (shared) | 8 GB | 80 GB NVMe | 20 TB | +€0.50 | DE, FI | €6.49 | Native Talos ISO; cloud-init | x86 shared |
| **Hetzner CAX21 (ARM)** | 4 (Ampere) | 8 GB | 80 GB NVMe | 20 TB | +€0.50 | DE, FI | €7.99 | Native Talos ISO (arm) | ARM64 shared |
| **Netcup VPS 500 G12** | 2 vCore | 4 GB DDR5 | 128 GB NVMe | unlimited | +€0.50 | DE (Nuremberg), AT (Vienna), NL (Amsterdam) | €4.85 | Own ISO via SCP; qcow2/raw; snapshots | EPYC 9645 shared |
| **Netcup VPS 1000 G12** | 4 vCore | 8 GB DDR5 | 256 GB NVMe | unlimited | +€0.50 | DE, AT, NL | €8.41 | Own ISO via SCP (Talos boot issues reported) | EPYC 9645 shared |
| **Netcup RS 1000 G12** | 4 **dedicated** | 8 GB DDR5 | 256 GB NVMe | unlimited | incl. | DE, AT | €10.36 | Own ISO via SCP | EPYC 9645 dedicated |
| **Contabo Cloud VPS 10** | 4 | 8 GB | 75 GB NVMe / 150 GB SSD | unlimited* | incl. | DE + EU | €3.60 (+ setup unless prepaid) | Custom ISO/qcow2 add-on; cloud-init | EPYC shared (oversold) |
| **Contabo Cloud VPS 20** | 6 | 12 GB | 100 GB NVMe / 200 GB SSD | unlimited* | incl. | DE + EU | €5.60 | Custom ISO/qcow2 add-on | EPYC shared |
| **OVH VPS-1 (VPS 2026)** | 4 | 8 GB | 75 GB SSD | unlimited (EU) | incl. | FR, DE, PL, UK | ~€6 (≈$6.46) | OS catalog + API; weaker custom ISO | x86 shared |
| **Vultr Regular (current)** | 1 | 1 GB | 25 GB SSD | 1 TB | incl. | DE (Frankfurt), FR, NL, UK, others | ~$5 | Full self-service custom ISO + scripts | shared |
| **Vultr High Performance** | 1 | 1 GB | 25–32 GB NVMe | ~2 TB | incl. | EU | ~$6 | Full custom ISO | shared NVMe |
| **Oracle Cloud Always Free (Ampere A1)** | up to 4 Arm OCPU | up to 24 GB | up to 200 GB block | 10 TB/mo | 1 reserved | DE (Frankfurt), NL, UK, others | €0 | Image catalog; capacity-limited | ARM64 |

\* Contabo "unlimited" traffic is subject to a fair-use throttling policy. Netcup/Hetzner figures are post-increase, ex-VAT; Contabo shows VAT-inclusive in the EU.

### Provider-by-provider assessment

**Hetzner Cloud — best overall for this use case.** Post-increase entry pricing: CX23 (2/4 GB/40 GB) €3.99, CAX11 ARM (2/4 GB/40 GB) €4.49, CX33 (4/8 GB/80 GB) €6.49, CAX21 ARM (4/8 GB/80 GB) €7.99 — all with 20 TB traffic and IPv4 at +€0.50/mo, in Germany/Finland, on NVMe. Consistent performance, excellent EU network. One caveat for sustained heavy CPU: shared CX/CPX/CAX plans are subject to fair-use CPU limits (community estimates cite roughly 20–33% sustained per vCPU before throttling — not an officially published number); for a bursty learning cluster this is rarely a problem, but if you want guaranteed cores, the CCX (dedicated) line or a Netcup RS is the answer. Signup sometimes triggers manual identity verification — budget a day. Talos is a native Public ISO; cloud-init is supported. This is the platform that best advances the Kubernetes/IaC career goal.

**Netcup — strongest raw specs-per-euro among EU "dedicated-ish" options, with friction.** The VPS G12 line (AMD EPYC 9645 "Turin", DDR5 ECC, NVMe, 2.5 Gbit/s, unlimited traffic) is excellent value. Per Netcup's published post-increase pricing: VPS 500 G12 went €4.09 → €4.85, VPS 1000 G12 (4 vCore/8 GB/256 GB NVMe) went €7.10 → €8.41, and the Root Server RS 1000 G12 (4 *dedicated* cores/8 GB/256 GB NVMe) went €8.74 → €10.36. Caveats: (a) after the hike only the VPS 500 G12 (€4.85) sits under your €6 ceiling; (b) Netcup imposes a 12-month minimum contract on the cheapest billing, a €5 setup fee on flexible billing, and manual account verification; (c) a developer reproducibly reported Talos failing to boot cleanly on a Netcup Root Server, so Talos-on-Netcup is not turnkey. Custom ISO upload works via SCP/FTP. Great for a high-spec EU node; less ideal as your *Talos* node specifically.

**Contabo — the most RAM/storage per euro, with the most caveats.** Cloud VPS 10 (4 vCPU / 8 GB / 75 GB NVMe or 150 GB SSD) is €3.60/mo and Cloud VPS 20 (6 vCPU / 12 GB / 100 GB NVMe) is €5.60/mo, both with unlimited (fair-use) traffic and included IPv4. It natively supports custom .iso/.qcow2 images (paid add-on) and cloud-init. The well-documented downsides: CPU steal and I/O variability from overselling (multiple reviews/benchmarks report 20–40% CPU steal at peak and inconsistent disk I/O), ticket-only support with multi-day response times, occasional provisioning delays / "dirty IP" suspensions, setup fees unless you prepay 3/6/12 months, and no hourly billing. For a learning lab where occasional variability is acceptable, the RAM is unbeatable; for anything latency-sensitive it's a false economy.

**Vultr — keep only if you value self-service arbitrary ISOs.** The $5 Regular plan is 1 vCPU / 1 GB / 25 GB / 1 TB; High Performance is $6 for 1 GB NVMe. Vultr's strengths are full self-service custom ISO upload, startup scripts, Terraform, and 32 global locations including EU (Frankfurt, Paris, Amsterdam, London). Its weaknesses for you: only 1 GB RAM at this price, a documented Kubernetes node-creation rate limit (reports of ~5 nodes/day), backups at +20%, and a polarized support reputation (Trustpilot ~1.8/5 vs G2 ~4.3/5). Since Hetzner now covers Talos natively, Vultr's unique advantage no longer applies to your roadmap.

**OVH — fine where you already are, not the value leader.** The new "VPS 2026" range starts around €6 (VPS-1: 4 vCPU / 8 GB / 75 GB SSD, unlimited EU traffic, free anti-DDoS, daily backups). Strengths: bundled Tbps-class anti-DDoS, unlimited EU traffic, EU data residency outside the US CLOUD Act, mature API + Terraform. Weaknesses: post-2026 hike (~30% on VPS-1), a confusing multi-console Manager, inconsistent support, and weaker arbitrary-custom-ISO support than Vultr/Netcup/Contabo. Keep your existing OVH nodes in the cluster; no strong reason to add more for this budget.

**Oracle Cloud Always Free — the wildcard power node.** Per Oracle's official docs: "All tenancies get the first 3,000 OCPU hours and 18,000 GB hours per month for free for VM instances using the VM.Standard.A1.Flex shape … For Always Free tenancies, this is equivalent to 4 OCPUs and 24 GB of memory" (splittable across up to 4 VMs), plus 200 GB block storage and 10 TB/mo egress, in EU regions (Frankfurt, Amsterdam, etc.) — permanently free. This is dramatically more RAM than any €6 plan. Caveats: ARM-only for the big shape (fine — k3s, Pi-hole, OpenWebUI, LiteLLM all have arm64 images), frequent "out of host capacity" errors when provisioning A1 in popular regions, requires a credit card for verification, idle reclamation (Oracle reclaims instances whose 95th-percentile CPU is <20% over 7 days), and you manage all networking/firewall yourself. It will not boot a custom Talos ISO the way a KVM VPS does, so treat it as a fat k3s node, not a Talos node. As a free extra worker with up to 24 GB RAM for the memory-hungry LLM stack, it's outstanding if you can grab capacity.

### ARM viability for your stack
Your workloads are arm64-friendly: k3s, Headscale/WireGuard, Pi-hole, and SvelteKit (Node) all run natively on arm64. OpenWebUI and LiteLLM publish multi-arch (arm64) container images, so Hetzner CAX, Oracle Ampere, and Netcup ARM are all viable. Mixing architectures in one cluster is fine for k3s as long as you use multi-arch images (or node selectors). The main thing to verify per release is any niche LiteLLM/OpenWebUI dependency, but as of 2026 both ship arm64 images.

## Recommendations

**Stage 1 — Replace Vultr now.** Provision a **Hetzner CX33** (4 vCPU / 8 GB / 80 GB NVMe, €6.49 + €0.50 IPv4 ≈ €7/mo) or, to stay strictly at/under €6, a **Hetzner CX23** (2 vCPU / 4 GB / 40 GB, €3.99 + €0.50) — either is a massive upgrade over 1 GB Vultr at similar money. Add it to your Headscale mesh and join it to the k3s cluster. Destroy the Vultr instance once services are migrated. This single move quadruples-to-octuples your RAM headroom for OpenWebUI + LiteLLM.

**Stage 2 — Build the IaC muscle (the actual career payoff).** Manage the Hetzner node(s) with Terraform (`hetznercloud/hcloud` provider) and cloud-init. Use a Hetzner private network to wire nodes together as a "real" cluster topology. This is directly resume-relevant.

**Stage 3 — Talos phase.** When you move to Talos, do it on **Hetzner**: select the native **Talos Linux ISO** in the console (or, for a customized schematic, use the Packer/snapshot method or a support-ticket upload), and pass machine config via cloud-init `user_data` — keep it under the 32 KiB limit with `talosctl gen config --with-examples=false --with-docs=false`. You no longer need Vultr for this.

**If you specifically want more RAM/disk than Hetzner's €6 tier:** add a **Contabo Cloud VPS 20** (6 vCPU / 12 GB / 100 GB NVMe, €5.60) as a fat worker node, accepting performance variability — and buy the Custom Images add-on if you want Talos there. **If you want guaranteed (non-shared) CPU:** step up to a **Netcup RS 1000 G12** (4 dedicated cores / 8 GB, €10.36) — over budget but the best dedicated-core value in the EU.

**Free bonus node:** If you can get capacity, add an **Oracle Always Free Ampere A1** VM (e.g., 2 OCPU / 12 GB or the full 4/24) as a k3s worker to host the memory-hungry OpenWebUI/LiteLLM pods at zero cost.

**Decision thresholds that would change this advice:**
- If you needed *guaranteed* sustained CPU (e.g., constant compilation/CI), switch the primary from Hetzner CX (shared) to Hetzner CCX or Netcup RS (dedicated cores).
- If your binding constraint becomes *RAM-per-euro above all* and you can tolerate variability → Contabo.
- If you require *self-service arbitrary custom ISOs* (not just Talos) → keep one Vultr or Netcup node for that flexibility.
- If Oracle A1 capacity is reliably available in your region → lean on it for the LLM workloads and keep paid nodes smaller.

## Caveats
- **Prices are post-2026-increase and ex-VAT** (except Contabo, which shows VAT-inclusive in the EU). VPS pricing is volatile in 2026 due to the memory shortage — verify on each provider's official page before ordering, and confirm renewal pricing (some increases hit existing contracts too, e.g. Netcup +18.51%).
- **Hetzner shared-CPU fair-use limits** apply to CX/CPX/CAX; community estimates of sustained-CPU caps (~20–33%/vCPU) are not officially published figures — treat as guidance, not a guarantee.
- **Contabo performance variability** (CPU steal 20–40% at peak, inconsistent I/O, slow ticket support, possible setup fees and IP-reputation issues) is well-documented; it's a value play, not a performance play.
- **Netcup contract & verification**: 12-month minimum on cheapest billing, €5 setup on flexible billing, manual account verification, and reported Talos-boot difficulties on Root Servers.
- **Vultr** has a documented Kubernetes node-creation rate limit and a polarized support reputation.
- **Oracle Always Free** is capacity-constrained (frequent "out of capacity"), ARM-only for the large shape, reclaims idle instances, and requires a card for signup; it is not a custom-ISO/Talos host.
- **Talos on non-Hetzner KVM VPS** (Netcup, Contabo) can hit UEFI/BIOS boot quirks; Hetzner's native Talos ISO is the smoothest path.
- Some pricing figures were cross-referenced from third-party trackers and review sites rather than read live from each control panel; the official provider pages are the authoritative source at purchase time.