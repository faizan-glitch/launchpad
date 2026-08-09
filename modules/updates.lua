local shell = require("shell")

local updates = {
  name = "Automatic updates",
}

function updates.run(config, ctx)
  local path1 = "/etc/apt/apt.conf.d/20auto-upgrades"
  local path2 = "/etc/apt/apt.conf.d/50unattended-upgrades-hardener"
  local lines1 = {
    "APT::Periodic::Update-Package-Lists \"1\";",
    "APT::Periodic::Unattended-Upgrade \"1\";",
  }
  local lines2 = {
    "Unattended-Upgrade::Automatic-Reboot \"false\";",
    "Unattended-Upgrade::Remove-Unused-Dependencies \"true\";",
    "Unattended-Upgrade::MinimalSteps \"true\";",
  }

  if ctx.backup then
    ctx.backup:save(path1)
    ctx.backup:save(path2)
  end

  assert(shell.run("apt-get update"))
  assert(shell.run("apt-get install -y unattended-upgrades apt-listchanges"))
  assert(shell.write(path1, table.concat(lines1, "\n") .. "\n"))
  assert(shell.write(path2, table.concat(lines2, "\n") .. "\n"))
  assert(shell.run("dpkg-reconfigure -f noninteractive unattended-upgrades"))
  ctx.ui.step_ok("Automatic updates enabled")
end

function updates.rollback(config, ctx)
  shell.run("rm -f /etc/apt/apt.conf.d/20auto-upgrades")
  shell.run("rm -f /etc/apt/apt.conf.d/50unattended-upgrades-hardener")
end

return updates
