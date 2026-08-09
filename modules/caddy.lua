local shell = require("shell")
local validate = require("validate")

local caddy = {
  name = "Caddy",
}

local function join_ports(ports)
  return table.concat(ports, ", ")
end

local function upstream_targets(ports)
  local targets = {}

  for _, port in ipairs(ports) do
    targets[#targets + 1] = "127.0.0.1:" .. tostring(port)
  end

  return targets
end

local function render_header_block()
  return {
    "    header {",
    "      -Server",
    "      Strict-Transport-Security \"max-age=31536000; includeSubDomains; preload\"",
    "      X-Content-Type-Options nosniff",
    "      X-Frame-Options DENY",
    "      Referrer-Policy no-referrer",
    "      Permissions-Policy \"camera=(), microphone=(), geolocation=()\"",
    "    }",
  }
end

local function render_rate_limit_block(rate_limit)
  if not rate_limit or not rate_limit.enabled then
    return {}
  end

  return {
    "    rate_limit {",
    "      zone client_ip {",
    "        key {remote_host}",
    "        events " .. tostring(rate_limit.max_events),
    "        window " .. tostring(rate_limit.window),
    "        ipv4_prefix " .. tostring(rate_limit.ipv4_prefix or 32),
    "        ipv6_prefix " .. tostring(rate_limit.ipv6_prefix or 64),
    "      }",
    "    }",
  }
end

local CADDY_VERSION = "v2.11.4"
local XCADDY_VERSION = "v0.4.6"
local RATLIMIT_VERSION = "v0.1.0"

local function render_caddyfile(config)
  local domain = config.caddy.domain
  local upstreams = upstream_targets(config.caddy.upstream_ports or {})
  local rate_limit = config.caddy.rate_limit
  local lines = {
    "# Managed by launchpad",
    domain .. " {",
    "  route {",
  }

  for _, line in ipairs(render_header_block()) do
    lines[#lines + 1] = line
  end

  for _, line in ipairs(render_rate_limit_block(rate_limit)) do
    lines[#lines + 1] = line
  end

  lines[#lines + 1] = "    reverse_proxy " .. table.concat(upstreams, " ")
  lines[#lines + 1] = "  }"
  lines[#lines + 1] = "  encode zstd gzip"
  lines[#lines + 1] = "}"
  lines[#lines + 1] = ""

  return table.concat(lines, "\n")
end

function caddy.run(config, ctx)
  local path = "/etc/caddy/Caddyfile"
  local domain = config.caddy.domain
  local ports = config.caddy.upstream_ports or {}
  local rate_limit = config.caddy.rate_limit or { enabled = false }
  local caddy_binary = "/usr/bin/caddy"

  if not validate.non_empty(domain) then
    error("Caddy domain is required")
  end

  if #ports == 0 then
    error("At least one upstream port is required for Caddy")
  end

  if ctx.backup then
    ctx.backup:save(path)
  end

  assert(shell.run("apt-get update"))
  if rate_limit.enabled then
    assert(shell.run("apt-get install -y caddy golang-go git"))
    assert(shell.run("systemctl stop caddy"))
    assert(shell.run("! systemctl is-active --quiet caddy"))
    if ctx.backup then
      ctx.backup:save(caddy_binary)
    end

    local build_tmp_dir = "/var/tmp/caddy-hardener-build"
    assert(shell.run("mkdir -p " .. shell.quote(build_tmp_dir)))
    assert(shell.run(
      "TMPDIR=" .. shell.quote(build_tmp_dir) ..
      " GOTMPDIR=" .. shell.quote(build_tmp_dir) ..
      " go install github.com/caddyserver/xcaddy/cmd/xcaddy@" .. XCADDY_VERSION
    ))

    local gopath = shell.capture("go env GOPATH") or "/root/go"
    if gopath == "" then
      gopath = "/root/go"
    end

    local xcaddy = gopath .. "/bin/xcaddy"
    local built_binary = build_tmp_dir .. "/caddy-hardener"
    assert(shell.run(
      "TMPDIR=" .. shell.quote(build_tmp_dir) ..
      " GOTMPDIR=" .. shell.quote(build_tmp_dir) ..
      " " .. xcaddy .. " build " .. CADDY_VERSION ..
      " --with github.com/mholt/caddy-ratelimit@" .. RATLIMIT_VERSION ..
      " --output " .. shell.quote(built_binary)
    ))
    assert(shell.run("install -m 0755 " .. shell.quote(built_binary) .. " " .. shell.quote(caddy_binary)))
    assert(shell.run("rm -rf " .. shell.quote(build_tmp_dir)))
  else
    assert(shell.run("apt-get install -y caddy"))
  end

  assert(shell.run("mkdir -p /etc/caddy /var/log/caddy"))
  assert(shell.write(path, render_caddyfile(config)))
  assert(shell.run("caddy fmt --overwrite " .. shell.quote(path)))
  assert(shell.run("caddy validate --config " .. shell.quote(path) .. " --adapter caddyfile"))
  assert(shell.run("systemctl enable caddy"))
  assert(shell.run("systemctl restart caddy"))

  if rate_limit.enabled then
    ctx.ui.step_ok("Caddy configured for " .. domain .. " -> " .. join_ports(ports) .. " with rate limiting")
  else
    ctx.ui.step_ok("Caddy configured for " .. domain .. " -> " .. join_ports(ports))
  end
end

function caddy.rollback(config, ctx)
  local path = "/etc/caddy/Caddyfile"
  shell.run("rm -f " .. shell.quote(path))
  shell.run("systemctl disable --now caddy")
end

return caddy
