variable "system_server_ip" {
  description = "The IP address of the target server for system configuration."
  type        = string
  # No default, as it must be provided by the calling module
}

variable "system_server_hostname" {
  description = "The hostname of the target server."
  type        = string
}

variable "system_ssh_user" {
  description = "The username for SSH connections to the server."
  type        = string
}

variable "system_ssh_private_key_path" {
  description = "The path to the SSH private key for server connections."
  type        = string
}

variable "system_podman_user_uid" {
  description = "The UID of the podman user on the server."
  type        = string
}

variable "system_homelab_dir" {
  description = "The path to the homelab directory on the server."
  type        = string
}

variable "system_services" {
  description = "Map of services for mDNS alias generation and other system tasks."
  type = map(object({
    enabled = bool
    port    = number
  }))
}
