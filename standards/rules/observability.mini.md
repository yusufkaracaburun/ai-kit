---
name: observability
description: Structured logs, metrics, and traces — every request observable end-to-end
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# Observability

If you cannot answer "what is the system doing right now?" and "what did it
do during incident X?" from instrumentation alone, the system is unobservable.
Three pillars: logs, metrics, traces.

## Logs

- **Structured (JSON), not printf.** Every log line a key/value record.
- **Include correlation id** on every line in a request scope
  (`request_id`, `trace_id`). One id flows through the whole call chain.
- **Levels mean something.** `ERROR` = something a human must look at.
  `WARN` = degraded but functioning. `INFO` = state transitions worth
  knowing about. `DEBUG` = off in prod.
- **Never log secrets.** Tokens, passwords, PII headers, full request
  bodies of auth endpoints. Use field-level redaction.
- **Don't log inside hot loops** without rate-limiting.

## Metrics

- **RED for services** — Rate, Errors, Duration per endpoint.
- **USE for resources** — Utilization, Saturation, Errors per pool/queue.
- **Histograms over averages.** Average latency hides the long tail; p95/p99
  is what users feel.
- **Cardinality discipline.** No user_id or request_id as a label —
  cardinality explodes the time-series DB.

## Traces

- **Instrument boundaries** — HTTP server, HTTP client, DB calls, queue
  publish/consume. Use OpenTelemetry where possible.
- **Span names describe the operation**, not the URL
  (`db.query.user_lookup`, not `/api/v1/users/abc-123`).
- **Propagate context** across async boundaries (jobs, events, threads).

## Hard rules

- A new endpoint without a metric + log is incomplete.
- An incident postmortem must identify which signal could have caught the
  issue earlier — and add it if missing.
- Dashboards are versioned in-repo (Grafana JSON, etc.), not click-built.

## See also

- [`error-handling.mini.md`](./error-handling.mini.md) — when to log vs throw.
