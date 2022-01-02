#!/bin/sh -x

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
  local payload="${2}" method="${3:-post}"
  echo -n "${payload}" | grep -qE '^[{[]' && ctype="application/json" || ctype="application/x-www-form-urlencoded"
  [ -n "${payload}" ] || method=get ctype="text/plain"

  urlparsed="$(urlparse "${1}")"
  local protocol="$(echo "${urlparsed}" | awk -F'|' '{print $1}')" host="$(echo "${urlparsed}" | awk -F'|' '{print $4}')" port="$(echo "${urlparsed}" | awk -F'|' '{print $5}')" path="$(echo "${urlparsed}" | awk -F'|' '{print $6}')"
  [ -n "${protocol}" ] || return
  local s_port="${port}"
  [ "${protocol}" = "http" ] && s_port="${s_port:=80}" || s_port="${s_port:=443}"

  exec 4<> <(:)
  cat <<EOF >&4
$(echo -n ${method} | tr '[[:lower:]]' '[[:upper:]]') /${path} HTTP/1.1
host: ${host}${port:+:${port}}
content-type: ${ctype}
content-length: ${#payload}
connection: close

${payload}
EOF
  #[ "${protocol}" != "http" ] || req_cmd="nc ${host} ${port:-80}"
  ssl_cmd="busybox ssl_client -s 3 -n ${host}${port:+:${port}}"
  [ "${protocol}" != "http" ] && command -v openssl &>/dev/null && ssl_cmd="openssl s_client -connect ${host}:${port:-443} -quiet -servername ${host}${port:+:${port}}" || exec 3<>"/dev/tcp/${host}/${s_port}"
  [ "${protocol}" = "http" ] && (cat <&4 >&3 & cat <&3) || ${ssl_cmd} <&4
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

string_join() { local IFS="$1"; shift; echo "$*"; }

hex2bin(){ for i in $(seq 0 2 $((${#1}-1))); do printf "\x${1:${i}:2}"; done; }

bin2hex(){ for i in $(seq 0 $((${#1}-1))); do printf '%02X' "'${1:${i}:1}"; done; }

bb_http(){
  local RECVFD="$(mktemp)"; rm "${RECVFD}"; mkfifo "${RECVFD}"; exec 3<>"${RECVFD}"
  local SENDFD="$(mktemp)"; rm "${SENDFD}"; mkfifo "${SENDFD}"; exec 4<>"${SENDFD}"

  # BROKEN: alpine ssl_client takes only a single fd (a socket), not a pair of fifos
  #cat "${RECVFD}" | nc "${1}" 443 >&3 &
  #ssl_client -e -I -s3 -n "${1}" <<EOF
  ## OR
  #nc "${i}" 443 -e ssl_client -I -e -n "${i}" <<EOF

  nc "${1}" 443 >&4 <&3 &
  busybox ssl_client -e -s3 -r4 -n "${1}" <<EOF
GET / HTTP/1.1
host: ${1}
connection: close

EOF
}

# https://docs.ejabberd.im/developer/guide/#external
ejabberd_external_auth_dispatch(){
  hex2bin "00020000"  # failure
  #hex2bin "00020001"  # success
}

ejabberd_external_auth_parse(){
  while IFS= read -r pkt; do
    size="$(printf '%d' "$(bin2hex "${pkt:0:2}")")"

    cmd="$(echo -n    "${pkt:2:${size}}" | awk -F: '{print $1}')"
    jid="$(echo -n    "${pkt:2:${size}}" | awk -F: '{print $2}')"
    host="$(echo -n   "${pkt:2:${size}}" | awk -F: '{print $3}')"
    passwd="$(echo -n "${pkt:2:${size}}" | cut -d: -f4-)"

    case "${cmd}" in
      auth)        ejabberd_external_auth_dispatch "${cmd}" "${jid}" "${host}" "${passwd}";;
      isuser)      ejabberd_external_auth_dispatch "${cmd}" "${jid}" "${host}";;
      setpass)     hex2bin "00020000";;
      tryregister) hex2bin "00020000";;
      removeuser)  hex2bin "00020000";;
      removeuser3) hex2bin "00020000";;
      *)           hex2bin "00020000";;
    esac
  done
}

devone(){
  tr '\0' '\377' < /dev/zero
}
