#!/bin/bash

# Garantie dat runtime mappen er zijn
mkdir -p /var/run/sshd /run/sshd
chmod 0755 /var/run/sshd
chmod 0755 /run/sshd

# 1. Start Telnet daemon in de achtergrond
echo "Starting Telnet daemon..."
/usr/sbin/inetd &

# 2. Start SSH daemon in de achtergrond (zonder -d, want -d blokkeert het script)
echo "Starting OpenSSH Server..."
/usr/sbin/sshd

# 3. Start de Perl/Dancer applicatie in de achtergrond
echo "Starting Perl application..."
perl /app/dancr.pl &

# Wacht tot de app klaar staat
sleep 1

# 4. Houd de container open en stream de logging naar 'docker logs'
echo "Container is active. Following logs..."
tail -F /app/log/djedefre.log
