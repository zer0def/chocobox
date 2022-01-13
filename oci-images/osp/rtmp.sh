. /common.sh
cat <<EOF >/opt/osp/installs/osp-rtmp/conf/config.py
secretKey = "${FLASK_SECRET}"
debugMode = ${OSP_CORE_UI_DEBUG:-False}
ospCoreAPI = "${OSPCOREAPI:-http://127.0.0.1:5000}"
EOF

get_ospsession(){
  echo "${1}" | grep -Ei '^set-cookie:' | awk 'match($0, / ospSession=[^; ]*/) {print substr($0, RSTART, RLENGTH)}' | awk -F= '{print $NF}'
}

admin_login(){
  local payload csrf_token cookie

  while true; do
    until [ -n "${csrf_token}" ]; do
      payload="$(http "${OSPCOREAPI}/login")"
      csrf_token="$(echo "${payload}" | grep ' id="csrf_token" ' | awk 'match($0, / value="[^"]*"/) {print substr($0, RSTART, RLENGTH)}' | awk -F= '{print $NF}' | tr -d '"')"
      cookie="$(get_ospsession "${payload}")"
    done

    payload="$(http "${OSPCOREAPI}/login" "csrf_token=${csrf_token}&password=$(urlencode "${OSP_ADMIN_PASSWORD}")&email=$(urlencode "${OSP_ADMIN_EMAIL}")&submit=Login&next=" "content-type: application/x-www-form-urlencoded|cookie: ospSession=${cookie}")"
    if echo "${payload}" | grep -qE '^HTTP/1\.1 3'; then
      echo "$(get_ospsession "${payload}")"
      return
    else
      unset csrf_token
    fi
  done
}

COOKIE="$(admin_login)"
MYIP=$(hostname -i)
MYFQDN=$(hostname -f)
http "${OSPCOREAPI}/settings/admin" "address=$(urlencode "${MYFQDN}")&settingType=rtmpServer" "content-type: application/x-www-form-urlencoded|cookie: ospSession=${COOKIE}"
exec gunicorn app:app -k geventwebsocket.gunicorn.workers.GeventWebSocketWorker -w 1 --bind 0.0.0.0:5000 --access-logfile - --error-logfile -
