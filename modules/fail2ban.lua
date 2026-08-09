local shell = require("shell")

local fail2ban = {
  name = "Fail2Ban",
}

function fail2ban.run(config, ctx)
  local path = "/etc/fail2ban/jail.d/99-launchpad.local"
  local lines = {
    "[sshd]",
    "enabled = true",
    "port = " .. tostring(config.ssh.port),
    "maxretry = " .. tostring(config.fail2ban.maxretry),
    "findtime = " .. tostring(config.fail2ban.findtime),
    "bantime = " .. tostring(config.fail2ban.bantime),
  }

  if ctx.backup then
    ctx.backup:save(path)
  end

  assert(shell.run("apt-get update"))
  assert(shell.run("apt-get install -y fail2ban"))
  assert(shell.run("mkdir -p /etc/fail2ban/jail.d"))
  assert(shell.write(path, table.concat(lines, "\n") .. "\n"))
  assert(shell.run("systemctl enable --now fail2ban"))
  assert(shell.run("systemctl restart fail2ban"))

  ctx.ui.step_ok("Fail2Ban configured")
end

function fail2ban.rollback(config, ctx)
  local path = "/etc/fail2ban/jail.d/99-launchpad.local"
  shell.run("rm -f " .. shell.quote(path))
  shell.run("systemctl disable --now fail2ban")
end

return fail2ban
