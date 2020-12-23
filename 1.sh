#!/bin/bash
sudo cp disable-slaac.conf /etc/sysctl.d/11-no-slaac.conf
sudo sed -i "s/127.0.1.1/#127.0.1.1/g" /etc/hosts
sudo apt update
sudo apt upgrade -y
sudo apt install -y software-properties-common postfix nmap mailutils certbot python3-certbot-apache apache2 dovecot-core dovecot-imapd acl php7.4-fpm php7.4-imap php7.4-mbstring php7.4-mysql php7.4-json php7.4-curl php7.4-zip php7.4-xml php7.4-bz2 php7.4-intl php7.4-gmp dovecot-mysql postfix-policyd-spf-python opendkim opendkim-tools dovecot-lmtpd binutils postfixadmin postgrey fail2ban spamassassin spamc spamass-milter
sudo ufw allow 25/tcp
sudo ufw allow 465/tcp
