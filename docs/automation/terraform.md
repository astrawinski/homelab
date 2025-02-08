# Terraform Infrastructure Automation

## Overview

Terraform is used to define and manage the infrastructure of the homelab in a declarative manner. It allows for infrastructure as code (IaC), enabling automated provisioning, changes, and version control of homelab resources.

---

## Terraform Setup

### **1. Install Terraform**

Ensure Terraform is installed on your local machine or automation server:

```sh
sudo apt update && sudo apt install terraform -y
```

Verify installation:

```sh
terraform version
```

### **2. Directory Structure**

The Terraform configuration files are located in the `terraform/` directory:

```text
terraform/
├── main.tf        # Main Terraform configuration
├── variables.tf   # Variable definitions
├── outputs.tf     # Output values
├── providers.tf   # Provider configuration
├── modules/       # Custom Terraform modules
└── terraform.tfvars # Variable values (git-ignored if sensitive)
```

---

## Terraform Configuration

### **1. Define Providers**

Terraform uses providers to interact with cloud platforms, virtual machines, and other infrastructure. Example:

```hcl
provider "proxmox" {
  pm_api_url      = "https://proxmox.internal.strawinski.net:8006/api2/json"
  pm_api_token_id = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
}
```

### **2. Define Resources**

Example: Creating a Proxmox virtual machine:

```hcl
resource "proxmox_vm_qemu" "debian_vm" {
  name        = "debian-server"
  target_node = "proxmox"
  memory      = 4096
  cores       = 2
  os_type     = "cloud-init"
  disk {
    size = "20G"
    type = "scsi"
  }
}
```

### **3. Define Variables**

Define reusable variables in `variables.tf`:

```hcl
variable "pm_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}
```

### **4. Initialize and Apply Terraform**

Run the following commands to apply the configuration:

```sh
terraform init   # Initialize the working directory
terraform plan   # Preview changes
terraform apply  # Apply changes to the infrastructure
```

---

## State Management

Terraform maintains state to track managed infrastructure. Store Terraform state securely:

```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

For collaboration, use **Terraform Cloud** or a remote backend (e.g., S3, GitLab, Proxmox Storage).

---

## Best Practices

- **Use modules** to organize reusable code.
- **Use `.gitignore`** to exclude sensitive files like `terraform.tfvars`.
- **Use Terraform workspaces** for multiple environments (dev, prod).
- **Lock provider versions** to prevent unexpected updates.

---

## Next Steps

1. Define more Terraform modules for homelab automation.
2. Integrate Terraform with Ansible for post-provisioning configuration.
3. Automate Terraform runs using GitHub Actions or a local CI/CD pipeline.

---
