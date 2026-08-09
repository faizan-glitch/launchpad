local config = {}

config.profiles = {
  {
    id = "personal",
    label = "Personal VPS",
    description = "Minimal hardening for a personal server.",
    allowed_tcp_ports = {"22"},
  },
  {
    id = "web",
    label = "Web Server",
    description = "SSH plus common web ports.",
    allowed_tcp_ports = {"22", "80", "443"},
  },
  {
    id = "caddy",
    label = "Caddy Reverse Proxy",
    description = "Ready for a Caddy-based edge proxy setup.",
    allowed_tcp_ports = {"22", "80", "443"},
    stack = "caddy",
  },
  {
    id = "nginx",
    label = "Nginx Web Server",
    description = "Ready for an Nginx-based web server setup.",
    allowed_tcp_ports = {"22", "80", "443"},
    stack = "nginx",
  },
  {
    id = "mail",
    label = "Mail Server",
    description = "SSH plus common mail ports.",
    allowed_tcp_ports = {"22", "25", "465", "587", "993", "995"},
  },
  {
    id = "docker",
    label = "Docker Host",
    description = "SSH plus common exposed service ports.",
    allowed_tcp_ports = {"22", "80", "443"},
  },
  {
    id = "custom",
    label = "Custom",
    description = "Choose your own firewall ports.",
    allowed_tcp_ports = {},
  },
}

function config.default()
  return {
    hostname = "",
    username = "admin",
    dry_run = false,
    ssh = {
      port = 2222,
      disable_root_login = true,
      disable_password_auth = true,
      import_public_key = false,
      public_key = "",
    },
    firewall = {
      enabled = true,
      ipv6 = true,
      allowed_tcp_ports = {"22"},
    },
    caddy = {
      domain = "",
      upstream_ports = {"3000"},
      rate_limit = {
        enabled = true,
        max_events = 120,
        window = "1m",
        ipv4_prefix = 32,
        ipv6_prefix = 64,
      },
    },
    nginx = {
      domain = "",
    },
    limits = {
      nofile = 1048576,
    },
    fail2ban = {
      enabled = true,
      bantime = "24h",
      findtime = "10m",
      maxretry = 3,
    },
    swap = {
      enabled = true,
      size = "2G",
    },
    unattended_upgrades = {
      enabled = true,
    },
    apparmor = {
      enabled = true,
    },
    kernel = {
      enabled = true,
    },
    cleanup = {
      enabled = true,
    },
    idle_timeout = {
      enabled = true,
      minutes = 15,
    },
    fstab = {
      enabled = true,
    },
  }
end

return config
