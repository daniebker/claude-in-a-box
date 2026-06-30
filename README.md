# claude-code-box

A self-contained Linux dev box you can SSH into, with Claude Code pre-installed
and your GitHub SSH keys wired up so you can clone private repos.

## 1. Set up your keys

```bash
mkdir -p keys/github-keys

# Public key used to log INTO the container (your laptop's public key)
cp ~/.ssh/id_ed25519.pub keys/authorized_keys

# Key pair used so the container can SSH OUT to GitHub
cp ~/.ssh/id_ed25519 keys/github-keys/
cp ~/.ssh/id_ed25519.pub keys/github-keys/
```

You can list multiple lines in `keys/authorized_keys` if more than one machine
should be able to log in. The `github-keys` folder just needs a valid SSH
key pair that's registered with your GitHub account.

> Keys are mounted read-only into the container and copied into the `dev`
> user's `~/.ssh` at startup with correct permissions. They never get baked
> into the image itself.

## 2. Build and start

```bash
docker compose up -d --build
```

## 3. SSH in

```bash
ssh -p 2222 dev@localhost
```

## 4. Clone a repo and use Claude Code

```bash
git clone git@github.com:yourorg/yourrepo.git
cd yourrepo
claude
```

`claude` is the Claude Code CLI — run `claude auth login` the first time to
authenticate (or set `ANTHROPIC_API_KEY` as an environment variable, see
below).

## Notes

- The `dev` user's home directory is persisted in a named Docker volume
  (`dev-home`), so cloned repos and shell history survive container restarts.
- Password authentication is disabled; only key-based SSH login works.
- To pass an API key in automatically instead of running `claude auth login`,
  add this to the `claude-code-box` service in `docker-compose.yml`:

  ```yaml
  environment:
    - ANTHROPIC_API_KEY=sk-ant-...
  ```

  Or better, use an `.env` file and reference it with `env_file:`.
- To stop: `docker compose down` (the volume persists). To wipe everything
  including the home directory: `docker compose down -v`.
