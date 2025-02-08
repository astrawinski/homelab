# VLAN Configuration

## Overview

VLANs (Virtual Local Area Networks) are used to segment network traffic, improving security, performance, and management of networked devices. This document outlines VLAN configurations in the homelab, including use cases and best practices.

---

## VLAN Assignments

The following VLANs are configured on the **UniFi Dream Machine SE (UDM SE)**:

| VLAN ID | Name        | Subnet         | Purpose                   | DHCP  |
|---------|-------------|----------------|---------------------------|-------|
| 1       | Default     | 10.87.0.0/24   | Management VLAN           | ✅    |
| 2       | IOT         | 10.87.2.0/24   | Smart home & IoT devices  | ✅    |
| 3       | HOME        | 10.87.3.0/24   | Main LAN for workstations | ✅    |
| 4       | GUEST       | 192.168.2.0/24 | Guest network             | ✅    |
| 50      | VPN         | 10.87.50.0/24  | VPN Clients               | ✅    |

---

## VLAN Configuration in UniFi

### **1. Creating VLAN Networks**

To create VLANs on the **UDM SE**, follow these steps:

1. Go to **UniFi Network Controller** → **Settings** → **Networks**.
2. Click **Create New Network**.
3. Set the **Name** (e.g., `Homelab VMs`).
4. Set **VLAN ID** (e.g., `40`).
5. Assign a **Subnet** (e.g., `10.87.40.0/24`).
6. Enable **DHCP Server** (if required).
7. Save changes.

### **2. Assign VLANs to Switch Ports**

1. Go to **UniFi Network Controller** → **Devices**.
2. Select the **switch** and go to the **Ports** section.
3. Choose a port, click **Edit**, and set the **VLAN ID**.
4. For **trunk ports**, allow multiple VLANs.
5. Save changes.

### **3. VLAN Configuration for Wi-Fi SSIDs**

Each VLAN can have a dedicated Wi-Fi SSID:

1. Go to **Settings → Wi-Fi**.
2. Create a new **Wi-Fi network**.
3. Assign it to the corresponding **VLAN**.
4. Configure security settings.
5. Save and apply changes.

---

## VLAN Configuration in Proxmox

Proxmox uses VLAN-aware bridges to pass VLAN traffic to virtual machines.

### **1. Configure VLAN Bridge in `/etc/network/interfaces`**

```sh
auto vmbr0
iface vmbr0 inet static
    address 10.87.40.2/24
    gateway 10.87.40.1
    bridge_ports eno1
    bridge_stp off
    bridge_fd 0
```

### **2. Assign VLANs to VMs**

1. Open **Proxmox Web UI**.
2. Edit a VM and go to **Hardware → Network**.
3. Set the **VLAN Tag** (e.g., `40` for Homelab VMs).
4. Save and restart the VM.

---

## Firewall Rules for VLAN Security

To enforce security between VLANs, set up firewall rules in **UDM SE**.

### **Example: Block IoT VLAN from Accessing LAN**

- **Source:** `10.87.20.0/24` (IoT VLAN)
- **Destination:** `10.87.10.0/24` (Trusted LAN)
- **Action:** Deny

### **Example: Allow Homelab VLAN to Access Proxmox**

- **Source:** `10.87.40.0/24` (Homelab VLAN)
- **Destination:** `10.87.10.2` (Proxmox Server)
- **Ports:** `8006` (Proxmox Web UI)
- **Action:** Accept

---

## Best Practices

- **Use VLANs to separate trusted, IoT, and guest traffic.**
- **Limit inter-VLAN communication** to only necessary services.
- **Use VLAN-aware access points** to segment Wi-Fi traffic.
- **Monitor VLAN traffic logs** for anomalies.

---

## Troubleshooting

### **1. Devices on VLAN Can’t Access Internet?**

- Ensure the **VLAN is assigned correctly** to the switch port.
- Check if the **UDM SE DHCP server** is running for the VLAN.
- Verify **firewall rules are not blocking VLAN traffic**.

### **2. VLAN Not Working on Proxmox?**

- Ensure VLAN tagging is set on the **VM network adapter**.
- Verify VLAN bridge configuration in `/etc/network/interfaces`.

---

## Future Enhancements

- **Automate VLAN configurations** using Ansible.
- **Enable VLAN-based QoS** for bandwidth prioritization.
- **Expand VLANs** to separate more services (e.g., Security Cameras VLAN).

---
