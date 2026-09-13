# Measuring listener memory

Run the **CI and deploy** workflow on a feature branch with `memory_benchmark=true`. The workflow tests and builds that exact commit, verifies its release migrations, then runs the isolated measurement on the existing Hetzner host. The production deploy job cannot run from a feature branch. Results are uploaded as `vibes-memory-COMMIT`.

The measurement uses the existing pinned SSH host key and deployment account. It creates a private Docker network, a disposable Postgres database with a temporary trusted TLS certificate, and bounded candidate containers. It publishes no ports and does not alter the live app, database, proxy, or DNS.

The phases run in order:

1. Record existing containers, Docker memory, and available host memory.
2. Migrate and seed the disposable database from the candidate release; start one candidate and sample idle memory.
3. Connect 25 listeners for 25 seconds, with next/previous, station changes, and an authenticated admin edit.
4. Repeat with 100 listeners.
5. Start a second candidate and repeat with 100 listeners split across both containers, while the existing production container remains running.
6. Save results and remove only the task's containers, network, temporary credentials, and certificates.

The Python client uses real Phoenix LiveView WebSocket sessions and asserts successful joins, admin edits, and player refreshes. It does not stream YouTube video: those bytes go directly between YouTube and listeners' browsers. Each candidate has its own PubSub process; overlap checks exercise admin saves and listeners on each container, not distributed PubSub. Normal deployments drain the retiring container and clients reconnect with a fresh catalog.

Every phase begins with the same disposable catalog. Container memory is sampled using Docker's normal reporting; host available memory is recorded separately. A low-headroom check stops the run. Containers have memory and CPU limits, a remote ten-minute timeout, and cleanup handlers. Production settings are not tuned by this measurement.

For a manual run, first configure the existing SSH agent and pinned known_hosts entry, then set `CANDIDATE_IMAGE`, `MEMORY_BENCHMARK_SERVER`, `KAMAL_REGISTRY_USERNAME`, and `KAMAL_REGISTRY_PASSWORD` and run `scripts/measure-memory.sh`. The image must be the exact commit built by CI. The default output directory is `artifacts/memory`; do not put credentials in command-line arguments or source files.

## Results

The measured candidate results will be recorded here after the isolated Hetzner run passes.
