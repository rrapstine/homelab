resource "docker_network" "homelab_services_network" {
  name = var.homelab_network_name
}

locals {
  caddy_target_services = {
    for key, service_config in var.services : key => {
      container_name = "${key}_container"
      internal_port  = service_config.internal_app_port
    } if service_config.enabled && key != "caddy" && service_config.internal_app_port != null
  }
}

module "mdns_publisher" {
  source = "./system/mdns"

  system_server_hostname      = var.server_hostname
  system_server_ip            = var.server_ip
  system_ssh_user             = var.ssh_user
  system_ssh_private_key_path = var.ssh_private_key_path
  system_services             = var.services
}

module "caddy" {
  # Conditionally create Caddy if 'caddy' is enabled in the services map
  count = lookup(var.services, "caddy", { enabled = false }).enabled ? 1 : 0

  source = "./system/caddy"

  caddy_host_http_port  = var.caddy_host_http_port
  caddy_host_https_port = var.caddy_host_https_port

  caddy_network_name      = docker_network.homelab_services_network.name
  caddy_config_host_path  = var.caddy_config_host_path
  caddy_services_to_proxy = local.caddy_target_services
  local_domain            = var.local_domain
}

# --- Service Modules (Future - Placeholder Examples) ---
# module "homeassistant" {
#   count = lookup(var.services, "homeassistant", {enabled = false}).enabled ? 1 : 0
#   source = "./services/homeassistant" # Example path
#
#   container_name  = local.caddy_target_services["homeassistant"].container_name
#   internal_port   = var.services.homeassistant.internal_app_port # Use the correct field
#   network_name    = docker_network.homelab_services_network.name
#   # ... other variables ...
# }
#
# module "my_game_server" {
#   count = lookup(var.services, "my_game_server", {enabled = false}).enabled ? 1 : 0
#   source = "./services/my_game_server" # Example path
#
#   # This module would receive and use var.services.my_game_server.direct_exposed_ports
#   # to configure its docker_container ports {} blocks.
#   exposed_ports = var.services.my_game_server.direct_exposed_ports
#   network_name  = docker_network.homelab_services_network.name
#   # ... other variables ...
# }
