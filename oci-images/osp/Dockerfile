FROM python:3.10-alpine
ARG VERSION=0.8.17
COPY requirements.txt patches/ /tmp/
RUN apk add --no-cache -t .runtime-deps \
  libgcc \
  libjpeg-turbo \
  libpq \
  libstdc++ \
  uwsgi
RUN apk add --no-cache -t .build-deps \
  gcc \
  git \
  jpeg-dev \
  libffi-dev \
  libpq-dev \
  musl-dev \
  make \
  patch \
  zlib-dev \
 && pip install -U pip cryptography \
 && pip install --no-cache-dir -r /tmp/requirements.txt && rm /tmp/requirements.txt \
 && git clone https://gitlab.com/osp-group/flask-nginx-rtmp-manager -b "${VERSION}" /opt/osp \
 && cd /opt/osp && for i in $(find /tmp/ -type f -iname '*.patch'); do patch -Np1 <"${i}"; rm "${i}"; done && cd "${OLDPWD}" \
 && rm -rf /opt/osp/ATTRIBUTION \
  /opt/osp/CONTRIBUTING.md \
  /opt/osp/README.md \
  /opt/osp/.dockerignore \
  /opt/osp/.gitignore \
  /opt/osp/.gitlab-ci.yml \
  /opt/osp/osp-config.sh \
  /opt/osp/conf/osp-edge.conf \
  /opt/osp/.git \
  /opt/osp/cache \
  /opt/osp/db \
  /opt/osp/docs \
  /opt/osp/logs \
  /opt/osp/setup \
  /opt/osp/installs/ejabberd \
  /opt/osp/installs/nginx-core \
  /opt/osp/installs/osp-edge \
  /opt/osp/installs/osp-proxy \
  /opt/osp/installs/osp-rtmp/logs \
  /opt/osp/installs/osp-rtmp/setup \
 && mv /opt/osp/conf/config.py.dist /opt/osp/conf/config.py \
 && mv /opt/osp/installs/osp-rtmp/conf/config.py.dist /opt/osp/installs/osp-rtmp/conf/config.py \
 && mkdir -p /opt/osp/installs/osp-rtmp/rtmpsocket /var/www \
 && chown -R 1000:1000 /opt/osp /var/www \
 && apk del .build-deps
 #&& chown -R 1000:1000 /opt/osp/conf /opt/osp/installs/osp-rtmp/conf /opt/osp/installs/osp-rtmp/rtmpsocket /var/www \

# for serving content, because OSP doesn't know how to talk S3 yet; use hostPath volumes with on-host shared mounts in K8S
VOLUME ["/var/www"]
WORKDIR /opt/osp
USER 1000
EXPOSE 5000

COPY common.sh entrypoint.sh /
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]

#"--http-processes=10",
#"--single-interpreter",
#CMD ["uwsgi", "--die-on-term", "--master", "--http-websockets", "--gevent=1000", "--cheaper", "--cheaper-initial=2", "-p=10", "--http-socket=0.0.0.0:5000", "--threaded-logger", "--chdir=/opt/osp", "--file=/opt/osp/app.py", "--callable=app"]
CMD ["gunicorn", "app:app", "-k", "geventwebsocket.gunicorn.workers.GeventWebSocketWorker", "-w", "8", "--bind", "0.0.0.0:5000", "--access-logfile", "-", "--error-logfile", "-"]
