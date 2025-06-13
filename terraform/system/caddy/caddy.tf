resource "docker_volume" "caddy_data" {
  name = var.caddy_volume_name
}

resource "docker_image" "caddy" {
  name         = "caddy:2.7.6-alpine" # Caddy version is hardcoded here
  keep_locally = true
}

resource "local_file" "caddyfile" {
  content = templatefile("${path.module}/templates/Caddyfile.tftpl", {
    caddy_services_to_proxy = var.caddy_services_to_proxy,
    local_domain            = var.local_domain,
    timestamp               = timestamp()
  })
  filename = var.caddy_config_path_host
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
    host_path      = local_file.caddyfile.filename # This is var.caddy_config_path_host
    container_path = "/etc/caddy/Caddyfile"
    read_only      = true
  }

  networks_advanced {
    name = var.caddy_network_name
  }

  depends_on = [local_file.caddyfile, docker_volume.caddy_data]
}
