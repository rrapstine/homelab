###############################################
# mDNS Aliasing Configuration
###############################################

# Generate mDNS aliases configuration file
resource "local_file" "mdns_aliases_config" {
  content = templatefile("${path.module}/../templates/mdns-aliases.conf.tftpl", {
    services        = var.services
    server_hostname = var.server_hostname
  })
  filename = "${path.module}/../generated/mdns-aliases"
}

# Copy the Python script to the server
resource "null_resource" "deploy_mdns_script" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.server_ip
  }

  provisioner "file" {
    source      = "${path.module}/../../scripts/publish-mdns-aliases.py"
    destination = "/tmp/publish-mdns-aliases.py"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/richard/scripts",
      "mv /tmp/publish-mdns-aliases.py /home/richard/scripts/publish-mdns-aliases.py",
      "chmod +x /home/richard/scripts/publish-mdns-aliases.py"
    ]
  }
}

# Copy the mDNS aliases configuration to the server
resource "null_resource" "deploy_mdns_aliases_config" {
  triggers = {
    config_hash = local_file.mdns_aliases_config.content_md5
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.server_ip
  }

  provisioner "file" {
    source      = local_file.mdns_aliases_config.filename
    destination = "/home/richard/.mdns-aliases"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 644 /home/richard/.mdns-aliases"
    ]
  }
}

# Generate systemd service file from template
resource "local_file" "mdns_service" {
  content = templatefile("${path.module}/../templates/mdns-publisher.service.tftpl", {
    user = var.ssh_user
  })
  filename = "${path.module}/../generated/mdns-publisher.service"
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
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.server_ip
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
