variable "server_ip" {
  description = "The IP address of the server where Caddy will run."
  type        = string
}

variable "ssh_user" {
  description = "The SSH username for connecting to the server."
  type        = string
}

variable "ssh_private_key_path" {
  description = "The path to the SSH private key for connecting to the server."
  type        = string
}

variable "caddy_container_name" {
  description = "Name for the Caddy container."
  type        = string
  default     = "caddy"
}

variable "caddy_host_http_port" {
  description = "The HTTP port Caddy will listen on on the host."
  type        = number
  default     = 80
}

variable "caddy_host_https_port" {
  description = "The HTTPS port Caddy will listen on on the host."
  type        = number
  default     = 443
}

variable "caddy_network_name" {
  description = "The name of the Docker network Caddy and services will connect to."
  type        = string
}

variable "caddy_volume_name" {
  description = "Name for the Caddy data volume."
  type        = string
  default     = "caddy_data"
}

variable "caddy_config_path_host" {
  description = "Full path on the host where the generated Caddyfile will be stored."
  type        = string
}

variable "caddy_services_to_proxy" {
  description = "A map of services (already filtered and structured) to be proxied by Caddy."
  type = map(object({
    container_name = string # Name of the target container on the shared Docker network
    internal_port  = number # Internal port of the target container
  }))
  default = {} # Default to an empty map if no services are passed
}

variable "local_domain" {
  description = "The local domain suffix (e.g., 'legends.local')."
  type        = string
}
