FROM ubuntu:xenial

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mongodb && useradd -r -g mongodb mongodb

RUN apt-get update \
        && apt-get install -y --no-install-recommends \
                ca-certificates \
                jq \
                numactl \
        && rm -rf /var/lib/apt/lists/*

# grab gosu for easy step-down from root (https://github.com/tianon/gosu/releases)
ENV GOSU_VERSION 1.10
# grab "js-yaml" for parsing mongod's YAML config files (https://github.com/nodeca/js-yaml/releases)
ENV JSYAML_VERSION 3.10.0

RUN set -ex; \
        \
        apt-get update; \
        apt-get install -y --no-install-recommends \
                wget \
        ; \
        rm -rf /var/lib/apt/lists/*; \
        \
        dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
        wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
        wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
        export GNUPGHOME="$(mktemp -d)"; \
        gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
        gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
        command -v gpgconf && gpgconf --kill all || :; \
        rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc; \
        chmod +x /usr/local/bin/gosu; \
        gosu nobody true; \
        \
        wget -O /js-yaml.js "https://github.com/nodeca/js-yaml/raw/${JSYAML_VERSION}/dist/js-yaml.js"; \
# TODO some sort of download verification here
        \
        apt-get purge -y --auto-remove wget

RUN mkdir /docker-entrypoint-initdb.d

ENV GPG_KEYS \
# pub   rsa4096 2018-04-18 [SC] [expires: 2023-04-17]
#       9DA3 1620 334B D75D 9DCB  49F3 6881 8C72 E525 29D4
# uid           [ unknown] MongoDB 4.0 Release Signing Key <packaging@mongodb.com>
        9DA31620334BD75D9DCB49F368818C72E52529D4
# https://docs.mongodb.com/manual/tutorial/verify-mongodb-packages/#download-then-import-the-key-file
RUN set -ex; \
        export GNUPGHOME="$(mktemp -d)"; \
        for key in $GPG_KEYS; do \
                gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
        done; \
        gpg --export $GPG_KEYS > /etc/apt/trusted.gpg.d/mongodb.gpg; \
        command -v gpgconf && gpgconf --kill all || :; \
        rm -r "$GNUPGHOME"; \
        apt-key list

# Allow build-time overrides (eg. to build image with MongoDB Enterprise version)
# Options for MONGO_PACKAGE: mongodb-org OR mongodb-enterprise
# Options for MONGO_REPO: repo.mongodb.org OR repo.mongodb.com
# Example: docker build --build-arg MONGO_PACKAGE=mongodb-enterprise --build-arg MONGO_REPO=repo.mongodb.com .
ARG MONGO_PACKAGE=mongodb-org
ARG MONGO_REPO=repo.mongodb.org
ENV MONGO_PACKAGE=${MONGO_PACKAGE} MONGO_REPO=${MONGO_REPO}

ENV MONGO_MAJOR 4.0
ENV MONGO_VERSION 4.0.0

RUN echo "deb http://$MONGO_REPO/apt/ubuntu xenial/${MONGO_PACKAGE%-unstable}/$MONGO_MAJOR multiverse" | tee "/etc/apt/sources.list.d/${MONGO_PACKAGE%-unstable}.list"

RUN set -x \
        && apt-get update \
        && apt-get install -y \
                ${MONGO_PACKAGE}=$MONGO_VERSION \
                ${MONGO_PACKAGE}-server=$MONGO_VERSION \
                ${MONGO_PACKAGE}-shell=$MONGO_VERSION \
                ${MONGO_PACKAGE}-mongos=$MONGO_VERSION \
                ${MONGO_PACKAGE}-tools=$MONGO_VERSION \
        && rm -rf /var/lib/apt/lists/* \
        && rm -rf /var/lib/mongodb \
        && mv /etc/mongod.conf /etc/mongod.conf.orig

RUN mkdir -p /data/db /data/configdb \
        && chown -R mongodb:mongodb /data/db /data/configdb
VOLUME /data/db /data/configdb

COPY docker-entrypoint.sh /usr/local/bin/

RUN chmod 777 /usr/local/bin/docker-entrypoint.sh \
    && ln -s /usr/local/bin/docker-entrypoint.sh /

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 27017
CMD mongod --replSet joolia --bind_ip_all
