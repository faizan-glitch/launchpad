local shell = require("shell")

local swap = {
  name = "Configure Swap",
}

function swap.run(config, ctx)
  local swap_file = config.swap.file or "/swapfile"
  local swap_size = config.swap.size or "2G"

  local swapon = shell.capture("swapon --show")
  if swapon and swapon:match(swap_file) then
    ctx.ui.step_ok("Swap file " .. swap_file .. " is already configured and enabled.")
    return
  end

  ctx.ui.step_info("Configuring swap file " .. swap_file .. " of size " .. swap_size)

  local created_swap_file = not shell.exists(swap_file)

  if ctx.backup then
    ctx.backup:save("/etc/fstab")
    ctx.backup:save(swap_file)
  end

  assert(shell.run("fallocate -l " .. shell.quote(swap_size) .. " " .. shell.quote(swap_file)))
  assert(shell.run("chmod 0600 " .. shell.quote(swap_file)))
  assert(shell.run("mkswap " .. shell.quote(swap_file)))
  assert(shell.run("swapon " .. shell.quote(swap_file)))
  ctx.state.created_swap_file = created_swap_file

  local fstab = shell.read("/etc/fstab") or ""
  if not fstab:find(swap_file, 1, true) then
    assert(shell.write("/etc/fstab", fstab .. swap_file .. " none swap sw 0 0\n"))
    ctx.ui.step_ok("Added swap to /etc/fstab")
  end

  ctx.ui.step_ok("Successfully enabled swap file at " .. swap_file)
end

function swap.rollback(config, ctx)
  local swap_file = config.swap.file or "/swapfile"
  shell.run("swapoff " .. shell.quote(swap_file))

  if ctx.state and ctx.state.created_swap_file then
    shell.run("rm -f " .. shell.quote(swap_file))
  end
end

return swap
