#!/usr/bin/env bash
# =============================================================================
# sysadmin_recon.sh — Enterprise Linux Environment Discovery Script
# Run as root or with sudo for full output.
# Output is written to: /tmp/sysadmin_recon_<hostname>_<date>.txt
# =============================================================================

set -euo pipefail

REPORT="/tmp/sysadmin_recon_$(hostname -s)_$(date +%Y%m%d_%H%M%S).txt"
WARN="\e[33m[WARN]\e[0m"
OK="\e[32m[OK]\e[0m"
SECTION="\e[34m[----]\e[0m"

exec > >(tee -a "$REPORT") 2>&1

hr()  { echo; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }
hdr() { hr; echo "  $1"; hr; }
run() { command -v "$1" &>/dev/null && "$@" 2>/dev/null || echo "(command '$1' not found)"; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        Linux Enterprise Environment Recon           ║"
echo "║   $(date)   ║"
echo "╚══════════════════════════════════════════════════════╝"

# ─────────────────────────────────────────────
# 1. SYSTEM IDENTITY
# ─────────────────────────────────────────────
hdr "1. SYSTEM IDENTITY"

echo "--- Hostname & FQDN ---"
hostname; hostname -f 2>/dev/null || echo "(FQDN lookup failed)"

echo -e "\n--- OS Release ---"
cat /etc/os-release 2>/dev/null || cat /etc/redhat-release 2>/dev/null

echo -e "\n--- Kernel ---"
uname -r

echo -e "\n--- System Uptime ---"
uptime -p 2>/dev/null || uptime

echo -e "\n--- Last Reboot ---"
run who -b

echo -e "\n--- Architecture ---"
uname -m; lscpu | grep -E "^Architecture|^Model name|^Socket|^Thread|^Core" 2>/dev/null

# ─────────────────────────────────────────────
# 2. HARDWARE OVERVIEW
# ─────────────────────────────────────────────
hdr "2. HARDWARE OVERVIEW"

echo "--- CPU ---"
lscpu | grep -E "^(CPU\(s\)|Model name|Thread|Core|Socket)" 2>/dev/null

echo -e "\n--- Memory ---"
free -h

echo -e "\n--- Block Devices & Disks ---"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE 2>/dev/null

echo -e "\n--- Disk Usage ---"
df -hT --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null

echo -e "\n--- RAID / MD Devices ---"
cat /proc/mdstat 2>/dev/null || echo "(no mdstat)"

echo -e "\n--- LVM ---"
run pvs; run vgs; run lvs

echo -e "\n--- PCI Devices (summary) ---"
run lspci | grep -iE "network|storage|raid|vga" 2>/dev/null | head -30

# ─────────────────────────────────────────────
# 3. NETWORK CONFIGURATION
# ─────────────────────────────────────────────
hdr "3. NETWORK CONFIGURATION"

echo "--- IP Addresses ---"
ip -br addr show 2>/dev/null || ifconfig -a 2>/dev/null

echo -e "\n--- Routing Table ---"
ip route show 2>/dev/null

echo -e "\n--- DNS Configuration ---"
cat /etc/resolv.conf

echo -e "\n--- /etc/hosts ---"
cat /etc/hosts

echo -e "\n--- Active Connections (established) ---"
ss -tnp state established 2>/dev/null | head -40

echo -e "\n--- Listening Ports (TCP/UDP) ---"
ss -tlnup 2>/dev/null | head -60

echo -e "\n--- Firewall (iptables) ---"
iptables -L -n --line-numbers 2>/dev/null | head -80 || echo "(iptables not available or no rules)"

echo -e "\n--- Firewall (firewalld) ---"
run firewall-cmd --list-all 2>/dev/null

echo -e "\n--- Firewall (ufw) ---"
run ufw status verbose 2>/dev/null

echo -e "\n--- Network Interfaces (detailed) ---"
ip -s link show 2>/dev/null | head -80

echo -e "\n--- Hostname resolution (nsswitch) ---"
grep ^hosts /etc/nsswitch.conf 2>/dev/null

echo -e "\n--- NTP / Chrony / Timesyncd ---"
run timedatectl status
run chronyc tracking 2>/dev/null
run ntpq -p 2>/dev/null

# ─────────────────────────────────────────────
# 4. USERS & AUTHENTICATION
# ─────────────────────────────────────────────
hdr "4. USERS & AUTHENTICATION"

echo "--- Currently Logged In ---"
w 2>/dev/null || who

echo -e "\n--- Last Logins (last 20) ---"
last -20 2>/dev/null

echo -e "\n--- Failed Logins (last 20) ---"
lastb -20 2>/dev/null || echo "(lastb requires root)"

echo -e "\n--- Local Users (UID >= 1000, non-system) ---"
awk -F: '$3 >= 1000 && $3 < 65534 {print $1, "uid="$3, "home="$6, "shell="$7}' /etc/passwd

echo -e "\n--- System Users (UID < 1000) ---"
awk -F: '$3 < 1000 {print $1, "uid="$3, "shell="$7}' /etc/passwd

echo -e "\n--- Groups ---"
cat /etc/group | grep -v "^#"

echo -e "\n--- Sudoers / sudo access ---"
cat /etc/sudoers 2>/dev/null | grep -v "^#\|^$" || echo "(no read access)"
ls /etc/sudoers.d/ 2>/dev/null && cat /etc/sudoers.d/* 2>/dev/null | grep -v "^#\|^$"

echo -e "\n--- PAM / SSSD / LDAP ---"
run sssd --version 2>/dev/null
[ -f /etc/sssd/sssd.conf ] && cat /etc/sssd/sssd.conf || echo "(no sssd.conf)"
[ -f /etc/ldap/ldap.conf ] && cat /etc/ldap/ldap.conf || echo "(no ldap.conf)"

echo -e "\n--- Password Policy ---"
grep -E "^PASS_|^LOGIN_RETRIES|^LOGIN_TIMEOUT" /etc/login.defs 2>/dev/null

# ─────────────────────────────────────────────
# 5. SERVICES & PROCESSES
# ─────────────────────────────────────────────
hdr "5. SERVICES & PROCESSES"

echo "--- Systemd Services (running) ---"
systemctl list-units --type=service --state=running --no-pager 2>/dev/null | head -60

echo -e "\n--- Systemd Services (failed) ---"
systemctl list-units --type=service --state=failed --no-pager 2>/dev/null

echo -e "\n--- Systemd Timers ---"
systemctl list-timers --no-pager 2>/dev/null | head -30

echo -e "\n--- Top Processes by CPU ---"
ps aux --sort=-%cpu | head -20

echo -e "\n--- Top Processes by Memory ---"
ps aux --sort=-%mem | head -20

# ─────────────────────────────────────────────
# 6. PACKAGE MANAGEMENT & UPDATES
# ─────────────────────────────────────────────
hdr "6. PACKAGE MANAGEMENT & UPDATES"

echo "--- Package Manager Detection ---"
if command -v apt &>/dev/null; then
  echo "[apt] Installed packages: $(dpkg -l | grep -c '^ii')"
  echo "[apt] Upgradable:"; apt list --upgradable 2>/dev/null | head -30
elif command -v yum &>/dev/null; then
  echo "[yum] Installed packages: $(rpm -qa | wc -l)"
  echo "[yum] Pending updates:"; yum check-update 2>/dev/null | head -30 || true
elif command -v dnf &>/dev/null; then
  echo "[dnf] Installed packages: $(rpm -qa | wc -l)"
  echo "[dnf] Pending updates:"; dnf check-update 2>/dev/null | head -30 || true
fi

echo -e "\n--- Repositories ---"
ls /etc/apt/sources.list.d/ 2>/dev/null && cat /etc/apt/sources.list 2>/dev/null
ls /etc/yum.repos.d/ 2>/dev/null && grep -h baseurl /etc/yum.repos.d/*.repo 2>/dev/null | head -20

echo -e "\n--- Kernel Versions Installed ---"
ls /boot/vmlinuz* 2>/dev/null || rpm -q kernel 2>/dev/null

# ─────────────────────────────────────────────
# 7. STORAGE & FILESYSTEMS
# ─────────────────────────────────────────────
hdr "7. STORAGE & FILESYSTEMS"

echo "--- /etc/fstab ---"
cat /etc/fstab

echo -e "\n--- Mounted Filesystems ---"
mount | grep -v "^cgroup\|^proc\|^sys\|^devpts\|^tmpfs\|^udev\|^run\|^securityfs\|^pstore\|^bpf\|^tracefs"

echo -e "\n--- NFS Mounts ---"
mount | grep nfs || echo "(none)"

echo -e "\n--- NFS Exports ---"
cat /etc/exports 2>/dev/null || echo "(no exports file)"

echo -e "\n--- Samba / CIFS ---"
cat /etc/samba/smb.conf 2>/dev/null | grep -v "^#\|^;" | head -40 || echo "(no samba config)"

echo -e "\n--- iSCSI Sessions ---"
run iscsiadm -m session 2>/dev/null || echo "(no iscsi or not installed)"

# ─────────────────────────────────────────────
# 8. SECURITY & COMPLIANCE
# ─────────────────────────────────────────────
hdr "8. SECURITY & COMPLIANCE"

echo "--- SELinux Status ---"
run sestatus 2>/dev/null || echo "(SELinux not present)"

echo -e "\n--- AppArmor Status ---"
run apparmor_status 2>/dev/null || aa-status 2>/dev/null || echo "(AppArmor not present)"

echo -e "\n--- SUID/SGID Files (top dirs only, may be slow) ---"
find /usr/bin /usr/sbin /bin /sbin -perm /6000 -type f 2>/dev/null | head -30

echo -e "\n--- Listening Services vs Firewall (quick check) ---"
ss -tlnp 2>/dev/null | awk 'NR>1 {print $4}' | awk -F: '{print $NF}' | sort -un

echo -e "\n--- Recent Auth Log Entries ---"
journalctl -u sshd --since "24 hours ago" --no-pager 2>/dev/null | tail -30 \
  || grep -i "sshd\|sudo\|su\[" /var/log/auth.log 2>/dev/null | tail -30 \
  || grep -i "sshd\|sudo" /var/log/secure 2>/dev/null | tail -30 \
  || echo "(no accessible auth log)"

echo -e "\n--- Auditd Status ---"
run auditctl -s 2>/dev/null || echo "(auditd not running)"

echo -e "\n--- Fail2ban Status ---"
run fail2ban-client status 2>/dev/null || echo "(fail2ban not installed)"

# ─────────────────────────────────────────────
# 9. MONITORING & LOGGING
# ─────────────────────────────────────────────
hdr "9. MONITORING & LOGGING"

echo "--- Syslog / Journald disk usage ---"
journalctl --disk-usage 2>/dev/null

echo -e "\n--- Log Rotation Config ---"
cat /etc/logrotate.conf 2>/dev/null | grep -v "^#\|^$" | head -20
ls /etc/logrotate.d/ 2>/dev/null

echo -e "\n--- Monitoring Agents ---"
for agent in zabbix_agentd nagios nrpe node_exporter prometheus filebeat metricbeat telegraf datadog-agent; do
  systemctl is-active "$agent" 2>/dev/null && echo "  [ACTIVE] $agent" || true
done

echo -e "\n--- Rsyslog / Syslog-ng Remote Targets ---"
grep -E "^[^#].*(@@?[0-9a-zA-Z])" /etc/rsyslog.conf /etc/rsyslog.d/*.conf 2>/dev/null | head -20 \
  || grep -E "destination|tcp|udp" /etc/syslog-ng/syslog-ng.conf 2>/dev/null | head -20 \
  || echo "(no remote syslog detected)"

# ─────────────────────────────────────────────
# 10. VIRTUALISATION & CONTAINERS
# ─────────────────────────────────────────────
hdr "10. VIRTUALISATION & CONTAINERS"

echo "--- Virtualisation Type ---"
run systemd-detect-virt 2>/dev/null || echo "(unknown)"

echo -e "\n--- Docker ---"
if command -v docker &>/dev/null; then
  docker version --format "Server: {{.Server.Version}}" 2>/dev/null
  echo "Running containers:"; docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null
  echo "All containers:";     docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null
else echo "(docker not installed)"; fi

echo -e "\n--- Podman ---"
if command -v podman &>/dev/null; then
  podman version 2>/dev/null | grep Version
  podman ps -a 2>/dev/null
else echo "(podman not installed)"; fi

echo -e "\n--- Kubernetes (kubectl) ---"
if command -v kubectl &>/dev/null; then
  kubectl version --short 2>/dev/null
  kubectl get nodes 2>/dev/null
  kubectl get pods --all-namespaces 2>/dev/null | head -20
else echo "(kubectl not installed)"; fi

# ─────────────────────────────────────────────
# 11. ENTERPRISE INTEGRATIONS
# ─────────────────────────────────────────────
hdr "11. ENTERPRISE INTEGRATIONS"

echo "--- Kerberos / Active Directory ---"
run klist 2>/dev/null || echo "(no kerberos tickets)"
cat /etc/krb5.conf 2>/dev/null | grep -v "^#\|^$" | head -30 || echo "(no krb5.conf)"

echo -e "\n--- realm / Active Directory Membership ---"
run realm list 2>/dev/null || echo "(realm not installed)"

echo -e "\n--- Puppet Agent ---"
run puppet agent --version 2>/dev/null && puppet config print server 2>/dev/null || echo "(not installed)"

echo -e "\n--- Ansible ---"
run ansible --version 2>/dev/null | head -5

echo -e "\n--- Chef ---"
run chef-client --version 2>/dev/null || echo "(not installed)"

echo -e "\n--- Salt ---"
run salt-minion --version 2>/dev/null || echo "(not installed)"

echo -e "\n--- Backup Agent (check common ones) ---"
for bk in bacula-fd veeam commvault amanda-server; do
  systemctl is-active "$bk" 2>/dev/null && echo "  [ACTIVE] $bk" || true
done

# ─────────────────────────────────────────────
# 12. ENVIRONMENT SUMMARY
# ─────────────────────────────────────────────
hdr "12. ENVIRONMENT QUICK SUMMARY"

echo "Hostname     : $(hostname)"
echo "FQDN         : $(hostname -f 2>/dev/null)"
echo "OS           : $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
echo "Kernel       : $(uname -r)"
echo "Uptime       : $(uptime -p 2>/dev/null || uptime)"
echo "CPU Cores    : $(nproc)"
echo "RAM Total    : $(free -h | awk '/^Mem/{print $2}')"
echo "Disk (root)  : $(df -h / | awk 'NR==2{print $2 " total, " $3 " used (" $5 ")"}')"
echo "IP Addresses : $(ip -br addr show | grep UP | awk '{print $3}' | tr '\n' ' ')"
echo "Virt Type    : $(systemd-detect-virt 2>/dev/null || echo unknown)"
echo "SELinux      : $(getenforce 2>/dev/null || echo N/A)"
echo "Firewall     : $(systemctl is-active firewalld ufw 2>/dev/null | paste -s -d'/' || echo unknown)"
echo ""
echo "Report saved to: $REPORT"
echo ""
