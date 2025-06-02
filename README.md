# stack


The Docker stack configuration for [vibetype.app](https://vibetype.app/).

This project is deployed in accordance to the [DargStack template](https://github.com/dargstack/dargstack_template/) to make deployment a breeze. It is closely related to [Vibetype's source code](https://github.com/maevsi/vibetype/).

## Table of Contents


 1. [secrets](#secrets)
    
 2. [services](#services)
    
 3. [volumes](#volumes)
    

## secrets


 - ### `grafana_admin_email`
    
    The observation dashboard's admin email.
    
 - ### `grafana_admin_password`
    
    The observation dashboard's admin password.
    
 - ### `grafana_admin_user`
    
    The observation dashboard's admin user.
    
 - ### `grafana_discord_webhook`
    
    The observation dashboard's contact point for Discord.
    
 - ### `jobber_aliases`
    
    The job scheduler's SMTP client mail alias.
    
 - ### `jobber_aws-bucket`
    
    The job scheduler's AWS bucket name.
    
 - ### `jobber_aws-configuration`
    
    The job scheduler's AWS configuration.
    
 - ### `jobber_aws-credentials`
    
    The job scheduler's AWS credentials.
    
 - ### `jobber_msmtprc`
    
    The job scheduler's SMTP client configuration.
    
 - ### `portainer_admin-password`
    
    The container manager's admin password.
    
 - ### `postgraphile_connection`
    
    The GraphQL API's database URI.
    
 - ### `postgraphile_jwt-secret`
    
    The GraphQL API's JWT secret.
    
 - ### `postgraphile_owner-connection`
    
    The GraphQL API's database owner URI.
    
 - ### `postgres-backup_db` ![production](https://img.shields.io/badge/-production-informational.svg?style=flat-square)
    
    The database's name.
    
 - ### `postgres_db`
    
    The database's name.
    
 - ### `postgres_password`
    
    The database's password.
    
 - ### `postgres_role_service_grafana_password`
    
    The password of the observation dashboard's database role.
    
 - ### `postgres_role_service_grafana_username`
    
    The username of the observation dashboard's database role.
    
 - ### `postgres_role_service_postgraphile_password`
    
    The password of the GraphQL API database wrapper's database role.
    
 - ### `postgres_role_service_postgraphile_username`
    
    The username of the GraphQL API database wrapper's database role.
    
 - ### `postgres_role_service_vibetype_password`
    
    The `tusd` database role's password.
    
 - ### `postgres_role_service_vibetype_username`
    
    The `tusd` database role's password.
    
 - ### `postgres_user`
    
    The database's default user.
    
 - ### `sqitch_target`
    
    The database change management application's database connection string.
    
 - ### `traefik_cf-dns-api-token` ![production](https://img.shields.io/badge/-production-informational.svg?style=flat-square)
    
    The DNS provider's DNS API token.
    
 - ### `traefik_cf-zone-api-token` ![production](https://img.shields.io/badge/-production-informational.svg?style=flat-square)
    
    The DNS provider's zone API token.
    
 - ### `tusd_aws`
    
    The upload service's s3 credentials file.
    
 - ### `vibetype_api-notification-secret`
    
    The notification endpoint's secret.
    
 - ### `vibetype_aws-credentials`
    
    The cloud computing provider's user credentials.
    
 - ### `vibetype_firebase-service-account-credentials`
    
    The notification provider's service account credentials.
    
 - ### `vibetype_monday`
    
    The project management software's configuration.
    
 - ### `vibetype_openai-api-key`
    
    The AI provider's API key.
    
 - ### `vibetype_turnstile-key`
    
    The captcha provider's application key.
    

## services


 - ### `adminer`
    
    You can access the database's frontend at [adminer.localhost](https://adminer.localhost/).
    This information is required for login:
    
    |          |                     |
    | -------- | ------------------- |
    | System   | PostgreSQL          |
    | Server   | postgres            |
    | Username | [postgres_user]     |
    | Password | [postgres_password] |
    | Database | [postgres_db]       |
    
    Values in square brackets are [Docker secrets](https://docs.docker.com/engine/swarm/secrets/).
    
 - ### `cloudflared` ![production](https://img.shields.io/badge/-production-informational.svg?style=flat-square)
    
    You can configure the secure tunnel at [dash.cloudflare.com](https://dash.cloudflare.com/).
    
 - ### `debezium`
    
    You can see how changes in the database end up in the event stream using `redpanda-console`.
    
 - ### `debezium-postgres-connector`
    
    You can check the database connector's setup logs using `portainer`.
    
 - ### `geoip`
    
    You cannot access the ip geolocator via a web interface.
    
 - ### `grafana`
    
    You can access the observation dashboard at [grafana.localhost](https://grafana.localhost/).
    
 - ### `jobber`
    
    You cannot access the jobber via a web interface.
    
 - ### `minio` ![development](https://img.shields.io/badge/-development-informational.svg?style=flat-square)
    
    You can access the s3 console at [minio.localhost](https://minio.localhost/).
    You can access the s3 api service at [s3.localhost](https://s3.localhost/) if you want to access via cli from outside the stack.
    
 - ### `portainer`
    
    You can access the container manager's frontend at [portainer.localhost](https://portainer.localhost/).
    
 - ### `portainer-agent`
    
    You cannot access the container manager's agent directly.
    
 - ### `postgraphile`
    
    You can access the GraphQL API for the PostgreSQL database at [postgraphile.localhost](https://postgraphile.localhost/).
    
 - ### `postgres`
    
    You can access the database via `adminer`.
    
 - ### `postgres_backup` ![production](https://img.shields.io/badge/-production-informational.svg?style=flat-square)
    
    You cannot access the database backup directly.
    
 - ### `prometheus`
    
    You can access the metrics monitoring at [prometheus.localhost](https://prometheus.localhost/).
    
 - ### `reccoom`
    
    You cannot access the recommendation service directly.
    
 - ### `redpanda`
    
    You can access the event streaming platform's ui as described under `redpanda-console`.
    
 - ### `redpanda-console`
    
    You can access the event streaming platform's ui at [redpanda.localhost](https://redpanda.localhost/).
    
 - ### `sqitch`
    
    You cannot access the database migrations directly.
    
 - ### `traefik`
    
    You can access the reverse proxy's dashboard at [traefik.localhost](https://traefik.localhost/).
    
 - ### `traefik_certs-dumper` ![production](https://img.shields.io/badge/-production-informational.svg?style=flat-square)
    
    You cannot access the reverse proxy's certificate helper directly.
    
 - ### `tusd`
    
    You can access the upload service at [tusd.localhost](https://tusd.localhost/).
    
 - ### `vibetype`
    
    You can access the main project's frontend at [localhost](https://localhost/).
    

## volumes


 - ### `acme_data` ![production](https://img.shields.io/badge/-production-informational.svg?style=flat-square)
    
    The reverse proxy's certificate data.
    
 - ### `debezium_kafka_configuration`
    
    The change data capture's configuration.
    
 - ### `debezium_kafka_data`
    
    The change data capture's data.
    
 - ### `debezium_kafka_logs`
    
    The change data capture's logs.
    
 - ### `grafana_data`
    
    The observation dashboard's data.
    
 - ### `minio_data`
    
    The s3 server's data.
    
 - ### `portainer_data`
    
    The container manager's data.
    
 - ### `postgres_data`
    
    The database's data.
    
 - ### `prometheus_data`
    
    The metrics monitoring's data.
    
 - ### `redpanda_data`
    
    The message queue's data.
    

