resource "docker_volume" "caddy_data" {
  name = var.caddy_volume_name
}

resource "docker_image" "caddy" {
  name         = "caddy:2.7.6-alpine" # Caddy version is hardcoded here
  keep_locally = true
}

resource "null_resource" "ensure_caddy_config_on_server" {
  triggers = {
    caddyfile_content = templatefile("${path.module}/templates/Caddyfile.tftpl", {
      caddy_services_to_proxy = var.caddy_services_to_proxy,
      local_domain            = var.local_domain,
      timestamp               = timestamp()
    })
    config_destination_path = var.caddy_config_path_host
    server_ip               = var.server_ip
  }

  connection {
    type        = "ssh"
    host        = var.server_ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p '${dirname(var.caddy_config_path_host)}'",
    ]
  }

  provisioner "file" {
    content     = self.triggers.caddyfile_content
    destination = var.caddy_config_path_host
  }
}

resource "docker_container" "caddy" {
  image   = docker_image.caddy.image_id
  name    = var.caddy_container_name
  restart = "unless-stopped"

  ports {
    internal = 80
    external = var.caddy_host_http_port
  }
  ports {
    internal = 443
    external = var.caddy_host_https_port
  }

  volumes {
    volume_name    = docker_volume.caddy_data.name
    container_path = "/data"
  }
  volumes {
    host_path      = var.caddy_config_path_host
    container_path = "/etc/caddy/Caddyfile"
    read_only      = true
  }

  networks_advanced {
    name = var.caddy_network_name
  }

  env = [
    "CADDY_CONFIG_HASH=${sha256(null_resource.ensure_caddy_config_on_server.triggers.caddyfile_content)}"
  ]

  depends_on = [
    null_resource.ensure_caddy_config_on_server,
    docker_volume.caddy_data,
    docker_image.caddy
  ]
}
