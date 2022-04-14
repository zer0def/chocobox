#!/bin/sh -e
EJABBERDCTL=/home/ejabberd/bin/ejabberdctl
sleep 30
until "${EJABBERDCTL}" started; do sleep 3; done
[ "$("${EJABBERDCTL}" list_cluster | wc -l)" -gt 1 ] && "${EJABBERDCTL}" list_cluster | grep -qE "^'ejabberd@${HOSTNAME%-*}-${i}.${K8S_SVC_NAME}'\$" && exit 0 || for i in $(seq 0 $((${HOSTNAME##*-}-1))); do "${EJABBERDCTL}" join_cluster "ejabberd@${HOSTNAME%-*}-${i}.${K8S_SVC_NAME}" && exit 0 || continue; done; exit 1
