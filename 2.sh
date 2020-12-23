#!/bin/bash
sudo dpkg-reconfigure postfix
sudo postconf -e message_size_limit=104857600
sudo systemctl restart postfix
sudo ufw allow 80,443,587,465,143,993/tcp
sudo cp postfix-master.cf /etc/postfix/master.cf
sudo systemctl restart postfix
sudo apt install -y postgrey
sudo systemctl start postgrey
sudo systemctl enable postgrey
myimapname=$1
postfixadminsite=$2
myhostname=$3
mydomain=$(echo $myimapname | awk -F. '{print $(NF-1)"."$NF}')
sudo ufw allow 80,443,587,465,143,993/tcp
echo "<VirtualHost *:80>        
        ServerName $myimapname
        DocumentRoot /var/www/$myimapname
	</VirtualHost>" > /tmp/${myimapname}.conf
	

sudo mv /tmp/${myimapname}.conf /etc/apache2/sites-available/${myimapname}.conf

sudo mkdir /var/www/$myimapname
sudo a2ensite $myimapname
sudo systemctl reload apache2
sudo certbot --apache --agree-tos --redirect --hsts --staple-ocsp --email jonathan@thoughtwave.com -d $myimapname
sudo cp postfix-master.cf /etc/postfix/master.cf
sudo sed -i "s/ssl\/certs\/ssl-cert-snakeoil.pem/letsencrypt\/live\/$myimapname\/fullchain.pem/g" /etc/postfix/main.cf
sudo sed -i "s/ssl\/private\/ssl-cert-snakeoil.key/letsencrypt\/live\/$myimapname\/privkey.pem/g" /etc/postfix/main.cf
sudo systemctl restart postfix

sudo sed -i "s/#disable_plaintext/disable_plaintext/g" /etc/dovecot/conf.d/10-auth.conf 
sudo sed -i "s/= plain/= plain login/g" /etc/dovecot/conf.d/10-auth.conf 
sudo sed -i "s/ssl = yes/ssl = required/g" /etc/dovecot/conf.d/10-ssl.conf
sudo rm -f /etc/dovecot/private/dovecot.pem /etc/dovecot/private/dovecot.key
sudo ln -s /etc/letsencrypt/live/$myimapname/fullchain.pem /etc/dovecot/private/dovecot.pem
sudo ln -s /etc/letsencrypt/live/$myimapname/privkey.pem /etc/dovecot/private/dovecot.key
sudo sed -i "s/#ssl_prefer_server_ciphers = no/ssl_prefer_server_ciphers = yes/g" /etc/dovecot/conf.d/10-ssl.conf
echo "ssl_protocols = !SSLv3 !TLSv1 !TLSv1.1" | sudo tee -a /etc/dovecot/conf.d/10-ssl.conf
sudo sed -i "s/#ssl_min_protocol = TLSv1/ssl_min_protocol = TLSv1.2/g" /etc/dovecot/conf.d/10-ssl.conf
sudo cp dovecot-10-master.conf /etc/dovecot/conf.d/10-master.conf
echo "protocols = imap lmtp" | sudo tee -a /etc/dovecot/dovecot.conf

sudo systemctl restart dovecot
sudo dpkg-reconfigure postfixadmin
sudo sed -i "s/mysql'/mysqli'/g" /etc/dbconfig-common/postfixadmin.conf /etc/postfixadmin/dbconfig.inc.php
sudo mkdir /usr/share/postfixadmin/templates_c
sudo chown -R www-data /usr/share/postfixadmin/templates_c
sudo cp postfixadmin.conf /etc/apache2/sites-available/postfixadmin.conf
sudo sed -i "s/example/$postfixadminsite/g" /etc/apache2/sites-available/postfixadmin.conf
sudo a2ensite postfixadmin.conf
sudo systemctl reload apache2
sudo certbot --apache --agree-tos --redirect --hsts --staple-ocsp --email jonathan@thoughtwave.com -d $postfixadminsite

sudo systemctl restart apache2
sudo cp config.local.php /usr/share/postfixadmin
sudo ln -s /usr/share/postfixadmin/config.local.php /etc/postfixadmin/config.local.php
cat postfix-main-append.cf | sudo tee -a /etc/postfix/main.cf
sudo mkdir /etc/postfix/sql
sudo cp mysql_virtual_domains_maps.cf /etc/postfix/sql/
sudo cp mysql_virtual_mailbox_maps.cf /etc/postfix/sql/
sudo cp mysql_virtual_alias_domain_mailbox_maps.cf /etc/postfix/sql/
sudo cp mysql_virtual_alias_maps.cf /etc/postfix/sql/
sudo cp mysql_virtual_alias_domain_maps.cf /etc/postfix/sql/
sudo cp mysql_virtual_alias_domain_catchall_maps.cf /etc/postfix/sql/
sudo chmod 0640 /etc/postfix/sql/*
sudo chown -R postfix /etc/postfix/sql
sudo postconf -e "mydestination = $myhostname, localhost.$mydomain, localhost"
sudo systemctl restart postfix
sudo adduser vmail --system --group --uid 2000 --disabled-login --no-create-home
sudo mkdir /var/vmail/
sudo chown -R vmail:vmail /var/vmail/ 
sudo sed -i "s/~\/Maildir/\/var\/vmail\/%d\/%n/g" /etc/dovecot/conf.d/10-mail.conf
echo "mail_home = /var/vmail/%d/%n" | sudo tee -a /etc/dovecot/conf.d/10-mail.conf
sudo sed -i "s/#disable_plaintext/disable_plaintext/g" /etc/dovecot/conf.d/10-auth.conf 
sudo sed -i "s/auth_username_format = %n/auth_username_format = %u/g" /etc/dovecot/conf.d/10-auth.conf
sudo sed -i "s/#!include auth-sql.conf.ext/!include auth-sql.conf.ext/g" /etc/dovecot/conf.d/10-auth.conf
sudo sed -i "s/!include auth-system.conf.ext/#!include auth-system.conf.ext/g" /etc/dovecot/conf.d/10-auth.conf
sudo cp dovecot-sql.conf.ext /etc/dovecot
sudo systemctl restart dovecot
sudo systemctl restart postfix
sudo gpasswd -a postfix opendkim
sudo cp opendkim.conf /etc
sudo mkdir -p /etc/opendkim/keys
sudo chown -R opendkim:opendkim /etc/opendkim
sudo chmod go-rw /etc/opendkim/keys
echo "*@$mydomain default._domainkey.$mydomain" | sudo tee /etc/opendkim/signing.table
echo "default._domainkey.$mydomain $mydomain:default:/etc/opendkim/keys/$mydomain/default.private" | sudo tee /etc/opendkim/key.table
echo "127.0.0.1" > trusted.hosts
echo "localhost" >> trusted.hosts
echo "*.$mydomain" >> trusted.hosts
sudo cp trusted.hosts /etc/opendkim/trusted.hosts
sudo mkdir /etc/opendkim/keys/$mydomain
sudo opendkim-genkey -b 2048 -d $mydomain -D /etc/opendkim/keys/$mydomain -s default -v
sudo chown opendkim:opendkim /etc/opendkim/keys/$mydomain/default.private
echo "Create a TXT default._domainkey with the following:"
sudo cat /etc/opendkim/keys/$mydomain/default.txt
echo "@ TXT \"v=spf1 mx ~all\""
echo "_dmarc TXT \"v=DMARC1; p=none; pct=100; rua=mailto:dmarc@$mydomain\""

sudo opendkim-testkey -d $mydomain -s default -vvv
sudo mkdir /var/spool/postfix/opendkim
sudo chown opendkim:postfix /var/spool/postfix/opendkim
sudo sed -i "s/RUNDIR=\/run\/opendkim/RUNDIR=\/var\/spool\/postfix\/opendkim/g" /etc/default/opendkim
sudo a2enmod proxy_fcgi setenvi
sudo a2enconf php7.4-fpm
sudo cp 01-netcfg.yaml /etc/netplan
sudo netplan apply

sudo systemctl restart opendkim postfix apache2
sudo systemctl enable spamassassin
sudo systemctl start spamassassin


echo "Now go to https://www.linuxbabe.com/mail-server/setting-up-dkim-and-spf"
echo "Now go to https://www.linuxbabe.com/mail-server/create-dmarc-record"
echo "Now go to https://www.linuxbabe.com/mail-server/how-to-stop-your-emails-being-marked-as-spam"

