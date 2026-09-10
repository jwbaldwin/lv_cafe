# Cafe

An ambient video cafe built with Phoenix LiveView.

## Requirements

- Erlang/OTP 29.0.3
- Elixir 1.20.2
- PostgreSQL 18.1

The exact local versions are recorded in `.tool-versions`. If PostgreSQL is not installed locally, start it with `docker compose up -d postgres`.

## Setup

1. Run `mix setup`.
2. Start the endpoint with `mix phx.server` or `iex -S mix phx.server`.
3. Visit [localhost:4000](http://localhost:4000).

## Checks

Run the same validation used by CI with `mix precommit`. Build production assets with `MIX_ENV=prod mix assets.deploy`.

Pushes to `main` deploy to Hetzner through Kamal after formatting, compilation, tests, and the production asset build pass. PostgreSQL runs on PlanetScale; application connections use PgBouncer.

See [hosting and operations](docs/hosting.md) and the [guide for deploying another app](docs/deploy-another-app.md).
