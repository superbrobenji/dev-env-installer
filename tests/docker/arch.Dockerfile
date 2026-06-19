FROM archlinux:latest

RUN pacman -Sy --noconfirm sudo curl git ca-certificates && \
    useradd -m -G wheel -s /bin/bash dev && \
    sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

USER dev
WORKDIR /home/dev/installer
COPY --chown=dev:dev . /home/dev/installer/

CMD bash install.sh --skip-fonts --skip-chsh --yes && bash tests/docker/assert.sh
