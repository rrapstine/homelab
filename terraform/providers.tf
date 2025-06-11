terraform {
  required_providers {
  }
}

provider "podman" {
  host = "ssh://richard@192.168.69.1/run/user/1000/podman/podman.sock"
}
