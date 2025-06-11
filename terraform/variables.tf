# Global server configuration
variable "server_hostname" {
  description = "The hostname of the homelab"
  type        = string
  default     = "legends"
}

variable "server_ip" {
  description = "The IP address of the homelab"
  type        = string
  default     = "192.168.69.1"
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
