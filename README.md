# ghr - GitHub Actions Runner in Docker

A Docker container for running GitHub Actions self-hosted runners with persistent configuration across restarts.

## Requirements

- Docker (Docker Desktop on Windows, or Docker Engine on Linux/macOS)
- Admin access to a GitHub repository or organization
- PowerShell, Bash, or similar shell

## Quick Start

### 1. Build the image

```sh
docker build -t github-runner:latest .
```

### 2. Create a persistent volume

```sh
docker volume create github-runner-data
```

### 3. Get a registration token

Registration tokens are valid for 1 hour. Generate one from:

`https://github.com/<owner>/<repo>/settings/actions/runners/new`

Copy the token from the configuration command (starts with `A...`).

### 4. Start the runner

```sh
docker run -d \
  --name github-runner \
  --restart unless-stopped \
  -e RUNNER_URL="https://github.com/<owner>/<repo>" \
  -e RUNNER_TOKEN="<your-token>" \
  -e RUNNER_NAME="docker-runner-01" \
  -e RUNNER_LABELS="docker,linux,x64" \
  -v github-runner-data:/home/runner/actions-runner \
  github-runner:latest
```

On PowerShell, replace `\` with backticks:

```powershell
docker run -d `
  --name github-runner `
  --restart unless-stopped `
  -e RUNNER_URL="https://github.com/<owner>/<repo>" `
  -e RUNNER_TOKEN="<your-token>" `
  -e RUNNER_NAME="docker-runner-01" `
  -e RUNNER_LABELS="docker,linux,x64" `
  -v github-runner-data:/home/runner/actions-runner `
  github-runner:latest
```

### 5. Verify

Check the logs:

```sh
docker logs -f github-runner
```

The runner should appear as "Idle" in your repository's runner settings.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `RUNNER_URL` | Yes | — | Repository or organization URL |
| `RUNNER_TOKEN` | Yes | — | Registration token from GitHub |
| `RUNNER_NAME` | No | hostname | Display name for the runner |
| `RUNNER_LABELS` | No | `docker,linux,x64` | Comma-separated labels |
| `RUNNER_WORKDIR` | No | `_work` | Working directory for jobs |
| `RUNNER_GROUP` | No | `Default` | Runner group (organizations only) |

## Persistence

The Docker volume stores runner configuration (`.runner`, `.credentials`) and the job workspace (`_work/`). Once configured, the runner reconnects automatically on restart without needing a new token.

```sh
docker stop github-runner
docker start github-runner   # No token required
```

## Usage in Workflows

Target your runner using the labels you configured:

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, docker]
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on self-hosted runner"
```

## Common Tasks

**View logs**
```sh
docker logs -f github-runner
docker logs --tail 100 github-runner
```

**Shell access**
```sh
docker exec -it github-runner bash
```

**Restart**
```sh
docker restart github-runner
```

**Update runner version**

Edit `RUNNER_VERSION` in the Dockerfile, rebuild the image, then recreate the container with a fresh token.

**Full reset**
```sh
docker stop github-runner && docker rm github-runner
docker volume rm github-runner-data
docker volume create github-runner-data
# Run step 4 again with a new token
```

**Unregister from GitHub**

Get a removal token from the runner settings page, then:

```sh
docker exec -it github-runner ./config.sh remove --token <removal-token>
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Container exits immediately | Missing `RUNNER_URL` or `RUNNER_TOKEN` | Check environment variables on first run |
| Token expired | Tokens valid for 1 hour only | Generate a new token |
| Runner offline in GitHub | Container not running | Run `docker ps` to check status |
| Permission denied | Volume ownership mismatch | Runner uses UID 1000 |

## Security Notes

- Never commit registration tokens to version control
- The runner executes as a non-root user (UID 1000)
- Consider using Docker secrets for token management in production
- Keep the runner version updated for security patches
