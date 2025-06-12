variable "system_server_hostname" {
  description = "The hostname of the server where services are running (e.g., 'legends'). This will be used for mDNS announcements."
  type        = string
}

variable "system_server_ip" {
  description = "The IP address of the server where services are running. This will be used for mDNS announcements."
  type        = string
}

variable "system_ssh_user" {
  description = "The SSH username for connecting to the server to potentially manage mDNS services or scripts."
  type        = string
}

variable "system_ssh_private_key_path" {
  description = "The path to the SSH private key for connecting to the server."
  type        = string
}

variable "system_services" {
  description = "A map of service configurations. The mDNS publisher might use this to determine which services to announce."
  type = map(object({
    enabled = bool
  }))
}
