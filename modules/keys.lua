local shell = require("shell")

local keys = {
  name = "Import SSH public key",
}

local function normalize_key(value)
  if not value or value == "" then
    return nil
  end

  if shell.exists(value) then
    local content = shell.read(value)
    if content then
      return (content:gsub("%s+$", ""))
    end
  end

  return (value:gsub("%s+$", ""))
end

function keys.run(config, ctx)
  if not config.ssh.import_public_key or not config.ssh.public_key then
    ctx.ui.step_info("No SSH public key selected")
    return
  end

  local username = config.username
  local home = "/home/" .. username
  local ssh_dir = home .. "/.ssh"
  local auth_keys = ssh_dir .. "/authorized_keys"
  local key = normalize_key(config.ssh.public_key)

  if not key or key == "" then
    ctx.ui.step_info("SSH public key was empty; skipping")
    return
  end

  if ctx.backup then
    ctx.backup:save(auth_keys)
  end

  assert(shell.run("install -d -m 700 -o " .. shell.quote(username) .. " -g " .. shell.quote(username) .. " " .. shell.quote(ssh_dir)))
  assert(shell.write(auth_keys, key .. "\n"))
  assert(shell.run("chown " .. shell.quote(username) .. ":" .. shell.quote(username) .. " " .. shell.quote(auth_keys)))
  assert(shell.run("chmod 600 " .. shell.quote(auth_keys)))

  ctx.ui.step_ok("Imported SSH public key")
end

function keys.rollback(config, ctx)
  local auth_keys = "/home/" .. config.username .. "/.ssh/authorized_keys"
  shell.run("rm -f " .. shell.quote(auth_keys))
end

return keys
