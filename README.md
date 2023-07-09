# maevsi_stack


The Docker stack configuration for [maev.si](https://maev.si/).

This project is deployed in accordance to the [DargStack template](https://github.com/dargstack/dargstack_template/) to make deployment a breeze. It is closely related to [maevsi's source code](https://github.com/maevsi/maevsi/).

## Table of Contents


 1. [secrets](#secrets)
    
 2. [services](#services)
    
 3. [volumes](#volumes)
    

## secrets


 - ### `jobber_aliases`
    
    The job scheduler's SMTP client mail alias.
    
 - ### `jobber_aws-bucket`
    
    The job scheduler's AWS bucket name.
    
 - ### `jobber_aws-credentials`
    
    The job scheduler's AWS credentials.
    
 - ### `jobber_msmtprc`
    
    The job scheduler's SMTP client configuration.
    
 - ### `maevsi_sqitch-target`
    
    The database change management application's database connection string.
    
 - ### `pg-amqp-bridge_amqp-uri`
    
    The database-to-AMQP bridge's AMQP URI.
    
 - ### `pg-amqp-bridge_postgresql-uri`
    
    The database-to-AMQP bridge's database URI.
    
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
    
 - ### `postgres_role_maevsi-postgraphile_password`
    
    The `maevsi_postgraphile` database role's password.
    
 - ### `postgres_role_maevsi-stomper_password`
    
    The `stomper` database role's password.
    
 - ### `postgres_role_maevsi-tusd_password`
    
    The `tusd` database role's password.
    
 - ### `postgres_user`
    
    The database's default user.
    
 - ### `rabbitmq_definitions`
    
    The message queue's configuration.
    
 - ### `stomper_nodemailer-transporter`
    
    The email service's SMTP configuration.
    
 - ### `traefik_cf-dns-api-token` ![production](https://img.shields.io/badge/-production-informational.svg?style=flat-square)
    
    The DNS provider's DNS API token.
    
 - ### `traefik_cf-zone-api-token` ![production](https://img.shields.io/badge/-production-informational.svg?style=flat-square)
    
    The DNS provider's zone API token.
    
 - ### `tusd_aws`
    
    The upload service's s3 credentials file.
    

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
    
 - ### `jobber`
    
    You cannot access the jobber via a web interface.
    
 - ### `maevsi`
    
    You can access the main project's frontend at [localhost](https://localhost/).
    
 - ### `maevsi_beta` ![production](https://img.shields.io/badge/-production-informational.svg?style=flat-square)
    
    You can access the main project's beta version frontend at [beta.localhost](https://localhost/).
    
 - ### `minio`
    
    You can access the s3 console at [minio.localhost](https://minio.localhost/).
    You can access the s3 api service at [s3.localhost](https://s3.localhost/) if you want to access via cli from outside the stack.
    
 - ### `pg-amqp-bridge`
    
    You cannot access the database-to-AMQP bridge directly.
    
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
    
 - ### `rabbitmq`
    
    You can access the message queue at [rabbitmq.localhost](https://rabbitmq.localhost/).
    
 - ### `sqitch`
    
    You cannot access the database migrations directly.
    
 - ### `stomper`
    
    You cannot access the email service directly.
    
 - ### `traefik`
    
    You can access the reverse proxy's dashboard at [traefik.localhost](https://traefik.localhost/).
    
 - ### `traefik_certs-dumper` ![production](https://img.shields.io/badge/-production-informational.svg?style=flat-square)
    
    You cannot access the reverse proxy's certificate helper directly.
    
 - ### `tusd`
    
    You can access the upload service at [tusd.localhost](https://tusd.localhost/).
    

## volumes


 - ### `acme_data` ![production](https://img.shields.io/badge/-production-informational.svg?style=flat-square)
    
    The reverse proxy's certificate data.
    
 - ### `minio_data`
    
    The s3 server's data.
    
 - ### `portainer_data`
    
    The container manager's data.
    
 - ### `postgres_data`
    
    The database's data.
    
 - ### `rabbitmq_data`
    
    The message queue's data.
    

