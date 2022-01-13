#!/bin/sh

OSPCOREAPI="${OSPCOREAPI:-${OSP_API_PROTOCOL:-http}://${OSP_API_DOMAIN:-127.0.0.1:5000}}"

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

hex2ascii(){
  for i in $(seq 0 2 $((${#1}-1))); do printf "\x${1:${i}:2}"; done
}

ascii2hex(){
  for i in $(seq 0 $((${#1}-1))); do printf '%02X' "'${1:${i}:1}"; done
}

# https://docs.ejabberd.im/developer/guide/#external
ejabberd_external_auth_dispatch(){
  local payload="jid=$(urlencode "${2}")&host=$(urlencode "${3}")"
  [ -z "${4}" ] || payload+="&token=$(urlencode "${4}")"
  http "${OSPCOREAPI}/apiv1/xmpp/$(echo ${1} | tr '[[:upper:]]' '[[:lower:]]')" "${payload}" | awk '/^HTTP\/1\.1 [0-9]{3} / {print $2}' | head -n1 | grep -qE '^200$' && hex2ascii "00020001" || hex2ascii "00020000"
}

ejabberd_external_auth_parse(){
  while IFS= read -r pkt; do
    size="$(printf '%d' "$(ascii2hex "${pkt:0:2}")")"

    cmd="$(echo -n    "${pkt:2:${size}}" | awk -F: '{print $1}')"
    jid="$(echo -n    "${pkt:2:${size}}" | awk -F: '{print $2}')"
    host="$(echo -n   "${pkt:2:${size}}" | awk -F: '{print $3}')"
    passwd="$(echo -n "${pkt:2:${size}}" | cut -d: -f4-)"

    case "${cmd}" in
      auth)        ejabberd_external_auth_dispatch "${cmd}" "${jid}" "${host}" "${passwd}";;
      isuser)      ejabberd_external_auth_dispatch "${cmd}" "${jid}" "${host}";;
      setpass)     hex2ascii "00020000";;
      tryregister) hex2ascii "00020000";;
      removeuser)  hex2ascii "00020000";;
      removeuser3) hex2ascii "00020000";;
      *)           hex2ascii "00020000";;
    esac
  done
}

while true; do ejabberd_external_auth_parse; done
