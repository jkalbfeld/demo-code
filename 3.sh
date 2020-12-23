#!/bin/bash
sudo apt -y install fail2ban
sudo systemctl status fail2ban
cat > jail.local <<EOF
[postfix-flood-attack]
enabled  = true
bantime  = 10m
filter   = postfix-flood-attack
action   = iptables-multiport[name=postfix, port="http,https,smtp,submission,pop3,pop3s,imap,imaps,sieve", protocol=tcp]
logpath  = /var/log/mail.log
ignoreip = 127.0.0.1/8 ::1 199.79.202.0/24 199.33.244.0/24 199.188.96.0/22 206.197.110.0/24 2607:6100::/32
maxretry = 4

[postfix]
enabled = true
maxretry = 3
bantime = 1h
filter = postfix
logpath = /var/log/mail.log
EOF
sudo cp jail.local /etc/fail2ban

cat > postfix-flood-attack.conf <<EOF
[Definition]
failregex = lost connection after AUTH from (.*)\[<HOST>\]
ignoreregex =
EOF

sudo systemctl restart fail2ban
