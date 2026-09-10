# Deploy another Phoenix app on this server

This is the repeatable path used for Vibes: GitHub Actions → GHCR → Kamal → Hetzner, with PlanetScale Postgres and Cloudflare DNS

## Decisions to make first

Pick the service/image name, domain, repository, PlanetScale organization and database name. Decide whether deployment follows main automatically. Confirm the database budget and whether existing data needs moving

Vibes uses one app role for runtime and schema changes. Add a separate read-only role only when an MCP connection needs it. A separate CI SSH key is useful because it can be revoked without affecting personal access; it still inherits the deploy account's server permissions

## Inventory the source and target

Inspect the source deploy workflow, Dockerfile, runtime config, release startup scripts, secret names, database schema, uploads/volumes, workers, domains and health checks. Verify live hosting with the provider CLI rather than assuming checked-in config matches production

On Hetzner, inspect CPU, available memory, disk, listening ports, running containers and services. Check what owns ports 80/443. Leave unrelated services alone

For Vibes, Fly had two app machines with automatic suspend/start, a separate unmanaged Postgres database, and no application volume. Its release script forced Fly IPv6 and node naming. Those settings had to be removed

## PlanetScale

Use the official CLI, verify its download checksum, then authenticate with `pscale auth login`. Use `--format json` in automation and keep secret-bearing command output in restricted files or process memory

Create a Postgres single-node PS-5 database near the app, with the included PgBouncer. The base price was $5/month during this migration. Verify current pricing before creating another database. Cap storage at the included size if automatic growth charges are unwanted

Create an app role inheriting `pg_read_all_data,pg_write_all_data`. PlanetScale's display name is not the SQL role identifier: get the `username` from the creation response and use the part before the dot for grants

Grant that SQL role `USAGE, CREATE` on the app's schema. The role will own tables it creates and can apply later migrations to those tables. PlanetScale's `pscale sql --role admin` can apply this setup grant using ephemeral credentials; there is no need to keep a permanent setup/admin role

Use two connection URLs with the same username/password:

- `DATABASE_URL`: PgBouncer, port 6432, for the app
- `DIRECT_DATABASE_URL`: direct endpoint, port 5432, for migrations

Keep verified TLS explicit in Ecto runtime config. Do not assume libpq query parameters in a provider URL configure Postgrex equivalently. Vibes uses `ssl: [verify: :verify_peer, cacerts: :public_key.cacerts_get()]`

Run the existing migrations over the direct connection and verify the pooled connection separately. Starting from an empty database still needs schema creation and any initial catalog/seed data

## Secrets and access

Save the app credentials in 1Password Private and put only the values needed by CI in the repository's GitHub production environment. Keep a CI SSH key in its own SSH-key item. Never put actual secrets in source files, commit messages, command arguments, build arguments or logs

Vibes stores these GitHub production secrets:

- DATABASE_URL and DIRECT_DATABASE_URL
- SECRET_KEY_BASE and ADMIN_PASSWORD, preserved from Fly
- KAMAL_SERVER_IP and KAMAL_SERVER_HOST_KEY
- KAMAL_DEPLOY_SSH_PRIVATE_KEY

PHX_HOST is a production environment variable. Registry authentication uses the workflow's temporary GitHub token; grant the deploy/build jobs packages:write and contents:read

Pin the server's independently verified SSH host key in known_hosts. Require strict checking, disable agent forwarding, and authorize the CI public key for the deploy account. That account's Docker access is effectively administrative access

## App and Kamal configuration

Start from `config/deploy.yml`, `.kamal/secrets`, `Gemfile`, `Gemfile.lock`, and `.github/workflows/ci.yml` in this repo. Replace service/image names, repo labels, domain variable and runtime secret list

Vibes pins Kamal 2.12.0 and uses its `stop_timeout` setting. Follow current release notes before updating the version. Dependabot tracks Bundler, GitHub Actions, Docker and Mix dependencies

Kamal proxy routes multiple apps by hostname. Each app can listen on container port 4000 without publishing a host port. Bind Phoenix to all interfaces inside its container so the proxy can reach it; binding to container loopback will prevent that

Add `/healthz` outside the browser/session pipeline. It should verify the dependencies needed to serve the app, return 200 when ready, and avoid creating cookies. Vibes checks a database query

Build Linux amd64 images on GitHub Actions, then deploy the exact commit tag using `kamal deploy --skip-push --version COMMIT`. When building outside Kamal, include the image label `service=APP_NAME`; Kamal checks this before booting. Cache Docker layers in GHCR. Serialize production deployments and do not cancel one midway through a rollout

Keep migrations compatible with the currently running app. Run schema changes before deployment so readiness checks see the initialized schema. A code rollback does not reverse a schema change

## Server preparation

Install Docker from Docker's official stable Ubuntu apt repository and verify it works for the deploy account. Build images in CI so the small server only pulls and runs them

If Caddy already owns 80/443, inventory its sites before switching to Kamal proxy. Preserve its config and stop/disable it only when no active app depends on it. For additional Kamal apps, reuse the existing proxy instead of replacing it

Bootstrap through the manual GitHub workflow with `setup=true` so registry login uses the temporary CI token. Kamal performs registry login even for public images; a placeholder password will fail.

Run a preflight container with the final image and runtime environment, publishing a port only on 127.0.0.1. Verify health and the homepage over SSH before changing DNS

## Cutover and verification

Record the exact old DNS record, proxy status and TLS mode before editing. Change only the app's records; account for both A and AAAA records. Coordinate certificate issuance with DNS rather than weakening origin TLS. Cloudflare edits one record at a time: verify both target listeners first, then update A and AAAA consecutively. Preserve proxy status and verify the origin certificate afterward

For an existing domain still pointing at the old host, the bootstrap can successfully start Kamal but fail its final public health check. Verify the new route and app directly on the server, complete DNS cutover, then verify the public endpoint and run the normal deployment again

Verify HTTPS, the health endpoint, assets, WebSocket/LiveView connection, authentication and a representative database write. Watch container logs and measure memory while old and new containers overlap. Verify the next normal deployment uses the same workflow successfully

Keep the old host available until the new deployment is verified. For Vibes, no database contents needed transfer. For a populated app, design the data cutover separately; DNS rollback alone will not copy new writes back to the old database

After verification, remove temporary branch/build configuration, update the runbook with actual outcomes, and agree removal of the old app/database/resources so billing stops

## Why Kamal here

Xamal 0.4.2 was evaluated but not used. Its deploy path reloads one service Caddyfile rather than the root file that imports all services, making it unsuitable for this shared host without changes. We chose stock Kamal instead of maintaining a fork
