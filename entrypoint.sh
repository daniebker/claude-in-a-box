#!/bin/bash
set -e

USERNAME="dev"
HOME_DIR="/home/$USERNAME"

# Ensure home dir / .ssh exist even if a previously-created empty named
# volume is mounted over $HOME_DIR (Docker only auto-populates a named
# volume from the image on its very first use).
mkdir -p "$HOME_DIR/.ssh"
chown "$USERNAME:$USERNAME" "$HOME_DIR" "$HOME_DIR/.ssh"
chmod 700 "$HOME_DIR/.ssh"

# --- Inbound access: let you SSH INTO the container ---
# Expects your public key mounted at /tmp/keys/authorized_keys (read-only)
if [ -f /tmp/keys/authorized_keys ]; then
    cp /tmp/keys/authorized_keys "$HOME_DIR/.ssh/authorized_keys"
    chown "$USERNAME:$USERNAME" "$HOME_DIR/.ssh/authorized_keys"
    chmod 600 "$HOME_DIR/.ssh/authorized_keys"
    echo "[entrypoint] Installed authorized_keys for inbound SSH."
else
    echo "[entrypoint] WARNING: no /tmp/keys/authorized_keys found, inbound SSH login will not work."
fi

# --- Outbound access: let the container SSH OUT to GitHub ---
# Expects your private key(s) mounted (read-only) at /tmp/github-keys/
if [ -d /tmp/github-keys ] && [ "$(ls -A /tmp/github-keys 2>/dev/null)" ]; then
    cp -r /tmp/github-keys/. "$HOME_DIR/.ssh/"
    chown -R "$USERNAME:$USERNAME" "$HOME_DIR/.ssh"
    find "$HOME_DIR/.ssh" -type f -name "id_*" ! -name "*.pub" -exec chmod 600 {} \;
    find "$HOME_DIR/.ssh" -type f -name "*.pub" -exec chmod 644 {} \;

    # Pre-trust github.com so first clone doesn't prompt
    sudo -u "$USERNAME" ssh-keyscan -H github.com >> "$HOME_DIR/.ssh/known_hosts" 2>/dev/null || true
    chown "$USERNAME:$USERNAME" "$HOME_DIR/.ssh/known_hosts"

    echo "[entrypoint] Installed GitHub SSH key(s) for outbound git access."
else
    echo "[entrypoint] No /tmp/github-keys mounted, skipping GitHub key setup."
fi

chmod 700 "$HOME_DIR/.ssh"

# --- Docker socket: match the in-container "docker" group to the socket's GID ---
# The host's docker GID varies (and may collide with an existing group in the
# image), so it can't be fixed at build time.
if [ -S /var/run/docker.sock ]; then
    SOCK_GID="$(stat -c '%g' /var/run/docker.sock)"
    if [ "$SOCK_GID" != "0" ]; then
        if getent group "$SOCK_GID" >/dev/null; then
            usermod -aG "$(getent group "$SOCK_GID" | cut -d: -f1)" "$USERNAME"
        else
            groupmod -g "$SOCK_GID" docker
        fi
    fi
    echo "[entrypoint] Docker socket detected (gid $SOCK_GID); $USERNAME can use it."
fi

# Generate host keys if missing (first run)
ssh-keygen -A

eval "$(ssh-agent -s)"
exec /usr/sbin/sshd -D -e
