#!/usr/bin/env nu

# Deploy quadlet symlinks with dotter and reload the systemd user daemon.
# Run from the project root: pixi run install
#
# This only installs symlinks and reloads systemd.
# To start the enabled services afterwards, run: pixi run start

def main [] {
    print "Deploying quadlet symlinks with dotter..."
    ^dotter deploy

    print "Reloading systemd user daemon..."
    ^systemctl --user daemon-reload

    print "Done — run 'pixi run start' to start enabled services."
}
