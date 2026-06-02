#!/usr/bin/env nu

# Create Podman secrets from podman.secret.toml.
# Run from the project root: pixi run create-secrets
#
# Use --force to overwrite secrets that already exist.

def main [--force (-f)] {
    if not ("podman.secret.toml" | path exists) {
        error make { msg: "podman.secret.toml not found — decrypt with: git-crypt unlock" }
    }

    let secrets = (open podman.secret.toml)

    for name in ($secrets | columns) {
        let entry = ($secrets | get $name)
        let value = ($entry.value | str trim)

        if ($value | is-empty) {
            print $"  SKIP  ($name) — value is empty"
            continue
        }

        let exists = ((do { ^podman secret inspect $name } | complete).exit_code == 0)

        if $exists and not $force {
            print $"  EXISTS ($name) \(skipping, use --force to overwrite)"
            continue
        }

        if $exists {
            do { ^podman secret rm $name } | complete | ignore
        }

        $value | ^podman secret create $name -
        print $"  OK    ($name)"
    }
}
