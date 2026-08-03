FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Installeer alle pakketten in één keer
RUN apt-get update && apt-get install -y \
    perl \
    cpanminus \
    build-essential \
    libssl-dev \
    curl \
    libexpat1-dev \
    libpcap-dev \
    libmagickcore-dev \
    imagemagick \
    libimage-magick-perl \
    sqlite3 \
    cron \
    openssh-server \
    telnetd \
    inetutils-inetd \
    nmap \
    iproute2 \
    ipcalc \
    shared-mime-info \
    iputils-ping \
    arping \
    avahi-utils \
    bsdextrautils \
    curl \
    dos2unix \
    fping \
    grepcidr \
    bind9-host \
    jq \
    sqlite3 \
    openssh-client \
    sudo \
    groff-base \
    wget \
    libauthen-simple-pam-perl \
    && rm -rf /var/lib/apt/lists/*

# SSH en Telnet configuratie
RUN mkdir -p /var/run/sshd /run/sshd && \
    chmod 0755 /var/run/sshd && \
    chmod 0755 /run/sshd

# Richt de root SSH-omgeving in
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
COPY authorized_keys /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys && chown root:root /root/.ssh/authorized_keys

# SSH Config aanpassen (Schakel PAM uit voor Docker stabilized standalone)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

# Genereer unieke host keys
RUN ssh-keygen -A

# Stel een tijdelijk root-wachtwoord in (alleen nodig als je via Telnet wilt inloggen)
RUN echo 'root:debug123' | chpasswd

WORKDIR /app

# Kopieer en installeer Perl dependencies
COPY cpanfile /app/cpanfile
RUN cpanm --notest --installdeps .
RUN mkdir -p /app/log /app/database

# Maak de database
COPY schema.sql /app/schema.sql
RUN sqlite3 /app/database/djedefre.db < /app/schema.sql

# Kopieer applicatiebestanden
COPY dancr.pl /app
COPY api_routes.pm /app
COPY common_functions.pm /app
COPY dje_db.pm /app
COPY djedefre_user.pm /app
COPY drawing.pm /app
COPY djedefre_create_db.pl /app
COPY public/ /app/public
COPY scan_scripts/ /app/scan_scripts
COPY views/ /app/views

# Activeer het opstartscript (ZONDER hekje!)
COPY docker_startup.sh /app/docker_startup.sh
RUN chmod +x /app/docker_startup.sh

EXPOSE 3000 22 23

CMD ["/app/docker_startup.sh"]
