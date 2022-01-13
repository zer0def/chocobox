#!/bin/sh

. /common.sh

: ${DB_URL:=sqlite:////tmp/osp.db}

# functions to handle defaults for both kinds of boolean values

cat <<EOF >/opt/osp/conf/config.py
dbLocation = "${DB_URL}"
redisHost = "${REDIS_HOST:-127.0.0.1}"
redisPort = ${REDIS_PORT:-6379}
redisPassword = "${REDIS_PASSWORD}"
secretKey = "${FLASK_SECRET}"
passwordSalt = "${FLASK_SALT}"
allowRegistration = ${OSP_ALLOWREGISTRATION:-True}
requireEmailRegistration = ${OSP_REQUIREVERIFICATION:-True}
debugMode = ${OSP_CORE_UI_DEBUG:-False}
log_level = "${OSP_CORE_LOG_LEVEL:-debug}"
ospCoreAPI = "${OSPCOREAPI:-http://127.0.0.1:5000}"
ejabberdAdmin = "${EJABBERDADMIN:-admin}"
ejabberdPass = "${EJABBERDPASS}"

ejabberdHost = "${EJABBERDHOST:-localhost}"  # ejabberd vhost
#ejabberdServerHttpBindFQDN = "${EJABBERDHTTPBINDFQDN:-localhost}"
ejabberdServer = "${EJABBERDSERVER:-127.0.0.1}"

#RECAPTCHA_ENABLED = ${RECAPTCHA_ENABLED:-False}
#RECAPTCHA_SITE_KEY = "${RECAPTCHA_SITE_KEY}"
#RECAPTCHA_SECRET_KEY = "${RECAPTCHA_SECRET_KEY}"
#sentryIO_Enabled = ${SENTRY_ENABLED:-False}
#sentryIO_DSN = "${SENTRY_DSN}"
#sentryIO_Environment = "${SENTRY_ENV}"
EOF

wait_for_ejabberd
wait_for_db
until nc -z "${REDIS_HOST:-127.0.0.1}" "${REDIS_PORT:-6379}"; do sleep 1; done

exec "${@}"
