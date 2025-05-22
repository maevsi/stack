#!/bin/sh
THIS=$(dirname "$(readlink -f "$0")")

create() {
    NAME="$1"
    shift
    CONTENT=$*

    path="$THIS/$NAME"
    certfile="$path.crt"
    keyfile="$path.key"

    if [ "$CONTENT" != "" ]; then
        # shellcheck disable=SC2086
        mkcert \
            -cert-file "$certfile" \
            -ecdsa \
            -key-file "$keyfile" $CONTENT
    fi

    cat "$(mkcert -CAROOT)/rootCA.pem" >> "$certfile"
}

echo "key crt" | tr ' ' '\n' | while read -r glob; do
    if test -n "$(find "$THIS" -maxdepth 1 -name "*.$glob" -print -quit)"; then
        rm "$THIS"/*."$glob"
    fi
done

create "root"
create "traefik" \
    `# adminer` "adminer.app.localhost" \
    `# grafana` "grafana.app.localhost" \
    `# minio` "minio.app.localhost" \
    `# portainer` "portainer.app.localhost" \
    `# postgraphile` "postgraphile.app.localhost" \
    `# prometheus` "prometheus.app.localhost" \
    `# reccoom` "reccoom.app.localhost" \
    `# redpanda` "redpanda.app.localhost" \
    `# traefik` "traefik.app.localhost" \
    `# tusd` "tusd.app.localhost" \
    `# vibetype` "app.localhost" "www.app.localhost" "127.0.0.1" "0.0.0.0" \
    `# zammad` "zammad.app.localhost"