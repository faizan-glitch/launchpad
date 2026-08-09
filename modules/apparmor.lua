local shell = require("shell")

local apparmor = {
  name = "AppArmor",
}

local function basename(path)
  return path:match("^.*/([^/]+)$") or path
end

local function candidate_profiles(config)
  local profiles = {
    "/etc/apparmor.d/usr.sbin.sshd",
  }

  if config.stack == "caddy" then
    profiles[#profiles + 1] = "/etc/apparmor.d/usr.bin.caddy"
  elseif config.stack == "nginx" then
    profiles[#profiles + 1] = "/etc/apparmor.d/usr.sbin.nginx"
  elseif config.stack == "mail" then
    profiles[#profiles + 1] = "/etc/apparmor.d/usr.sbin.postfix"
    profiles[#profiles + 1] = "/etc/apparmor.d/usr.sbin.dovecot"
  end

  return profiles
end

local function render_grub_snippet()
  return table.concat({
    "# Managed by launchpad",
    'GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} apparmor=1 security=apparmor"',
  }, "\n") .. "\n"
end

function apparmor.run(config, ctx)
  local grub_path = "/etc/default/grub.d/99-launchpad-apparmor.cfg"
  local profiles = candidate_profiles(config)
  local enforced = {}

  if ctx.backup then
    ctx.backup:save(grub_path)
  end

  assert(shell.run("apt-get update"))
  assert(shell.run("apt-get install -y apparmor apparmor-utils apparmor-profiles apparmor-profiles-extra"))
  assert(shell.run("mkdir -p /etc/default/grub.d"))
  assert(shell.write(grub_path, render_grub_snippet()))
  assert(shell.run("update-grub"))
  assert(shell.run("systemctl enable --now apparmor"))
  assert(shell.run("systemctl restart apparmor"))

  for _, profile in ipairs(profiles) do
    if shell.exists(profile) then
      assert(shell.run("aa-enforce " .. shell.quote(profile)))
      enforced[#enforced + 1] = basename(profile)
    end
  end

  ctx.state.apparmor_profiles = enforced

  if #enforced > 0 then
    ctx.ui.step_ok("AppArmor enabled; enforced profiles: " .. table.concat(enforced, ", "))
  else
    ctx.ui.step_ok("AppArmor enabled; no matching packaged profiles found")
  end

  ctx.ui.step_info("AppArmor boot hardening is staged; reboot to activate the new GRUB kernel parameters")
end

function apparmor.rollback(config, ctx)
  local grub_path = "/etc/default/grub.d/99-launchpad-apparmor.cfg"
  local profiles = ctx.state and ctx.state.apparmor_profiles or {}

  for _, profile in ipairs(profiles) do
    shell.run("aa-complain " .. shell.quote("/etc/apparmor.d/" .. profile))
  end

  shell.run("rm -f " .. shell.quote(grub_path))
  shell.run("update-grub")
  shell.run("systemctl restart apparmor")
end

return apparmor
