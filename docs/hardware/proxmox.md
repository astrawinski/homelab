# Proxmox Configuration

## Overview

Proxmox Virtual Environment (Proxmox VE) is used as the primary hypervisor in the homelab. It enables efficient virtualization and containerization, allowing for flexible infrastructure management.

---

## Hardware Specifications

- **Host Machine:** Dedicated Proxmox server
- **Storage:** SSD for performance, additional HDD for backups
- **Network:** Connected via `eno1` interface
- **Processor:** Multi-core CPU for virtualization efficiency
- **Memory:** Sufficient RAM to support multiple VMs and containers

---

## Installation

### **1. Download and Prepare Installation Media**

- Obtain the latest Proxmox VE ISO from [Proxmox Downloads](https://www.proxmox.com/en/downloads)
- Flash the ISO to a USB drive using `dd` or `balenaEtcher`

### **2. Install Proxmox VE**

- Boot from USB and follow the guided installation
- Choose **SSD** as the installation target
- Configure network settings with **`eno1`** as the management interface
- Set the **timezone** to match the local environment

### **3. Initial Configuration**

After installation, configure:

```sh
nano /etc/hosts
```

Ensure the Proxmox hostname is correctly set:

```sh
127.0.0.1 localhost
192.168.x.x proxmox.internal.strawinski.net proxmox
```

---

## Networking Configuration

### **1. Network Interfaces**

The management interface is `eno1`. Bridge networking is used for VM connectivity.

Example `/etc/network/interfaces` configuration:

```sh
auto lo
iface lo inet loopback

auto eno1
iface eno1 inet manual

auto vmbr0
iface vmbr0 inet static
    address 10.87.x.x/24
    gateway 10.87.x.1
    bridge_ports eno1
    bridge_stp off
    bridge_fd 0
```

### **2. VLAN Support**

VLANs are managed through the **UniFi UDM SE** and assigned via bridge interfaces in Proxmox.

---

## Storage Configuration

### **1. Local Storage**

- `local` storage: Used for ISO images and backups.
- `local-lvm` (on SSD): Default VM storage for optimal performance.

### **2. Network Storage (Future Expansion)**

- **NFS Mounts** for additional storage
- **ZFS RAID** for redundancy

---

## Virtual Machines and Containers

### **1. VM Management**

- Windows 11 Pro VM configured for automation testing
- Debian-based Linux VMs for services

### **2. LXC Containers**

- Lightweight Linux Containers for specific services

---

## Backup Strategy

- **VM Snapshots** before major changes
- **Offsite Backups** via scheduled `rsync` or Proxmox Backup Server (PBS)
- **Automated Nightly Backups** for critical VMs

---

## Automation

### **1. Ansible Playbooks**

- Proxmox is configured and maintained using **Ansible**
- Automated deployment of new VMs and configuration adjustments

Example playbook snippet:

```yaml
- name: Configure Proxmox VMs
  hosts: proxmox
  tasks:
    - name: Ensure VM is present
      community.general.proxmox_kvm:
        api_user: root@pam
        api_password: "{{ vault_proxmox_password }}"
        api_host: proxmox.internal.strawinski.net
        vmid: 100
        node: proxmox
        state: started
```

---

## Troubleshooting

### **1. Common Issues**

- **Networking not working?**
  - Check VLAN assignments in UniFi
  - Restart networking: `systemctl restart networking`
- **Storage errors?**
  - Ensure `local-lvm` has available space
  - Use `pvesm status` to check storage pools
- **VM not starting?**
  - Check logs with `journalctl -xe` and `qm status <VMID>`

---

## Future Enhancements

- **Implement NFS/ZFS for external storage expansion**
- **Optimize backup strategies** with automated offsite replication
- **Integrate Terraform** for Infrastructure as Code deployment

---
