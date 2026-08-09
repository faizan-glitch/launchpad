local shell = require("shell")

local limits = {
  name = "File descriptor limits",
}

local function nofile_limit(config)
  return tostring((config.limits and config.limits.nofile) or 1048576)
end

local function render_pam_limits(limit)
  return table.concat({
    "# Managed by launchpad",
    "* soft nofile " .. limit,
    "* hard nofile " .. limit,
    "root soft nofile " .. limit,
    "root hard nofile " .. limit,
  }, "\n") .. "\n"
end

local function render_systemd_limits(limit)
  return table.concat({
    "# Managed by launchpad",
    "[Manager]",
    "DefaultLimitNOFILE=" .. limit,
  }, "\n") .. "\n"
end

function limits.run(config, ctx)
  local pam_path = "/etc/security/limits.d/99-launchpad.conf"
  local system_path = "/etc/systemd/system.conf.d/99-launchpad.conf"
  local user_path = "/etc/systemd/user.conf.d/99-launchpad.conf"
  local limit = nofile_limit(config)

  if ctx.backup then
    ctx.backup:save(pam_path)
    ctx.backup:save(system_path)
    ctx.backup:save(user_path)
  end

  assert(shell.run("mkdir -p /etc/security/limits.d /etc/systemd/system.conf.d /etc/systemd/user.conf.d"))
  assert(shell.write(pam_path, render_pam_limits(limit)))
  assert(shell.write(system_path, render_systemd_limits(limit)))
  assert(shell.write(user_path, render_systemd_limits(limit)))
  assert(shell.run("systemctl daemon-reload"))

  ctx.ui.step_ok("Open file descriptor limits raised to " .. limit)
end

function limits.rollback(config, ctx)
  local pam_path = "/etc/security/limits.d/99-launchpad.conf"
  local system_path = "/etc/systemd/system.conf.d/99-launchpad.conf"
  local user_path = "/etc/systemd/user.conf.d/99-launchpad.conf"

  shell.run("rm -f " .. shell.quote(pam_path))
  shell.run("rm -f " .. shell.quote(system_path))
  shell.run("rm -f " .. shell.quote(user_path))
  shell.run("systemctl daemon-reload")
end

return limits
