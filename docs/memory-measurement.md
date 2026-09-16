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

Measured on 2026-09-13 UTC on the existing 2-CPU, 1.875-GiB Hetzner host, using candidate `188bfdf2e69ebb1516b1e10b3d287ca897a06e57`. [The complete workflow passed](https://github.com/jwbaldwin/lv_cafe/actions/runs/34732924776); its artifact contains the raw samples, client reports, and cleanup verification. A durable [measurement summary](measurements/2026-09-13.json) is checked in here.

| Scenario | Peak candidate A | Peak candidate B | Minimum host available |
| --- | ---: | ---: | ---: |
| Fresh candidate idle | 145.0 MiB | — | 1,036 MiB |
| 25 listeners + edits | 151.8 MiB | — | 1,028 MiB |
| 100 listeners + edits | 239.8 MiB | — | 936 MiB |
| 100 listeners across two candidates + edits | 180.9 MiB | 172.7 MiB | 812 MiB |

All 25/100/100 listener joins, 2,400 playback/station actions, and four admin edits passed, including saved-data readback and player refresh assertions. There were no client failures. The disposable database peaked at 61.12 MiB and the load client at 36.88 MiB. Existing production stayed on the same running container and image; its baseline was about 168 MiB. Cleanup verified zero remaining task containers or networks.

These are short scenario tests, not a long soak or a maximum-throughput claim. Candidates were each capped at 0.5 CPU and 384 MiB; the extra database and load client also ran on the host. The measured headroom supports leaving production memory settings unchanged for the current small audience.

The Docker image decreased from 643,253,424 to 215,943,801 bytes uncompressed (66.4%). The deployed theme directory decreased from 209,044 KiB to 268 KiB of allocated disk space; the source-file comparison is documented in the theme image guide.
