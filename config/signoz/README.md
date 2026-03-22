\# InfraGuardian360 — APM Stack (Phase 4)



SigNoz + ClickHouse — full APM, distributed tracing, service maps.



\## What this replaces

\- New Relic APM — £25+/user/month

\- Dynatrace — £21+/host/month

\- Datadog APM — included in £18-23/host/month



\## What you get

\- Service dependency maps (auto-generated)

\- Per-request latency percentiles (P50, P90, P99)

\- Error rate tracking per service

\- DB slow query detection

\- JVM/Go/.NET runtime metrics

\- Kubernetes pod metrics

\- Distributed trace waterfall views



\## Deploy

```bash

docker compose -f docker/docker-compose.apm.yml up -d

```



\## Access

\- SigNoz UI:  https://apm.your-domain.com

\- Jaeger UI:  https://traces.your-domain.com



\## Instrument your applications



\### Auto-instrumentation (zero code changes) via Beyla eBPF

Already included in Phase 3 monitoring stack.



\### Manual SDK instrumentation



Java:

```bash

java -javaagent:opentelemetry-javaagent.jar \\

&#x20; -DOTEL\_EXPORTER\_OTLP\_ENDPOINT=http://your-server:4317 \\

&#x20; -DOTEL\_SERVICE\_NAME=your-service-name \\

&#x20; -jar your-app.jar

```



Python:

```bash

pip install opentelemetry-distro opentelemetry-exporter-otlp

opentelemetry-bootstrap -a install

OTEL\_EXPORTER\_OTLP\_ENDPOINT=http://your-server:4317 \\

OTEL\_SERVICE\_NAME=your-service \\

opentelemetry-instrument python your-app.py

```



Node.js:

```bash

npm install @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node

OTEL\_EXPORTER\_OTLP\_ENDPOINT=http://your-server:4317 \\

OTEL\_SERVICE\_NAME=your-service \\

node --require @opentelemetry/auto-instrumentations-node/register app.js

```



.NET:

```bash

dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol

\# Configure in Program.cs — see docs/quickstart.md

```



\## ClickHouse password setup

Generate SHA256 of your password for users.xml:

```bash

echo -n "your\_password" | sha256sum | cut -d' ' -f1

```

Replace REPLACE\_WITH\_SHA256\_OF\_YOUR\_CLICKHOUSE\_PASSWORD in config/clickhouse/users.xml

