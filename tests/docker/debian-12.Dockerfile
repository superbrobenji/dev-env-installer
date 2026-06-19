FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      sudo curl git ca-certificates locales && \
    locale-gen en_US.UTF-8 && \
    useradd -m -G sudo -s /bin/bash dev && \
    echo "dev ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    rm -rf /var/lib/apt/lists/*

USER dev
WORKDIR /home/dev/installer
COPY --chown=dev:dev . /home/dev/installer/

ENV LANG=en_US.UTF-8

CMD bash install.sh --skip-fonts --skip-chsh --yes && bash tests/docker/assert.sh
