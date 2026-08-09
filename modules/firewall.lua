local shell = require("shell")

local firewall = {
  name = "Firewall",
}

local function join_ports(ports)
  return table.concat(ports, ", ")
end

function firewall.run(config, ctx)
  local path = "/etc/nftables.conf"
  local ports = config.firewall.allowed_tcp_ports or {}
  local rules = {
    "#!/usr/sbin/nft -f",
    "flush ruleset",
    "",
    "table inet filter {",
    "  chain input {",
    "    type filter hook input priority 0; policy drop;",
    "    ct state established,related accept",
    "    iif lo accept",
    "    ip protocol icmp accept",
  }

  if config.firewall.ipv6 then
    rules[#rules + 1] = "    ip6 nexthdr icmpv6 accept"
  end

  for _, port in ipairs(ports) do
    rules[#rules + 1] = "    tcp dport " .. tostring(port) .. " accept"
    if port == "80" or port == "443" then
      rules[#rules + 1] = "    udp dport " .. tostring(port) .. " accept"
    end
  end

  rules[#rules + 1] = "  }"
  rules[#rules + 1] = "  chain forward {"
  rules[#rules + 1] = "    type filter hook forward priority 0; policy drop;"
  rules[#rules + 1] = "  }"
  rules[#rules + 1] = "  chain output {"
  rules[#rules + 1] = "    type filter hook output priority 0; policy accept;"
  rules[#rules + 1] = "  }"
  rules[#rules + 1] = "}"
  rules[#rules + 1] = ""

  if ctx.backup then
    ctx.backup:save(path)
  end

  assert(shell.run("apt-get update"))
  assert(shell.run("apt-get install -y nftables"))
  assert(shell.write(path, table.concat(rules, "\n")))
  assert(shell.run("nft -c -f /etc/nftables.conf"))
  assert(shell.run("systemctl enable --now nftables"))

  ctx.ui.step_ok("Firewall enabled with allowed ports: " .. join_ports(ports))
end

function firewall.rollback(config, ctx)
  local path = "/etc/nftables.conf"
  shell.run("rm -f " .. shell.quote(path))
  shell.run("systemctl disable --now nftables")
end

return firewall
