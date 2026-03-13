#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# Fedora 42 homelab mail server bootstrap
# - Installs Docker CE on Fedora 42
# - Builds a single container running Postfix + Dovecot
# - POP3 enabled, plaintext only
# - PAM auth using local users inside the container
# - Local delivery only via Dovecot LMTP
# - No TLS, no certs, no outbound remote SMTP
#
# IMPORTANT:
#   1) Edit the variables in the CONFIG section before running.
#   2) Run this script as root.
#   3) Add mailbox users to MAIL_USERS below in user:password form.
###############################################################################

############################
# CONFIG - EDIT THESE
############################
MAIL_DOMAIN="${MAIL_DOMAIN:-fedora.mail}"
MAIL_HOSTNAME="${MAIL_HOSTNAME:-fedora.mail}"
STACK_DIR="${STACK_DIR:-/opt/local-mailserver}"

# Space-separated list of local mailbox users to create inside container.
# Format: "username:password username2:password2"
MAIL_USERS="${MAIL_USERS:-mailtest:changeme123 mailuser:changeme123}"

############################
# PRECHECKS
############################
if [[ $EUID -ne 0 ]]; then
  echo "Run this script as root."
  exit 1
fi

if [[ -z "${MAIL_USERS}" ]]; then
  echo "Set MAIL_USERS before running."
  exit 1
fi

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
      dovecot-core \
      dovecot-pop3d \
      dovecot-lmtpd \
      dovecot-pgsql \
      procps \
      tini \
      passwd && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/mail/vhosts \
             /var/spool/postfix/private \
             /etc/postfix \
             /etc/dovecot/conf.d

COPY build/postfix-main.cf /etc/postfix/main.cf
COPY build/postfix-master.cf /etc/postfix/master.cf

COPY build/dovecot.conf /etc/dovecot/dovecot.conf
COPY build/10-auth.conf /etc/dovecot/conf.d/10-auth.conf
COPY build/10-mail.conf /etc/dovecot/conf.d/10-mail.conf
COPY build/10-master.conf /etc/dovecot/conf.d/10-master.conf
COPY build/10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf
COPY build/15-lda.conf /etc/dovecot/conf.d/15-lda.conf
COPY build/20-lmtp.conf /etc/dovecot/conf.d/20-lmtp.conf
COPY build/auth-system.conf.ext /etc/dovecot/conf.d/auth-system.conf.ext

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

MAIL_USERS_FILE="/etc/mail-users"

mkdir -p /var/mail/vhosts /var/spool/postfix/private

if [[ -f "${MAIL_USERS_FILE}" ]]; then
  while IFS=: read -r user pass; do
    [[ -z "${user}" ]] && continue
    if ! id "${user}" >/dev/null 2>&1; then
      useradd -m -d "/var/mail/vhosts/${user}" -s /usr/sbin/nologin "${user}"
    fi
    echo "${user}:${pass}" | chpasswd
    mkdir -p "/var/mail/vhosts/${user}/Maildir"
    chown -R "${user}:${user}" "/var/mail/vhosts/${user}"
  done < "${MAIL_USERS_FILE}"
fi

postfix check
postfix start
exec dovecot -F
EOF

############################
# USER FILE
############################
: > "${STACK_DIR}/build/mail-users"
for pair in ${MAIL_USERS}; do
  echo "${pair}" >> "${STACK_DIR}/build/mail-users"
done

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
      - ${STACK_DIR}/build/mail-users:/etc/mail-users:ro,Z
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
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain

# Never relay off-box / off-domain
relay_domains =
local_transport = lmtp:unix:private/dovecot-lmtp
default_transport = error:outbound remote delivery disabled

# Basic SMTP restrictions
smtpd_recipient_restrictions =
    reject_non_fqdn_recipient,
    reject_unknown_recipient_domain,
    reject_unauth_destination,
    permit

# Plaintext / no TLS
smtpd_tls_security_level = none
smtp_tls_security_level = none
smtpd_use_tls = no
smtp_use_tls = no

append_dot_mydomain = no
biff = no
readme_directory = no
disable_vrfy_command = yes
mailbox_size_limit = 0
recipient_delimiter = +
message_size_limit = 26214400
home_mailbox = Maildir/
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
!include auth-system.conf.ext
EOF

cat > "${STACK_DIR}/build/auth-system.conf.ext" <<'EOF'
passdb {
  driver = pam
}

userdb {
  driver = passwd
}
EOF

cat > "${STACK_DIR}/build/10-mail.conf" <<'EOF'
mail_location = maildir:~/Maildir

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
- PAM auth using local users inside the container
- Local delivery via Dovecot LMTP
- No TLS anywhere
- No LDAP, no AD, no remote relay

Mailbox storage on host:
  ${STACK_DIR}/data/mail/<username>/Maildir

Configured users:
$(for pair in ${MAIL_USERS}; do echo "  - ${pair%%:*}@${MAIL_DOMAIN}  (login user: ${pair%%:*})"; done)

Notes:
- Users authenticate with their local username, not full email address.
- Mail addressed to local users at @${MAIL_DOMAIN} is delivered locally.
- Postfix will not send mail to any remote server.

Useful commands:
  docker compose -f ${STACK_DIR}/docker-compose.yml logs -f
  docker exec -it local-mailserver bash
  docker exec -it local-mailserver postconf -n
  docker exec -it local-mailserver doveconf -n
EOF
