#!/usr/bin/env nu

# Start all services enabled in .dotter/local.toml.
# Run from the project root: pixi run start

use mod.nu *

def ensure-in-secrets-file [name: string] {
    let raw = (open podman.secret.toml --raw)
    if not ($raw | str contains $"[($name)]") {
        let stub = $"\n[($name)]\ndescription = \"Added automatically — set a value then run 'pixi run create-secrets'\"\nvalue = \"\"\n"
        $stub | save --append podman.secret.toml
        print $"  ADDED  ($name) placeholder to podman.secret.toml"
    }
}

def main [] {
    let packages = (enabled-packages)
    print $"Starting services for ($packages | length) enabled packages..."

    for pkg in $packages {
        let missing = (missing-secrets $pkg)
        if not ($missing | is-empty) {
            print $"  SKIP ($pkg) — missing secrets: ($missing | str join ', ')"
            for s in $missing {
                ensure-in-secrets-file $s
            }
            print $"  → Set values in podman.secret.toml then run: pixi run create-secrets"
            continue
        }

        for service in (package-services $pkg) {
            print $"  Starting ($service)..."
            do { ^systemctl --user start $service } | complete | ignore
            print $"    → (service-state $service)"
        }
    }
}
