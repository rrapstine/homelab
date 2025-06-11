# System layer - infrastructure and networking
module "system" {
  source = "./system"

  # Variables
  system_services             = var.services
  system_server_hostname      = var.server_hostname
  system_server_ip            = var.server_ip
  system_ssh_user             = var.ssh_user
  system_ssh_private_key_path = var.ssh_private_key_path
}
