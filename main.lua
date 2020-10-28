#!/usr/bin/lua5.3

--[[
Kestrel vision
Copyright (C) 2020  Oren Daniel

This file is licensed under the terms of the BSD 3-Clause License.
]]

kestrel = require "kestrel"
local unixsocket = require "socket.unix"

--[[
program requires 3 parameters
configuration path, video source, communication port
]]

local conffile = arg[1]
local source = arg[2]
local commpath = arg[3]

_conf = {}
local device = nil
local processor = function(image, contours) end


local function loadv4l()
	-- set fps
	if _conf.fps ~= nil then 
		os.execute("v4l2-ctl -d " .. source .. " -p " .. tostring(_conf.fps))
	end

	-- load v4l settings
	if _conf.v4l ~= nil then
		for i, v in pairs(_conf.v4l) do
			os.execute("v4l2-ctl -d " .. source .. " -c " .. i .. "=" .. tostring(v))
		end
	end
end

-- returns a string in parsable format
local function dump(t)
	if type(t) == 'table' then
		local s = '{ '
		for k, v in pairs(t) do
			if type(k) == 'string' then 
				k = '"' .. k .. '"'
			end
			if type(v) == 'string' then
				v = '"' .. v .. '"'
			end
			local nested = dump(v) 
			s = s .. '[' .. k .. '] = ' .. nested .. ', '
		end
		return s .. '} '
	elseif type(t) == 'number' or type(t) == 'boolean' or type(t) == 'string' then
		return tostring(t)
	else return "nil" end
end

-- remove the N words from string
local function trimwords(str, d)
	local res = str
	for i=1,d do res, _ = res:gsub('^.-%s', '', 1) end
	return res
end

-- load config
if io.open(conffile, 'r') ~= nil then
	_conf = dofile(conffile)
end

-- load v4l after loading settings
loadv4l()

-- open device
if _conf.width ~= nil and _conf.height ~= nil then
	device = kestrel.opendevice(source, _conf.width, _conf.height)
else
	device = kestrel.opendevice(source)
end


-- load processor function
if _conf.processorfile ~= nil then
	if io.open(_conf.processorfile, 'r') ~= nil then
		processor = dofile(_conf.processorfile)
	end
end

-- setup communication socket
local socket = unixsocket()
assert(socket:bind(commpath .. "/socket"))
assert(socket:listen())
local client = socket:accept()
client:settimeout(0)

while true do
	local image = device:readframe()
	local bin = nil
	local cnts = {}
	
	if _conf.threshold ~= nil then
		-- rgb threshold
		if _conf.threshold.type == "rgb" then
			bin = image:inrange(_conf.threshold.lower or {}, _conf.threshold.upper or {})
		
		-- hsv threshold
		elseif _conf.threshold.type == "hsv" then
			local hsv = kestrel.rgb_to_hsv(image)
			bin = hsv:inrange(_conf.threshold.lower or {}, _conf.threshold.upper or {})
		
		elseif _conf.threshold.type == "gray" then
			local gray = kestrel.grayscale(image)
			bin = hsv:inrange(_conf.threshold.lower or {}, _conf.threshold.upper or {})
		end
		
		-- if threshold succeeded trace contours
		if bin ~= nil then
			if (_conf.tracesteps or 0) > 0 then 
				cnts = kestrel.findcontours(bin, _conf.tracesteps, _conf.tracesteps)
			else
				cnts = kestrel.findcontours(bin) 
			end
		end
		
		-- filter contours
		for i, cnt in pairs(cnts) do
			local exp = cnt:extreme()
			local cnt_w = exp[2].x - exp[4].x +1
			local cnt_h = exp[3].y - exp[1].y +1
			local area = cnt:area()
			local extent = area / (cnt_w * cnt_h)
			local ratio = cnt_w / cnt_h

			if _conf.threshold.ratio ~= nil then
				if (ratio < (_conf.threshold.ratio[1] or 0)) or
					(ratio > (_conf.threshold.ratio[2] or math.huge)) then
					table.remove(cnts, i)
				end
			end

			if _conf.threshold.area ~= nil then
				if (area < (_conf.threshold.area[1] or 0)) or
					(area > (_conf.threshold.area[2] or math.huge)) then
					table.remove(cnts, i)
				end
			end

			if _conf.threshold.extent ~= nil then
				if (extent < (_conf.threshold.extent[1] or 0)) or 
					(extent > (_conf.threshold.extent[2] or math.huge)) then
					table.remove(cnts, i)
				end
			end
		end
	end
	
	-- pass result to processor function
	if processor(image, cnts or {}) ~= nil then break end

	local command = client:receive()

	-- parse command
	if command ~= nil then
		if command == "stop!" then -- stop program
			client:send("stopped\n")
			break

		elseif command == "save!" then -- save configuration file
			local file = io.open(conffile, 'w+')
			if file ~= nil then
				file:write("return " .. dump(_conf))
				file:close()
				client:send("done\n")
			end

		elseif command == "shoot!" then -- write pixelmap of image and contours
			local w
			local h
			_, w, h = image:shape()
			local buffer = kestrel.newimage(1, w, h)

			if cnts ~= nil then
				for i=1,#cnts do
					for _, p in pairs(cnts[i]:totable()) do buffer:setat(1, p.x, p.y, 255) end
				end
			end

			kestrel.write_pixelmap(image, commpath .. "/image.ppm")
			kestrel.write_pixelmap(buffer, commpath .. "/contours.ppm")
			os.execute("convert " .. commpath .. "/*.ppm +append " .. commpath .. "/result.jpg")
			os.execute("rm " .. commpath .. "/*.ppm")
			client:send("done\n")

		elseif command == "restartdevice!" then -- restart device
			device:close()
			if _conf.width ~= nil and _conf.height ~= nil then
				device = kestrel.opendevice(source, _conf.width, _conf.height)

			else device = kestrel.opendevice(source) end
			client:send("done\n")

		elseif command == "loadv4l!" then -- update v4l settings
			loadv4l()
			client:send("done\n")

		else
			local exec = load(command)
			if exec ~= nil then 
				local status, result = pcall(exec)
				if status then client:send(dump(result) .. "\n")

				else client:send("error running command\n") end

			else
				client:send("invalid command\n")
			end

		end
	end

end

socket:close()
device:close()
