#!/usr/bin/env nu

# Interactive troubleshooter for failed graph database quadlet services.
# Run from the project root: pixi run trouble
#
# Commands:
#   df          — display all failed / activating services
#   aa <id>     — activate a service by its id from the df list
#   sa          — show systemctl status (activated service, or all failed)
#   la          — show journalctl logs for the activated service
#   ha          — show podman health history for the activated service
#   q / qq      — quit

use mod.nu *

def do-df [failed] {
    if ($failed | is-empty) {
        print "No failed or activating services."
    } else {
        print ($failed | table)
    }
}

def do-sa [services: list<string>] {
    for service in $services {
        print $"\n── systemctl status ($service) ──"
        let out = (do { ^systemctl --user status --no-pager $service } | complete)
        print $out.stdout
    }
}

def do-la [service: string] {
    print $"\n── journalctl ($service) — last 50 lines ──"
    let out = (do { ^journalctl --user --no-pager -eu $service -n 50 } | complete)
    print $out.stdout
}

def do-ha [service: string] {
    let container = $"systemd-($service | str replace '.service' '')"
    print $"\n── podman health ($container) ──"
    let result = (do { ^podman inspect $container --format '{{json .State.Health}}' } | complete)
    if $result.exit_code == 0 {
        print ($result.stdout | str trim | from json | table)
    } else {
        print "  container not found or not running"
    }
}

def main [] {
    mut failed = (get-failed)
    mut active = ""

    do-df $failed
    print "\nCommands: df  aa <id>  sa  la  ha  q"

    loop {
        let prompt = if ($active | is-empty) {
            "pgdb> "
        } else {
            $"pgdb [($active)]> "
        }

        let line = (input $prompt | str trim)
        if ($line | is-empty) { continue }

        let parts = ($line | split row " " | where { |p| not ($p | is-empty) })
        let op = ($parts | first)
        let args = ($parts | skip 1)

        match $op {
            "df" => {
                $failed = (get-failed)
                do-df $failed
            }
            "aa" => {
                if ($args | is-empty) {
                    print "Usage: aa <id>"
                } else {
                    let idx = ($args | first | into int)
                    if $idx >= 0 and $idx < ($failed | length) {
                        $active = ($failed | get $idx | get service)
                        print $"Activated: ($active)"
                        # Warn immediately if required secrets are absent
                        let pkg = ($active | str replace ".service" "")
                        let missing = (missing-secrets $pkg)
                        if not ($missing | is-empty) {
                            print $"  WARNING: missing secrets — ($missing | str join ', ')"
                            print $"  → Set values in podman.secret.toml then run: pixi run create-secrets"
                        }
                    } else {
                        print $"Unknown id ($idx) — run df to refresh the list"
                    }
                }
            }
            "sa" => {
                if ($active | is-empty) {
                    do-sa ($failed | each { |r| $r.service })
                } else {
                    do-sa [$active]
                }
            }
            "la" => {
                if ($active | is-empty) {
                    print "No service activated — use aa <id> first"
                } else {
                    do-la $active
                }
            }
            "ha" => {
                if ($active | is-empty) {
                    print "No service activated — use aa <id> first"
                } else {
                    do-ha $active
                }
            }
            "q" | "qq" | "quit" => { break }
            _ => {
                print $"Unknown command: ($op)"
                print "Commands: df  aa <id>  sa  la  ha  q"
            }
        }
    }
}
