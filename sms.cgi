#!/usr/bin/python3.7
#
# (c) 2020 - Jonathan Kalbfeld
# To use this, send a text with the word ASSISTANCE
# to 888-383-3249
#
#
import cgi
import smtplib
import subprocess
import email
import re
import logging
import signalwire
import os
from email.mime.text import MIMEText
from email.message import EmailMessage
from signalwire.rest import Client as signalwire_client

client = signalwire_client("-secret-", "-secret-", signalwire_space_url = 'thoughtwave.signalwire.com')

form = cgi.FieldStorage()


print("Content-type: text/html\n\n");
print("This is not a public endpoint.");

smtp_ssl_host = 'po.thoughtwave.com' 
smtp_ssl_port = 465
username = 'sms@thoughtwave.com'
password = '-secret-'

for param in form.keys():
    print("<b>%20s</b>: %s<br/>" % (param, form[param]))

sendernum = str(form.getvalue("From"))
sn = sendernum[1:]


sender = sendernum + " <sms@thoughtwave.com>"
destination = str(form.getvalue("To"))
targets = [destination + " <jonathan@thoughtwave.com>",destination + " <textreply@thoughtwave.com>","3102271662@tmomail.net"]

body = str(form.getvalue('Body'))
uuid = str(form.getvalue('MessageSid'))


message_body = "Please visit https://meet.thoughtwave.com/" + uuid + " and wait for the host to join"
uhd_message_body = "Please visit https://uhd.thoughtwave.com/" + uuid + " and wait for the host to join"
announcement = ""
helptext = """
ASSISTANCE display this message
MEETING request a meeting
URGENT MEETING request an urgent meeting
911 request a call now
"""

if (body.upper() == 'ASSISTANCE'):
    message = client.messages.create(from_='+13103177900', body=helptext, to=sendernum)

if (body.upper() == 'SCHEDULE'):
    message = client.messages.create(from_='+13103177900', body=message_body, to=sendernum)
    announcement = " (" + message_body + ") for an expert witness call with " + sendernum

if (body.upper() == 'MEETING'):
    message = client.messages.create(from_='+13103177900', body=message_body, to=sendernum)
    announcement = " (" + message_body + ") for a call with " + sendernum

if (body.upper() == 'URGENT MEETING'):
    message = client.messages.create(from_='+13103177900', body=message_body, to=sendernum)
    announcement = " (" + message_body + ") for an URGENT call with " + sendernum

if (body.upper() == '911'):
    message = client.messages.create(from_='+13103177911', body=message_body, to=sendernum)
    announcement = " (" + message_body + ") for an URGENT call with " + sendernum
    file = open("/var/spool/asterisk/outgoing/" + sn + ".call","w")
    file.write("Channel: SIP/" + sn + "@voipms\n")
    file.write("CallerID: \"ThoughtWave Technologies\" <13103177900>\n")
    file.write("MaxRetries: 2\n")
    file.write("RetryTime: 60\n")
    file.write("WaitTime: 30\n")
    file.write("Context: default\n")
    file.write("Extension: collaborate\n")
    file.write("Priority: 1\n")
    file.write("Setvar=CALLERID="+sn)
    file.close()
    os.chmod("/var/spool/asterisk/outgoing/" + sn + ".call", 0o777)

if (body.upper() == 'UHD'):
    message = client.messages.create(from_='+13103177900', body=uhd_message_body, to=sendernum)
    announcement = " (" + uhd_message_body + ") for an UHD call with " + sendernum

if (body.upper() != 'ASSISTANCE'):
    if (sendernum != 'None'):
        file = open("/tmp/inbound.txt","w")
        file.write(body)
        file.close()
        os.system("/usr/bin/pico2wave -w /usr/share/asterisk/sounds/report.wav < /tmp/inbound.txt")

        msg = EmailMessage()
        msg['Subject'] = "Inbound SMS message to " + destination
        msg['From'] = sender
        msg['To'] = ', '.join(targets)
        msg.set_payload(body + announcement)
        server = smtplib.SMTP_SSL(smtp_ssl_host, smtp_ssl_port)
        server.login(username, password)
        server.sendmail(sender, targets, msg.as_string())
        server.quit()
