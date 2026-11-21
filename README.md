# ticketbench-infra

[![CI](https://github.com/ryczek02/ticketbench-infra/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ryczek02/ticketbench-infra/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/github/license/ryczek02/ticketbench-infra)](LICENSE)

Docker Compose stack, observability configuration, benchmark matrices and
Ansible playbooks for ticketbench. Part of
[ryczek02/ticketbench](https://github.com/ryczek02/ticketbench).

## Quick start

```
docker compose up -d --wait
tbench ping                                   # or: docker compose run --rm tbench ping
scripts/bench.sh config/smoke.yaml            # about a minute
scripts/bench.sh                              # full matrix, see below
```

`scripts/bench.sh` starts the stack, runs the matrix, writes the LaTeX
tables and pgfplots data, and builds the PDF when the report repository is
checked out next to this one. `DEV=1 scripts/bench.sh` builds the images
from `../services` and `../cli` instead of pulling them.

## Services

| Service | Port on the host | Notes |
|---|---|---|
| postgres | 5432 | PostgreSQL 17, `shared_buffers=1GB`, `max_connections=1200` |
| mariadb | 3306 | MariaDB 11.8, `innodb_buffer_pool_size=1G`, `max_connections=1200` |
| mongo | 27017 | MongoDB 8.0, single-node replica set `rs0`, WiredTiger cache 1 GB |
| valkey | 6379 | Valkey 8.1, no RDB and no AOF |
| store-postgres, store-mariadb, store-mongo, store-valkey | 7001 to 7004 | gRPC store services |
| bench-runner | 7070 | gRPC runner (7000 is taken by AirPlay on macOS) |
| otel-collector | 4317, 4318 | OTLP in, traces to Jaeger, metrics to Prometheus |
| jaeger | 16686 | trace UI |
| prometheus | 9090 | OTLP receiver enabled |
| grafana | 3000 | anonymous admin, dashboard "ticketbench" |

The three disk-based engines get the same 1 GB cache. Valkey keeps the whole
dataset in memory, so the 10 million ticket run needs about 4 GB more. Give
Docker Desktop at least 10 GB.

## Matrices

`config/matrix.yaml` is the run used in the report:

- 3 sizes: 500 thousand, 1 million and 10 million tickets;
- 4 engines;
- 27 scenarios, each with 1 warm-up and 5 measured repetitions, without and with secondary indexes;
- query plans for both index modes;
- contention with 1, 10, 100 and 1000 clients on 500 hot seats, every booking strategy, 3 rounds each;
- a tracing overhead pass on 500 thousand tickets.

`config/smoke.yaml` uses 20 thousand tickets and runs in about a minute. CI
uses it.

## Security experiment

`docker-compose.security.yml` turns on TLS for all four databases (own CA,
generated on first start by the `certs` container) and creates
least-privilege application users. It uses separate volumes, so the main
setup is not touched.

| Database | Application user | TLS |
|---|---|---|
| PostgreSQL | role `tb_app`: SELECT, INSERT, UPDATE, DELETE through default privileges | `ssl=on`, clients use `verify-full` |
| MariaDB | `tb_app`: SELECT, INSERT, UPDATE, DELETE on `ticketbench.*` | `--ssl-cert`, clients verify the CA |
| MongoDB | auth with a keyfile, `tb_app` with a custom role: find, insert, update, remove | `allowTLS` |
| Valkey | ACL user `tbapp`: model key prefixes only, no `@admin` or `@dangerous` | TLS port 6380 |

```
docker compose -f docker-compose.yml -f docker-compose.security.yml up -d --wait
tbench matrix --config config/security.yaml
```

The stores load data as the admin user and then run every scenario and the
contention test through the profiles `base`, `role`, `tls` and `tls_role`.

## Observability

Every result row carries the trace id of its segment. Open
`http://localhost:16686/trace/<trace_id>` to see the runner span, the store
span and the SQL, MongoDB or Valkey commands below it. Grafana shows p95
scenario time per engine, booking attempt latency and lost seats per second
from the metrics the stores export.

## Ansible

```
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml                              # Docker + stack on localhost
ansible-playbook bench.yml -e tb_matrix=matrix.yaml    # run, report, fetch results
ansible-playbook teardown.yml                          # docker compose down -v
ansible-playbook -i inventories/remote/hosts.yml site.yml bench.yml
```

The `docker` role installs Docker Engine and the compose plugin on Debian
and Ubuntu when they are missing. `ticketbench` copies this directory to
`~/ticketbench`, pulls the images and waits for every health check. `bench`
runs the matrix through the CLI container, generates the report files and
copies the results back to the controller.

## CI

The workflow validates both compose files, the script and the dashboard,
then runs ansible-lint. An end-to-end job provisions the GitHub runner with
the playbooks, runs the smoke matrix on the images from GHCR, checks the
result files and uploads them. The job also runs every Monday, so a broken
image shows up without a new commit.

## Authors

Łukasz Ryczko, Łukasz Pacholec. MIT license.
