# Point Docker API clients (testcontainers, kind, act) at the rootless podman socket (systemctl --user enable --now podman.socket)
[[ $OSTYPE == linux* && -S $XDG_RUNTIME_DIR/podman/podman.sock ]] && export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
