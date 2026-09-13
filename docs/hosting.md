# Vibes hosting

## Deployment

Vibes runs as a Docker container on the existing Ubuntu 24.04 Hetzner server, managed by Kamal 2.12.0. Kamal proxy serves `PHX_HOST` over HTTPS. GitHub Actions builds amd64 images in GitHub Container Registry and deploys main only after checks pass. Gemfile.lock fixes the deployment-tool versions; Dependabot proposes upgrades.

The Kamal service and image are `vibes` and `ghcr.io/jwbaldwin/vibes`. The internal Elixir release remains `cafe`. Port 4000 is reachable inside the Docker network, with no published app port. Kamal proxy routes each domain to its own app, allowing other Kamal services on this server without allocating separate host ports.

Database: PlanetScale `weirdbit/vibes`, Postgres 18, PS-5 single node in us-east-1, $5/month base price. Storage is capped at the included 10 GB. App traffic uses included PgBouncer on 6432 with a five-connection Ecto pool. Schema changes run from the exact release image in CI through the direct endpoint on 5432 with verified TLS.

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

Schema changes run before app deployment so the readiness check can query the new database. Keep future migrations compatible with the running app; a code rollback does not undo schema changes. Cafe.Release.migrate remains available for release-based operations, but the checked-in migration wrapper requires a direct database connection.

## Release-image migrations

The deploy job logs in to GHCR, pulls `ghcr.io/jwbaldwin/vibes:${GITHUB_SHA}`, and runs `/app/bin/migrate` from that image before invoking Kamal. The migration receives `DIRECT_DATABASE_URL` and `SECRET_KEY_BASE` through a mode-0600 temporary environment file on the GitHub runner. The file is removed and the runner logs out of GHCR when the step exits; Docker's `--rm` removes the one-off container. The direct URL is never put in a command argument or the Kamal configuration, and the runtime app continues to receive only the PgBouncer `DATABASE_URL`.

Non-pull-request workflows also run that exact image twice against a disposable Postgres service before production deployment: the first pass exercises a fresh schema and the second pass exercises an already migrated schema. That check uses test-only credentials and does not load the production environment.

For a fresh disposable database or a new installation, load the catalog only after migrations with `/app/bin/cafe eval Cafe.Release.seed`. Seeds are separate from schema migrations, are safe to rerun, and do not run as part of a production deploy against an existing catalog.

The migration step uses `set -euo pipefail`, so a failed migration prevents `kamal setup` or `kamal deploy` from running. Kamal then deploys the same `${GITHUB_SHA}` with `--skip-push --version`, preserving its normal deploy lock, proxy health check, and old-container drain behavior. A workflow dispatch from a non-main ref builds its candidate image but cannot run the production deploy job; production dispatches must target `main`.

The migration runs while the currently running web container may still serve requests. Migrations therefore follow an expand/contract contract: add new tables or columns first, keep the old `playlists` shape readable and writable (or dual-write it) until the replacement is healthy, and remove old names only in a later release. The stations consolidation is the deliberate exception: a populated legacy catalog refuses to migrate unless the workflow dispatch sets `stations_cutover=true`.

Run that one-time cutover from `main` with `stations_cutover=true`. The workflow asks Kamal to put only Vibes into maintenance, waits up to the configured 30-second drain timeout, and then stops only the Vibes web container. This closes existing application connections, including admin WebSockets, before the destructive rename; the shared kamal-proxy container and other apps remain up. If the migration fails, Ecto rolls back its transaction and the workflow starts the old container and resumes its Vibes route. If deployment or health checks fail after the schema change, Vibes stays unavailable and the workflow prints recovery instructions; roll the schema back with the exact release image or fix forward before restoring an older release that expects `playlists`.

`/healthz` checks a real database query without creating a browser session. It is public and outside the browser pipeline so deployment probes avoid session/CSRF work. Kamal keeps the old container until the replacement passes its health check. Shutdown and proxy draining use 30-second timeouts.

## Cutover

1. Configure the single vibes_app database role and GitHub production secrets
2. Install Docker on Hetzner and give the deploy user Docker access
3. Preserve Caddy's existing config, then stop/disable Caddy before starting Kamal proxy on 80/443
4. Build and migrate; verify the new app on the server before changing DNS
5. Configure origin TLS and update Cloudflare's existing Vibes record to Hetzner, preserving Full (strict) TLS and WebSocket support
6. Verify health, playback, LiveView reconnection, admin login, curation writes, and feedback
7. Verify a second deployment, proxy routing, and memory during overlapping containers
8. Retain the old host until cutover is verified, then remove only the retired app and database after authorization

No data export/import was needed. Existing migrations built the schema; a fresh database receives the bundled station catalog through the separate release seed command. Fly has now been retired; future code rollbacks use Kamal and the existing PlanetScale database.

## Changes from Annie's deployment

- Pin current Kamal 2.12.0 and its dependencies instead of installing an unbounded latest gem
- Use Kamal's stop_timeout setting instead of a raw Docker stop-timeout option
- Use the current checkout, SSH-agent, and Buildx action releases
- Give the deployment job explicit contents:read and packages:write permissions
- Disable SSH agent forwarding and require the pinned host key
- Share Kamal proxy by domain, using one Vibes hostname and no Annie-specific integrations
- Build on GitHub Actions, cache Docker layers in GHCR, and serialize production deployments
- Run the exact release image's schema changes over a direct Postgres connection before deployment; normal traffic uses PgBouncer
- Require `stations_cutover=true` for the one-time destructive catalog rename, drain and stop only Vibes before it runs, and keep the shared proxy available

## Credential records

1Password Private: `Vibes Production` and `Vibes GitHub Actions SSH`. The former admin login and production secure note are consolidated into the `Vibes Production` login item; the duplicate secure note is archived. The login password is `ADMIN_PASSWORD`, and admin autofill remains available. The database uses one `vibes_app` role for runtime and migrations

See [Deploy another app](deploy-another-app.md) for the repeatable procedure and migration-specific lessons

## Migration record — September 9, 2026

- Created the PlanetScale database and one app role, granted schema creation, and applied all existing migrations through the direct endpoint
- Preserved the signing key and admin password; saved production credentials and the dedicated CI SSH key in 1Password and GitHub
- Installed Docker from its official Ubuntu repository. Confirmed the old Caddy configuration served only a maintenance response before stopping it; saved `/etc/caddy/Caddyfile.before-vibes-kamal`
- Verified the first release in a temporary container bound to server loopback. The homepage and database check returned 200, with about 171 MiB of idle container memory
- Bootstrapped stock Kamal and its shared proxy through the manual CI workflow. The proxy passed the new app's database readiness check and registered the Vibes HTTPS route
- The first bootstrap caught a missing `service=vibes` image label; the workflow now supplies it. Local proxy boot with a placeholder registry password also failed because Kamal always logs in; CI supplies its temporary GitHub token

Cloudflare's original Vibes records were A `66.241.125.15` and AAAA `2a09:8280:1::65:e11e:0`, both proxied with automatic TTL. The target addresses are A `5.161.214.38` and AAAA `2a01:4ff:f0:6671::1`. The zone uses automatic Full (strict) TLS; Always Use HTTPS was off. These original values are retained here as migration history; both address families now point to Hetzner

The obsolete `_acme-challenge.vibes` CNAME pointing to `vibes.jwbaldwin.com.xdk0nn.flydns.net` was removed after Fly retirement. Kamal does not need this DNS record

### Domain cutover

The migration PR was merged as `4d4a556d1c8be3c8d9b2189b5fff78128e21e101`. Main passed tests, built the image, and deployed the replacement successfully; the public check failed while DNS/HTTPS cutover was pending

Both Cloudflare address records were switched to Hetzner with proxy status preserved. IPv4 was briefly saved back to Fly during a proposed fallback, then restored to Hetzner after the decision to keep the new origin and wait

Public probes had triggered certificate requests on the staged proxy while the domain still pointed at Fly. Those failed authorizations exhausted Let's Encrypt's per-domain/account allowance and delayed certificate issuance. Future migrations should avoid registering an automatically issued TLS route on the publicly reachable proxy long before DNS is ready

### Completed verification and retirement — September 10 UTC

Origin certificate issuance recovered with Cloudflare proxying still enabled and Full (strict) preserved. No DNS-only workaround, custom certificate, or TLS verification bypass was needed. The origin serves a Let’s Encrypt YE1 certificate for `vibes.jwbaldwin.com`, valid through December 9, 2026; Kamal manages renewal. Avoid premature certificate attempts while DNS still points elsewhere, and honor ACME retry windows instead of repeatedly probing a pending origin.

- Public and direct-origin HTTPS health checks returned 200; the public response passed through Cloudflare
- The normal main deployment rerun completed successfully, including migrations, Kamal replacement, and the public health check: [run 34430446202](https://github.com/jwbaldwin/lv_cafe/actions/runs/34430446202)
- Browser LiveView connected, station switching changed the video, and a feedback submission reached the database. Public HTTPS admin authentication passed
- A playlist update through the app role and verified-TLS PgBouncer connection succeeded inside a rolled-back transaction. The exact feedback test row was removed afterward
- Deleted Fly apps `vibes-cafe` and `vibes-cafe-db`, including their machines and database volume. Provider inventory confirms neither app remains; unrelated Fly applications remain intact
- Removed the obsolete Fly certificate DNS record and repository `FLY_API_TOKEN` secret. Removed `fly.toml` and corrected the README deployment instructions
- Consolidated credentials into two active 1Password items: `Vibes Production` (login and app credentials) and `Vibes GitHub Actions SSH` (native SSH key). The duplicate production secure note is archived

Cloudflare now has exactly two Vibes records: proxied A `5.161.214.38` and proxied AAAA `2a01:4ff:f0:6671::1`, both with automatic TTL. Fly is no longer a rollback target or hosting dependency
