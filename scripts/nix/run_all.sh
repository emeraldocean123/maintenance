#!/usr/bin/env bash
set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
maint_root="$(cd "$here/../.." && pwd)"
logs_dir="$maint_root/logs"
mkdir -p "$logs_dir"
ts="$(date +%Y%m%d_%H%M%S)"
log="$logs_dir/nix_$ts.log"

logf() { echo "[$(date -Is)] $*" | tee -a "$log"; }

# Try to find repo root hosting the maintenance folder; fallback to maint_root
if git -C "$maint_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  root_repo="$(git -C "$maint_root" rev-parse --show-toplevel)"
else
  root_repo="$maint_root"
fi

logf "Nix maintenance started at root: $root_repo"

have() { command -v "$1" >/dev/null 2>&1; }

if ! have statix; then logf "statix not found; install via nix: nix profile install nixpkgs#statix"; fi
if ! have deadnix; then logf "deadnix not found; install via nix: nix profile install nixpkgs#deadnix"; fi
if ! have treefmt; then logf "treefmt not found; install via nix: nix profile install nixpkgs#treefmt"; fi

found_nix_files=$(git -C "$root_repo" ls-files '*.nix' 2>/dev/null || true)
if [ -z "$found_nix_files" ]; then
  logf "No .nix files tracked by git at $root_repo; nothing to check"
  exit 0
fi

if have statix; then
  logf "Running statix check"
  statix check "$root_repo" | tee -a "$log" || true
fi

if have deadnix; then
  logf "Running deadnix (report only)"
  deadnix "$root_repo" | tee -a "$log" || true
fi

if have treefmt && [ -f "$root_repo/treefmt.toml" ]; then
  logf "Running treefmt"
  (cd "$root_repo" && treefmt) | tee -a "$log" || true
else
  logf "treefmt.toml not found; skipping treefmt"
fi

logf "Nix maintenance completed"

