# Ansible Automation for Homelab

## Overview

This document outlines the use of Ansible for automating the homelab setup, including infrastructure provisioning, configuration management, and software installation.

---

## Directory Structure

```text
homelab/
├── ansible/
│   ├── ansible.cfg          # Ansible configuration file
│   ├── group_vars/          # Group-specific variables
│   ├── host_vars/           # Host-specific variables
│   ├── inventories/         # Inventory files for different environments
│   ├── playbooks/           # Playbooks for automating tasks
│   ├── roles/               # Modular role definitions
```

---

## Ansible Configuration

- The **`ansible.cfg`** file contains global settings, including:
  - Default inventory location
  - SSH connection parameters
  - Privilege escalation settings

---

## Inventory Management

- Inventories will define the hosts Ansible manages.
- Inventory files are stored in `inventories/` and can be static (`hosts.ini`) or dynamic.

## Key Playbooks (Examples for now)

| Playbook                 | Description |
|--------------------------|-------------|
| `install_wsl.yml`        | Installs and configures WSL on Windows machines. |
| `bootstrap_windows.yml`  | Automates Windows 11 Pro setup. |
| `configure_proxmox.yml`  | Sets up Proxmox, storage, and networking. |
| `unifi_config.yml`       | Manages UniFi network configuration. |

---

## Best Practices

- Use **roles** for modular playbooks (`roles/` directory).
- Store sensitive variables in `ansible-vault`.
- Ensure **idempotency**—playbooks should not make unnecessary changes.
- Use **tags** to run specific tasks:

  ```sh
  ansible-playbook install_wsl.yml --tags="install"
  ```

- Test playbooks using `--check` mode before applying changes.

---

## Running Ansible Playbooks

- Running a playbook:

  ```sh
  ansible-playbook playbooks/bootstrap_windows.yml -i inventories/hosts.ini
  ```

- Running a playbook on a single host:

  ```sh
  ansible-playbook playbooks/configure_proxmox.yml -l proxmox01.internal.strawinski.net
  ```

---

## Future Enhancements

- Implement dynamic inventory scripts.
- Automate backups for Ansible-managed hosts.
- Improve logging and reporting of Ansible runs.

---
