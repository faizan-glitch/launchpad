local shell = require("shell")

local cleanup = {
  name = "Cleanup",
}

function cleanup.run(config, ctx)
  assert(shell.run("apt-get autoremove -y"))
  assert(shell.run("apt-get autoclean"))
  ctx.ui.step_ok("Package cleanup complete")
end

return cleanup
