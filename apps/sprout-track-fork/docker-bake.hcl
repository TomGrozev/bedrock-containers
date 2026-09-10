target "docker-metadata-action" {}

variable "APP" {
  default = "sprout-track-fork"
}

# Build source: the user's fork of sprout-track. Unlike the sibling `sprout-track`
# app (which re-layers the PUBLISHED sprouttrack/sprout-track image), this fork has
# no published image for `main` (it publishes to Docker Hub only on release). So we
# build the fork's OWN Dockerfile from a pinned commit of its `main` branch (the
# `fork-src` target below), then harden that result onto Wolfi via ./Dockerfile.
variable "SOURCE" {
  default = "https://github.com/TomGrozev/sprout-track"
}

# Pinned commit of the fork's `main`. Renovate bumps this to main's HEAD and
# auto-merges (git-refs datasource; customManager + auto-merge rule scoped to this
# file live in ../../renovate.json5), which triggers a rebuild. The build clones
# this exact commit, so images are reproducible.
variable "REF" {
  default = "a4a25aa7612b5859fdadf9bf8e61aeaae5f343d6"
}

# Short commit tag for the local image. buildx bake's expression parser cannot
# evaluate function calls inside string templates ("${APP}:${substr(REF, 0, 7)}"
# fails to parse), so the full tag string is built inside this zero-arg function.
function "fork_short_tag" {
  params = []
  result = "${APP}:${substr(REF, 0, 7)}"
}

group "default" {
  targets = ["image-local"]
}

# Application image built from the fork's SOURCE using the fork's OWN Dockerfile,
# pinned to REF. The args match the defaults the published sprouttrack/sprout-track
# image is built with, so the resulting /app + docker-startup.sh layout is exactly
# what ./Dockerfile (FROM forkimage) expects to harden.
target "fork-src" {
  context = "${SOURCE}.git#${REF}"
  args = {
    ENABLE_NOTIFICATIONS = "true"
    DATABASE_PROVIDER    = "sqlite"
  }
}

target "image" {
  inherits = ["docker-metadata-action"]
  contexts = {
    forkimage = "target:fork-src"
  }
  labels = {
    "org.opencontainers.image.source" = "${SOURCE}"
  }
}

target "image-local" {
  inherits = ["image"]
  output   = ["type=docker"]
  tags     = [fork_short_tag(), "${APP}:main"]
}

target "image-all" {
  inherits = ["image"]
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}
