set shell := ["nu", "-c"]
default:
  @just --list

get-tailscale-version-on-nodes:
  for n in [hetzner-s0 ovh-s0 ovh-s1] { print $"($n): (ssh $n tailscale version | lines | first)" }

