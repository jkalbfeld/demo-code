#!/bin/bash
echo '"OPTIONS=${OPTIONS} -r 8"' | sudo tee -a /etc/default/spamass-milter

sudo sed -i "s/CRON=0/CRON=1/g" /etc/default/spamassassin
echo 'OPTIONS="${OPTIONS} -- --max-size=5120000"' | sudo tee -a /etc/default/spamassassin
sudo cat > local.cf <<EOF
header   FROM_SAME_AS_TO   ALL=~/\nFrom: ([^\n]+)\nTo: \1/sm
describe FROM_SAME_AS_TO   From address is the same as To address.
score    FROM_SAME_AS_TO   2.0
header    EMPTY_RETURN_PATH    ALL =~ /<>/i
describe  EMPTY_RETURN_PATH    empty address in the Return Path header.
score     EMPTY_RETURN_PATH    3.0
header    CUSTOM_DMARC_FAIL   Authentication-Results =~ /dmarc=fail/
describe  CUSTOM_DMARC_FAIL   This email failed DMARC check
score     CUSTOM_DMARC_FAIL   3.0
body      BE_POLITE       /(hi|hello|dear) xiao\@linuxbabe\.com/i
describe  BE_POLITE       This email does not use a proper name for the recipient
score     BE_POLITE       5.0
body      GOOD_EMAIL    /(debian|ubuntu|linux mint|centos|red hat|RHEL|OpenSUSE|Fedora|Arch Linux|Raspberry Pi|Kali Linux)/i
describe  GOOD_EMAIL    I do not think spammer would include these words in the email body.
score     GOOD_EMAIL    -4.0
body      BOUNCE_MSG    /(Undelivered Mail Returned to Sender|Undeliverable|Auto-Reply|Automatic reply)/i
describe  BOUNCE_MSG    Undelivered mail notifications or auto-reply messages
score     BOUNCE_MSG    -1.5
EOF
sudo cp local.cf /etc/spamassassin/
sudo systemctl restart postfix spamass-milter
sudo systemctl enable spamassassin
sudo systemctl start spamassassin
sudo systemctl restart spamassassin

sudo apt install -y dovecot-sieve
cat > 15-lda-append.conf <<EOF
protocol lda {
    # Space separated list of plugins to load (default is global mail_plugins).
    mail_plugins = $mail_plugins sieve
}
EOF
cat 15-lda-append.conf | sudo tee -a /etc/dovecot/conf.d/15-lda.conf

cat > 20-lmtp-append.conf <<EOF
protocol lmtp {
      mail_plugins = quota sieve
}
EOF
sudo cp 20-lmtp-append.conf /etc/dovecot/conf.d/20-lmtp.conf



cat > 90-sieve-replace.conf <<EOF
plugin {
  sieve = file:~/sieve;active=~/.dovecot.sieve
  sieve_before = /var/mail/SpamToJunk.sieve
}
EOF
sudo cp 90-sieve-replace.conf /etc/dovecot/conf.d/90-sieve.conf

cat > SpamToJunk.sieve <<EOF
require "fileinto";

if header :contains "X-Spam-Flag" "YES"
{
   fileinto "Junk";
   stop;
}
EOF
sudo cp SpamToJunk.sieve /var/mail/

sudo sievec /var/mail/SpamToJunk.sieve
sudo systemctl restart dovecot

cat > smtp_header_checks <<EOF
/^X-Spam-Checker-Version:/    IGNORE
EOF
sudo cp smtp_header_checks /etc/postfix
sudo postmap /etc/postfix/smtp_header_checks
sudo systemctl reload postfix
