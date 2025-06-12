# This file manages the host-based mDNS publisher components
# by deploying them to the target server via SSH.

locals {
  local_generated_dir = "${path.module}/mdns/.generated/"
}

# Ensure that the .generated directory exists locally
resource "null_resource" "ensure_local_generated_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.local_generated_dir}"
  }
}

# Generate mDNS aliases configuration file
resource "local_file" "mdns_aliases_config" {
  content = templatefile("${path.module}/mdns/templates/mdns-aliases.conf.tftpl", {
    services        = var.system_services
    server_hostname = var.system_server_hostname
  })
  filename = "${path.module}/mdns/.generated/mdns-aliases"
}

# Copy the Python script to the server
resource "null_resource" "deploy_mdns_script" {
  triggers = {
    script_content_hash = filemd5("${path.module}/scripts/publish-mdns-aliases.py")
  }

  connection {
    type        = "ssh"
    user        = var.system_ssh_user
    private_key = file(var.system_ssh_private_key_path)
    host        = var.system_server_ip
  }

  provisioner "file" {
    source      = "${path.module}/mdns/scripts/publish-mdns-aliases.py"
    destination = "/tmp/publish-mdns-aliases.py"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/${var.system_ssh_user}/scripts",
      "mv /tmp/publish-mdns-aliases.py /home/${var.system_ssh_user}/scripts/publish-mdns-aliases.py",
      "chmod +x /home/${var.system_ssh_user}/scripts/publish-mdns-aliases.py"
    ]
  }
}

# Copy the mDNS aliases configuration to the server
resource "null_resource" "deploy_mdns_aliases_config" {
  triggers = {
    mdns_aliases_config_hash = local_file.mdns_aliases_config.content_md5
  }

  connection {
    type        = "ssh"
    user        = var.system_ssh_user
    private_key = file(var.system_ssh_private_key_path)
    host        = var.system_server_ip
  }

  provisioner "file" {
    source      = local_file.mdns_aliases_config.filename
    destination = "/home/${var.system_ssh_user}/.mdns-aliases"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 644 /home/${var.system_ssh_user}/.mdns-aliases"
    ]
  }
}

# Generate systemd service file from template
resource "local_file" "mdns_service" {
  content = templatefile("${path.module}/mdns/templates/mdns-publisher.service.tftpl", {
    user = var.system_ssh_user
  })
  filename = "${path.module}/mdns/.generated/mdns-publisher.service"
}

# Deploy systemd service for mDNS publisher
resource "null_resource" "deploy_mdns_service" {
  depends_on = [
    null_resource.deploy_mdns_script,
    null_resource.deploy_mdns_aliases_config
  ]

  triggers = {
    service_hash = local_file.mdns_service.content_md5
  }

  connection {
    type        = "ssh"
    user        = var.system_ssh_user
    private_key = file(var.system_ssh_private_key_path)
    host        = var.system_server_ip
  }

  provisioner "file" {
    source      = local_file.mdns_service.filename
    destination = "/tmp/mdns-publisher.service"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/mdns-publisher.service /etc/systemd/system/mdns-publisher.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable mdns-publisher.service",
      "sudo systemctl restart mdns-publisher.service"
    ]
  }
}
