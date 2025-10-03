FROM debian:latest
# metadata
ARG VERSION
ENV VERSION=${VERSION}
ARG BUILD_DATE
ENV BUILD_DATE=${BUILD_DATE}
LABEL org.opencontainers.image.source="https://github.com/egabosh/dabo" \
      org.opencontainers.image.description="dabo crypto trading bot" \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.authors="Oliver Bohlen (aka olli/egabosh)" \
      org.opencontainers.image.licenses="GPL-3.0 (for dabo-bot in /dabo)" \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.vendor="egabosh" \
      org.opencontainers.image.documentation="https://github.com/egabosh/dabo#readme" \
      org.opencontainers.image.base.name="Debian Linux" \
      org.opencontainers.image.base.licenses="Various, see https://www.debian.org/legal/licenses/"
# basics
ARG PIP_PACKAGES
ENV PIP_PACKAGES=${PIP_PACKAGES}
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/python-dabo/bin:$PATH"
RUN apt-get update && \
  apt-get -y dist-upgrade && \
  apt-get -y install curl && \
  curl -L https://github.com/egabosh/linux-setups/raw/refs/heads/main/debian/docker/build-debian-env.sh >build-debian-env.sh && \
  bash -ex build-debian-env.sh && \
# remove unnecessary software and clean-up apt
  apt-get -y remove --purge man-db cryptsetup ffmpeg mediainfo nmap libcrypt-cbc-perl libcrypt-des-perl cifs-utils golang make sshfs imagemagick libimage-exiftool-perl sqlite3 openssh-server gpg rblcheck crudini kpartx && \
  apt-get -y autoremove && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
# create dabo user
  addgroup --system --gid 10000 dabo && \
  adduser --system --disabled-password --disabled-login --gid 10000 --uid 10000 --home /dabo/home dabo && \
# install latest dabo from github
  mkdir /git && \
  cd /git && \
  git clone https://github.com/egabosh/dabo.git && \
  mv dabo/dabo/* /dabo && \
  mv dabo/LICENSE /dabo && \
  rm -r /git && \
  chown -R 10000:10000 /dabo && \
  mkdir -p /dabo/home /dabo/htdocs /dabo/secrets /dabo/strategies && \
  find /dabo -type d -exec chmod 0700 {} \; && \
  find /dabo -type f -exec chmod 0600 {} \; && \
  chmod 0700 /dabo/*.sh && \
# install python, ccxt and optional tensorflow
  mkdir /python-dabo && \
  cd /python-dabo && \
  python3 -m venv /python-dabo && \
  pip install --upgrade pip && \
  pip install $PIP_PACKAGES && \
# clean-up pip
  pip cache purge
# defaults
ENTRYPOINT ["/dabo/dabo-bot.sh"]
