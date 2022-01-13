#!/bin/sh

. /common.sh

if [ -n "${OSP_ADMIN_USER}" ] && [ -n "${OSP_ADMIN_PASSWORD}" ] && [ -n "${OSP_ADMIN_EMAIL}" ]; then
  until http "${OSPCOREAPI:-http://127.0.0.1:5000}" | grep -qE '^HTTP/1\.1 2'; do sleep 3; done

  INITIAL_SETUP_PAYLOAD="username=$(urlencode "${OSP_ADMIN_USER}")&password1=$(urlencode "${OSP_ADMIN_PASSWORD}")&password2=$(urlencode "${OSP_ADMIN_PASSWORD}")&email=$(urlencode "${OSP_ADMIN_EMAIL}")&serverName=$(urlencode "${OSP_SERVER_NAME}")&siteProtocol=$(urlencode "${OSP_SERVER_PROTOCOL:-http://}")&serverAddress=$(urlencode "${OSP_SERVER_ADDRESS}")&smtpAddress=$(urlencode "${OSP_SMTP_SERVER}")&smtpSendAs=$(urlencode "${OSP_SMTP_SEND_AS}")&smtpPort=$(urlencode "${OSP_SMTP_PORT:-25}")&smtpUser=$(urlencode "${OSP_SMTP_USER}")&smtpPassword=$(urlencode "${OSP_SMTP_PASSWORD}")"
  [ -z "${OSP_SMTP_TLS}" ] || INITIAL_SETUP_PAYLOAD="${INITIAL_SETUP_PAYLOAD}&smtpTLS=$(urlencode "${OSP_SMTP_TLS}")"
  [ -z "${OSP_SMTP_SSL}" ] || INITIAL_SETUP_PAYLOAD="${INITIAL_SETUP_PAYLOAD}&smtpSSL=$(urlencode "${OSP_SMTP_SSL}")"
  [ -z "${OSP_ALLOW_RECORDING}" ] || INITIAL_SETUP_PAYLOAD="${INITIAL_SETUP_PAYLOAD}&recordSelect=$(urlencode "${OSP_ALLOW_RECORDING}")"
  [ -z "${OSP_ALLOW_UPLOAD}" ] || INITIAL_SETUP_PAYLOAD="${INITIAL_SETUP_PAYLOAD}&uploadSelect=$(urlencode "${OSP_ALLOW_UPLOAD}")"
  [ -z "${OSP_ALLOW_COMMENT}" ] || INITIAL_SETUP_PAYLOAD="${INITIAL_SETUP_PAYLOAD}&allowComments=$(urlencode "${OSP_ALLOW_COMMENT}")"
  [ -z "${OSP_ADAPTIVE_STREAMING}" ] || INITIAL_SETUP_PAYLOAD="${INITIAL_SETUP_PAYLOAD}&adaptiveStreaming=$(urlencode "${OSP_ADAPTIVE_STREAMING}")"
  [ -z "${OSP_DISPLAY_EMPTY}" ] || INITIAL_SETUP_PAYLOAD="${INITIAL_SETUP_PAYLOAD}&showEmptyTables=$(urlencode "${OSP_DISPLAY_EMPTY}")"

  until http "${OSPCOREAPI:-http://127.0.0.1:5000}/settings/initialSetup" "${INITIAL_SETUP_PAYLOAD}" | grep -qE '^HTTP/1\.1 3'; do sleep 1; done
fi
