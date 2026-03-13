#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# Fedora 42 homelab mail server bootstrap
# - Installs Docker CE on Fedora 42
# - Builds a single container running Postfix + Dovecot
# - POP3 enabled, plaintext only
# - LDAP/AD auth for mailbox logins
# - Postfix uses LDAP to validate local recipients
# - Local delivery only via Dovecot LMTP
# - No TLS, no certs, no outbound remote SMTP
#
# IMPORTANT:
#   1) Edit the variables in the CONFIG section before running.
#   2) Run this script as root.
#   3) Users must log in with full email address by default.
###############################################################################

############################
# CONFIG - EDIT THESE
############################
MAIL_DOMAIN="${MAIL_DOMAIN:-example.lab}"
MAIL_HOSTNAME="${MAIL_HOSTNAME:-mail.example.lab}"

# AD / LDAP
AD_LDAP_HOST="${AD_LDAP_HOST:-CHANGE_ME_AD_HOST}"
AD_LDAP_PORT="${AD_LDAP_PORT:-389}"
AD_BASE_DN="${AD_BASE_DN:-DC=example,DC=lab}"
AD_BIND_DN="${AD_BIND_DN:-CN=svc-mail-lookup,OU=Service Accounts,DC=example,DC=lab}"
AD_BIND_PW="${AD_BIND_PW:-CHANGE_ME_AD_BIND_PASSWORD}"

# Optional custom LDAP filters:
# Default assumes mailbox users are AD users with a populated "mail" attribute.
# If needed, tighten these with group membership filters.
DOVECOT_PASS_FILTER="${DOVECOT_PASS_FILTER:-(&(objectClass=user)(mail=%u))}"
POSTFIX_QUERY_FILTER="${POSTFIX_QUERY_FILTER:-(&(objectClass=user)(mail=%s))}"

# Where to place the generated stack
STACK_DIR="${STACK_DIR:-/opt/local-mailserver}"

############################
# PRECHECKS
############################
if [[ $EUID -ne 0 ]]; then
  echo "Run this script as root."
  exit 1
fi

for v in AD_LDAP_HOST AD_BASE_DN AD_BIND_DN AD_BIND_PW; do
  if [[ "${!v}" == CHANGE_ME* ]]; then
    echo "You must set $v before running."
    exit 1
  fi
done

echo "==> Installing prerequisites on Fedora..."
dnf -y install dnf-plugins-core firewalld curl ca-certificates

echo "==> Removing any conflicting Docker packages (ignore failures if not present)..."
dnf -y remove docker docker-client docker-client-latest docker-common docker-latest \
  docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux \
  docker-engine moby-engine containerd runc || true

echo "==> Adding Docker CE repo..."
dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo

echo "==> Installing Docker CE..."
dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Enabling Docker and firewalld..."
systemctl enable --now docker
systemctl enable --now firewalld

echo "==> Opening firewall ports 25/tcp and 110/tcp..."
firewall-cmd --permanent --add-service=smtp || true
firewall-cmd --permanent --add-port=110/tcp || true
firewall-cmd --reload || true

echo "==> Creating stack directories..."
mkdir -p "${STACK_DIR}"/{data/mail,build}
cd "${STACK_DIR}"

############################
# DOCKERFILE
############################
cat > "${STACK_DIR}/Dockerfile" <<'EOF'
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      postfix \
      postfix-ldap \
      dovecot-core \
      dovecot-pop3d \
      dovecot-lmtpd \
      dovecot-ldap \
      ldap-utils \
      procps \
      tini && \
    rm -rf /var/lib/apt/lists/*

# Create vmail user/group for mailbox ownership
RUN groupadd -g 2000 vmail && \
    useradd -r -u 2000 -g vmail -d /var/mail/vhosts -s /usr/sbin/nologin vmail

# Prepare filesystem
RUN mkdir -p /var/mail/vhosts \
             /var/spool/postfix/private \
             /etc/postfix \
             /etc/dovecot/conf.d && \
    chown -R vmail:vmail /var/mail/vhosts

COPY build/postfix-main.cf /etc/postfix/main.cf
COPY build/postfix-master.cf /etc/postfix/master.cf
COPY build/postfix-ldap-users.cf /etc/postfix/ldap-users.cf

COPY build/dovecot.conf /etc/dovecot/dovecot.conf
COPY build/10-auth.conf /etc/dovecot/conf.d/10-auth.conf
COPY build/10-mail.conf /etc/dovecot/conf.d/10-mail.conf
COPY build/10-master.conf /etc/dovecot/conf.d/10-master.conf
COPY build/10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf
COPY build/15-lda.conf /etc/dovecot/conf.d/15-lda.conf
COPY build/20-lmtp.conf /etc/dovecot/conf.d/20-lmtp.conf
COPY build/auth-ldap.conf.ext /etc/dovecot/conf.d/auth-ldap.conf.ext
COPY build/dovecot-ldap.conf.ext /etc/dovecot/dovecot-ldap.conf.ext

COPY build/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 25 110

ENTRYPOINT ["/usr/bin/tini","--","/entrypoint.sh"]
EOF

############################
# ENTRYPOINT
############################
cat > "${STACK_DIR}/build/entrypoint.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p /var/mail/vhosts /var/spool/postfix/private
chown -R vmail:vmail /var/mail/vhosts

# Postfix wants these
postfix check

# Start Postfix in background
postfix start

# Run Dovecot in foreground
exec dovecot -F
EOF

############################
# DOCKER COMPOSE
############################
cat > "${STACK_DIR}/docker-compose.yml" <<EOF
services:
  mailserver:
    build: .
    container_name: local-mailserver
    hostname: ${MAIL_HOSTNAME}
    restart: unless-stopped
    network_mode: host
    volumes:
      - ${STACK_DIR}/data/mail:/var/mail/vhosts:Z
EOF

############################
# POSTFIX CONFIG
############################
cat > "${STACK_DIR}/build/postfix-main.cf" <<EOF
compatibility_level = 3.7

myhostname = ${MAIL_HOSTNAME}
mydomain = ${MAIL_DOMAIN}
myorigin = \$mydomain

inet_interfaces = all
inet_protocols = ipv4

# Only accept mail for this local domain
mydestination = localhost
virtual_mailbox_domains = ${MAIL_DOMAIN}
virtual_mailbox_maps = ldap:/etc/postfix/ldap-users.cf
virtual_transport = lmtp:unix:private/dovecot-lmtp

# Never relay off-box / off-domain
relay_domains =
local_transport = error:local delivery disabled
default_transport = error:outbound remote delivery disabled

# Basic SMTP restrictions
smtpd_recipient_restrictions =
    reject_non_fqdn_recipient,
    reject_unknown_recipient_domain,
    reject_unauth_destination

# Plaintext / no TLS
smtpd_tls_security_level = none
smtp_tls_security_level = none
smtpd_use_tls = no
smtp_use_tls = no

# General behavior
append_dot_mydomain = no
biff = no
readme_directory = no
disable_vrfy_command = yes
mailbox_size_limit = 0
recipient_delimiter = +
message_size_limit = 26214400
EOF

cat > "${STACK_DIR}/build/postfix-master.cf" <<'EOF'
smtp      inet  n       -       y       -       -       smtpd
pickup    unix  n       -       y       60      1       pickup
cleanup   unix  n       -       y       -       0       cleanup
qmgr      unix  n       -       n       300     1       qmgr
tlsmgr    unix  -       -       y       1000?   1       tlsmgr
rewrite   unix  -       -       y       -       -       trivial-rewrite
bounce    unix  -       -       y       -       0       bounce
defer     unix  -       -       y       -       0       bounce
trace     unix  -       -       y       -       0       bounce
verify    unix  -       -       y       -       1       verify
flush     unix  n       -       y       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       y       -       -       smtp
relay     unix  -       -       y       -       -       smtp
showq     unix  n       -       y       -       -       showq
error     unix  -       -       y       -       -       error
retry     unix  -       -       y       -       -       error
discard   unix  -       -       y       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       y       -       -       lmtp
anvil     unix  -       -       y       -       1       anvil
scache    unix  -       -       y       -       1       scache
EOF

cat > "${STACK_DIR}/build/postfix-ldap-users.cf" <<EOF
server_host = ${AD_LDAP_HOST}
server_port = ${AD_LDAP_PORT}
version = 3

bind = yes
bind_dn = ${AD_BIND_DN}
bind_pw = ${AD_BIND_PW}

search_base = ${AD_BASE_DN}
scope = sub
start_tls = no

query_filter = ${POSTFIX_QUERY_FILTER}
result_attribute = mail
EOF

############################
# DOVECOT CONFIG
############################
cat > "${STACK_DIR}/build/dovecot.conf" <<'EOF'
!include_try /usr/share/dovecot/protocols.d/*.protocol
!include conf.d/*.conf
!include_try local.conf
EOF

cat > "${STACK_DIR}/build/10-auth.conf" <<'EOF'
disable_plaintext_auth = no
auth_mechanisms = plain login
#!include auth-system.conf.ext
!include auth-ldap.conf.ext
EOF

cat > "${STACK_DIR}/build/auth-ldap.conf.ext" <<'EOF'
passdb {
  driver = ldap
  args = /etc/dovecot/dovecot-ldap.conf.ext
}

userdb {
  driver = static
  args = uid=vmail gid=vmail home=/var/mail/vhosts/%d/%n mail=maildir:/var/mail/vhosts/%d/%n/Maildir
}
EOF

cat > "${STACK_DIR}/build/10-mail.conf" <<'EOF'
mail_location = maildir:/var/mail/vhosts/%d/%n/Maildir
first_valid_uid = 2000
last_valid_uid = 2000
mail_uid = 2000
mail_gid = 2000

namespace inbox {
  inbox = yes
}
EOF

cat > "${STACK_DIR}/build/10-master.conf" <<'EOF'
service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    user = postfix
    group = postfix
    mode = 0600
  }
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    user = postfix
    group = postfix
    mode = 0660
  }
}
EOF

cat > "${STACK_DIR}/build/10-ssl.conf" <<'EOF'
ssl = no
verbose_ssl = no
EOF

cat > "${STACK_DIR}/build/15-lda.conf" <<EOF
postmaster_address = postmaster@${MAIL_DOMAIN}
EOF

cat > "${STACK_DIR}/build/20-lmtp.conf" <<EOF
protocols = pop3 lmtp

protocol lmtp {
  postmaster_address = postmaster@${MAIL_DOMAIN}
}
EOF

cat > "${STACK_DIR}/build/dovecot-ldap.conf.ext" <<EOF
hosts = ${AD_LDAP_HOST}:${AD_LDAP_PORT}
ldap_version = 3
dn = ${AD_BIND_DN}
dnpass = ${AD_BIND_PW}
base = ${AD_BASE_DN}
scope = subtree
deref = never
auth_bind = yes

# Users authenticate with full email address by default.
pass_filter = ${DOVECOT_PASS_FILTER}

# No password lookup here because auth_bind handles password verification.
# Keep username unchanged.
pass_attrs = =user=%u
EOF

############################
# BUILD + START
############################
echo "==> Building container image..."
docker compose build --no-cache

echo "==> Starting mail server..."
docker compose up -d

echo
echo "==> Container status:"
docker compose ps

echo
echo "==> Recent logs:"
docker compose logs --tail=100

cat <<EOF

DONE.

What is now running:
- SMTP on port 25
- POP3 on port 110
- LDAP auth against AD for Dovecot logins
- Postfix recipient validation against AD LDAP
- Local delivery via Dovecot LMTP
- No TLS anywhere

Mailbox path on host:
  ${STACK_DIR}/data/mail/<domain>/<user>/Maildir

Test ideas:
  1) From another machine, connect POP3 to:
       server: ${MAIL_HOSTNAME} or this server IP
       port:   110
       user:   user@${MAIL_DOMAIN}
  2) Send a local-domain message:
       swaks --server <server-ip> --to user@${MAIL_DOMAIN} --from test@${MAIL_DOMAIN}
  3) Check logs:
       docker compose -f ${STACK_DIR}/docker-compose.yml logs -f

If your AD users do NOT log in with "mail" matching their mailbox address,
adjust these two variables and re-run:
  DOVECOT_PASS_FILTER
  POSTFIX_QUERY_FILTER

Common AD alternatives:
  DOVECOT_PASS_FILTER='(&(objectClass=user)(userPrincipalName=%u))'
  POSTFIX_QUERY_FILTER='(&(objectClass=user)(userPrincipalName=%s))'
EOF
