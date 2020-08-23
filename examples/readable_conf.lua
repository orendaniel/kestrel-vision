local conf = {}

conf.width = 160
conf.height = 120
conf.fps = 30
conf.tracesteps = 3

conf.processorfile = 'examples/processor.lua' -- THE PATH IS RELATIVE FOR CURRENT WORKING DIRECTORY

conf.v4l = {
	["brightness"] = 50, -- for example
	--[[
	please refer to v4l2-ctl to view 
	the controls that your camera supports
	]]
}


conf.threshold = {
	["type"] = "hsv", -- or rgb, gray
	["lower"] = {0, 0, 40},
	["upper"] = {255, 255, 255},
	["ratio"] = {0, math.huge},
	["area"] = {0, math.huge},
	["extent"] = {0, math.huge}
}


return conf
