target "docker-metadata-action" {}

variable "APP" {
  default = "sprout-track"
}

# renovate: datasource=docker depName=sprouttrack/sprout-track
variable "VERSION" {
  default = "1.6.3"
}

variable "SOURCE" {
  default = "https://github.com/Oak-and-Sprout/sprout-track"
}

group "default" {
  targets = ["image-local"]
}

target "image" {
  inherits = ["docker-metadata-action"]
  args = {
    VERSION = "${VERSION}"
  }
  labels = {
    "org.opencontainers.image.source" = "${SOURCE}"
  }
}

target "image-local" {
  inherits = ["image"]
  output   = ["type=docker"]
  tags     = ["${APP}:${VERSION}"]
}

target "image-all" {
  inherits = ["image"]
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}
