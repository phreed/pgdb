# Shared helpers for pgdb pixi scripts.
# Scripts import with: use mod.nu *

# Return the systemd active state string for a user service.
export def service-state [service: string]: nothing -> string {
    (do { ^systemctl --user is-active $service } | complete).stdout | str trim
}

# Return the podman container status string, or "not created" if absent.
export def container-health [name: string]: nothing -> string {
    let out = (do {
        ^podman ps --all --filter $"name=^($name)$" --format "{{.Status}}"
    } | complete).stdout | str trim
    if ($out | is-empty) { "not created" } else { $out }
}

# Return the list of packages enabled in .dotter/local.toml.
export def enabled-packages []: nothing -> list<string> {
    open .dotter/local.toml | get packages
}

# Return the systemd service names for all containers in a package directory.
export def package-services [pkg: string]: nothing -> list<string> {
    glob $"systemd/($pkg)/*.container"
    | each {|c| $"($c | path basename | str replace '.container' '').service" }
}

# Return names of secrets referenced by a package's container files that do not yet exist.
export def missing-secrets [pkg: string]: nothing -> list<string> {
    let existing = (
        do { ^podman secret ls --format "{{.Name}}" } | complete
    ).stdout | lines | str trim | where {|s| not ($s | is-empty) }

    glob $"systemd/($pkg)/*.container"
    | each {|f|
        open $f
        | lines
        | where {|l| $l | str starts-with "Secret="}
        | each {|l|
            # Secret=name,type=env,target=VAR  →  extract "name"
            ($l | str replace --regex "^Secret=" "") | split row "," | first
        }
    }
    | flatten
    | uniq
    | where {|s| not ($s in $existing) }
}

# Return records for all services currently in a failed or transitional state.
export def get-failed []: nothing -> table<service: string, state: string> {
    glob "systemd/**/*.container"
    | each {|path|
        let stem = ($path | path basename | str replace ".container" "")
        let service = $"($stem).service"
        { service: $service, state: (service-state $service) }
    }
    | where state in ["failed", "activating", "deactivating"]
    | sort-by state service
}
