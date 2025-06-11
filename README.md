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
- **Containers**: All services managed by Terraform
- **Networking**: mDNS (.local domains) for service discovery
- **Reverse Proxy**: Caddy for clean URLs without port numbers
- **Goal**: Everything working perfectly on home network first

### Phase 3: Secure External Access (Future)
- **Home Assistant**: External access via secure tunnel/VPN
- **Jellyseerr**: (TBD) Possible external access for media requests
- **Security**: SSL certificates, enhanced authentication
- **Isolation**: Separate network segments for internet-facing services

## 🚀 Services

| Service | Phase 2 Status | Phase 3 Status | Description |
|---------|----------------|----------------|-------------|
| Minecraft | 🔄 Planned | ❌ Local Only | Paper server for friends |
| Home Assistant | 🔄 Planned | 🔄 Planned | Home automation hub |
| Jellyfin | 🔄 Planned | ❌ Local Only | Media server |
| Jellyseerr | 🔄 Planned | 🤔 TBD | Media request management |
| Caddy | 🔄 Planned | 🔄 Enhanced | Reverse proxy |

## 📋 Prerequisites

- Ubuntu Server 24.04 LTS with Btrfs filesystem
- SSH access with sudo privileges
- Local network: 192.168.68.0/22 (homelab server at 192.168.69.1)

## 🛠️ Setup

### Phase 1: Server Provisioning ✅
```bash
# Run from your local machine
scp scripts/provision-server.sh richard@192.168.69.1:~/
ssh richard@192.168.69.1
./provision-server.sh
```

### Phase 2: Service Deployment (Current Focus)
```bash
# Deploy all services via Terraform
cd terraform/
terraform init
terraform plan
terraform apply
```

### Phase 3: External Access (Future)
```bash
# Enhanced security and external tunneling
# Configuration TBD based on Phase 2 learnings
```

## 📁 Repository Structure

```
homelab/
├── scripts/
│   └── provision-server.sh     # Server setup script
├── terraform/                  # Infrastructure as Code
│   ├── providers.tf           # Terraform and provider setup
│   ├── variables.tf           # Variable definitions (schema only)
│   ├── terraform.tfvars       # Actual variable values for deployment
│   ├── main.tf               # Global resources and orchestration
│   ├── outputs.tf            # Deployment results
│   ├── system/               # Infrastructure layer
│   │   ├── network.tf        # mDNS aliases, container networks
│   │   └── caddy.tf          # Reverse proxy configuration
│   └── services/             # Application layer
│       ├── jellyfin.tf       # Media server
│       ├── homeassistant.tf  # Home automation hub
│       ├── jellyseerr.tf     # Media request management
│       └── minecraft.tf      # Game server
├── docs/                      # Additional documentation
├── .gitignore                 # Git ignore rules
└── README.md                  # This file
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
```bash
# Add a new service: create new .tf file in services/
# Remove a service: set enabled = false in variables.tf
# Modify system infrastructure: edit files in system/
terraform plan && terraform apply
```

## 🌐 Access

### Phase 2: Local Network Access
After Phase 2 deployment, services will be available on your home network:

**Web Services (via Caddy Reverse Proxy):**
- `http://homeassistant.legends.local`
- `http://jellyfin.legends.local`
- `http://jellyseerr.legends.local`

**Game Services:**
- **Minecraft Java**: `minecraft.legends.local:25565`
- **Minecraft Bedrock**: `minecraft.legends.local:19132`

**Direct Access (troubleshooting):**
- Home Assistant: `http://legends.local:8123`
- Jellyfin: `http://legends.local:8096`
- Jellyseerr: `http://legends.local:5055`
- Caddy Admin: `http://legends.local:2019`

### Phase 3: External Access (Future)
- Home Assistant: Secure external URL (method TBD)
- Jellyseerr: Possible external access (decision pending)

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
