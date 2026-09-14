------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Host-specific monitors come from modules/host.lua (see ~/.config/machine).
local host = require("modules.host")

for _, monitor in ipairs(host.monitors) do
    hl.monitor(monitor)
end

hl.monitor({
	output	  = "",
	mode	  = "preferred",
	position  = "auto",
	scale	  = "1",
})