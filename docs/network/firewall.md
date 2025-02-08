# Homelab Firewall Configuration

## Overview

The firewall in the homelab is managed via the **UniFi Dream Machine SE (UDM SE)** and controls network security, access, and segmentation. This document outlines the firewall rules, best practices, and troubleshooting steps.

---

## Firewall Objectives

- **Prevent Unauthorized Access**: Ensure external threats cannot reach internal services.
- **Network Segmentation**: Enforce VLAN isolation and allow only necessary traffic.
- **Optimize Performance**: Prevent unnecessary traffic from consuming bandwidth.
- **Enable Remote Access**: Securely allow VPN and SSH access where needed.

---

## Default Firewall Rules

By default, the UniFi firewall applies these rules:

| Rule Type  | Source | Destination | Action |
|------------|--------|-------------|--------|
| LAN IN    | Any    | LAN         | Accept |
| WAN IN    | Any    | WAN         | Drop   |
| GUEST IN  | Any    | LAN         | Drop   |
| LOCAL IN  | Any    | Controller  | Accept |

- **LAN IN** allows unrestricted internal communication.
- **WAN IN** blocks incoming connections from the internet.
- **GUEST IN** prevents guest devices from accessing internal resources.
- **LOCAL IN** allows communication with the UniFi controller.

---

## Custom Firewall Rules

### **1. VLAN Isolation Rules**

To enforce security between VLANs, define explicit allow or deny rules.

#### **Deny IoT VLAN Access to LAN**

```text
Source: 10.87.20.0/24 (IoT VLAN)
Destination: 10.87.10.0/24 (Trusted LAN)
Action: Drop
```

#### **Allow Homelab VLAN to Access Proxmox**

```text
Source: 10.87.40.0/24 (Homelab VLAN)
Destination: 10.87.10.2 (Proxmox Server)
Ports: 8006 (Web UI)
Action: Accept
```

#### **Allow Remote VPN Access**

```text
Source: WireGuard VPN (10.87.50.0/24)
Destination: Trusted LAN (10.87.10.0/24)
Action: Accept
```

---

## Port Forwarding Rules

Port forwarding allows external access to internal services.

### **Example: SSH Access to a Specific Host**

- **External Port**: `2222`
- **Internal Host**: `10.87.10.5`
- **Internal Port**: `22`
- **Action**: Accept

Command to test from outside:

```sh
ssh -p 2222 user@your-external-ip
```

### **Example: Web Server Access**

- **External Port**: `443`
- **Internal Host**: `10.87.10.20`
- **Internal Port**: `443`
- **Action**: Accept

Ensure HTTPS is enabled and the server is secured.

---

## IDS/IPS & Threat Management

The **UDM SE** has built-in Intrusion Detection & Prevention System (IDS/IPS). To enable:

1. Go to **Settings → Threat Management**.
2. Set **Detection Mode** (IDS) or **Prevention Mode** (IPS).
3. Choose a security level:
   - **Low**: Minimal impact, allows most traffic.
   - **Balanced**: Recommended setting for security vs. performance.
   - **High**: Blocks aggressive traffic patterns.

---

## Best Practices

- **Use VLANs** to separate trusted, IoT, and guest networks.
- **Limit port forwarding** to only necessary services.
- **Enable logging** for all critical firewall rules.
- **Use VPNs** instead of exposing services to the internet.
- **Regularly review logs** for unauthorized access attempts.

---

## Troubleshooting

### **1. Can’t Access a Service?**

- Check firewall logs for dropped packets.
- Ensure correct **port forwarding rules** are applied.
- Verify that the service is **listening on the correct port**.

### **2. Internet Slow After Enabling IPS?**

- Reduce security level from **High** to **Balanced**.
- Upgrade UniFi firmware for performance improvements.

### **3. VLAN Devices Can’t Communicate?**

- Check VLAN rules and ensure **inter-VLAN traffic** is permitted where needed.
- Use **ping tests** to diagnose reachability issues.

---

## Future Enhancements

- **Automate firewall rule changes** using Ansible.
- **Implement Geo-IP blocking** for unnecessary regions.
- **Monitor firewall events** with external logging solutions.

---
