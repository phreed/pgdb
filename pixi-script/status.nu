#!/usr/bin/env nu

# Show the systemd and podman state of every graph database quadlet service.
# Run from the project root: pixi run status
# Use --watch / -w to refresh continuously.

use mod.nu *

def get-status [] {
    glob "systemd/**/*.container"
    | each {|path|
        let db   = ($path | path dirname | path basename)
        let stem = ($path | path basename | str replace ".container" "")
        {
            database: $db
            service:  $"($stem).service"
            active:   (service-state $"($stem).service")
            health:   (container-health $"systemd-($stem)")
        }
    }
    | sort-by database
}

def main [
    --watch (-w)              # Repeatedly refresh the status display
    --interval (-i): int = 5  # Refresh interval in seconds (default: 5)
] {
    if $watch {
        try {
            loop {
                clear
                print $"pgdb status — (date now | format date '%Y-%m-%d %H:%M:%S') — every ($interval)s — Ctrl-C to stop\n"
                print (get-status | table)
                sleep ($interval * 1sec)
            }
        } catch {|err|
            if $err.msg == "Interrupted" {
                print "\nStopped."
            } else {
                error make {msg: $err.msg}
            }
        }
    } else {
        print (get-status | table)
    }
}
