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
    enabled = bool
    port    = number
    version = string
  }))
}
