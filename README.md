# 🛡️ sysadmin-recon

> **A single-script Linux environment discovery tool for newly appointed Systems Administrators.**  
> Run it on any host to instantly understand what you're managing — hardware, network, users, services, security posture, and enterprise integrations — all in one shot!

---

## 📋 Table of Contents

- [Overview](#overview)
- [What It Checks](#what-it-checks)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Sample Output](#sample-output)
- [Sections Explained](#sections-explained)
- [Tips & Use Cases](#tips--use-cases)
- [Compatibility](#compatibility)
- [Disclaimer](#disclaimer)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

`sysadmin_recon.sh` is a zero-dependency Bash script that performs a comprehensive read-only audit of a Linux system. It is designed for:

- **New sysadmins** inheriting unknown infrastructure
- **On-call engineers** who need rapid situational awareness
- **Security teams** performing baseline assessments
- **DevOps/SRE teams** documenting fleet configurations

The script collects output from dozens of native Linux commands, organises them into 12 logical sections, and saves a timestamped report to `/tmp/`.

---

## What It Checks

| # | Section | Key Information Gathered |
|---|---------|--------------------------|
| 1 | **System Identity** | Hostname, FQDN, OS, kernel version, uptime, last reboot |
| 2 | **Hardware** | CPU, RAM, disks, LVM, RAID, PCI devices |
| 3 | **Network** | IPs, routes, DNS, firewall rules, open ports, NTP |
| 4 | **Users & Auth** | Local users, groups, sudoers, SSH keys, LDAP/SSSD/AD |
| 5 | **Services & Processes** | Running/failed systemd units, cron jobs, top processes |
| 6 | **Package Management** | Installed packages, pending updates, configured repos |
| 7 | **Storage** | `/etc/fstab`, NFS mounts/exports, Samba, iSCSI |
| 8 | **Security** | SELinux/AppArmor, SUID files, auth logs, fail2ban, auditd |
| 9 | **Monitoring & Logging** | Log rotation, remote syslog targets, monitoring agents |
| 10 | **Containers & VMs** | Docker, Podman, Kubernetes nodes and pods |
| 11 | **Enterprise Integrations** | Puppet, Ansible, Chef, Salt, Kerberos, Active Directory |
| 12 | **Quick Summary** | One-screen snapshot of the most important facts |

---

## Requirements

- **OS:** Any modern Linux distribution (Debian/Ubuntu, RHEL/CentOS/Rocky, Arch, SUSE, etc.)
- **Shell:** Bash 4.0+
- **Privileges:** `sudo` or `root` recommended for full output (the script degrades gracefully without it)
- **Dependencies:** None beyond standard Linux coreutils — the script uses only tools already present on the system

---

## Installation

### Option 1 — Clone the repo

```bash
git clone https://github.com/<your-username>/sysadmin-recon.git
cd sysadmin-recon
chmod +x sysadmin_recon.sh
```

### Option 2 — One-liner (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/<your-username>/sysadmin-recon/main/sysadmin_recon.sh \
  -o sysadmin_recon.sh && chmod +x sysadmin_recon.sh
```

### Option 3 — wget

```bash
wget -q https://raw.githubusercontent.com/<your-username>/sysadmin-recon/main/sysadmin_recon.sh
chmod +x sysadmin_recon.sh
```

---

## Usage

### Basic (recommended — run as root)

```bash
sudo ./sysadmin_recon.sh
```

### Without sudo (reduced output)

```bash
./sysadmin_recon.sh
```

### Save output to a custom location

```bash
sudo ./sysadmin_recon.sh | tee ~/my_server_audit.txt
```

### Run across multiple hosts via SSH

```bash
for host in web01 web02 db01 db02; do
  ssh "$host" "sudo bash -s" < sysadmin_recon.sh > "${host}_recon.txt"
  echo "Done: $host"
done
```

### Run from Ansible

```yaml
- name: Run sysadmin recon on all hosts
  hosts: all
  become: true
  tasks:
    - name: Copy script
      copy:
        src: sysadmin_recon.sh
        dest: /tmp/sysadmin_recon.sh
        mode: '0755'
    - name: Execute
      shell: /tmp/sysadmin_recon.sh
    - name: Fetch report
      fetch:
        src: "/tmp/sysadmin_recon_{{ inventory_hostname }}_*.txt"
        dest: ./reports/
        flat: false
```

---

## Sample Output

```
╔══════════════════════════════════════════════════════╗
║        Linux Enterprise Environment Recon           ║
║   Sun May 31 09:14:02 UTC 2026                      ║
╚══════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. SYSTEM IDENTITY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

--- Hostname & FQDN ---
prod-web-01
prod-web-01.example.internal

--- OS Release ---
PRETTY_NAME="Ubuntu 22.04.4 LTS"
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  12. ENVIRONMENT QUICK SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Hostname     : prod-web-01
FQDN         : prod-web-01.example.internal
OS           : Ubuntu 22.04.4 LTS
Kernel       : 5.15.0-107-generic
Uptime       : up 47 days, 3 hours, 22 minutes
CPU Cores    : 8
RAM Total    : 31Gi
Disk (root)  : 100G total, 42G used (44%)
IP Addresses : 10.0.1.15/24 192.168.100.5/24
Virt Type    : kvm
SELinux      : N/A
Firewall     : inactive/active

Report saved to: /tmp/sysadmin_recon_prod-web-01_20260531_091402.txt
```

---

## Sections Explained

### 1. System Identity
Establishes the basic facts: what is this machine called, what OS and kernel is it running, how long has it been up. A long uptime (1000+ days) often signals a machine that has never been rebooted for kernel updates — a potential security concern.

### 2. Hardware
Helps you understand resource capacity and physical/virtual topology. Checks CPU cores, total RAM, disk layout via `lsblk`, LVM volume groups, and RAID arrays via `/proc/mdstat`.

### 3. Network
The most critical section for understanding connectivity. Lists every IP, the routing table, DNS servers, firewall rules (`iptables`, `firewalld`, `ufw`), all listening ports, and time synchronisation status. Unexpected open ports or missing firewall rules are common findings here.

### 4. Users & Authentication
Enumerates local accounts, groups, sudoers configuration, SSH authorised keys, and enterprise auth integrations (SSSD, LDAP, Active Directory via `realm`). Stale accounts and overly broad sudo rules are common in inherited systems.

### 5. Services & Processes
Shows every running and failed systemd service, all cron jobs (system-wide and per-user), and top CPU/memory consumers. Failed services often indicate misconfigurations left unresolved by the previous admin.

### 6. Package Management
Lists installed package counts, upgradable packages, and configured repositories. A large queue of pending security updates is a common inherited debt.

### 7. Storage
Shows how storage is mounted (`/etc/fstab`), NFS exports and mounts, Samba shares, and iSCSI sessions. Undocumented NFS exports to `*` are a frequent security finding.

### 8. Security
Checks SELinux/AppArmor enforcement mode, world-writable directories, SUID binaries, recent authentication log entries, and fail2ban status. This section often surfaces the most urgent action items.

### 9. Monitoring & Logging
Checks whether logs are being forwarded to a central syslog server, whether log rotation is configured, and whether any monitoring agents (Zabbix, Datadog, Prometheus exporters, etc.) are running.

### 10. Containers & Virtualisation
Detects whether the host is a VM, and checks for Docker, Podman, and Kubernetes. Lists all running and stopped containers.

### 11. Enterprise Integrations
Checks for configuration management agents (Puppet, Ansible, Chef, Salt) and identity integrations (Kerberos tickets, AD realm membership). A server missing from a Puppet/Ansible inventory is often a forgotten shadow system.

### 12. Quick Summary
A concise, copy-pasteable snapshot of the most important facts — useful for incident reports, handover documents, or Slack/Teams messages when escalating an issue.

---

## Tips & Use Cases

**Diff two servers to find inconsistencies:**
```bash
diff <(ssh web01 "sudo bash sysadmin_recon.sh 2>/dev/null") \
     <(ssh web02 "sudo bash sysadmin_recon.sh 2>/dev/null")
```

**Find all servers missing a monitoring agent:**
```bash
grep -L "ACTIVE.*zabbix_agentd" /path/to/reports/*.txt
```

**Extract just the quick summary from all reports:**
```bash
for f in reports/*.txt; do
  echo "=== $f ==="; sed -n '/ENVIRONMENT QUICK SUMMARY/,/Report saved/p' "$f"
done
```

**Schedule a weekly audit:**
```cron
0 6 * * 1 root /opt/sysadmin_recon.sh > /var/log/weekly_recon.log 2>&1
```

---

## Compatibility

| Distribution | Tested | Notes |
|---|---|---|
| Ubuntu 20.04 / 22.04 / 24.04 | ✅ | Full support |
| Debian 11 / 12 | ✅ | Full support |
| RHEL / CentOS 7 / 8 / 9 | ✅ | Uses `yum`/`dnf` path |
| Rocky Linux / AlmaLinux 8 / 9 | ✅ | Full support |
| Amazon Linux 2 / 2023 | ✅ | Full support |
| SUSE / openSUSE | ⚠️ | Partial — some commands differ |
| Arch Linux | ⚠️ | Partial — no `apt`/`yum`, limited systemd services |

The script uses `command -v` checks before every tool call and prints a graceful message for missing commands, so it will never crash due to a missing binary.

---

## Disclaimer

This script is **read-only** — it does not make any changes to the system. All commands are informational only (`cat`, `ls`, `ss`, `ps`, `df`, etc.).

However:
- Running it as root gives full visibility but also means any bugs could theoretically cause unexpected reads of sensitive files.
- In highly regulated environments (PCI-DSS, HIPAA), ensure report files containing system details are handled securely and deleted after review.
- Do **not** commit report output to version control — it contains sensitive system information.

---

## Contributing

Contributions welcome! To add support for a new tool, monitoring agent, or enterprise integration:

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/add-grafana-agent-check`
3. Add your section to `sysadmin_recon.sh` following the existing pattern
4. Test on at least one distro
5. Open a Pull Request with a description of what was added and why

Please keep the script self-contained (no external dependencies) and ensure all new command calls are wrapped with `command -v` guards.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built for sysadmins, by sysadmins. If it saved you an hour on day one, give it a ⭐.*
