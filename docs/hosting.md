# Vibes hosting

## Deployment

Vibes runs as a Docker container on the existing Ubuntu 24.04 Hetzner server, managed by Kamal 2.12.0. Kamal proxy serves `PHX_HOST` over HTTPS. GitHub Actions builds amd64 images in GitHub Container Registry and deploys main only after checks pass. Gemfile.lock fixes the deployment-tool versions; Dependabot proposes upgrades.

The Kamal service and image are `vibes` and `ghcr.io/jwbaldwin/vibes`. The internal Elixir release remains `cafe`. Port 4000 is reachable inside the Docker network, with no published app port. Kamal proxy routes each domain to its own app, allowing other Kamal services on this server without allocating separate host ports.

Database: PlanetScale `weirdbit/vibes`, Postgres 18, PS-5 single node in us-east-1, $5/month base price. Storage is capped at the included 10 GB. App traffic uses included PgBouncer on 6432 with a five-connection Ecto pool. Schema changes run from CI through the direct endpoint on 5432 with verified TLS.

## GitHub production environment

Variable: `PHX_HOST`

Secrets:

- `KAMAL_SERVER_IP`
- `KAMAL_SERVER_HOST_KEY`: independently verified OpenSSH known_hosts entry
- `KAMAL_DEPLOY_SSH_PRIVATE_KEY`: dedicated deployment private key
- `DATABASE_URL`: application role, PgBouncer endpoint
- `DIRECT_DATABASE_URL`: same application role, direct endpoint
- `SECRET_KEY_BASE`
- `ADMIN_PASSWORD`

GHCR uses the workflow's temporary GitHub token with packages:write permission. SSH agent forwarding is disabled. Host keys are checked against the pinned known_hosts entry. Actual secrets stay out of source control and terminal output; `.kamal/secrets` contains environment references only.

## Operations

Install the Gemfile with Bundler and run commands with `bundle exec`. Normal deploys come from main; the workflow also has a manual setup option for initial bootstrap.

- Deploy: `bundle exec kamal deploy`
- Status: `bundle exec kamal details`
- Logs: `bundle exec kamal app logs`
- Rollback: `bundle exec kamal rollback VERSION`

Schema changes run before app deployment so the readiness check can query the new database. Keep future migrations compatible with the running app; a code rollback does not undo schema changes. Cafe.Release.migrate remains available for release-based operations, but must use a direct database connection.

`/healthz` checks a real database query without creating a browser session. It is public and outside the browser pipeline so deployment probes avoid session/CSRF work. Kamal keeps the old container until the replacement passes its health check. Shutdown and proxy draining use 30-second timeouts.

## Cutover

1. Configure the single vibes_app database role and GitHub production secrets
2. Install Docker on Hetzner and give the deploy user Docker access
3. Preserve Caddy's existing config, then stop/disable Caddy before starting Kamal proxy on 80/443
4. Build and migrate; verify the new app on the server before changing DNS
5. Configure origin TLS and update Cloudflare's existing Vibes record to Hetzner, preserving Full (strict) TLS and WebSocket support
6. Verify health, playback, LiveView reconnection, admin login, curation writes, and feedback
7. Verify a second deployment, proxy routing, and memory during overlapping containers
8. Retain Fly for rollback until cutover is verified, then agree removal of only vibes-cafe and vibes-cafe-db

No data export/import is needed. Existing migrations build the schema and load the bundled playlist catalog. Rollback to Fly changes the Cloudflare origin back; data written after cutover will not exist in Fly's database.

## Changes from Annie's deployment

- Pin current Kamal 2.12.0 and its dependencies instead of installing an unbounded latest gem
- Use Kamal's stop_timeout setting instead of a raw Docker stop-timeout option
- Use the current checkout, SSH-agent, and Buildx action releases
- Give the deployment job explicit contents:read and packages:write permissions
- Disable SSH agent forwarding and require the pinned host key
- Share Kamal proxy by domain, using one Vibes hostname and no Annie-specific integrations
- Build on GitHub Actions, cache Docker layers in GHCR, and serialize production deployments
- Run schema changes over a direct Postgres connection before deployment; normal traffic uses PgBouncer

## Credential records

1Password Private: `Vibes Production` and `Vibes GitHub Actions SSH`. The existing `Vibes admin` entry remains unchanged. The database uses one `vibes_app` role for runtime and migrations

See [Deploy another app](deploy-another-app.md) for the repeatable procedure and migration-specific lessons
