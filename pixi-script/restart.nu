#!/usr/bin/env nu

# Restart all failed or transitional graph database quadlet services.
# Run from the project root: pixi run restart

use mod.nu *

def main [] {
    let failed = (get-failed)

    if ($failed | is-empty) {
        print "No failed services to restart."
        return
    }

    print $"Restarting ($failed | length) failed services..."

    for row in $failed {
        let service = $row.service
        print $"  Restarting ($service)..."
        do { ^systemctl --user restart $service } | complete | ignore
        print $"    → (service-state $service)"
    }
}
