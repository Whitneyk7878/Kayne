sed -i 's|ssl_cert = </etc/pki/dovecot/certs/dovecot.pem|ssl_cert = </etc/dovecot/ssl/dovecot.crt|' /etc/dovecot/conf.d/10-ssl.conf
sed -i 's|ssl_key = </etc/pki/dovecot/private/dovecot.pem|ssl_key = </etc/dovecot/ssl/dovecot.pem|' /etc/dovecot/conf.d/10-ssl.conf
sed -i 's|#ssl_protocols = !SSLv2|ssl_protocols = !SSLv3 !TLSv1 !TLSv1.1|' /etc/dovecot/conf.d/10-ssl.conf
