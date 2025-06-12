# Homelab Infrastructure

A modern, Infrastructure-as-Code homelab setup using Ubuntu Server, Podman containers, and Terraform.

## 🎯 Goals

- **Modular**: Each service managed independently via Terraform
- **Reliable**: Btrfs snapshots for easy rollbacks
- **Simple**: Set-and-forget local network services
- **Documented**: Clear setup and maintenance procedures

## 🏗️ Architecture

### Phase 1: Server Foundation ✅
- **Host OS**: Ubuntu Server 24.04 LTS with Btrfs
- **Container Runtime**: Rootless Podman with remote access
- **Snapshot Strategy**: Conservative Btrfs snapshots (7 days retention)
- **Basic Security**: UFW firewall and SSH hardening

### Phase 2: Local Network Services 🔄
- **Containers**: All services (e.g., Jellyfin, Home Assistant) are planned to be managed by Terraform using Podman.
- **Networking**:
    -   **mDNS (.local domains)**: Service discovery is handled by mDNS.
        -   *Current Implementation*: A Python script (`publish-mdns-aliases.py`) runs directly on the host, managed by a systemd service. Terraform deploys this script, its configuration, and the service unit. This logic is contained within the `terraform/system/mdns/` module.
        -   *Future Enhancement*: The mDNS publisher itself will be containerized after core services are stable.
- **Reverse Proxy**: Caddy is planned for clean URLs without port numbers for web-accessible services.
- **Goal**: Everything working perfectly on home network first.

### Phase 3: Secure External Access (Future)
- **Home Assistant**: External access via secure tunnel/VPN
- **Jellyseerr**: (TBD) Possible external access for media requests
- **Security**: SSL certificates, enhanced authentication
- **Isolation**: Separate network segments for internet-facing services

## 🚀 Services

(This section outlines planned services. Terraform configurations for these will be added as they are developed.)

| Service | Phase 2 Status | Phase 3 Status | Description |
|---------|----------------|----------------|-------------|
| Minecraft | 🔄 Planned | ❌ Local Only | Paper server for friends |
| Home Assistant | 🔄 Planned | 🔄 Planned | Home automation hub |
| Jellyfin | 🔄 Planned | ❌ Local Only | Media server |
| Jellyseerr | 🔄 Planned | 🤔 TBD | Media request management |
| Caddy | 🔄 Planned | 🔄 Enhanced | Reverse proxy |

## 📋 Prerequisites

- Ubuntu Server 24.04 LTS with Btrfs filesystem
- SSH access with sudo privileges to your homelab server
- Local network (e.g., `192.168.1.0/24`) with a known IP for your homelab server.
- **Python Environment (for current mDNS setup)**:
    - Python 3 installed on the homelab server.
    - A Python virtual environment (e.g., `/home/<your_username>/venvs/mdns_publisher_venv`) with the `mdns-publisher` package installed. This is used by the host-based mDNS script.

## 🛠️ Setup

### Phase 1: Server Provisioning ✅
```bash
# Run from your local machine
scp scripts/provision-server.sh <your_username>@<your_server_ip>:~/
ssh <your_username>@<your_server_ip>
./provision-server.sh
```

### Phase 2: Service Deployment (Current Focus)
The immediate focus is on the mDNS host publisher. Other services will be added progressively.
```bash
# Deploy configuration via Terraform
cd terraform/
terraform init
terraform plan
terraform apply
```
To manage mDNS aliases, edit the `services` variable in `terraform/terraform.tfvars` and re-apply the configuration.

### Phase 3: External Access (Future)
```bash
# Enhanced security and external tunneling
# Configuration TBD based on Phase 2 learnings
```

## 📁 Repository Structure

```
.
├── README.md
├── scripts
│   └── provision-server.sh
└── terraform
    ├── main.tf                 # Root Terraform configuration, instantiates modules
    ├── providers.tf            # Terraform provider configurations
    ├── system
    │   ├── mdns
    │   │   ├── publisher.tf    # Terraform logic for host-based mDNS setup
    │   │   ├── scripts
    │   │   │   └── publish-mdns-aliases.py # Python mDNS publisher script
    │   │   └── templates
    │   │       ├── mdns-aliases.conf.tftpl    # Template for mDNS alias list
    │   │       └── mdns-publisher.service.tftpl # Template for the systemd service
    │   └── variables.tf        # Variable definitions for the system module
    ├── terraform.tfstate       # Terraform state file (tracks managed infrastructure)
    ├── terraform.tfvars        # Actual variable values for deployment (DO NOT COMMIT SENSITIVE DATA IF PUBLIC)
    └── variables.tf            # Root variable declarations (schema)
```

## 🔧 Management

### Snapshot Management
```bash
# Available after provisioning
homelab-snapshots              # List all snapshots
homelab-snapshot-pre "desc"    # Create pre-change snapshot
homelab-snapshot-post "desc"   # Create post-change snapshot
homelab-rollback <number>      # Rollback to snapshot
```

### Service Management
Terraform manages the deployment of services. As services are developed:
- New Terraform resource blocks will be added (likely in `terraform/main.tf` or dedicated `.tf` files for modularity).
- Service-specific variables will be defined in `variables.tf` and configured in `terraform.tfvars`.
- To enable/disable or modify services, update their respective Terraform configurations or variables and run:
```bash
terraform plan && terraform apply
```

## 🌐 Access

### Phase 2: Local Network Access
After Phase 2 deployment, services will be available on your home network. Replace `<service_name>`, `<server_hostname>`, and `<your_domain>` with your actual values.

**Web Services (via Caddy Reverse Proxy - when implemented):**
- `http://homeassistant.<your_domain>.local`
- `http://jellyfin.<your_domain>.local`
- `http://jellyseerr.<your_domain>.local`

**Game Services:**
- **Minecraft Java**: `minecraft.<your_domain>.local:25565`
- **Minecraft Bedrock**: `minecraft.<your_domain>.local:19132`

**Direct Access (troubleshooting, using server's mDNS hostname):**
- Home Assistant: `http://<server_hostname>.local:8123`
- Jellyfin: `http://<server_hostname>.local:8096`
- Jellyseerr: `http://<server_hostname>.local:5055`
- Caddy Admin: `http://<server_hostname>.local:2019` (when Caddy is implemented)

## 🚨 Backup & Recovery

- **Automatic**: Daily snapshots at 6 AM and 6 PM
- **Manual**: Use `homelab-snapshot-pre` before changes
- **Recovery**: Use `homelab-rollback <number>` to restore
- **Retention**: 7 daily snapshots, 10 manual snapshots max

## 📚 Documentation

- [Server Provisioning Details](docs/provisioning.md) *(Coming Soon)*
- [Terraform Configuration Guide](docs/terraform.md) *(Coming Soon)*
- [Troubleshooting Guide](docs/troubleshooting.md) *(Coming Soon)*

## 🤝 Contributing

This is a personal homelab project, but feel free to use it as inspiration for your own setup!

## 📄 License

MIT License - See LICENSE file for details
```
