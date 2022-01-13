FROM debian:testing-slim
ARG X2GO_GPG_KEY=E1F958385BFE2B6E
ENV X2GO_GPG_KEY=${X2GO_GPG_KEY:-E1F958385BFE2B6E}
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install gnupg \
 && apt-key adv --recv-keys --keyserver keys.gnupg.net ${X2GO_GPG_KEY:-E1F958385BFE2B6E} \
 && echo "deb http://packages.x2go.org/debian testing extras main" > /etc/apt/sources.list.d/x2go.list \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get -y install x2goserver xfce4 dbus-x11 lxterminal firefox-esr sudo \
 && rm /etc/ssh/ssh_host_* \
 && echo '%adm ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/adm \
 && useradd -ms /bin/bash x2go \
 && usermod -aG adm x2go \
 && echo x2go:x2go | chpasswd \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/sshd
CMD ["/bin/sh", "-xc", "`which ssh-keygen` -A && exec `which sshd` -D"]
