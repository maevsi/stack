# Elasticsearch certificate

The helpdesk talks to the search engine over HTTPS, and the certificate securing that connection is one the search engine issued to itself.
Nothing in this repository creates it and no certificate authority outside the stack vouches for it, so the helpdesk only accepts it because the authority's certificate was imported into the helpdesk by hand.
This document records where that certificate comes from, how it got into the helpdesk, and when it has to be replaced.

## Where the certificate comes from

On the first start of a node, the search engine runs its own security auto-configuration.
It generates a certificate authority and a server certificate, writes both into `config/certs/` inside the container, and enables HTTPS.
That directory is the `elasticsearch-configuration` volume, so the files survive redeployments.

Auto-configuration only ever runs once.
It skips itself as soon as `xpack.security.enabled` is present in `config/elasticsearch.yml`, which is exactly what its own first run writes there.
Everything below therefore describes a one-time setup.

The name the helpdesk connects to has to appear in the server certificate, otherwise verification fails on a hostname mismatch even when the authority is trusted.
Auto-configuration puts the container's host name into the certificate for this reason, which is why `src/development/elasticsearch/compose.yaml` sets `hostname` to `elasticsearch`.

The same setting could be made with `network.publish_host`, and doing so deadlocks the boot.
The swarm publishes a service's name in its service discovery only once the task passes its health check, so the search engine would wait for a name that only appears after it serves requests, and it dies with `UnknownHostException` instead.
Docker writes the `hostname` value into the container's own `/etc/hosts`, which is available from the first moment of the boot.

## How the helpdesk trusts it

Read the authority's certificate out of the running container:

```sh
docker exec "$(docker ps -q -f name=vibetype_elasticsearch)" \
  cat /usr/share/elasticsearch/config/certs/http_ca.crt
```

Then add it in the helpdesk under **Settings > Security > SSL Certificates**, either by uploading the file or by pasting its contents including the `-----BEGIN CERTIFICATE-----` delimiters.
The console equivalent is `rails r 'SSLCertificate.create!(certificate: STDIN.read)'`.

The helpdesk verifies the connection by default, controlled by its `es_ssl_verify` setting.
Turning that setting off instead of importing the certificate is possible but is not how this stack is set up.

## When it has to be replaced

Auto-configuration issues the authority for three years and the server certificate for two, and it renews neither.
The certificates currently in production were generated when the search engine first started, around February 2026:

| Certificate | Expires |
| --- | --- |
| Server certificate | around February 2028 |
| Certificate authority | around February 2029 |

Once the server certificate lapses, the helpdesk stops reaching the search engine and search results silently go stale.
Check the authority's dates with the command below, and subtract a year for the server certificate.
The image ships no `openssl`, so the certificate is piped out to the one on the node:

```sh
docker exec "$(docker ps -q -f name=vibetype_elasticsearch)" \
  cat /usr/share/elasticsearch/config/certs/http_ca.crt | openssl x509 -noout -dates
```

Replacing them means removing the `elasticsearch-configuration` volume so auto-configuration runs again, then repeating the import above with the newly generated authority.
The old certificate in the helpdesk should be deleted at that point, since it no longer matches anything.
