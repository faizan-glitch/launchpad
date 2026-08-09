local shell = require("shell")

local hostname = {
  name = "Set hostname",
}

local function update_hosts_file(contents, new_hostname)
  local lines = {}
  local replaced = false

  for line in (contents .. "\n"):gmatch("(.-)\n") do
    if line:match("^127%.0%.1%.1%s+") then
      lines[#lines + 1] = "127.0.1.1\t" .. new_hostname
      replaced = true
    else
      lines[#lines + 1] = line
    end
  end

  if not replaced then
    lines[#lines + 1] = "127.0.1.1\t" .. new_hostname
  end

  return table.concat(lines, "\n")
end

function hostname.run(config, ctx)
  local hosts_path = "/etc/hosts"
  local hostname_path = "/etc/hostname"

  if ctx.backup then
    ctx.backup:save(hosts_path)
    ctx.backup:save(hostname_path)
  end

  ctx.state.previous_hostname = shell.capture("hostnamectl --static") or ""

  assert(shell.write(hostname_path, config.hostname .. "\n"))

  local existing = shell.read(hosts_path) or ""
  assert(shell.write(hosts_path, update_hosts_file(existing, config.hostname)))

  shell.run("hostnamectl set-hostname " .. shell.quote(config.hostname))
  ctx.ui.step_ok("Hostname set to " .. config.hostname)
end

function hostname.rollback(config, ctx)
  local previous_hostname = ctx.state and ctx.state.previous_hostname
  if previous_hostname and previous_hostname ~= "" then
    shell.run("hostnamectl set-hostname " .. shell.quote(previous_hostname))
  else
    shell.run("hostnamectl set-hostname localhost")
  end
end

return hostname
