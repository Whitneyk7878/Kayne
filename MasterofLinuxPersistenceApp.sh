#!/usr/bin/env bash
# ==============================================================================
# Linux Persistence Response Console (Text-only interactive Bash TUI)
# - Menu-driven threat hunting + persistence monitoring based on provided playbook
# - OS-family selection at startup (Debian/RHEL/etc) to adapt commands/paths
# - Always-visible menu: screen redraw keeps menu at top; output scrolls beneath
#
# Safety posture:
# - "Monitor/Audit" actions are default.
# - Remediation actions exist, but require explicit confirmations.
# - Prefer running as root for best coverage.
# ==============================================================================

set -u
IFS=$'\n\t'

# ------------------------------- Globals --------------------------------------
APP_NAME="Linux Persistence Console"
APP_VER="1.0"
LOGFILE=""
QUAR_DIR=""
OS_FAMILY="unknown"      # debian|rhel|arch|suse|alpine|other
INIT_SYSTEM="unknown"    # systemd|openrc|sysv|unknown
PKG_MGR="unknown"        # apt|dnf|yum|pacman|zypper|apk|unknown
AUTH_LOGS=()             # candidate auth log files
CRON_SVC=""              # cron vs crond
SUDO_GROUP=""            # sudo vs wheel
SYSTEMD_LIB_DIRS=()      # /lib/systemd/system or /usr/lib/systemd/system etc
NEED_REDRAW=1
LAST_MENU=""
MENU_STACK=("main")
################################################# CUSTOM ###############################################

view_full_output() {
  if command -v less >/dev/null 2>&1; then
    less -R +G "$LOGFILE"
  else
    echo "less not found. Install it or use: cat \"$LOGFILE\" | more"
    read -r _
  fi
}

######################################################################################################



# ------------------------------ Utilities -------------------------------------
ts() { date +"%Y-%m-%d %H:%M:%S"; }

is_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]]; }

have() { command -v "$1" >/dev/null 2>&1; }

hr() {
  local cols
  cols="$(tput cols 2>/dev/null || echo 80)"
  printf '%*s\n' "$cols" '' | tr ' ' '-'
}

append_log() {
  # Always prefix with timestamp
  local line="${1:-}"
  printf "[%s] %s\n" "$(ts)" "$line" >> "$LOGFILE"
}

log_block() {
  # Usage: log_block "Title" "command string"
  local title="$1"
  local cmd="$2"
  append_log "=== $title ==="
  append_log "CMD: $cmd"
  # Run via bash -c so users can pass compound commands
  # shellcheck disable=SC2086
  bash -c "$cmd" >>"$LOGFILE" 2>&1
  append_log ""
}

require_root_or_warn() {
  local why="${1:-This action works best as root.}"
  if ! is_root; then
    append_log "WARNING: Not running as root. Some results may be incomplete."
    append_log "         $why"
    append_log ""
    return 1
  fi
  return 0
}

confirm() {
  # confirm "Prompt"
  local prompt="${1:-Are you sure?}"
  local ans
  while true; do
    echo -n "$prompt [y/N]: "
    read -r ans
    case "${ans,,}" in
      y|yes) return 0 ;;
      n|no|"") return 1 ;;
      *) echo "Please enter y or n." ;;
    esac
  done
}

push_menu() { MENU_STACK+=("$1"); }
pop_menu() {
  if ((${#MENU_STACK[@]} > 1)); then
    unset 'MENU_STACK[-1]'
  fi
}
cur_menu() { echo "${MENU_STACK[-1]}"; }

set_redraw() { NEED_REDRAW=1; }
on_winch() { set_redraw; }
trap on_winch SIGWINCH

cleanup() {
  # Keep log by default; just remove temp quarantine dir if empty or not created
  :
}
trap cleanup EXIT

# ------------------------------ OS Detection ----------------------------------
autodetect_os_family() {
  local id_like id
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-}"
    id_like="${ID_LIKE:-}"
    case "${id}" in
      debian|ubuntu|linuxmint|kali) echo "debian"; return ;;
      rhel|centos|fedora|rocky|almalinux|ol) echo "rhel"; return ;;
      arch|manjaro) echo "arch"; return ;;
      suse|opensuse*|sles) echo "suse"; return ;;
      alpine) echo "alpine"; return ;;
    esac
    # fallback on ID_LIKE
    if [[ "$id_like" == *debian* ]]; then echo "debian"; return; fi
    if [[ "$id_like" == *rhel* ]] || [[ "$id_like" == *fedora* ]]; then echo "rhel"; return; fi
    if [[ "$id_like" == *arch* ]]; then echo "arch"; return; fi
    if [[ "$id_like" == *suse* ]]; then echo "suse"; return; fi
  fi
  echo "other"
}

detect_init_system() {
  if have systemctl && [[ -d /run/systemd/system ]]; then
    echo "systemd"
  elif have rc-service || [[ -d /run/openrc ]]; then
    echo "openrc"
  elif have service; then
    echo "sysv"
  else
    echo "unknown"
  fi
}

set_family_defaults() {
  INIT_SYSTEM="$(detect_init_system)"

  case "$OS_FAMILY" in
    debian)
      PKG_MGR="apt"
      AUTH_LOGS=("/var/log/auth.log" "/var/log/secure")
      CRON_SVC="cron"
      SUDO_GROUP="sudo"
      SYSTEMD_LIB_DIRS=("/lib/systemd/system" "/usr/lib/systemd/system" "/etc/systemd/system")
      ;;
    rhel)
      PKG_MGR="dnf"
      have dnf || PKG_MGR="yum"
      AUTH_LOGS=("/var/log/secure" "/var/log/auth.log")
      CRON_SVC="crond"
      SUDO_GROUP="wheel"
      SYSTEMD_LIB_DIRS=("/usr/lib/systemd/system" "/etc/systemd/system" "/lib/systemd/system")
      ;;
    arch)
      PKG_MGR="pacman"
      AUTH_LOGS=("/var/log/auth.log" "/var/log/secure" "/var/log/journal")
      CRON_SVC="cronie"
      SUDO_GROUP="wheel"
      SYSTEMD_LIB_DIRS=("/usr/lib/systemd/system" "/etc/systemd/system")
      ;;
    suse)
      PKG_MGR="zypper"
      AUTH_LOGS=("/var/log/messages" "/var/log/audit/audit.log" "/var/log/secure" "/var/log/auth.log")
      CRON_SVC="cron"
      SUDO_GROUP="wheel"
      SYSTEMD_LIB_DIRS=("/usr/lib/systemd/system" "/etc/systemd/system" "/lib/systemd/system")
      ;;
    alpine)
      PKG_MGR="apk"
      AUTH_LOGS=("/var/log/messages" "/var/log/auth.log")
      CRON_SVC="crond"
      SUDO_GROUP="wheel"
      SYSTEMD_LIB_DIRS=()
      ;;
    *)
      PKG_MGR="unknown"
      AUTH_LOGS=("/var/log/auth.log" "/var/log/secure" "/var/log/messages")
      CRON_SVC="cron"
      SUDO_GROUP="sudo"
      SYSTEMD_LIB_DIRS=("/etc/systemd/system" "/usr/lib/systemd/system" "/lib/systemd/system")
      ;;
  esac
}

choose_os_family_interactive() {
  local autod
  autod="$(autodetect_os_family)"

  clear
  echo "$APP_NAME v$APP_VER"
  hr
  echo "Select OS family (this drives which commands/paths are used)."
  echo "Auto-detected: $autod"
  echo
  echo "  1) Debian/Ubuntu/Kali (apt, /var/log/auth.log)"
  echo "  2) RHEL/Fedora/CentOS/Rocky/Alma (dnf/yum, /var/log/secure)"
  echo "  3) Arch/Manjaro (pacman)"
  echo "  4) SUSE/openSUSE (zypper)"
  echo "  5) Alpine (apk / OpenRC common)"
  echo "  6) Other / mixed"
  echo
  echo -n "Choice [default: autodetect=$autod]: "
  local c
  read -r c

  case "$c" in
    1) OS_FAMILY="debian" ;;
    2) OS_FAMILY="rhel" ;;
    3) OS_FAMILY="arch" ;;
    4) OS_FAMILY="suse" ;;
    5) OS_FAMILY="alpine" ;;
    6) OS_FAMILY="other" ;;
    "" ) OS_FAMILY="$autod" ;;
    * ) OS_FAMILY="$autod" ;;
  esac

  set_family_defaults
}

init_runtime() {
  LOGFILE="$(mktemp -t persistence_console.XXXXXX.log)"
  QUAR_DIR="$(mktemp -d -t persistence_quarantine.XXXXXX)"
  append_log "$APP_NAME v$APP_VER started"
  append_log "Log file: $LOGFILE"
  append_log "Quarantine dir: $QUAR_DIR"
  append_log ""
}

# ------------------------------ UI Rendering ----------------------------------
menu_title() {
  case "$(cur_menu)" in
    main) echo "Main Menu" ;;
    quick) echo "Quick Actions (Course of Action)" ;;
    accounts) echo "Accounts & Credentials" ;;
    shells) echo "Shell / Profile Persistence" ;;
    sched) echo "Scheduled Tasks (cron/at/timers/anacron)" ;;
    services) echo "Services & Daemons (init systems)" ;;
    boot) echo "Bootloader / Initramfs / Kernel Modules" ;;
    libs) echo "Libraries / Dynamic Loader Hijacking" ;;
    device) echo "Device & Event-Triggered Execution (udev/acpi)" ;;
    apps) echo "Application-Specific Persistence (web/app services)" ;;
    hijack) echo "Binary & Filesystem Hijacking (PATH/aliases/SUID)" ;;
    logs) echo "Logs / Anti-Forensics Adjacent" ;;
    weird) echo "Weird / Niche Checks (tmp/hidden)" ;;
    reports) echo "Reports / Utilities" ;;
    *) echo "Menu" ;;
  esac
}

breadcrumb() {
  local out=""; local m
  for m in "${MENU_STACK[@]}"; do
    out+="$m > "
  done
  echo "${out% > }"
}

print_header() {
  local host user now cols
  host="$(hostname 2>/dev/null || echo "unknown-host")"
  user="$(whoami 2>/dev/null || echo "unknown-user")"
  now="$(ts)"
  cols="$(tput cols 2>/dev/null || echo 80)"

  echo "$APP_NAME v$APP_VER"
  hr
  printf "Host: %s | User: %s | Time: %s\n" "$host" "$user" "$now"
  printf "OS Family: %s | Init: %s | Pkg: %s | Root: %s\n" "$OS_FAMILY" "$INIT_SYSTEM" "$PKG_MGR" "$(is_root && echo yes || echo no)"
  printf "Path: %s\n" "$(breadcrumb)"
  hr
  echo "Controls: enter option number/letter, 'b' back, 'r' refresh, 'c' clear output, 's' save report, 'q' quit"
  hr
}

print_menu() {
  local m
  m="$(cur_menu)"
  case "$m" in
    main)
      cat <<'EOF'
  1) Quick Actions (recommended sequence)
  2) Accounts & Credentials
  3) Shell / Profile Persistence
  4) Scheduled Tasks (cron/at/timers)
  5) Services & Daemons
  6) Boot / Kernel / Initramfs
  7) Libraries / Loader Hijacking
  8) Device & Event Triggers (udev/acpi)
  9) Application Persistence (web/app)
 10) Binary/File Hijacks (PATH/aliases/SUID)
 11) Logs / Anti-Forensics Adjacent
 12) Weird / Niche Checks
 13) Reports / Utilities
EOF
      ;;
    quick)
      cat <<'EOF'
  1) Change password (passwd <user>)
  2) Who is logged in? (who / w)
  3) Audit users (getent passwd summary)
  4) "Modify user permissions" helper (review sudo/wheel, shells, lock users)
  5) Disable "dodgy services" helper (sshd/telnet/cockpit/etc)
  6) Firewall status + rules view (iptables/nft/ufw/firewalld)
  7) Apply basic firewall baseline (optional; confirm)
  8) Cron + AT sweep (all users + system)
  9) Find executables created in last hour (fast/slow modes)
 10) Find services created in last hour (systemd unit file hunt)
 11) Command history/journal hunting (24h) (journalctl grep)
EOF
      ;;
    accounts)
      cat <<'EOF'
  1) List all accounts (getent passwd w/ UID/GID/Home/Shell)
  2) Find suspicious UID 0 accounts (besides root)
  3) Find "system users" with real shells (UID<1000 + /bin/bash etc)
  4) Find odd home directories (/tmp,/var/tmp,/var/www,/dev/shm)
  5) Check password change timeline (chage -l root + chosen user)
  6) Search auth logs for passwd/chpasswd/useradd/usermod
  7) Audit sudoers: list /etc/sudoers.d + sudo -l -U user
  8) Remediation: lock user / set nologin shell / delete user (confirm)
EOF
      ;;
    shells)
      cat <<'EOF'
  1) Scan user shell startup files (~/.bashrc, ~/.profile, ~/.zshrc, etc)
  2) Scan global profiles (/etc/profile, /etc/bashrc, /etc/profile.d/*)
  3) Check /etc/environment and /etc/login.defs for LD_*/PATH/UID_MIN changes
  4) Check /etc/skel for template abuse
  5) Grep for suspicious strings across /etc and /home (curl|wget|base64|/dev/tcp|LD_PRELOAD)
EOF
      ;;
    sched)
      cat <<'EOF'
  1) Dump all user crontabs + system cron directories
  2) List recently modified cron files (mtime window)
  3) AT jobs: list (atq) + show job (at -c JOBID)
  4) systemd timers: list + inspect a timer/service (systemctl cat)
  5) anacron: view /etc/anacrontab
  6) Restart scheduler service (cron/crond) (confirm)
EOF
      ;;
    services)
      cat <<'EOF'
  1) systemd: list unit files (services) + highlight suspicious names
  2) systemd: inspect unit (systemctl cat <name>)
  3) systemd: disable/stop service or timer (confirm)
  4) systemd user services: list for a user + check lingering
  5) SysV init scripts: list /etc/init.d and rc*.d links
  6) rc.local: show and permissions check
  7) inetd/xinetd: show configs if present
  8) NetworkManager dispatcher scripts: list + view
EOF
      ;;
    boot)
      cat <<'EOF'
  1) GRUB configs: show /etc/default/grub and grub.cfg path(s)
  2) Search GRUB for suspicious kernel params (init=, rdinit=)
  3) Initramfs build hooks: Debian initramfs-tools / RHEL dracut configs
  4) List loaded kernel modules (lsmod) + look for odd module names
  5) Check modules-load.d and modprobe.d for forced loads
  6) Rebuild initramfs (optional; confirm) [Debian:update-initramfs | RHEL:dracut]
EOF
      ;;
    libs)
      cat <<'EOF'
  1) Check /etc/ld.so.preload (existence + contents)
  2) Search for LD_PRELOAD / LD_LIBRARY_PATH definitions (etc + home)
  3) Package verification (rpm -Va | debsums -s | pacman -Qkk) (best-effort)
  4) List recently modified shared libraries in common lib dirs
  5) Run ldconfig (confirm)
EOF
      ;;
    device)
      cat <<'EOF'
  1) udev rules: list /etc/udev/rules.d and grep RUN+= / PROGRAM=
  2) ACPI scripts: list /etc/acpi, /etc/acpi/events (if present)
  3) Reload udev rules + trigger (confirm; cautious)
EOF
      ;;
    apps)
      cat <<'EOF'
  1) Web root quick scan: recently modified files (common roots)
  2) Search for suspicious script extensions in web roots (.php in upload dirs, etc) (best-effort)
  3) App service files under /etc/systemd/system matching app* or custom
  4) Scan /opt and /usr/local for recently modified executables
EOF
      ;;
    hijack)
      cat <<'EOF'
  1) PATH inspection for users (su - user -c 'echo $PATH') (requires root for other users)
  2) Find attacker-controlled PATH dirs that precede /usr/bin (/tmp,/dev/shm,etc)
  3) Alias/function scan in shell configs (grep alias/function for common cmds)
  4) Binary integrity spot-check: 'file' on critical binaries + pkg verify hint
  5) SUID/SGID inventory (find -perm -4000/-2000)
  6) Recent executables in world-writable dirs (/tmp,/var/tmp,/dev/shm)
EOF
      ;;
    logs)
      cat <<'EOF'
  1) logrotate configs: inspect /etc/logrotate.conf and /etc/logrotate.d/*
  2) Monitoring/backup agent directories (zabbix/nagios/nrpe/backup.d) presence scan
  3) Auth log grep (passwd|chpasswd|useradd|usermod|sudo) across known log paths
  4) journalctl 24h: grep COMMAND=|execve|sudo
EOF
      ;;
    weird)
      cat <<'EOF'
  1) /tmp,/var/tmp,/dev/shm recent files (mtime window)
  2) Hidden files/dirs quick scan (limited depth; avoid full / by default)
  3) Full persistence "sweep" (runs many read-only checks; can take time)
EOF
      ;;
    reports)
      cat <<'EOF'
  1) Save current log to ./persistence_report_<timestamp>.log
  2) Save + collect key artifacts into tar.gz (paths list; best-effort)
  3) Show where quarantine dir is (for files you move manually)
  4) Clear output log
EOF
      ;;
    *)
      echo "No menu."
      ;;
  esac
}

draw_screen() {
  local lines cols ui_lines avail
  lines="$(tput lines 2>/dev/null || echo 40)"
  cols="$(tput cols 2>/dev/null || echo 80)"

  clear
  ui_lines=0

  # Capture header into screen and count lines roughly
  print_header; ui_lines=$((ui_lines + 7))
  print_menu
  # Count menu lines by estimating: re-render menu into wc -l
  ui_lines=$((ui_lines + $(print_menu | wc -l | tr -d ' ')))
  hr; ui_lines=$((ui_lines + 1))

  # Output area
  avail=$((lines - ui_lines - 2))
  if (( avail < 5 )); then avail=5; fi

  if [[ -s "$LOGFILE" ]]; then
    echo "Output (latest $avail lines):"
    tail -n "$avail" "$LOGFILE" 2>/dev/null || true
  else
    echo "Output: (none yet)"
  fi

  hr
  echo -n "Choice: "
}

# ------------------------------ Action Helpers --------------------------------
pick_user() {
  local u
  echo -n "Enter username: "
  read -r u
  echo "$u"
}

pick_unit() {
  local u
  echo -n "Enter systemd unit name (e.g., sshd.service): "
  read -r u
  echo "$u"
}

pick_jobid() {
  local j
  echo -n "Enter AT job id: "
  read -r j
  echo "$j"
}

mtime_window() {
  local d
  echo -n "Enter days window (default 3): "
  read -r d
  echo "${d:-3}"
}

# ------------------------------ Quick Actions ---------------------------------
qa_change_password() {
  local u; u="$(pick_user)"
  if [[ -z "$u" ]]; then append_log "No user entered."; return; fi
  require_root_or_warn "passwd usually requires root to change other users."
  append_log "Launching passwd for user: $u"
  append_log "NOTE: passwd is interactive; output may not be captured."
  append_log ""
  passwd "$u"
  append_log "passwd completed for $u (verify manually)."
  append_log ""
}

qa_who() {
  log_block "Logged in users (who)" "who"
  log_block "Logged in users (w)" "w"
}

qa_getent_passwd() {
  log_block "All accounts summary (getent passwd)" "getent passwd | awk -F: '{print \$1, \$3, \$4, \$6, \$7}'"
}

qa_user_perms_helper() {
  require_root_or_warn "Reviewing other users and modifying sudo/groups requires root."
  echo
  echo "This helper can:"
  echo " - list members of $SUDO_GROUP (if it exists)"
  echo " - lock a user"
  echo " - set nologin shell"
  echo " - remove user from sudo/wheel group"
  echo
  if ! confirm "Proceed to interactive user-perms helper?"; then
    append_log "User-perms helper cancelled."
    return
  fi

  local u action
  u="$(pick_user)"
  if [[ -z "$u" ]]; then append_log "No user entered."; return; fi

  echo "Select action for $u:"
  echo "  1) Lock account (usermod -L / passwd -l)"
  echo "  2) Set shell to nologin"
  echo "  3) Remove from $SUDO_GROUP group (if present)"
  echo "  4) Show sudo -l -U user"
  echo -n "Choice: "
  read -r action

  case "$action" in
    1)
      if confirm "Lock $u?"; then
        log_block "Lock account $u" "usermod -L '$u' 2>/dev/null || passwd -l '$u'"
      fi
      ;;
    2)
      if confirm "Set $u shell to /usr/sbin/nologin?"; then
        log_block "Set nologin shell for $u" "usermod -s /usr/sbin/nologin '$u'"
      fi
      ;;
    3)
      if getent group "$SUDO_GROUP" >/dev/null 2>&1; then
        if confirm "Remove $u from group $SUDO_GROUP?"; then
          log_block "Remove $u from $SUDO_GROUP" "gpasswd -d '$u' '$SUDO_GROUP' 2>/dev/null || deluser '$u' '$SUDO_GROUP' 2>/dev/null || true"
        fi
      else
        append_log "Group $SUDO_GROUP not found on this system."
        append_log ""
      fi
      ;;
    4)
      log_block "sudo -l -U $u" "sudo -l -U '$u' 2>&1 || true"
      ;;
    *)
      append_log "Invalid selection in user-perms helper."
      append_log ""
      ;;
  esac
}

qa_disable_dodgy_services() {
  require_root_or_warn "Disabling services typically requires root."
  local services=("sshd.service" "ssh.service" "telnet.socket" "telnet.service" "cockpit.socket" "cockpit.service" "rsh.socket" "rlogin.socket" "rexec.socket")
  append_log "Dodgy-services helper: attempting to detect/disable commonly abused services."
  append_log "List includes: sshd/ssh, telnet, cockpit, rsh/rlogin/rexec (best-effort)."
  append_log ""

  if ! confirm "Proceed (stop/disable if found)?"; then
    append_log "Dodgy-services helper cancelled."
    append_log ""
    return
  fi

  if [[ "$INIT_SYSTEM" == "systemd" ]] && have systemctl; then
    local s
    for s in "${services[@]}"; do
      if systemctl list-unit-files | awk '{print $1}' | grep -qx "$s"; then
        log_block "Disable/stop $s" "systemctl disable --now '$s' 2>&1 || true"
      fi
    done
  else
    append_log "Non-systemd init detected ($INIT_SYSTEM). Provide manual service disabling as needed."
    append_log ""
  fi

  append_log "NOTE: Package removal is separate; use your package manager if required."
  append_log ""
}

qa_firewall_status() {
  append_log "Firewall status + rules view (best-effort):"
  append_log ""

  if have nft; then log_block "nft ruleset" "nft list ruleset 2>/dev/null || true"; fi
  if have iptables; then log_block "iptables rules" "iptables -L -v -n 2>/dev/null || true"; fi
  if have ufw; then log_block "ufw status" "ufw status verbose 2>/dev/null || true"; fi
  if have firewall-cmd; then
    log_block "firewalld zones" "firewall-cmd --list-all 2>/dev/null || true"
    log_block "firewalld permanent zones" "firewall-cmd --permanent --list-all-zones 2>/dev/null || true"
  fi

  if ! have nft && ! have iptables && ! have ufw && ! have firewall-cmd; then
    append_log "No common firewall tooling detected (nft/iptables/ufw/firewalld)."
    append_log ""
  fi
}

qa_apply_basic_firewall() {
  require_root_or_warn "Applying firewall rules requires root."
  append_log "Applying a BASIC baseline firewall is risky if you don't know required ports."
  append_log "This will attempt ONE of: ufw baseline OR firewalld baseline OR nft baseline (whichever is present)."
  append_log "You should have console access in case you lock yourself out."
  append_log ""

  if ! confirm "Proceed to apply a basic baseline firewall?"; then
    append_log "Firewall baseline cancelled."
    append_log ""
    return
  fi

  if have ufw; then
    if confirm "Use ufw: default deny incoming, allow outgoing, allow ssh?"; then
      log_block "ufw baseline" "ufw --force reset && ufw default deny incoming && ufw default allow outgoing && ufw allow ssh && ufw --force enable && ufw status verbose"
    fi
    return
  fi

  if have firewall-cmd; then
    if confirm "Use firewalld: set default zone public, allow ssh service?"; then
      log_block "firewalld baseline" "firewall-cmd --set-default-zone=public && firewall-cmd --permanent --zone=public --add-service=ssh && firewall-cmd --reload && firewall-cmd --list-all"
    fi
    return
  fi

  if have nft; then
    if confirm "Use nft: create a minimal inet filter table (allow established + lo + ssh, drop others)?"; then
      # This is a minimal baseline and may conflict with existing rulesets.
      log_block "nft baseline (minimal)" \
"nft list ruleset >/dev/null 2>&1 && echo 'NOTE: existing nft ruleset present; not overwriting automatically.' && exit 0 || true;
nft add table inet filter;
nft 'add chain inet filter input { type filter hook input priority 0; policy drop; }';
nft add rule inet filter input ct state established,related accept;
nft add rule inet filter input iif lo accept;
nft add rule inet filter input tcp dport 22 accept;
nft list ruleset"
    fi
    return
  fi

  append_log "No supported firewall manager found (ufw/firewalld/nft)."
  append_log ""
}

qa_cron_at_sweep() {
  require_root_or_warn "Reading other users' crontabs and some spool files requires root."
  # Mirrors the playbook "cron + at jobs" spirit (best-effort)
  log_block "Cron sweep (all users + system locations)" \
"crontab -l 2>/dev/null;
for u in \$(cut -f1 -d: /etc/passwd); do
  echo '--- crontab for '\"\$u\"' ---';
  crontab -l -u \"\$u\" 2>/dev/null || true;
done;
echo '--- /etc/cron* and cron.d ---';
ls -la /etc/cron* /etc/cron.d 2>/dev/null || true;
echo '--- dump /etc/crontab ---';
cat /etc/crontab 2>/dev/null || true;
echo '--- spool hints (varies by distro) ---';
ls -la /var/spool/cron /var/spool/cron/crontabs /var/spool/at /var/spool/cron/atjobs 2>/dev/null || true"

  if have atq; then log_block "AT queue (atq)" "atq 2>/dev/null || true"; fi
}

qa_recent_execs() {
  require_root_or_warn "Scanning / is root-heavy and noisy."
  echo "Mode:"
  echo "  1) FAST (xdev, common dirs)"
  echo "  2) SLOW (entire /, can take a long time)"
  echo -n "Choice: "
  local c
  read -r c
  case "$c" in
    1)
      log_block "Recent executables (last 60 minutes) FAST" \
"find /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /opt -type f -executable -cmin -60 2>/dev/null || true"
      ;;
    2)
      log_block "Recent executables (last 60 minutes) SLOW" \
"find / -type f -executable -cmin -60 2>/dev/null || true"
      ;;
    *)
      append_log "Invalid mode."
      append_log ""
      ;;
  esac
}

qa_recent_services() {
  require_root_or_warn "Scanning systemd unit paths requires root for full coverage."
  local paths="/etc/systemd /lib/systemd /usr/lib/systemd /etc/systemd/system /usr/lib/systemd/system /lib/systemd/system"
  log_block "Recent systemd service files (last 60 minutes)" \
"find $paths -type f -name '*.service' -cmin -60 2>/dev/null || true"
}

qa_journal_commands() {
  if have journalctl; then
    log_block "journalctl 24h command hunting" "journalctl --since '24 hours ago' 2>/dev/null | grep -E 'COMMAND=|execve|sudo' || true"
  else
    append_log "journalctl not available."
    append_log ""
  fi
}

# --------------------------- Accounts & Credentials ----------------------------
acc_list_accounts() {
  log_block "Accounts (getent passwd)" "getent passwd | awk -F: '{print \$1, \$3, \$4, \$6, \$7}'"
}

acc_uid0() {
  log_block "UID 0 accounts (besides root)" "getent passwd | awk -F: '(\$3==0){print}' | grep -v '^root:' || true"
}

acc_system_users_with_shells() {
  log_block "System users (UID<1000) with real shells" \
"getent passwd | awk -F: '(\$3<1000){print \$1\":\"\$3\":\"\$7}' | grep -E ':(/bin/(bash|sh)|/usr/bin/zsh|/bin/zsh)$' || true"
}

acc_odd_homes() {
  log_block "Odd home dirs (/tmp,/var/tmp,/var/www,/dev/shm)" \
"getent passwd | awk -F: '{print \$1, \$6}' | egrep '(/tmp|/var/tmp|/var/www|/dev/shm)' || true"
}

acc_chage() {
  local u; u="$(pick_user)"
  if [[ -z "$u" ]]; then append_log "No user entered."; return; fi
  require_root_or_warn "chage on other users requires root."
  log_block "chage -l root" "chage -l root 2>/dev/null || true"
  log_block "chage -l $u" "chage -l '$u' 2>/dev/null || true"
}

acc_authlog_search() {
  local found=0 f
  for f in "${AUTH_LOGS[@]}"; do
    if [[ -r "$f" ]]; then
      found=1
      log_block "Auth log search in $f" "grep -iE 'passwd|chpasswd|useradd|usermod' '$f' 2>/dev/null | tail -n 200 || true"
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    append_log "No readable auth logs found in: ${AUTH_LOGS[*]}"
    append_log ""
  fi
}

acc_sudo_audit() {
  require_root_or_warn "Listing sudoers drop-ins and sudo -l may require root privileges."
  log_block "List /etc/sudoers.d" "ls -la /etc/sudoers.d 2>/dev/null || true"
  local u; u="$(pick_user)"
  if [[ -n "$u" ]]; then
    log_block "sudo -l -U $u (effective sudo rules)" "sudo -l -U '$u' 2>&1 || true"
  fi
  log_block "Quick grep for NOPASSWD in sudoers" "grep -R \"NOPASSWD\" /etc/sudoers /etc/sudoers.d 2>/dev/null || true"
}

acc_remediate_user() {
  require_root_or_warn "User remediation requires root."
  local u; u="$(pick_user)"
  if [[ -z "$u" ]]; then append_log "No user entered."; return; fi

  echo "Remediation for $u:"
  echo "  1) Lock account"
  echo "  2) Set nologin shell"
  echo "  3) Delete user (userdel -r)  (!!)"
  echo -n "Choice: "
  local c
  read -r c
  case "$c" in
    1)
      if confirm "Lock $u?"; then
        log_block "Lock $u" "usermod -L '$u' 2>/dev/null || passwd -l '$u'"
      fi
      ;;
    2)
      if confirm "Set shell to /usr/sbin/nologin for $u?"; then
        log_block "Set nologin for $u" "usermod -s /usr/sbin/nologin '$u'"
      fi
      ;;
    3)
      append_log "DANGER: Deleting a user can destroy evidence and break services."
      append_log ""
      if confirm "Really delete $u and remove home (-r)?"; then
        log_block "Backup suggestion" "echo 'Consider backing up /home/$u before deletion.'"
        log_block "userdel -r $u" "userdel -r '$u' 2>&1 || true"
      fi
      ;;
    *)
      append_log "Invalid remediation choice."
      append_log ""
      ;;
  esac
}

# --------------------------- Shell / Profile Persistence -----------------------
shell_scan_user_dotfiles() {
  require_root_or_warn "Reading other users' dotfiles requires root."
  local u; u="$(pick_user)"
  if [[ -z "$u" ]]; then append_log "No user entered."; return; fi
  local home
  home="$(getent passwd "$u" | awk -F: '{print $6}')"
  if [[ -z "$home" || ! -d "$home" ]]; then
    append_log "Could not find home for $u."
    append_log ""
    return
  fi
  log_block "List dotfiles in $home" "ls -la '$home' 2>/dev/null || true"
  log_block "Inspect common shell files for suspicious patterns" \
"grep -nE 'curl|wget|base64|/dev/tcp|nc |ncat|socat|python -c|perl -e|LD_PRELOAD|LD_LIBRARY_PATH|alias (ls|ps|netstat|ssh|sudo)|function (ls|ps|ssh|sudo)' \
'$home'/.bashrc '$home'/.bash_profile '$home'/.bash_login '$home'/.profile '$home'/.zshrc '$home'/.zprofile '$home'/.kshrc 2>/dev/null || true"
}

shell_scan_global_profiles() {
  log_block "Inspect /etc/profile and bashrc variants" \
"for f in /etc/profile /etc/bash.bashrc /etc/bashrc; do
  echo '--- '\"\$f\"' ---';
  sed -n '1,220p' \"\$f\" 2>/dev/null || true;
done"
  log_block "List /etc/profile.d" "ls -la /etc/profile.d 2>/dev/null || true"
  log_block "Suspicious pattern grep in /etc/profile.d" \
"grep -R -nE 'curl|wget|base64|/dev/tcp|nc |ncat|socat|LD_PRELOAD|LD_LIBRARY_PATH|PATH=' /etc/profile.d 2>/dev/null || true"
}

shell_check_environment_login_defs() {
  log_block "Check /etc/environment" "sed -n '1,200p' /etc/environment 2>/dev/null || true"
  log_block "Check /etc/login.defs (UID_MIN/GID_MIN/umask hints)" "grep -nE 'UID_MIN|GID_MIN|UMASK|PASS_' /etc/login.defs 2>/dev/null || true"
  log_block "Quick grep for LD_*/PATH in /etc/environment and /etc/login.defs" "grep -nE 'LD_PRELOAD|LD_LIBRARY_PATH|PATH=' /etc/environment /etc/login.defs 2>/dev/null || true"
}

shell_check_skel() {
  require_root_or_warn "Reading /etc/skel requires root on hardened systems."
  log_block "List /etc/skel" "ls -la /etc/skel 2>/dev/null || true"
  log_block "Grep suspicious patterns in /etc/skel dotfiles" \
"grep -R -nE 'curl|wget|base64|/dev/tcp|nc |ncat|socat|LD_PRELOAD|LD_LIBRARY_PATH|alias (ls|ps|ssh|sudo)' /etc/skel 2>/dev/null || true"
}

shell_grep_wide() {
  require_root_or_warn "Grepping across /home may require root."
  log_block "Wide grep in /etc and /home for high-signal strings (best-effort)" \
"grep -R -nE 'curl\\s|wget\\s|/dev/tcp|LD_PRELOAD|LD_LIBRARY_PATH|base64\\s+-d|nc\\s|ncat\\s|socat\\s|python\\s+-c|perl\\s+-e' /etc /home 2>/dev/null | head -n 400 || true"
}

# --------------------------- Scheduled Tasks / Schedulers ----------------------
sched_dump_cron() {
  qa_cron_at_sweep
}

sched_recent_cron_files() {
  local d; d="$(mtime_window)"
  require_root_or_warn "cron directories may be root-only."
  log_block "Recently modified cron files (mtime -$d days)" "find /etc/cron* /var/spool/cron* -type f -mtime -$d 2>/dev/null -ls || true"
}

sched_at_list_show() {
  if ! have atq; then
    append_log "atq not found (at package may be missing)."
    append_log ""
    return
  fi
  log_block "AT queue (atq)" "atq 2>/dev/null || true"
  local j; j="$(pick_jobid)"
  if [[ -n "$j" ]]; then
    require_root_or_warn "Viewing others' at jobs may require root."
    log_block "AT job contents (at -c $j)" "at -c '$j' 2>/dev/null || true"
  fi
}

sched_systemd_timers() {
  if [[ "$INIT_SYSTEM" != "systemd" ]] || ! have systemctl; then
    append_log "systemd timers not applicable (init=$INIT_SYSTEM)."
    append_log ""
    return
  fi
  log_block "systemctl list-timers --all" "systemctl list-timers --all --no-pager 2>/dev/null || true"
  echo -n "Inspect a timer/service? Enter unit name or blank to skip: "
  local u; read -r u
  if [[ -n "$u" ]]; then
    log_block "systemctl cat $u" "systemctl cat '$u' 2>/dev/null || true"
  fi
}

sched_anacron() {
  log_block "View /etc/anacrontab" "sed -n '1,220p' /etc/anacrontab 2>/dev/null || true"
}

sched_restart_cron() {
  require_root_or_warn "Restarting cron requires root."
  if ! confirm "Restart scheduler service ($CRON_SVC) now?"; then
    append_log "Restart cron cancelled."
    append_log ""
    return
  fi
  if [[ "$INIT_SYSTEM" == "systemd" ]] && have systemctl; then
    log_block "Restart $CRON_SVC" "systemctl restart '$CRON_SVC' 2>&1 || true; systemctl status '$CRON_SVC' --no-pager 2>/dev/null | head -n 80 || true"
  else
    log_block "Restart $CRON_SVC (non-systemd best-effort)" "service '$CRON_SVC' restart 2>&1 || true"
  fi
}

# --------------------------- Services & Daemons --------------------------------
svc_list_systemd_units() {
  if [[ "$INIT_SYSTEM" != "systemd" ]] || ! have systemctl; then
    append_log "systemd not detected. Use SysV/OpenRC menus instead."
    append_log ""
    return
  fi
  log_block "systemctl list-unit-files --type=service" "systemctl list-unit-files --type=service --no-pager 2>/dev/null || true"
  log_block "Heuristic: suspicious-ish service names (generic/updater/network-check/random)" \
"systemctl list-unit-files --type=service --no-pager 2>/dev/null | awk '{print \$1}' | egrep -i '(update|updater|upgrade|network-check|check|monitor|helper|system-.*upgrade|[a-z0-9]{12,}\\.service)' || true"
}

svc_inspect_unit() {
  if [[ "$INIT_SYSTEM" != "systemd" ]] || ! have systemctl; then
    append_log "systemd not detected."
    append_log ""
    return
  fi
  local u; u="$(pick_unit)"
  if [[ -z "$u" ]]; then append_log "No unit entered."; return; fi
  log_block "systemctl cat $u" "systemctl cat '$u' 2>/dev/null || true"
  log_block "systemctl status $u" "systemctl status '$u' --no-pager 2>/dev/null | head -n 120 || true"
}

svc_disable_unit() {
  require_root_or_warn "Disabling units requires root."
  if [[ "$INIT_SYSTEM" != "systemd" ]] || ! have systemctl; then
    append_log "systemd not detected."
    append_log ""
    return
  fi
  local u; u="$(pick_unit)"
  if [[ -z "$u" ]]; then append_log "No unit entered."; return; fi
  if confirm "Disable + stop $u now?"; then
    log_block "Disable/stop $u" "systemctl disable --now '$u' 2>&1 || true"
    log_block "daemon-reload" "systemctl daemon-reload 2>&1 || true"
  fi
}

svc_systemd_user_services() {
  require_root_or_warn "Enumerating per-user services often requires root."
  local u; u="$(pick_user)"
  if [[ -z "$u" ]]; then append_log "No user entered."; return; fi
  if ! have systemctl; then append_log "systemctl not found."; append_log ""; return; fi

  log_block "User services for $u" "su - '$u' -c \"systemctl --user list-unit-files --type=service --no-pager\" 2>/dev/null || true"
  log_block "User timers for $u" "su - '$u' -c \"systemctl --user list-unit-files --type=timer --no-pager\" 2>/dev/null || true"
  if have loginctl; then
    log_block "Linger status for $u" "loginctl show-user '$u' 2>/dev/null | grep -i Linger || true"
  fi
}

svc_sysv_init() {
  log_block "List /etc/init.d" "ls -la /etc/init.d 2>/dev/null || true"
  log_block "List rc*.d links" "ls -la /etc/rc*.d /etc/rc.d/rc*.d 2>/dev/null || true"
}

svc_rc_local() {
  local f1="/etc/rc.local"
  local f2="/etc/rc.d/rc.local"
  if [[ -r "$f1" ]]; then
    log_block "rc.local ($f1)" "ls -la '$f1'; sed -n '1,220p' '$f1'"
  fi
  if [[ -r "$f2" ]]; then
    log_block "rc.local ($f2)" "ls -la '$f2'; sed -n '1,220p' '$f2'"
  fi
  if [[ ! -r "$f1" && ! -r "$f2" ]]; then
    append_log "No rc.local file found."
    append_log ""
  fi
}

svc_inetd_xinetd() {
  log_block "inetd.conf" "ls -la /etc/inetd.conf 2>/dev/null || true; sed -n '1,220p' /etc/inetd.conf 2>/dev/null || true"
  log_block "xinetd configs" "ls -la /etc/xinetd.conf /etc/xinetd.d 2>/dev/null || true; grep -R -nE 'server\\s*=|/bin/(sh|bash)' /etc/xinetd* 2>/dev/null || true"
}

svc_nm_dispatcher() {
  local d="/etc/NetworkManager/dispatcher.d"
  log_block "NetworkManager dispatcher dir listing" "ls -la '$d' 2>/dev/null || true"
  log_block "Preview dispatcher scripts (first 200 lines each)" \
"for f in '$d'/*; do
  [[ -f \"\$f\" ]] || continue;
  echo '--- '\"\$f\"' ---';
  sed -n '1,200p' \"\$f\" 2>/dev/null || true;
done"
}

# --------------------------- Boot / Kernel / Initramfs -------------------------
boot_show_grub() {
  log_block "/etc/default/grub" "sed -n '1,240p' /etc/default/grub 2>/dev/null || true"
  log_block "Possible grub.cfg paths" "ls -la /boot/grub/grub.cfg /boot/grub2/grub.cfg 2>/dev/null || true"
}

boot_grep_grub_params() {
  log_block "Search GRUB configs for init=/rdinit=" \
"grep -R -nE '(\\binit=|\\brdinit=)' /etc/default/grub /boot/grub*/grub.cfg 2>/dev/null || true"
}

boot_initramfs_hooks() {
  case "$OS_FAMILY" in
    debian)
      log_block "initramfs-tools configs/hooks" "ls -la /etc/initramfs-tools 2>/dev/null || true; find /etc/initramfs-tools -type f -maxdepth 3 -ls 2>/dev/null || true"
      ;;
    rhel|suse)
      log_block "dracut configs/modules" "ls -la /etc/dracut.conf /etc/dracut.conf.d 2>/dev/null || true; find /etc/dracut.conf.d -type f -maxdepth 2 -ls 2>/dev/null || true"
      ;;
    *)
      log_block "Initramfs config dirs (best-effort)" "ls -la /etc/initramfs-tools /etc/dracut.conf.d /etc/dracut.conf 2>/dev/null || true"
      ;;
  esac
}

boot_lsmod() {
  log_block "Loaded kernel modules (lsmod)" "lsmod 2>/dev/null || true"
  log_block "modules-load.d & modprobe.d" "ls -la /etc/modules-load.d /etc/modprobe.d 2>/dev/null || true; grep -R -n . /etc/modules-load.d /etc/modprobe.d 2>/dev/null | head -n 240 || true"
}

boot_forced_module_loads() {
  log_block "Search for forced module loads" \
"grep -R -nE '(^\\s*[^#].*\\.ko|\\binstall\\b|\\boptions\\b|\\bblacklist\\b|\\bmodprobe\\b)' /etc/modules-load.d /etc/modprobe.d 2>/dev/null | head -n 300 || true"
}

boot_rebuild_initramfs() {
  require_root_or_warn "Rebuilding initramfs requires root."
  append_log "Rebuilding initramfs can take time and may impact boot if misconfigured."
  append_log ""
  if ! confirm "Proceed to rebuild initramfs now?"; then
    append_log "Initramfs rebuild cancelled."
    append_log ""
    return
  fi
  case "$OS_FAMILY" in
    debian)
      if have update-initramfs; then
        log_block "update-initramfs -u -k all" "update-initramfs -u -k all 2>&1 || true"
      else
        append_log "update-initramfs not found."
        append_log ""
      fi
      ;;
    rhel|suse)
      if have dracut; then
        log_block "dracut --force" "dracut --force 2>&1 || true"
      else
        append_log "dracut not found."
        append_log ""
      fi
      ;;
    *)
      append_log "Unknown OS family; cannot choose initramfs rebuild command safely."
      append_log ""
      ;;
  esac
}

# --------------------------- Libraries / Loader Hijacking ----------------------
libs_ld_preload() {
  if [[ -e /etc/ld.so.preload ]]; then
    log_block "/etc/ld.so.preload (contents)" "ls -la /etc/ld.so.preload; sed -n '1,220p' /etc/ld.so.preload 2>/dev/null || true"
  else
    append_log "/etc/ld.so.preload does not exist."
    append_log ""
  fi
}

libs_search_ld_env() {
  require_root_or_warn "Searching across /home may require root."
  log_block "Search LD_PRELOAD / LD_LIBRARY_PATH in /etc and /home (best-effort)" \
"grep -R -nE 'LD_PRELOAD|LD_LIBRARY_PATH' /etc /home 2>/dev/null | head -n 300 || true"
}

libs_pkg_verify() {
  require_root_or_warn "Package verification best run as root."
  case "$OS_FAMILY" in
    rhel|suse)
      if have rpm; then
        log_block "rpm -Va (checksum mismatches '^..5')" "rpm -Va 2>/dev/null | grep '^..5' || true"
      else
        append_log "rpm not found."
        append_log ""
      fi
      ;;
    debian)
      if have debsums; then
        log_block "debsums -s (failed sums only)" "debsums -s 2>/dev/null || true"
      else
        append_log "debsums not found. Install with apt if desired: apt-get install debsums"
        append_log ""
      fi
      ;;
    arch)
      if have pacman; then
        log_block "pacman -Qkk (integrity check; can be long)" "pacman -Qkk 2>/dev/null | head -n 300 || true"
      else
        append_log "pacman not found."
        append_log ""
      fi
      ;;
    *)
      append_log "No package verification routine for OS_FAMILY=$OS_FAMILY."
      append_log ""
      ;;
  esac
}

libs_recent_libs() {
  require_root_or_warn "Scanning library dirs may require root."
  local d; d="$(mtime_window)"
  log_block "Recently modified shared libraries (mtime -$d days) common lib dirs" \
"find /lib /lib64 /usr/lib /usr/lib64 -type f \\( -name '*.so*' -o -name 'ld-*' \\) -mtime -$d 2>/dev/null -ls | head -n 400 || true"
}

libs_ldconfig() {
  require_root_or_warn "ldconfig requires root."
  if confirm "Run ldconfig now?"; then
    log_block "ldconfig" "ldconfig 2>&1 || true"
  fi
}

# --------------------------- Device & Event Triggers ---------------------------
dev_udev_rules() {
  require_root_or_warn "udev rules often require root to read fully."
  log_block "List udev rules" "ls -la /etc/udev/rules.d /lib/udev/rules.d 2>/dev/null || true"
  log_block "Grep RUN+=/PROGRAM= in udev rules" \
"grep -R -nE 'RUN\\+=|PROGRAM=' /etc/udev/rules.d /lib/udev/rules.d 2>/dev/null | head -n 300 || true"
}

dev_acpi() {
  log_block "ACPI directories" "ls -la /etc/acpi /etc/acpi/events 2>/dev/null || true"
  log_block "ACPI handlers (preview)" \
"for f in /etc/acpi/* /etc/acpi/events/*; do
  [[ -f \"\$f\" ]] || continue;
  echo '--- '\"\$f\"' ---';
  sed -n '1,200p' \"\$f\" 2>/dev/null || true;
done"
}

dev_reload_udev() {
  require_root_or_warn "Reloading udev rules requires root."
  append_log "Reloading udev rules can have side effects. Use cautiously."
  append_log ""
  if confirm "Proceed with: udevadm control --reload-rules && udevadm trigger ?"; then
    log_block "Reload udev rules" "udevadm control --reload-rules && udevadm trigger 2>&1 || true"
  fi
}

# --------------------------- Application Persistence ---------------------------
app_webroot_scan() {
  require_root_or_warn "Reading web roots may require root."
  local d; d="$(mtime_window)"
  local roots=("/var/www" "/srv/www" "/usr/share/nginx/html" "/var/www/html")
  local r
  for r in "${roots[@]}"; do
    if [[ -d "$r" ]]; then
      log_block "Recent files in $r (mtime -$d)" "find '$r' -type f -mtime -$d -ls 2>/dev/null | head -n 300 || true"
    fi
  done
  append_log "Web root scan done (only common roots checked)."
  append_log ""
}

app_webshell_heuristics() {
  require_root_or_warn "Heuristics may require root."
  local roots=("/var/www" "/srv/www" "/usr/share/nginx/html" "/var/www/html")
  local r
  for r in "${roots[@]}"; do
    [[ -d "$r" ]] || continue
    log_block "Heuristic grep in $r for webshell-ish strings (eval/base64/system/exec)" \
"grep -R -nE '(eval\\(|base64_decode\\(|system\\(|shell_exec\\(|passthru\\(|popen\\(|proc_open\\(|`\\s*\\w+\\s*`)' '$r' 2>/dev/null | head -n 200 || true"
  done
}

app_service_files() {
  require_root_or_warn "Inspecting /etc/systemd/system needs root for full view."
  if [[ "$INIT_SYSTEM" == "systemd" ]] && have systemctl; then
    log_block "Custom app-ish unit files in /etc/systemd/system" "ls -la /etc/systemd/system 2>/dev/null || true"
    log_block "Units matching app* or custom patterns" "ls -la /etc/systemd/system/app* /etc/systemd/system/*custom* 2>/dev/null || true"
  else
    append_log "systemd not detected; check init scripts manually under /etc/init.d or supervisor configs."
    append_log ""
  fi
}

app_scan_opt_usr_local() {
  require_root_or_warn "Scanning /opt and /usr/local requires root."
  local d; d="$(mtime_window)"
  log_block "Recent executables in /opt and /usr/local (mtime -$d)" \
"find /opt /usr/local -type f -executable -mtime -$d -ls 2>/dev/null | head -n 400 || true"
}

# --------------------------- Hijacking / SUID / PATH ---------------------------
hijack_path_users() {
  require_root_or_warn "Using su - user requires root."
  echo -n "Enter username (or 'ALL' for all local users): "
  local u; read -r u
  if [[ -z "$u" ]]; then append_log "No user entered."; append_log ""; return; fi

  if [[ "${u^^}" == "ALL" ]]; then
    local usr
    for usr in $(getent passwd | awk -F: '{print $1}'); do
      log_block "PATH for $usr" "su - '$usr' -c 'echo \$PATH' 2>/dev/null || true"
    done
  else
    log_block "PATH for $u" "su - '$u' -c 'echo \$PATH' 2>/dev/null || true"
  fi
}

hijack_suspicious_path_dirs() {
  require_root_or_warn "Checking multiple user PATHs requires root."
  log_block "Suspicious PATH entries that precede /usr/bin (heuristic)" \
"for u in \$(getent passwd | awk -F: '{print \$1}'); do
  p=\$(su - \"\$u\" -c 'echo \$PATH' 2>/dev/null || true);
  [[ -z \"\$p\" ]] && continue;
  echo \"USER=\$u PATH=\$p\" | egrep '(^|:)(/tmp|/var/tmp|/dev/shm|/run/user)' && echo \"---\" ;
done || true"
}

hijack_alias_function_scan() {
  require_root_or_warn "Scanning home dirs needs root."
  log_block "Alias/function scan for common commands in /etc and /home" \
"grep -R -nE '^(alias|function)\\s+(ls|ps|netstat|ss|ssh|sudo|su|ip|systemctl)\\b' /etc /home 2>/dev/null | head -n 350 || true"
}

hijack_binary_spotcheck() {
  require_root_or_warn "Spotchecking binaries under /usr/bin may require root in some cases."
  local bins=(/usr/bin/ssh /usr/bin/sudo /usr/bin/su /usr/bin/login /usr/bin/systemctl /bin/ps /usr/bin/top /usr/bin/netstat /usr/bin/ss /bin/bash)
  local b
  for b in "${bins[@]}"; do
    [[ -e "$b" ]] || continue
    log_block "file $b" "ls -la '$b'; file '$b' 2>/dev/null || true"
  done
  append_log "If any of these show as 'shell script' unexpectedly, investigate immediately."
  append_log ""
}

hijack_suid_sgid() {
  require_root_or_warn "SUID/SGID inventory requires root."
  log_block "SUID inventory (xdev)" "find / -perm -4000 -type f -xdev 2>/dev/null | sort | head -n 400 || true"
  log_block "SGID inventory (xdev)" "find / -perm -2000 -type f -xdev 2>/dev/null | sort | head -n 400 || true"
}

hijack_world_writable_execs() {
  require_root_or_warn "Scanning world-writable dirs requires root."
  local d; d="$(mtime_window)"
  log_block "Recent files in /tmp,/var/tmp,/dev/shm (mtime -$d)" "find /tmp /var/tmp /dev/shm -maxdepth 3 -type f -mtime -$d -ls 2>/dev/null | head -n 400 || true"
}

# --------------------------- Logs / Anti-Forensics -----------------------------
logs_logrotate() {
  require_root_or_warn "Reading /etc/logrotate.d often needs root."
  log_block "/etc/logrotate.conf (preview)" "sed -n '1,260p' /etc/logrotate.conf 2>/dev/null || true"
  log_block "/etc/logrotate.d listing" "ls -la /etc/logrotate.d 2>/dev/null || true"
  log_block "Find postrotate blocks" "grep -R -n 'postrotate\\|endscript' /etc/logrotate.conf /etc/logrotate.d 2>/dev/null || true"
}

logs_agents_scan() {
  require_root_or_warn "Agent dirs may be root-only."
  log_block "Agent dirs presence scan" "ls -la /etc/zabbix /etc/nagios /etc/nrpe.d /etc/backup.d 2>/dev/null || true"
  log_block "Custom scripts in agent dirs (best-effort)" "find /etc/zabbix /etc/nagios /etc/nrpe.d /etc/backup.d -type f -maxdepth 3 -ls 2>/dev/null | head -n 300 || true"
}

logs_auth_grep() {
  acc_authlog_search
}

logs_journal_24h() {
  qa_journal_commands
}

# --------------------------- Weird / Niche Checks ------------------------------
weird_tmp_recent() {
  require_root_or_warn "Listing tmp/shm may require root."
  local d; d="$(mtime_window)"
  log_block "Recent files in /tmp /var/tmp /dev/shm (mtime -$d)" "find /tmp /var/tmp /dev/shm -maxdepth 3 -type f -mtime -$d -ls 2>/dev/null | head -n 500 || true"
}

weird_hidden_quick() {
  require_root_or_warn "Hidden scan can be noisy; root helps."
  echo -n "Base path to scan (default /, recommended /etc or /var/www): "
  local base; read -r base
  base="${base:-/etc}"
  log_block "Hidden files/dirs quick scan under $base (depth 4)" "find '$base' -maxdepth 4 -name '.*' -ls 2>/dev/null | head -n 400 || true"
}

weird_full_sweep() {
  require_root_or_warn "Full sweep is best as root."

  append_log "Starting FULL persistence sweep (read-only). This may take time."
  append_log ""

  qa_who
  qa_getent_passwd
  acc_uid0
  acc_system_users_with_shells
  acc_odd_homes
  acc_sudo_audit

  shell_scan_global_profiles
  shell_check_environment_login_defs
  shell_check_skel
  shell_grep_wide

  sched_dump_cron
  if [[ "$INIT_SYSTEM" == "systemd" ]] && have systemctl; then
    sched_systemd_timers
    svc_list_systemd_units
  fi

  libs_ld_preload
  libs_search_ld_env
  libs_recent_libs

  dev_udev_rules
  dev_acpi

  app_webroot_scan
  hijack_alias_function_scan
  hijack_suid_sgid
  weird_tmp_recent

  append_log "FULL sweep complete."
  append_log ""
}

# --------------------------- Reports / Utilities -------------------------------
rep_save_log() {
  local out="persistence_report_$(date +%Y%m%d_%H%M%S).log"
  cp -f "$LOGFILE" "./$out"
  append_log "Saved report to ./$out"
  append_log ""
}

rep_collect_tar() {
  require_root_or_warn "Collecting artifacts often requires root."
  local out="persistence_artifacts_$(date +%Y%m%d_%H%M%S).tar.gz"
  local tmpdir
  tmpdir="$(mktemp -d -t persistence_artifacts.XXXXXX)"

  # Collect key artifacts best-effort (do NOT fail hard)
  cp -a /etc/passwd /etc/group "$tmpdir" 2>/dev/null || true
  cp -a /etc/shadow /etc/gshadow "$tmpdir" 2>/dev/null || true
  cp -a /etc/sudoers "$tmpdir" 2>/dev/null || true
  cp -a /etc/sudoers.d "$tmpdir" 2>/dev/null || true
  cp -a /etc/profile /etc/bash.bashrc /etc/bashrc "$tmpdir" 2>/dev/null || true
  cp -a /etc/profile.d "$tmpdir" 2>/dev/null || true
  cp -a /etc/environment /etc/login.defs "$tmpdir" 2>/dev/null || true
  cp -a /etc/crontab /etc/cron.* /etc/cron.d "$tmpdir" 2>/dev/null || true
  cp -a /etc/anacrontab "$tmpdir" 2>/dev/null || true
  cp -a /etc/udev/rules.d "$tmpdir" 2>/dev/null || true
  cp -a /etc/acpi "$tmpdir" 2>/dev/null || true
  cp -a /etc/ld.so.preload "$tmpdir" 2>/dev/null || true
  cp -a /etc/default/grub "$tmpdir" 2>/dev/null || true
  cp -a /boot/grub*/grub.cfg "$tmpdir" 2>/dev/null || true

  # Add console log
  cp -f "$LOGFILE" "$tmpdir/console_output.log" 2>/dev/null || true

  tar -czf "./$out" -C "$tmpdir" . 2>/dev/null || true
  rm -rf "$tmpdir"

  append_log "Saved artifacts bundle to ./$out"
  append_log ""
}

rep_show_quarantine() {
  append_log "Quarantine directory (for files you move manually): $QUAR_DIR"
  append_log ""
}

rep_clear_log() {
  : > "$LOGFILE"
  append_log "Output cleared."
  append_log ""
}

# ------------------------------ Menu Dispatch ---------------------------------
dispatch_main() {
  case "$1" in
    1) push_menu "quick" ;;
    2) push_menu "accounts" ;;
    3) push_menu "shells" ;;
    4) push_menu "sched" ;;
    5) push_menu "services" ;;
    6) push_menu "boot" ;;
    7) push_menu "libs" ;;
    8) push_menu "device" ;;
    9) push_menu "apps" ;;
    10) push_menu "hijack" ;;
    11) push_menu "logs" ;;
    12) push_menu "weird" ;;
    13) push_menu "reports" ;;
    *) append_log "Unknown option in main menu: $1"; append_log "" ;;
  esac
}

dispatch_quick() {
  case "$1" in
    1) qa_change_password ;;
    2) qa_who ;;
    3) qa_getent_passwd ;;
    4) qa_user_perms_helper ;;
    5) qa_disable_dodgy_services ;;
    6) qa_firewall_status ;;
    7) qa_apply_basic_firewall ;;
    8) qa_cron_at_sweep ;;
    9) qa_recent_execs ;;
    10) qa_recent_services ;;
    11) qa_journal_commands ;;
    *) append_log "Unknown option in quick actions: $1"; append_log "" ;;
  esac
}

dispatch_accounts() {
  case "$1" in
    1) acc_list_accounts ;;
    2) acc_uid0 ;;
    3) acc_system_users_with_shells ;;
    4) acc_odd_homes ;;
    5) acc_chage ;;
    6) acc_authlog_search ;;
    7) acc_sudo_audit ;;
    8) acc_remediate_user ;;
    *) append_log "Unknown option in accounts: $1"; append_log "" ;;
  esac
}

dispatch_shells() {
  case "$1" in
    1) shell_scan_user_dotfiles ;;
    2) shell_scan_global_profiles ;;
    3) shell_check_environment_login_defs ;;
    4) shell_check_skel ;;
    5) shell_grep_wide ;;
    *) append_log "Unknown option in shells: $1"; append_log "" ;;
  esac
}

dispatch_sched() {
  case "$1" in
    1) sched_dump_cron ;;
    2) sched_recent_cron_files ;;
    3) sched_at_list_show ;;
    4) sched_systemd_timers ;;
    5) sched_anacron ;;
    6) sched_restart_cron ;;
    *) append_log "Unknown option in schedulers: $1"; append_log "" ;;
  esac
}

dispatch_services() {
  case "$1" in
    1) svc_list_systemd_units ;;
    2) svc_inspect_unit ;;
    3) svc_disable_unit ;;
    4) svc_systemd_user_services ;;
    5) svc_sysv_init ;;
    6) svc_rc_local ;;
    7) svc_inetd_xinetd ;;
    8) svc_nm_dispatcher ;;
    *) append_log "Unknown option in services: $1"; append_log "" ;;
  esac
}

dispatch_boot() {
  case "$1" in
    1) boot_show_grub ;;
    2) boot_grep_grub_params ;;
    3) boot_initramfs_hooks ;;
    4) boot_lsmod ;;
    5) boot_forced_module_loads ;;
    6) boot_rebuild_initramfs ;;
    *) append_log "Unknown option in boot/kernel: $1"; append_log "" ;;
  esac
}

dispatch_libs() {
  case "$1" in
    1) libs_ld_preload ;;
    2) libs_search_ld_env ;;
    3) libs_pkg_verify ;;
    4) libs_recent_libs ;;
    5) libs_ldconfig ;;
    *) append_log "Unknown option in libs: $1"; append_log "" ;;
  esac
}

dispatch_device() {
  case "$1" in
    1) dev_udev_rules ;;
    2) dev_acpi ;;
    3) dev_reload_udev ;;
    *) append_log "Unknown option in device triggers: $1"; append_log "" ;;
  esac
}

dispatch_apps() {
  case "$1" in
    1) app_webroot_scan ;;
    2) app_webshell_heuristics ;;
    3) app_service_files ;;
    4) app_scan_opt_usr_local ;;
    *) append_log "Unknown option in apps: $1"; append_log "" ;;
  esac
}

dispatch_hijack() {
  case "$1" in
    1) hijack_path_users ;;
    2) hijack_suspicious_path_dirs ;;
    3) hijack_alias_function_scan ;;
    4) hijack_binary_spotcheck ;;
    5) hijack_suid_sgid ;;
    6) hijack_world_writable_execs ;;
    *) append_log "Unknown option in hijack: $1"; append_log "" ;;
  esac
}

dispatch_logs() {
  case "$1" in
    1) logs_logrotate ;;
    2) logs_agents_scan ;;
    3) logs_auth_grep ;;
    4) logs_journal_24h ;;
    *) append_log "Unknown option in logs: $1"; append_log "" ;;
  esac
}

dispatch_weird() {
  case "$1" in
    1) weird_tmp_recent ;;
    2) weird_hidden_quick ;;
    3) weird_full_sweep ;;
    *) append_log "Unknown option in weird: $1"; append_log "" ;;
  esac
}

dispatch_reports() {
  case "$1" in
    1) rep_save_log ;;
    2) rep_collect_tar ;;
    3) rep_show_quarantine ;;
    4) rep_clear_log ;;
    *) append_log "Unknown option in reports: $1"; append_log "" ;;
  esac
}

dispatch_current_menu() {
  local choice="$1"
  case "$(cur_menu)" in
    main) dispatch_main "$choice" ;;
    quick) dispatch_quick "$choice" ;;
    accounts) dispatch_accounts "$choice" ;;
    shells) dispatch_shells "$choice" ;;
    sched) dispatch_sched "$choice" ;;
    services) dispatch_services "$choice" ;;
    boot) dispatch_boot "$choice" ;;
    libs) dispatch_libs "$choice" ;;
    device) dispatch_device "$choice" ;;
    apps) dispatch_apps "$choice" ;;
    hijack) dispatch_hijack "$choice" ;;
    logs) dispatch_logs "$choice" ;;
    weird) dispatch_weird "$choice" ;;
    reports) dispatch_reports "$choice" ;;
    *) append_log "Unknown menu state: $(cur_menu)"; append_log "" ;;
  esac
}

# ------------------------------- Main Loop -------------------------------------
main() {
  init_runtime
  choose_os_family_interactive

  append_log "Selected OS_FAMILY=$OS_FAMILY INIT_SYSTEM=$INIT_SYSTEM PKG_MGR=$PKG_MGR"
  append_log ""

  while true; do
    draw_screen
    local choice
    read -r choice

    case "${choice,,}" in
      q|quit|exit)
        clear
        echo "Exiting. Log saved at: $LOGFILE"
        echo "Quarantine dir: $QUAR_DIR"
        exit 0
        ;;
      b|back)
        pop_menu
        ;;
      r|refresh)
        : # redraw next loop
        ;;
      c|clear)
        rep_clear_log
        ;;
      s|save)
        rep_save_log
        ;;
      p|pager)
      view_full_output
      ;;
      "")
        : # no-op
        ;;
      *)
        dispatch_current_menu "$choice"
        ;;
    esac
  done
}

main "$@"
