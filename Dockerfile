FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# --- Base packages ---
RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    vim \
    nano \
    tmux \
    htop \
    unzip \
    jq \
    gnupg \
    emacs \
    ripgrep \
    fd-find \
    && rm -rf /var/lib/apt/lists/*

# --- Node.js (required for Claude Code) ---
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# --- Claude Code CLI ---
RUN npm install -g @anthropic-ai/claude-code

# --- Create non-root dev user ---
# Ubuntu base images already ship a user/group at uid/gid 1000 (the "ubuntu"
# user), so remove it first to avoid collisions, then create "dev" cleanly.
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

RUN if getent passwd $USER_UID >/dev/null; then \
        userdel -r "$(getent passwd $USER_UID | cut -d: -f1)" 2>/dev/null || true; \
    fi \
    && if getent group $USER_GID >/dev/null; then \
        groupdel "$(getent group $USER_GID | cut -d: -f1)" 2>/dev/null || true; \
    fi \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# --- Docker CLI ---
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y \
        docker-ce-cli \
        docker-buildx-plugin \
        docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 999 docker 2>/dev/null || true \
    && usermod -aG docker $USERNAME

# --- Doom Emacs ---
USER $USERNAME
RUN git clone --depth 1 https://github.com/doomemacs/doomemacs /home/$USERNAME/.config/emacs \
    && /home/$USERNAME/.config/emacs/bin/doom install --no-fonts -y
USER root

# --- SSH setup ---
RUN mkdir -p /var/run/sshd \
    && mkdir -p /home/$USERNAME/.ssh \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh \
    && chmod 700 /home/$USERNAME/.ssh

# Allow password auth off, pubkey auth on, keep container-friendly settings
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && echo "AllowUsers $USERNAME" >> /etc/ssh/sshd_config

# Entrypoint script handles authorized_keys + git ssh key copy-in at runtime
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
