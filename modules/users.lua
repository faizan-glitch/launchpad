local shell = require("shell")

local users = {
  name = "Create administrative user",
}

function users.run(config, ctx)
  local username = config.username
  local existing = shell.capture("id -u " .. shell.quote(username))

  assert(shell.run("apt-get update"))
  assert(shell.run("apt-get install -y sudo"))

  if existing and existing ~= "" then
    ctx.ui.step_info("User already exists: " .. username)
    ctx.state.created_user = false
    local groups = shell.capture("id -nG " .. shell.quote(username)) or ""
    ctx.state.user_had_sudo = groups:match("%f[%S]sudo%f[%s]") ~= nil
  else
    assert(shell.run("useradd -m -s /bin/bash " .. shell.quote(username)))
    ctx.ui.step_ok("Created user " .. username)
    ctx.state.created_user = true
    ctx.state.user_had_sudo = false
    if ctx.backup then
      ctx.backup:track_created("/home/" .. username)
    end
  end

  assert(shell.run("usermod -aG sudo " .. shell.quote(username)))
  ctx.ui.step_ok("Added user to sudo group")
end

function users.rollback(config, ctx)
  local username = config.username
  if ctx.state and ctx.state.created_user then
    shell.run("deluser --remove-home " .. shell.quote(username))
  elseif ctx.state and ctx.state.user_had_sudo == false then
    shell.run("deluser " .. shell.quote(username) .. " sudo")
  end
end

return users
