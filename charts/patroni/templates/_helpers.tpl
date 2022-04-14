{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "patroni.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "patroni.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "patroni.hashedname" -}}
{{- printf "%s-%s" .Release.Name (printf "%s:%s" .Values.image.repository .Values.image.tag | sha256sum | trunc 8) -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "patroni.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the service account to use.
*/}}
{{- define "patroni.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "patroni.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "patroni.databases" -}}
{{ range $dbConfig := .Values.databases }}
{{- printf "%s:%s:%s" $dbConfig.name $dbConfig.user $dbConfig.pass }}
{{ end }}
{{- end -}}

{{- define "patroni.postgresql.tls.secret" -}}
{{ default (printf "%s-pg-tls" (include "patroni.hashedname" .)) (index .Values.tls "secretName") }}
{{- end -}}

{{- define "patroni.pgbouncer.tls.serverSecret" -}}
{{ default (printf "%s-pgb-server-tls" (include "patroni.fullname" .)) (index (default (dict) (index (default (dict) (index .Values.pgbouncer "tls")) "server")) "secretName") }}
{{- end -}}

{{- define "patroni.pgbouncer.tls.clientSecret" -}}
{{ default (printf "%s-pgb-client-tls" (include "patroni.fullname" .)) (index (default (dict) (index (default (dict) (index .Values.pgbouncer "tls")) "client")) "secretName") }}
{{- end -}}

{{/* unused, but may be of use in the future */}}
{{- define "patroni.spiloConfiguration" -}}
{{- $spiloConfig := .Values.spiloConfiguration -}}
{{- if .Capabilities.APIVersions.Has "cert-manager.io/v1" -}}
{{- if index (default (dict) (index .Values.tls "issuerRef")) "name" -}}
{{- $spiloConfig = mergeOverwrite $spiloConfig (dict "bootstrap" (dict "dcs" (dict "postgresql" (dict "parameters" (dict "ssl" "on" "ssl_ca_file" "/etc/pg-tls/ca.crt" "ssl_cert_file" "/etc/pg-tls/tls.crt" "ssl_key_file" "/etc/pg-tls/tls.key"))))) -}}
{{- end -}}
{{- end -}}
{{- if and (not (index (default (dict) (index .Values.tls "issuerRef")) "name")) (index .Values.tls "ca") (index .Values.tls "crt") (index .Values.tls "key") -}}
{{- $spiloConfig = mergeOverwrite $spiloConfig (dict "bootstrap" (dict "dcs" (dict "postgresql" (dict "parameters" (dict "ssl" "on" "ssl_ca_file" "/etc/pg-tls/ca.crt" "ssl_cert_file" "/etc/pg-tls/tls.crt" "ssl_key_file" "/etc/pg-tls/tls.key"))))) -}}
{{- end -}}
{{ toYaml $spiloConfig }}
{{- end -}}

{{- define "patroni.pgbouncer" -}}
{{- $pgbServerTls := default (dict) (index (default (dict) (index .Values.pgbouncer "tls")) "server") }}
{{- $pgbClientTls := default (dict) (index (default (dict) (index .Values.pgbouncer "tls")) "client") }}
[databases]
* = host={{ template "patroni.hashedname" . }}

[pgbouncer]
listen_addr = *
listen_port = 5432
auth_file = /etc/pgbouncer/userlist.txt
auth_type = md5
auth_user = pgbouncer
auth_query = SELECT uname, phash from public.user_lookup($1);
pool_mode = session
max_client_conn = 1000
default_pool_size = 200
ignore_startup_parameters = extra_float_digits
server_fast_close = 1

# Log settings
admin_users = {{ default (list .Values.pgbouncer.credentials.username) .Values.pgbouncer.admin_users | join "," }}
stats_users = {{ default (list .Values.pgbouncer.credentials.username) .Values.pgbouncer.stats_users | join "," }}

{{- if .Capabilities.APIVersions.Has "cert-manager.io/v1" }}
{{- if index (default (dict) (index $pgbServerTls "issuerRef")) "name" }}
server_tls_ca_file = /etc/pgb-tls/server/ca.crt
server_tls_key_file = /etc/pgb-tls/server/tls.key
server_tls_cert_file = /etc/pgb-tls/server/tls.crt
server_tls_sslmode = {{ default "prefer" (index $pgbServerTls "sslmode") }}
{{- end }}
{{- if index (default (dict) (index $pgbClientTls "issuerRef")) "name" }}
client_tls_ca_file = /etc/pgb-tls/client/ca.crt
client_tls_key_file = /etc/pgb-tls/client/tls.key
client_tls_cert_file = /etc/pgb-tls/client/tls.crt
client_tls_sslmode = {{ default "prefer" (index $pgbClientTls "sslmode") }}
{{- end }}
{{- end }}
{{- if and (not (index (default (dict) (index $pgbServerTls "issuerRef")) "name")) (index $pgbServerTls "ca") (index $pgbServerTls "crt") (index $pgbServerTls "key") }}
server_tls_ca_file = /etc/pgb-tls/server/ca.crt
server_tls_key_file = /etc/pgb-tls/server/tls.key
server_tls_cert_file = /etc/pgb-tls/server/tls.crt
server_tls_sslmode = {{ default "prefer" (index $pgbServerTls "sslmode") }}
{{- end }}
{{- if and (not (index (default (dict) (index $pgbClientTls "issuerRef")) "name")) (index $pgbClientTls "ca") (index $pgbClientTls "crt") (index $pgbClientTls "key") }}
client_tls_ca_file = /etc/pgb-tls/client/ca.crt
client_tls_key_file = /etc/pgb-tls/client/tls.key
client_tls_cert_file = /etc/pgb-tls/client/tls.crt
client_tls_sslmode = {{ default "prefer" (index $pgbClientTls "sslmode") }}
{{- end }}
{{- end -}}

{{/* originally borrowed from https://github.com/zalando/spilo/blob/1.6-p2/postgres-appliance/scripts/post_init.sh */}}
{{- define "patroni.post_init_script" -}}
#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

(echo "SET synchronous_commit = 'local';

DO \$\$
BEGIN
    PERFORM * FROM pg_catalog.pg_authid WHERE rolname = 'admin';
    IF FOUND THEN
        ALTER ROLE admin WITH CREATEDB NOLOGIN NOCREATEROLE NOSUPERUSER NOREPLICATION INHERIT;
    ELSE
        CREATE ROLE admin CREATEDB;
    END IF;
END;\$\$;

DO \$\$
BEGIN
    PERFORM * FROM pg_catalog.pg_authid WHERE rolname = '$1';
    IF FOUND THEN
        ALTER ROLE $1 WITH NOCREATEDB NOLOGIN NOCREATEROLE NOSUPERUSER NOREPLICATION INHERIT;
    ELSE
        CREATE ROLE $1;
    END IF;
END;\$\$;

DO \$\$
BEGIN
    PERFORM * FROM pg_catalog.pg_authid WHERE rolname = 'robot_zmon';
    IF FOUND THEN
        ALTER ROLE robot_zmon WITH NOCREATEDB NOLOGIN NOCREATEROLE NOSUPERUSER NOREPLICATION INHERIT;
    ELSE
        CREATE ROLE robot_zmon;
    END IF;
END;\$\$;

DO \$\$
BEGIN
    PERFORM * FROM pg_catalog.pg_authid WHERE rolname = '{{ .Values.pgbouncer.credentials.username }}';
    IF FOUND THEN
        ALTER ROLE {{ .Values.pgbouncer.credentials.username }} WITH INHERIT LOGIN ENCRYPTED PASSWORD '{{ .Values.pgbouncer.credentials.password }}';
    ELSE
        CREATE ROLE {{ .Values.pgbouncer.credentials.username }} LOGIN ENCRYPTED PASSWORD '{{ .Values.pgbouncer.credentials.password }}';
    END IF;
END;\$\$;

CREATE EXTENSION IF NOT EXISTS pg_auth_mon SCHEMA public;
ALTER EXTENSION pg_auth_mon UPDATE;
GRANT SELECT ON TABLE public.pg_auth_mon TO robot_zmon;

CREATE EXTENSION IF NOT EXISTS pg_cron SCHEMA public;
ALTER EXTENSION pg_cron UPDATE;

ALTER POLICY cron_job_policy ON cron.job USING (username = current_user OR
    (pg_has_role(current_user, 'admin', 'MEMBER')
    AND pg_has_role(username, 'admin', 'MEMBER')
    AND NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname = username AND rolsuper)
    ));
REVOKE SELECT ON cron.job FROM public;
GRANT SELECT ON cron.job TO admin;
GRANT UPDATE (database, nodename) ON cron.job TO admin;

CREATE OR REPLACE FUNCTION cron.schedule(p_schedule text, p_database text, p_command text)
RETURNS bigint
LANGUAGE plpgsql
AS \$function\$
DECLARE
    l_jobid bigint;
BEGIN
    IF NOT (SELECT rolcanlogin FROM pg_roles WHERE rolname = current_user)
    THEN RAISE 'You cannot create a job using a role that cannot log in';
    END IF;

    SELECT schedule INTO l_jobid FROM cron.schedule(p_schedule, p_command);
    UPDATE cron.job SET database = p_database, nodename = '' WHERE jobid = l_jobid;
    RETURN l_jobid;
END;
\$function\$;
REVOKE EXECUTE ON FUNCTION cron.schedule(text, text) FROM public;
GRANT EXECUTE ON FUNCTION cron.schedule(text, text) TO admin;
REVOKE EXECUTE ON FUNCTION cron.schedule(text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION cron.schedule(text, text, text) TO admin;
REVOKE EXECUTE ON FUNCTION cron.unschedule(bigint) FROM public;
GRANT EXECUTE ON FUNCTION cron.unschedule(bigint) TO admin;
GRANT USAGE ON SCHEMA cron TO admin;

CREATE OR REPLACE FUNCTION public.user_lookup(in i_username text, out uname text, out phash text)
RETURNS record
LANGUAGE plpgsql
SECURITY DEFINER
AS \$\$
BEGIN
    SELECT usename, passwd FROM pg_catalog.pg_shadow
    WHERE usename = i_username AND usename != '{{ .Values.pgbouncer.credentials.username }}' INTO uname, phash;
    RETURN;
END;\$\$;
REVOKE ALL ON FUNCTION public.user_lookup(text) FROM public, {{ .Values.pgbouncer.credentials.username }};
GRANT EXECUTE ON FUNCTION public.user_lookup(text) TO {{ .Values.pgbouncer.credentials.username }};

CREATE EXTENSION IF NOT EXISTS file_fdw SCHEMA public;
DO \$\$
BEGIN
    PERFORM * FROM pg_catalog.pg_foreign_server WHERE srvname = 'pglog';
    IF NOT FOUND THEN
        CREATE SERVER pglog FOREIGN DATA WRAPPER file_fdw;
    END IF;
END;\$\$;

CREATE TABLE IF NOT EXISTS public.postgres_log (
    log_time timestamp(3) with time zone,
    user_name text,
    database_name text,
    process_id integer,
    connection_from text,
    session_id text NOT NULL,
    session_line_num bigint NOT NULL,
    command_tag text,
    session_start_time timestamp with time zone,
    virtual_transaction_id text,
    transaction_id bigint,
    error_severity text,
    sql_state_code text,
    message text,
    detail text,
    hint text,
    internal_query text,
    internal_query_pos integer,
    context text,
    query text,
    query_pos integer,
    location text,
    application_name text,
    CONSTRAINT postgres_log_check CHECK (false) NO INHERIT
);
GRANT SELECT ON public.postgres_log TO admin;"

# Sunday could be 0 or 7 depending on the format, we just create both
for i in $(seq 0 7); do
    echo "CREATE FOREIGN TABLE IF NOT EXISTS public.postgres_log_$i () INHERITS (public.postgres_log) SERVER pglog
    OPTIONS (filename '../pg_log/postgresql-$i.csv', format 'csv', header 'false');
GRANT SELECT ON public.postgres_log_$i TO admin;

CREATE OR REPLACE VIEW public.failed_authentication_$i WITH (security_barrier) AS
SELECT *
  FROM public.postgres_log_$i
 WHERE command_tag = 'authentication'
   AND error_severity = 'FATAL';
ALTER VIEW public.failed_authentication_$i OWNER TO postgres;
GRANT SELECT ON TABLE public.failed_authentication_$i TO robot_zmon;
"
done

cat _zmon_schema.dump

PGVER=$(psql -qbd "$2" -XtAc "SELECT pg_catalog.current_setting('server_version_num')::int/10000")
if [ $PGVER -ge 12 ]; then RESET_ARGS="oid, oid, bigint"; fi

[ -f "{{ default "/tmp/dbsUsers" (index .Values "dbsUsersMountpoint") | quote }}" ] && for i in $(cat "{{ default "/tmp/dbsUsers" (index .Values "dbsUsersMountpoint") | quote }}"); do
    DATABASE="$(echo ${i} | awk -F: '{print $1}')" USERNAME="$(echo ${i} | awk -F: '{print $2}')" PASSWORD="$(echo ${i} | awk -F: '{print $3}')"
    cat <<EOF
DO \$\$
BEGIN
    PERFORM * FROM pg_catalog.pg_authid WHERE rolname = '${USERNAME}';
    IF FOUND THEN
        ALTER ROLE ${USERNAME} WITH NOCREATEDB LOGIN NOCREATEROLE NOSUPERUSER NOREPLICATION INHERIT;
    ELSE
        CREATE ROLE ${USERNAME} INHERIT LOGIN ENCRYPTED PASSWORD '${PASSWORD}';
    END IF;
END;\$\$;
EOF
done ||:

while IFS= read -r db_name; do
    echo "\c ${db_name}"
    # In case if timescaledb binary is missing the first query fails with the error
    # ERROR:  could not access file "$libdir/timescaledb-$OLD_VERSION": No such file or directory
    TIMESCALEDB_VERSION=$(echo -e "SELECT NULL;\nSELECT extversion FROM pg_catalog.pg_extension WHERE extname = 'timescaledb'" | psql -tAX -d "${db_name}" 2> /dev/null | tail -n 1)
    if [ "x$TIMESCALEDB_VERSION" != "x" ] && [ "x$TIMESCALEDB_VERSION" != "x$TIMESCALEDB" ] \
            && [ $PGVER -gt 11 -o "x$TIMESCALEDB_VERSION" != "x$TIMESCALEDB_LEGACY" ]; then
        echo "ALTER EXTENSION timescaledb UPDATE;"
    fi
    UPGRADE_POSTGIS=$(echo -e "SELECT COUNT(*) FROM pg_catalog.pg_extension WHERE extname = 'postgis'" | psql -tAX -d "${db_name}" 2> /dev/null | tail -n 1)
    if [ "x$UPGRADE_POSTGIS" = "x1" ]; then
        # public.postgis_lib_version() is available only if postgis extension is created
        UPGRADE_POSTGIS=$(echo -e "SELECT extversion != public.postgis_lib_version() FROM pg_catalog.pg_extension WHERE extname = 'postgis'" | psql -tAX -d "${db_name}" 2> /dev/null | tail -n 1)
        if [ "x$UPGRADE_POSTGIS" = "xt" ]; then
            echo "ALTER EXTENSION postgis UPDATE;"
            echo "SELECT public.postgis_extensions_upgrade();"
        fi
    fi
    sed "s/:HUMAN_ROLE/$1/" create_user_functions.sql
    echo "CREATE EXTENSION IF NOT EXISTS pg_stat_statements SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pg_stat_kcache SCHEMA public;
CREATE EXTENSION IF NOT EXISTS set_user SCHEMA public;
ALTER EXTENSION set_user UPDATE;
GRANT EXECUTE ON FUNCTION public.set_user(text) TO admin;
GRANT EXECUTE ON FUNCTION public.pg_stat_statements_reset($RESET_ARGS) TO admin;"
    cat metric_helpers.sql
done < <(psql -d "$2" -tAc 'select pg_catalog.quote_ident(datname) from pg_catalog.pg_database where datallowconn')
) | psql -qbXd "$2"

cat <<EOF | psql -d template1
CREATE OR REPLACE FUNCTION public.user_lookup(in i_username text, out uname text, out phash text)
RETURNS record
LANGUAGE plpgsql
SECURITY DEFINER
AS \$\$
BEGIN
    SELECT usename, passwd FROM pg_catalog.pg_shadow
    WHERE usename = i_username AND usename != '{{ .Values.pgbouncer.credentials.username }}' INTO uname, phash;
    RETURN;
END;\$\$;
REVOKE ALL ON FUNCTION public.user_lookup(text) FROM public, {{ .Values.pgbouncer.credentials.username }};
GRANT EXECUTE ON FUNCTION public.user_lookup(text) TO {{ .Values.pgbouncer.credentials.username }};
EOF

[ -f "{{ default "/tmp/dbsUsers" (index .Values "dbsUsersMountpoint") | quote }}" ] && for i in $(cat "{{ default "/tmp/dbsUsers" (index .Values "dbsUsersMountpoint") | quote }}"); do
    DATABASE="$(echo ${i} | awk -F: '{print $1}')" USERNAME="$(echo ${i} | awk -F: '{print $2}')" PASSWORD="$(echo ${i} | awk -F: '{print $3}')"
    [ $(psql -qbtA -c 'SELECT 1 FROM pg_catalog.pg_database WHERE datname = '\'${DATABASE}\'';' "$2" | wc -l) -gt 0 ] || psql -qb -c 'CREATE DATABASE '${DATABASE}' OWNER '${USERNAME}' ENCODING '\''UTF8'\'' LC_COLLATE '\''en_US.UTF-8'\'' LC_CTYPE '\''en_US.UTF-8'\'';'
done ||:
{{- end -}}
