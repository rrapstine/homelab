# System layer - infrastructure and networking
module "system" {
  source = "./system"

  # Variables
  services        = var.services
  server_hostname = var.server_hostname
  server_ip      = var.server_ip
  ssh_user       = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
}
