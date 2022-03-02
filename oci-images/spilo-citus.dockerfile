ARG PGMAJOR=14
ARG TIMESCALEDB_VERSION=2.6.0
#ARG SPILO_VERSION=2.1-p3
#FROM registry.opensource.zalan.do/acid/spilo-${PGMAJOR}:${SPILO_VERSION}
#ARG PGMAJOR=14.0
#FROM docker.io/timescale/timescaledb-ha:pg${PGMAJOR}-ts${TIMESCALE_VERSION}-latest
ARG SPILO_VERSION=2.1p4
ARG CITUS_VERSION=10.2
FROM docker.io/zer0def/spilo:${PGMAJOR}-${SPILO_VERSION}-tsl${TIMESCALEDB_VERSION}

USER 0
RUN . /etc/os-release \
 && export DEBIAN_FRONTEND=noninteractive \
 && apt update && apt -y install gnupg \
 && curl -sSL https://repos.citusdata.com/community/gpgkey | gpg --dearmor -o /etc/apt/trusted.gpg.d/citusdata-archive-keyring.gpg \
 && curl -sSL "https://repos.citusdata.com/community/config_file.list?os=${ID}&dist=${VERSION_CODENAME}" > /etc/apt/sources.list.d/citus.list \
 && apt update \
 && apt -y install \
      "postgresql-12-citus-${CITUS_VERSION}" \
      "postgresql-13-citus-${CITUS_VERSION}" \
      "postgresql-14-citus-${CITUS_VERSION}" \
 && apt clean \
 && rm -rf /var/lib/apt/lists/*

RUN export DEBIAN_FRONTEND=noninteractive \
 && apt update \
 && apt -y install \
      postgresql-9.6-citus-8.0 \
      postgresql-10-citus-8.3 \
      postgresql-11-citus-10.0 \
 && apt clean \
 && rm -rf /var/lib/apt/lists/*
#USER 1000
