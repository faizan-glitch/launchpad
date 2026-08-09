package.path = "./?.lua;./?/init.lua;./modules/?.lua;" .. package.path

local ui = require("ui")
local shell = require("shell")
local config_lib = require("config")
local validate = require("validate")
local backup = require("backup")

local modules = {
  require("modules.hostname"),
  require("modules.swap"),
  require("modules.users"),
  require("modules.keys"),
  require("modules.limits"),
  require("modules.ssh"),
  require("modules.kernel"),
  require("modules.firewall"),
  require("modules.caddy"),
  require("modules.certbot"),
  require("modules.nginx"),
  require("modules.fail2ban"),
  require("modules.updates"),
  require("modules.apparmor"),
  require("modules.cleanup"),
  require("modules.idle_timeout"),
  require("modules.fstab"),
}

local function assert_root()
  local uid = shell.capture("id -u")
  if uid ~= "0" then
    error("Please run this script as root.")
  end
end

local function split_ports(value)
  local ports = {}
  for item in tostring(value):gmatch("[^,%s]+") do
    ports[#ports + 1] = item
  end
  return ports
end

local function profile_menu()
  local choices = {}
  for _, profile in ipairs(config_lib.profiles) do
    choices[#choices + 1] = {
      label = profile.label .. " - " .. profile.description,
      profile = profile,
    }
  end

  return ui.choose("Server type?", choices, 1).profile
end

local function feature_menu(cfg)
  local items = ui.multiselect("Quick feature menu", {
    { label = "Dry-run mode", enabled = cfg.dry_run },
    { label = "Import SSH public key", enabled = cfg.ssh.import_public_key },
    { label = "Enable firewall", enabled = cfg.firewall.enabled },
    { label = "Enable IPv6 firewall rules", enabled = cfg.firewall.ipv6 },
    { label = "Install and configure Fail2Ban", enabled = cfg.fail2ban.enabled },
    { label = "Configure swap file", enabled = cfg.swap.enabled },
    { label = "Configure unattended upgrades", enabled = cfg.unattended_upgrades.enabled },
    { label = "Apply AppArmor hardening", enabled = cfg.apparmor.enabled },
    { label = "Configure idle timeout", enabled = cfg.idle_timeout.enabled },
    { label = "Harden fstab", enabled = cfg.fstab.enabled },
    { label = "Run package cleanup", enabled = cfg.cleanup.enabled },
  })

  cfg.dry_run = items[1].enabled
  cfg.ssh.import_public_key = items[2].enabled
  cfg.firewall.enabled = items[3].enabled
  cfg.firewall.ipv6 = items[4].enabled
  cfg.fail2ban.enabled = items[5].enabled
  cfg.swap.enabled = items[6].enabled
  cfg.unattended_upgrades.enabled = items[7].enabled
  cfg.apparmor.enabled = items[8].enabled
  cfg.idle_timeout.enabled = items[9].enabled
  cfg.fstab.enabled = items[10].enabled
  cfg.cleanup.enabled = items[11].enabled
end

local function has_ssh_key_source(value)
  if value == nil or value == "" then
    return false
  end

  return validate.ssh_public_key(value) or shell.exists(value)
end

local function ask_public_key(cfg)
  if not cfg.ssh.import_public_key then
    cfg.ssh.public_key = ""
    return
  end

  local input = ui.ask("SSH public key or path to .pub file", cfg.ssh.public_key)
  while input ~= nil and input ~= "" and not has_ssh_key_source(input) do
    print("Enter a full SSH public key or a readable path to a .pub file.")
    input = ui.ask("SSH public key or path to .pub file", cfg.ssh.public_key)
  end

  cfg.ssh.public_key = input or ""
end

local function ensure_ssh_access(cfg)
  if has_ssh_key_source(cfg.ssh.public_key) then
    return
  end

  if cfg.ssh.disable_password_auth or cfg.ssh.disable_root_login then
    print("An SSH public key is required when root login or password authentication is disabled, to avoid lockout.")
    cfg.ssh.import_public_key = true
    repeat
      ask_public_key(cfg)
    until has_ssh_key_source(cfg.ssh.public_key)
  end
end

local function ask_caddy_config(cfg)
  if cfg.stack ~= "caddy" then
    return
  end

  cfg.caddy.domain = ui.ask("Caddy domain", cfg.caddy.domain)
  while not validate.hostname(cfg.caddy.domain) do
    print("Please enter a valid domain or hostname.")
    cfg.caddy.domain = ui.ask("Caddy domain", cfg.caddy.domain)
  end

  local ports = ui.ask("Caddy upstream ports (comma-separated)", table.concat(cfg.caddy.upstream_ports or {}, ", "))
  while not validate.port_list(ports) or ports == "" do
    print("Please enter one or more valid port numbers, separated by commas.")
    ports = ui.ask("Caddy upstream ports (comma-separated)", table.concat(cfg.caddy.upstream_ports or {}, ", "))
  end

  cfg.caddy.upstream_ports = {}
  for _, port in ipairs(split_ports(ports)) do
    cfg.caddy.upstream_ports[#cfg.caddy.upstream_ports + 1] = port
  end

  cfg.caddy.rate_limit.enabled = ui.ask_yes_no("Enable Caddy rate limiting?", cfg.caddy.rate_limit.enabled)
  if cfg.caddy.rate_limit.enabled then
    local max_events = ui.ask("Rate limit requests per window", tostring(cfg.caddy.rate_limit.max_events))
    while not validate.integer_range(max_events, 1, 1000000) do
      print("Please enter a whole number greater than 0.")
      max_events = ui.ask("Rate limit requests per window", tostring(cfg.caddy.rate_limit.max_events))
    end
    cfg.caddy.rate_limit.max_events = tonumber(max_events)

    local window = ui.ask("Rate limit window (e.g. 30s, 1m, 5m)", cfg.caddy.rate_limit.window)
    while not validate.duration(window) do
      print("Please enter a duration like 30s, 1m, or 5m.")
      window = ui.ask("Rate limit window (e.g. 30s, 1m, 5m)", cfg.caddy.rate_limit.window)
    end
    cfg.caddy.rate_limit.window = window

    local ipv6_prefix = ui.ask("IPv6 prefix bits for rate limiting", tostring(cfg.caddy.rate_limit.ipv6_prefix))
    while not validate.integer_range(ipv6_prefix, 0, 128) do
      print("Please enter a whole number between 0 and 128.")
      ipv6_prefix = ui.ask("IPv6 prefix bits for rate limiting", tostring(cfg.caddy.rate_limit.ipv6_prefix))
    end
    cfg.caddy.rate_limit.ipv6_prefix = tonumber(ipv6_prefix)
  end
end

local function gather_config()
  local cfg = config_lib.default()
  local profile = profile_menu()
  cfg.profile = profile.id
  cfg.stack = profile.stack

  cfg.username = ui.ask("Administrative username", cfg.username)
  while not validate.username(cfg.username) do
    print("Please enter a valid Linux username.")
    cfg.username = ui.ask("Administrative username", cfg.username)
  end

  cfg.hostname = ui.ask("Hostname", cfg.hostname)
  while not validate.hostname(cfg.hostname) do
    print("Please enter a valid hostname.")
    cfg.hostname = ui.ask("Hostname", cfg.hostname)
  end

  cfg.swap.enabled = ui.ask_yes_no("Configure swap file?", true)
  if cfg.swap.enabled then
    cfg.swap.size = ui.ask("Swap file size (e.g. 1G, 2G, 4G)", cfg.swap.size)
    while not validate.swap_size(cfg.swap.size) do
      print("Please enter a swap size like 512M, 1G, or 2G.")
      cfg.swap.size = ui.ask("Swap file size (e.g. 1G, 2G, 4G)", cfg.swap.size)
    end
  end

  local ssh_port = ui.ask("SSH port", tostring(cfg.ssh.port))
  while not validate.port(ssh_port) do
    print("Please enter a valid port number between 1 and 65535.")
    ssh_port = ui.ask("SSH port", tostring(cfg.ssh.port))
  end
  cfg.ssh.port = tonumber(ssh_port)

  cfg.ssh.disable_root_login = ui.ask_yes_no("Disable root SSH login?", true)
  cfg.ssh.disable_password_auth = ui.ask_yes_no("Disable password authentication over SSH?", true)

  local nofile_limit = ui.ask("Open file descriptor limit (nofile)", tostring(cfg.limits.nofile))
  while not validate.integer_range(nofile_limit, 1024, 1048576) do
    print("Please enter a whole number between 1024 and 1048576.")
    nofile_limit = ui.ask("Open file descriptor limit (nofile)", tostring(cfg.limits.nofile))
  end
  cfg.limits.nofile = tonumber(nofile_limit)

  cfg.firewall.enabled = ui.ask_yes_no("Enable firewall?", true)
  cfg.firewall.ipv6 = ui.ask_yes_no("Enable IPv6 firewall rules?", true)
  cfg.fail2ban.enabled = ui.ask_yes_no("Install and configure Fail2Ban?", true)
  cfg.unattended_upgrades.enabled = ui.ask_yes_no("Configure unattended upgrades?", true)
  cfg.apparmor.enabled = ui.ask_yes_no("Apply AppArmor hardening?", true)
  cfg.kernel.enabled = ui.ask_yes_no("Apply kernel hardening?", true)
  cfg.idle_timeout.enabled = ui.ask_yes_no("Configure idle timeout?", true)
  cfg.fstab.enabled = ui.ask_yes_no("Harden fstab?", true)
  cfg.cleanup.enabled = ui.ask_yes_no("Run package cleanup at the end?", true)

  feature_menu(cfg)
  ask_caddy_config(cfg)
  if cfg.stack == "nginx" then
    cfg.nginx.domain = ui.ask("Nginx domain", cfg.nginx.domain)
    while not validate.hostname(cfg.nginx.domain) do
      print("Please enter a valid domain or hostname.")
      cfg.nginx.domain = ui.ask("Nginx domain", cfg.nginx.domain)
    end
  end
  ask_public_key(cfg)
  ensure_ssh_access(cfg)

  if cfg.firewall.enabled then
    if profile.id == "custom" then
      local ports = ui.ask("Extra firewall TCP ports (comma-separated)", "")
      cfg.firewall.allowed_tcp_ports = { tostring(cfg.ssh.port) }
      for _, port in ipairs(split_ports(ports)) do
        if validate.port(port) then
          cfg.firewall.allowed_tcp_ports[#cfg.firewall.allowed_tcp_ports + 1] = port
        end
      end
    else
      cfg.firewall.allowed_tcp_ports = {}
      for _, port in ipairs(profile.allowed_tcp_ports) do
        cfg.firewall.allowed_tcp_ports[#cfg.firewall.allowed_tcp_ports + 1] = port
      end
      cfg.firewall.allowed_tcp_ports[1] = tostring(cfg.ssh.port)
    end
  else
    cfg.firewall.allowed_tcp_ports = {}
  end

  return cfg
end

local function print_summary(cfg)
  ui.section("Configuration summary")
  ui.print_kv("Profile", cfg.profile or "custom")
  ui.print_kv("Hostname", cfg.hostname)
  ui.print_kv("Swap", cfg.swap.enabled and "enabled (" .. cfg.swap.size .. ")" or "disabled")
  ui.print_kv("Username", cfg.username)
  ui.print_kv("SSH port", cfg.ssh.port)
  ui.print_kv("Root SSH login", cfg.ssh.disable_root_login and "disabled" or "enabled")
  ui.print_kv("Open file descriptor limit", tostring(cfg.limits.nofile))
  ui.print_kv("Password auth", cfg.ssh.disable_password_auth and "disabled" or "enabled")
  ui.print_kv("SSH key import", cfg.ssh.import_public_key and "enabled" or "disabled")
  ui.print_kv("Dry-run", cfg.dry_run and "enabled" or "disabled")
  ui.print_kv("Firewall", cfg.firewall.enabled and "enabled" or "disabled")
  ui.print_kv("Fail2Ban", cfg.fail2ban.enabled and "enabled" or "disabled")
  ui.print_kv("Unattended upgrades", cfg.unattended_upgrades.enabled and "enabled" or "disabled")
  ui.print_kv("AppArmor", cfg.apparmor.enabled and "enabled" or "disabled")
  ui.print_kv("Kernel hardening", cfg.kernel.enabled and "enabled" or "disabled")
  ui.print_kv("Idle timeout", cfg.idle_timeout.enabled and "enabled" or "disabled")
  ui.print_kv("Fstab hardening", cfg.fstab.enabled and "enabled" or "disabled")
  ui.print_kv("Cleanup", cfg.cleanup.enabled and "enabled" or "disabled")
  ui.print_kv("Allowed TCP ports", table.concat(cfg.firewall.allowed_tcp_ports, ", "))
  if cfg.stack then
    ui.print_kv("Suggested stack", cfg.stack)
  end
  if cfg.stack == "caddy" then
    ui.print_kv("Caddy domain", cfg.caddy.domain)
    ui.print_kv("Caddy upstream ports", table.concat(cfg.caddy.upstream_ports, ", "))
    ui.print_kv("Caddy rate limit", cfg.caddy.rate_limit.enabled and "enabled" or "disabled")
    if cfg.caddy.rate_limit.enabled then
      ui.print_kv("Rate limit", tostring(cfg.caddy.rate_limit.max_events) .. " per " .. cfg.caddy.rate_limit.window)
      ui.print_kv("IPv6 prefix", tostring(cfg.caddy.rate_limit.ipv6_prefix))
    end
  elseif cfg.stack == "nginx" then
    ui.print_kv("Nginx domain", cfg.nginx.domain)
  end
end

local function enabled_modules(cfg)
  local selected = {}

  for _, module in ipairs(modules) do
    if module.name == "Set hostname" then
      selected[#selected + 1] = module
    elseif module.name == "Configure Swap" and cfg.swap.enabled then
      selected[#selected + 1] = module
    elseif module.name == "Create administrative user" then
      selected[#selected + 1] = module
    elseif module.name == "Import SSH public key" and cfg.ssh.import_public_key then
      selected[#selected + 1] = module
    elseif module.name == "File descriptor limits" then
      selected[#selected + 1] = module
    elseif module.name == "Configure SSH" then
      selected[#selected + 1] = module
    elseif module.name == "Kernel hardening" and cfg.kernel.enabled then
      selected[#selected + 1] = module
    elseif module.name == "Firewall" and cfg.firewall.enabled then
      selected[#selected + 1] = module
    elseif module.name == "Caddy" and cfg.stack == "caddy" then
      selected[#selected + 1] = module
    elseif module.name == "Certbot SSL" and cfg.stack == "nginx" then
      selected[#selected + 1] = module
    elseif module.name == "Nginx" and cfg.stack == "nginx" then
      selected[#selected + 1] = module
    elseif module.name == "Fail2Ban" and cfg.fail2ban.enabled then
      selected[#selected + 1] = module
    elseif module.name == "Automatic updates" and cfg.unattended_upgrades.enabled then
      selected[#selected + 1] = module
    elseif module.name == "AppArmor" and cfg.apparmor.enabled then
      selected[#selected + 1] = module
    elseif module.name == "Configure Idle Timeout" and cfg.idle_timeout.enabled then
      selected[#selected + 1] = module
    elseif module.name == "Fstab hardening" and cfg.fstab.enabled then
      selected[#selected + 1] = module
    elseif module.name == "Cleanup" and cfg.cleanup.enabled then
      selected[#selected + 1] = module
    end
  end

  return selected
end

local function run_modules(cfg, ctx)
  local executed = {}

  for _, module in ipairs(enabled_modules(cfg)) do
    executed[#executed + 1] = module
    ui.step_info("Running: " .. module.name)
    local ok, err = pcall(module.run, cfg, ctx)
    if not ok then
      ui.step_fail(module.name .. " failed")
      print(err)
      return false, executed
    end
  end

  return true, executed
end

local function rollback_modules(cfg, ctx, executed)
  for i = #executed, 1, -1 do
    local module = executed[i]
    if module.rollback then
      ui.step_info("Rolling back: " .. module.name)
      pcall(module.rollback, cfg, ctx)
    end
  end
  if ctx.backup then
    ctx.backup:restore()
  end
end

local function main()
  ui.banner()
  assert_root()

  local cfg = gather_config()
  print_summary(cfg)

  if not ui.ask_yes_no("Proceed with changes?", false) then
    print("Aborted.")
    return
  end

  shell.set_dry_run(cfg.dry_run)

  local ctx = {
    ui = ui,
    shell = shell,
    state = {},
    backup = backup.new("/var/backups/launchpad"),
  }

  local ok, executed = run_modules(cfg, ctx)
  if not ok then
    if ui.ask_yes_no("An error occurred. Roll back changes?", true) then
      rollback_modules(cfg, ctx, executed)
      print("Rollback complete.")
    end
    os.exit(1)
  end

  print("")
  print("Completed successfully.")
  if shell.is_dry_run() then
    print("Dry-run mode: no changes were written.")
  else
    print("Backup location: " .. ctx.backup.backup_dir)
  end
end

main()
