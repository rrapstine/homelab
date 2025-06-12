# Global server configuration
variable "server_hostname" {
  description = "The hostname of the homelab"
  type        = string
}

variable "server_ip" {
  description = "The IP address of the homelab"
  type        = string
}

# SSH configuration
variable "ssh_user" {
  description = "The username for the ssh client"
  type        = string
}

variable "ssh_private_key_path" {
  description = "The path to SSH private key"
  type        = string
}

# Generic service configuration
variable "services" {
  description = "Map of service configurations for dynamic deployment"
  type = map(object({
    enabled           = bool
    internal_app_port = optional(number)
    direct_exposed_ports = optional(list(object({
      internal = number
      external = number
      protocol = optional(string, "tcp")
    })))
  }))
}

# Networking configuration
variable "local_domain" {
  description = "The fully qualified domain name of the server"
  type        = string
}

variable "container_network_name" {
  description = "The name of the shared docker network"
  type        = string
}

# Caddy configuration
variable "caddy_config_host_path" {
  description = "The full path on the host system where Terraform will generate the Caddyfile"
  type        = string
}

variable "caddy_http_port" {
  description = "The port Caddy will use for HTTP traffic"
  type        = number
  default     = 80
}

variable "caddy_https_port" {
  description = "The port Caddy will use for HTTPS traffic"
  type        = number
  default     = 443
}
