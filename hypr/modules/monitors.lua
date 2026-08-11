------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "DP-3",
    mode     = "2560x1440@180",
    position = "0x0",
    scale    = "1",
    cm 		 = "auto",
})

hl.monitor({
	output	  = "DP-2",
	mode	  = "1920x1080@144",
	position  = "-1080x0",
	scale	  = "1",
	transform = 1,
	disabled  = false,
})

hl.monitor({
	output	 = "HDMI-A-1",
	mode	 = "1920x1080@60",
	position = "2560x0",
	scale	 = "1",
	disabled  = false,
})

hl.monitor({
	output	  = "",
	mode	  = "preferred",
	position  = "auto",
	scale	  = "1",
})
