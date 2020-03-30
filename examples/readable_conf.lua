local conf = {}

conf.width = 160
conf.height = 120
conf.fps = 30
conf.tracesteps = 3

conf.processorfile = 'processor.lua'

conf.v4l = {
	["brightness"] = 0,
}


conf.thershold = {
	["type"] = "hsv", --or rgb, gray
	["lower"] = {0, 0, 40},
	["upper"] = {255, 255, 255},
	["ratio"] = {0, math.huge},
	["area_filter"] = {0, math.huge},
	["solidity"] = {0, math.huge}
}


return conf
