# Cafe Project Guide

## Common Commands
- Setup: `mix setup` (installs deps, creates DB, runs migrations, seeds DB, assets)
- Run server: `mix phx.server` or `iex -S mix phx.server`
- Format code: `mix format`
- Run all tests: `mix test`
- Run single test: `mix test path/to/test_file.exs:line_number`
- Reset database: `mix ecto.reset`
- Asset commands: `mix assets.setup`, `mix assets.build`, `mix assets.deploy`

## Code Style Guidelines
- **Naming**: PascalCase for modules, snake_case for functions/variables
- **Modules**: Context-based design with Cafe.* for business logic, CafeWeb.* for web layer
- **LiveView**: Component-based design with clear separation of concerns
- **Imports**: Group by type (Phoenix, Ecto, custom), avoid wildcard imports
- **Formatting**: Follows Phoenix conventions, see .formatter.exs
- **Error handling**: Use `with` pattern and explicit `{:ok, result}` or `{:error, reason}` tuples
- **Testing**: Each context module has corresponding test module with fixtures

Always run `mix format` before committing changes.