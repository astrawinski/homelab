# UniFi UDM SE Configuration

## Overview

The **UniFi Dream Machine Special Edition (UDM SE)** is the primary network gateway and controller in the homelab. It provides:

- **Routing & Firewall**: Controls internet and internal LAN traffic.
- **VLAN Segmentation**: Separates network traffic for security and efficiency.
- **VPN & Remote Access**: Allows secure access to internal resources.
- **Integration with Proxmox**: Manages network connectivity for virtual machines.
- **Threat Management & IDS/IPS**: Protects the network from external threats.

---

## Hardware Specifications

- **Model:** UniFi Dream Machine Special Edition (UDM SE)
- **CPU:** Quad-core ARM Cortex-A57
- **RAM:** 4GB DDR4
- **Storage:** 16GB eMMC (expandable with external storage)
- **Networking:**
  - **8× GbE LAN Ports (RJ45)**
  - **1× 2.5GbE WAN Port**
  - **1× 10GbE SFP+ Port**
  - **Built-in UniFi Controller**

---

## Initial Setup

### **1. Connect & Power On**

- Plug the **WAN** port into your modem or upstream router.
- Connect a computer to **LAN Port 1** (or use Wi-Fi if available).
- Power on the UDM SE and wait for the status LED to turn **solid white**.

### **2. Access the UniFi Controller**

- Open a browser and go to:  
  **[https://unifi.ui.com](https://unifi.ui.com)**
- Log in with your **Ubiquiti account**.
- Follow the setup wizard to:
  - Set an **admin username/password**.
  - Configure **WAN settings** (DHCP, Static IP, or PPPoE).
  - Set up **LAN & VLAN networks**.

### **3. Update Firmware**

- Go to **Settings → System → Updates**.
- If an update is available, apply it to ensure stability and security.

---

## Network Configuration

### **1. Default Network Setup**

By default, the UDM SE creates:

- **LAN (192.168.1.0/24)**
- **Guest VLAN (192.168.2.0/24)**

### **2. Custom VLAN Setup**

To segment traffic, create VLANs in **Settings → Networks**:

#### Example VLANs

| VLAN | Purpose              | Subnet          | DHCP Enabled |
|------|----------------------|----------------|-------------|
| 10   | Trusted LAN          | 10.87.10.0/24  | ✅          |
| 20   | IoT Devices         | 10.87.20.0/24  | ✅          |
| 30   | Guest Wi-Fi         | 10.87.30.0/24  | ✅          |
| 40   | Homelab VMs         | 10.87.40.0/24  | ✅          |

#### Example VLAN Configuration in UDM SE

- **Go to `Settings → Networks` → Create New Network**
- Set **Network Name** (e.g., `Homelab VMs`)
- Set **VLAN ID** (e.g., `40`)
- Assign a **subnet** (e.g., `10.87.40.0/24`)
- Enable **DHCP** if devices need automatic IPs.

---

## Firewall Configuration

### **1. Default Rules**

- **LAN IN**: Allows internal traffic between devices.
- **WAN IN**: Blocks all unsolicited inbound connections.
- **GUEST IN**: Isolates guest traffic from LAN.

### **2. Custom Firewall Rules**

To control network access:

1. **Deny IoT access to LAN**
   - Rule: **Deny Traffic from VLAN 20 to VLAN 10**
   - **Source:** `10.87.20.0/24`
   - **Destination:** `10.87.10.0/24`
   - **Action:** Deny

2. **Allow Proxmox management from LAN**
   - **Source:** `10.87.10.0/24`
   - **Destination:** `10.87.40.2` (Proxmox IP)
   - **Port:** `8006` (Proxmox UI)
   - **Action:** Allow

---

## Backup Strategy

- Enable **automatic UniFi Cloud backups**.
- Export **local backup files** (`Settings → System → Backup`).
- Store periodic backups on a **separate storage device**.

---

## Troubleshooting

### **1. Internet Not Working?**

- Check **WAN status** (`Settings → Internet`).
- Restart **modem and UDM SE**.

### **2. VLANs Not Working?**

- Ensure VLANs are **assigned correctly** to interfaces.
- Verify **firewall rules are not blocking traffic**.

### **3. Slow Network Speeds?**

- Disable **IDS/IPS** (if high CPU usage).
- Check **QoS & Bandwidth Profiles**.

---

## Future Enhancements

- **Implement High Availability (HA)** using a backup router.
- **Expand VLANs** to segment services further.
- **Automate firewall rule management** with Ansible.

---
