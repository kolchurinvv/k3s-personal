{
  description = "k3s Migration — cluster ops toolkit";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        # Only tools NOT already provided system-wide (see ~/.config/nixos).
        # Already on PATH, deliberately omitted: kubectl, mongodb-tools, git, gh,
        # ethtool, podman; jq/curl/wget/yaml all covered by nushell.
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # --- Cluster ops (current) ---
            kubernetes-helm   # helm — the reason for this update
            k9s               # cluster TUI (ops + learning)
            kubectx           # kubectx + kubens (namespace switching)
            cmctl             # cert-manager CLI (Phase 6)

            # --- Roadmap (kept ready) ---
            openbao           # OSS Vault fork — dynamic secrets (Phase 11)
            restic            # encrypted backups → R2 (Phase 11)
            talosctl          # Talos rebuild (Phase 2)

            # --- Utilities not on the base system ---
            openssl           # cert inspection (s_client / x509)
            dnsutils          # dig — DNS-01 challenge + Phase 10 DNS
            sqlite            # webui.db inspection
          ];

          shellHook = ''
            # Isolate to the lab cluster — never touch work kubeconfigs from this repo.
            export KUBECONFIG="$HOME/.kube/k3s-kolchurin-config"
            echo "k3s-migration devshell  ·  KUBECONFIG → k3s-lab  ·  helm $(helm version --short 2>/dev/null)"
          '';
        };
      });
}
