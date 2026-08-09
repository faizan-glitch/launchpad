local shell = require("shell")

local idle_timeout = {
  name = "Configure Idle Timeout",
}

function idle_timeout.run(config, ctx)
  local path = "/etc/profile.d/launchpad-timeout.sh"

  local timeout_minutes = config.idle_timeout.minutes or 15
  local timeout_seconds = timeout_minutes * 60
  local lines = {
    "# Managed by launchpad",
    "export TMOUT=" .. tostring(timeout_seconds),
    "readonly TMOUT",
    "export HISTCONTROL=ignoredups",
  }

  if ctx.backup then
    ctx.backup:save(path)
  end

  assert(shell.write(path, table.concat(lines, "\n") .. "\n"))
  assert(shell.run("chmod 644 " .. shell.quote(path)))

  ctx.ui.step_ok("Idle timeout (" .. tostring(timeout_minutes) .. "m) configured in /etc/profile.d/launchpad-timeout.sh")
end

function idle_timeout.rollback(config, ctx)
  local path = "/etc/profile.d/launchpad-timeout.sh"
  shell.run("rm -f " .. shell.quote(path))
end

return idle_timeout
