local shell = require("shell")

local ssh = {
  name = "Configure SSH",
}

function ssh.run(config, ctx)
  local path = "/etc/ssh/sshd_config.d/99-launchpad.conf"
  local main_path = "/etc/ssh/sshd_config"
  local lines = {
    "# Managed by launchpad",
    "Port " .. tostring(config.ssh.port),
    "PermitRootLogin " .. (config.ssh.disable_root_login and "no" or "prohibit-password"),
    "PasswordAuthentication " .. (config.ssh.disable_password_auth and "no" or "yes"),
    "KbdInteractiveAuthentication no",
    "PubkeyAuthentication yes",
    "AllowAgentForwarding no",
    "X11Forwarding no",
    "AllowUsers " .. tostring(config.username)
  }

  if ctx.backup then
    ctx.backup:save(path)
    ctx.backup:save(main_path)
  end

  assert(shell.run("apt-get update"))
  assert(shell.run("apt-get install -y openssh-server"))
  assert(shell.run("mkdir -p /etc/ssh/sshd_config.d"))

  local main_content = shell.read(main_path) or ""
  if not main_content:match("Include%s+/etc/ssh/sshd_config%.d/%*%.conf") then
    main_content = "Include /etc/ssh/sshd_config.d/*.conf\n" .. main_content
  end
  assert(shell.write(main_path, main_content))
  assert(shell.write(path, table.concat(lines, "\n") .. "\n"))

  local test = shell.run("sshd -t")
  if not test then
    error("sshd configuration test failed")
  end

  assert(shell.run("systemctl restart ssh"))
  ctx.ui.step_ok("SSH configured and restarted")
end

function ssh.rollback(config, ctx)
  local path = "/etc/ssh/sshd_config.d/99-launchpad.conf"
  shell.run("rm -f " .. shell.quote(path))
  shell.run("systemctl restart ssh")
end

return ssh
