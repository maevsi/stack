# Grafana configuration

Grafana used to have its datasources, alerting, and dashboards provisioned from files under `src/development/grafana/configurations/`.
That configuration is now stored the same way as anything else configured by hand in the UI: in Grafana's own Postgres-backed database (`GF_DATABASE_*` in `src/development/grafana/compose.yaml`), which already persists across restarts.
Hardcoding it as files added no reliability and made it harder to change on a live instance, so it has been removed in favor of the steps below.

Apply these once per environment, after Grafana's first login (`src/development/grafana/compose.yaml` provisions the admin credentials).

## Datasources

Add both under **Connections → Data sources → Add new data source**.

### PostgreSQL

| Setting | Value |
| --- | --- |
| Type | `PostgreSQL` |
| Host URL | `postgres:5432` |
| Database name | the value of the `postgres-db` secret |
| Username | the value of the `postgres-role-service-grafana-username` secret |
| Password | the value of the `postgres-role-service-grafana-password` secret |
| TLS/SSL mode | `disable` |
| Version | `15.0` |

### Prometheus

| Setting | Value |
| --- | --- |
| Type | `Prometheus` |
| Prometheus server URL | `http://prometheus:9090` |
| HTTP Method | `POST` |
| Manage alerts via Alerting UI | on |
| Cache level | `High` |
| Incremental querying, overlap window | `10m` |

## Alerting

### Discord contact point

Add under **Alerting → Contact points → Add contact point**.

| Setting | Value |
| --- | --- |
| Name | `Discord` |
| Integration | `Discord` |
| Webhook URL | the value of the `grafana-discord-webhook` secret |
| Use Discord's username | off |

Optionally customize the message template so alerts render with the annotations, labels, and links formatted for Discord:

````
{{ define "__alert_details" }}
{{ range . }}
⏰ **Started At:** {{ .StartsAt }}{{ if ne .EndsAt.String "0001-01-01 00:00:00 +0000 UTC" }}
🛑 **Ended At:** {{ .EndsAt }}{{ end }}

📝 **Annotations**
{{ range .Annotations.SortedPairs }}- `{{ .Name }}` = {{ .Value }}
{{ end }}🏷️ **Labels**
{{ range .Labels.SortedPairs }}- `{{ .Name }}` = {{ .Value }}
{{ end }}{{ if .GeneratorURL }}
🔗 [Alert rule]({{ .GeneratorURL }}){{ end }}{{ if .DashboardURL }}
📊 [Dashboard]({{ .DashboardURL }}){{ end }}{{ if .PanelURL }}
📈 [Panel]({{ .PanelURL }}){{ end }}{{ if .SilenceURL }}
🔕 [Silence this alert]({{ .SilenceURL }}){{ end }}{{ end }}{{ end }}{{ define "default.message_custom" }}{{ if .Alerts.Firing }}## 🚨 **Firing Alerts**
{{ template "__alert_details" .Alerts.Firing }}{{ end }}{{ if .Alerts.Resolved }}## ✅ **Resolved Alerts**
{{ template "__alert_details" .Alerts.Resolved }}{{ end }}{{ end }}{{ template "default.message_custom" . }}
````

### Alert rule: notifications pending

Add under **Alerting → Alert rules → New alert rule**, in the `Infrastructure` folder.

- **Query (A)**, on the PostgreSQL datasource, code mode: `SELECT COUNT(1) FROM vibetype_private.notification WHERE is_acknowledged IS NULL OR is_acknowledged IS FALSE`
- **Reduce (B)**: last of A
- **Threshold (C)**: B is above 0, this is the alert condition
- **Evaluation**: every `10s`, for `1m`, group `Critical`, repeat every 7 days
- **No data / error state**: `NoData` / `Error`
- **Summary annotation**: "There are notifications which are not sent out, or at least not marked as acknowledged."
- **Contact point**: `Discord`

## Dashboards

Add under **Dashboards → New → Import**.

The following were provisioned from public community dashboards and can be reimported straight from grafana.com, entering the dashboard ID directly in the import screen:

| Dashboard | grafana.com ID |
| --- | --- |
| cAdvisor | `19792` |
| Node Exporter Full | `1860` |

The `Redpanda Ops Dashboard`, `Grafana metrics`, and `Prometheus 2.0 Stats` dashboards were also provisioned from community sources, but without a recorded grafana.com ID.
Search grafana.com's dashboard library by name, or recover the exact JSON that was previously provisioned from this repository's git history (`git log --diff-filter=D -- 'src/development/grafana/configurations/dashboards/**'`) and import it via **Upload dashboard JSON file**.

Two dashboards were specific to this project rather than imported from the community, both querying the PostgreSQL datasource. Recreate their panels as needed:

**KPIs** (folder `Management`):

| Panel | Type | Query |
| --- | --- | --- |
| Monthly active users | Stat | `SELECT COUNT(DISTINCT id) FROM vibetype_private.account WHERE last_activity >= NOW() - INTERVAL '30 days'` |
| Last user activity | Bar chart | `SELECT DATE_TRUNC('month', last_activity) AS month, COUNT(*) AS "Active user count" FROM vibetype_private.account GROUP BY DATE_TRUNC('month', last_activity) ORDER BY month` |
| User count | Time series | `SELECT created_at as time, row_number() OVER (ORDER BY created_at) FROM vibetype_private.account` |
| Accounts | Stat | `SELECT COUNT(*) FROM vibetype_private.account` |

**Operations** (folder `Infrastructure`):

| Panel | Type | Query |
| --- | --- | --- |
| Notifications pending | Stat | `SELECT COUNT(1) FROM vibetype_private.notification WHERE is_acknowledged IS FALSE` |

The full JSON for both, including panel layout and styling, is likewise recoverable from git history at the same path as above.
