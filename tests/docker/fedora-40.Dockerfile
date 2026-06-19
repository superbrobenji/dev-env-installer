FROM fedora:40

RUN dnf install -y sudo curl git ca-certificates glibc-langpack-en && \
    useradd -m -G wheel -s /bin/bash dev && \
    echo "dev ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER dev
WORKDIR /home/dev/installer
COPY --chown=dev:dev . /home/dev/installer/

CMD bash install.sh --skip-fonts --skip-chsh --yes && bash tests/docker/assert.sh
