#!/bin/bash
# jonathan@thoughtwave.com
NAME=${1:-$(hostname -f)}
echo 'deb https://download.jitsi.org stable/' | sudo tee /etc/apt/sources.list.d/jitsi-stable.list
wget -qO -  https://download.jitsi.org/jitsi-key.gpg.key | sudo apt-key add -
sudo apt -y install apt-transport-https
sudo apt -y update 
sudo apt -y install jitsi-meet
sudo ufw allow 80,443/tcp
sudo ufw allow 10000,5000/udp
sudo apt -y install certbot
sudo sed -i 's/\.\/certbot-auto/certbot/g' /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
sudo chmod ugo+x /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
sudo /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
sudo sed -i "s/\ ssl;/ ssl\ http2;/g" /etc/nginx/sites-enabled/*.conf
sudo systemctl reload nginx
sudo sed -i 's/authentication = "anonymous"/authentication = "internal_plain"/g' /etc/prosody/conf.d/*.cfg.lua
cat > /tmp/append <<EOF  
VirtualHost "guest.$NAME"
    authentication = "anonymous"
    c2s_require_encryption = false
EOF
cat /tmp/append | sudo tee -a /etc/prosody/conf.d/$NAME.cfg.lua
sudo sed -i "s/\/\/ anonymousdomain: 'guest.example.com'/anonymousdomain: 'guest.$NAME'/g" /etc/prosody/conf.d/*.cfg.lua
echo "org.jitsi.jicofo.auth.URL=XMPP:$NAME" |sudo tee -a /etc/jitsi/jicofo/sip-communicator.properties
sudo systemctl restart jitsi-videobridge2 prosody jicofo
sudo prosodyctl register admin $NAME
