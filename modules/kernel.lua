local shell = require("shell")

local kernel = {
  name = "Kernel hardening",
}

function kernel.run(config, ctx)
  local path = "/etc/sysctl.d/99-launchpad.conf"
  local lines = {
    "# Managed by launchpad",
    "kernel.dmesg_restrict = 1",
    "kernel.kptr_restrict = 2",
    "kernel.yama.ptrace_scope = 1",
    "fs.protected_hardlinks = 1",
    "fs.protected_symlinks = 1",
    "net.ipv4.conf.default.accept_source_route = 0",
    "net.ipv4.conf.all.accept_redirects = 0",
    "net.ipv4.conf.default.accept_redirects = 0",
    "net.ipv4.conf.all.send_redirects = 0",
    "net.ipv4.conf.default.send_redirects = 0",
    "net.ipv4.tcp_syncookies = 1",
    "net.ipv4.icmp_echo_ignore_broadcasts = 1",
    "net.ipv4.conf.all.rp_filter = 1",
    "net.ipv4.conf.default.rp_filter = 1",
    "# Disable source packet routing",
    "net.ipv4.conf.all.accept_source_route = 0",
    "net.ipv6.conf.all.accept_source_route = 0",
    "# Log Martians (packets with impossible addresses)",
    "net.ipv4.conf.all.log_martians = 1",
    "# Protect against SYN flood attacks",
    "net.ipv4.tcp_syncookies = 1",
    "net.ipv4.tcp_max_syn_backlog = 2048",
    "net.ipv4.tcp_synack_retries = 2",
  }

  if ctx.backup then
    ctx.backup:save(path)
  end

  assert(shell.write(path, table.concat(lines, "\n") .. "\n"))
  assert(shell.run("sysctl --system"))
  ctx.ui.step_ok("Kernel parameters applied")
end

function kernel.rollback(config, ctx)
  local path = "/etc/sysctl.d/99-launchpad.conf"
  shell.run("rm -f " .. shell.quote(path))
  shell.run("sysctl --system")
end

return kernel
