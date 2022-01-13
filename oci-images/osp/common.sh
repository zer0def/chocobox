#!/bin/sh

urlparse(){
  local protocol="${1%%://*}" tail="${1#*://}"
  [ "${protocol}" != "${tail}" ] || unset protocol
  local head="${tail%%#*}" fragment="${tail#*#}"
  [ "${fragment}" != "${head}" ] || unset fragment
  local head="${head%%\?*}" qs="${head#*\?}"
  [ "${qs}" != "${head}" ] || unset qs
  local netloc="${head%%/*}" path="${head#*/}"
  [ "${netloc}" != "${path}" ] || unset path
  local auth="${netloc%@*}" endpoint="${netloc#*@}"
  [ "${auth}" != "${endpoint}" ] || unset auth
  local user pass
  [ -z "${auth}" ] || user="${auth%%:*}" pass="${auth#*:}"
  local host="${endpoint%:*}" port="${endpoint##*:}"
  [ "${port}" != "${host}" ] || unset port
  echo "${protocol}|${user}|${pass}|${host}|${port}|${path}|${qs}|${fragment}"
}

http(){
  local payload="${2}" headers="${3:-content-type: application/x-www-form-urlencoded}" method="${4:-post}"
  echo -n "${payload}" | grep -qE '^[{[]' && headers="content-type: application/json" ||:
  [ -n "${payload}" ] || method=get headers="content-type: text/plain"

  urlparsed="$(urlparse "${1}")"
  local protocol="$(echo "${urlparsed}" | awk -F'|' '{print $1}')" host="$(echo "${urlparsed}" | awk -F'|' '{print $4}')" port="$(echo "${urlparsed}" | awk -F'|' '{print $5}')" path="$(echo "${urlparsed}" | awk -F'|' '{print $6}')"
  [ -n "${protocol}" ] || return
  local s_port="${port}"
  [ "${protocol}" = "http" ] && s_port="${s_port:=80}" || s_port="${s_port:=443}"

  local tmpfile="$(mktemp)"; rm "${tmpfile}"; mkfifo "${tmpfile}"
  exec 4<>"${tmpfile}"
  cat <<EOF >&4
$(echo -n ${method} | tr '[[:lower:]]' '[[:upper:]]') /${path} HTTP/1.1
host: ${host}${port:+:${port}}
content-length: ${#payload}
connection: close
$(echo ${headers} | tr '|' '\n')

${payload}
EOF
  req_cmd="nc -w1 ${host} ${port:-80}"
  [ "${protocol}" = "http" ] || req_cmd="openssl s_client -connect ${host}:${port:-443} -quiet -servername ${host}${port:+:${port}}"
  ${req_cmd} <&4
  rm "${tmpfile}"
}

urlencode(){
  local old_lc_collate="${LC_COLLATE}"; LC_COLLATE=C
  for i in $(seq 0 $((${#1}-1))); do
    case "${1:${i}:1}" in
      [a-zA-Z0-9.~_-]) printf '%s' "${1:${i}:1}";;
      *) printf '%%%02X' "'${1:${i}:1}";;
    esac
  done
  LC_COLLATE="${old_lc_collate}"
}

urldecode(){ local url_encoded="${1//+/ }"; printf '%b' "${url_encoded//%/\\x}"; }

wait_for_db(){
  db_urlparsed="$(urlparse "${DB_URL}")"
  db_scheme="$(echo "${db_urlparsed}" | awk -F'|' '{print $1}')" db_host="$(echo "${db_urlparsed}" | awk -F'|' '{print $4}')" db_port="$(echo "${db_urlparsed}" | awk -F'|' '{print $5}')" db_path="$(echo "${db_urlparsed}" | awk -F'|' '{print $6}')"
  case "${db_scheme}" in
    mysql*) : "${db_port:=3306}";;
    postgresql*) : "${db_port:=5432}";;
  esac
  [ "${db_scheme}" = "sqlite" ] || until nc -z "${db_host}" "${db_port}"; do sleep 1; done
}

wait_for_ejabberd(){
  until nc -z "${EJABBERDSERVER:-localhost}" "${EJABBERD_HTTP_PORT:-5280}"; do sleep 1; done  # L3
  until http "http://${EJABBERDSERVER:-localhost}:${EJABBERD_HTTP_PORT:-5280}${EJABBERD_HTTP_XMLRPC_PATH:-/xmlrpc}" "<?xml version='1.0'?><methodCall><methodName>status</methodName><params><param><value><struct><member><name>user</name><value><string>${EJABBERDADMIN:-admin}</string></value></member><member><name>password</name><value><string>${EJABBERDPASS}</string></value></member><member><name>server</name><value><string>${EJABBERDHOST:-localhost}</string></value></member><member><name>admin</name><value><boolean>1</boolean></value></member></struct></value></param></params></methodCall>" "content-type: text/xml" | grep -qE '^HTTP/1\.1 2'; do sleep 1; done  # L4
}

mkdir -p /var/www/live /var/www/videos /var/www/live-rec /var/www/live-adapt /var/www/stream-thumb /var/www/images /opt/osp/installs/osp-rtmp/rtmpsocket
