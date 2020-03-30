#!/usr/bin/lua5.3

--[[
Kestrel
Copyright (C) 2020  Oren Daniel

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--

kestrel = require "kestrel"
local socket = require "socket"

--[[
program requires 3 parameters
configuration path, video source, communication port
]]--

local conffile = arg[1]
local source = arg[2]
local port = arg[3]

conf = {}
local device = nil
local processor = function(image, contours) end


local function loadv4l()
	-- set fps
	if conf.fps ~= nil then os.execute("v4l2-ctl -d ".. source .. " -p " .. tostring(conf.fps)) end

	-- load v4l settings
	if conf.v4l ~= nil then
		for i, v in pairs(conf.v4l) do
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
	conf = dofile(conffile)
end

loadv4l()

-- open device
if conf.width ~= nil and conf.height ~= nil then
	device = kestrel.opendevice(source, conf.width, conf.height)
else
	device = kestrel.opendevice(source)
end


-- load processor function
if conf.processorfile ~= nil then
	if io.open(conf.processorfile, 'r') ~= nil then
		processor = dofile(conf.processorfile)
	end
end

-- setup communication socket
local tcp = socket.tcp()
assert(tcp:bind("0.0.0.0", port))
assert(tcp:listen())
tcp:settimeout(0)
local client

while true do
	print(os.clock())
	local image = device:readframe()
	local bin = nil
	local cnts = {}
	
	if conf.threshold ~= nil then
		-- rgb threshold
		if conf.threshold.type == "rgb" then
			bin = image:inrange(conf.threshold.lower or {}, conf.threshold.upper or {})
		
		-- hsv threshold
		elseif conf.threshold.type == "hsv" then
			local hsv = kestrel.rgb_to_hsv(image)
			bin = hsv:inrange(conf.threshold.lower or {}, conf.threshold.upper or {})
		
		elseif conf.threshold.type == "gray" then
			local gray = kestrel.grayscale(image)
			bin = hsv:inrange({conf.threshold.lower[1]} or {}, {conf.threshold.upper[1]} or {})
		end
		
		-- if threshold succeeded trace contours
		if bin ~= nil then
			if (conf.tracesteps or 0) > 0 then 
				cnts = kestrel.findcontours(bin, conf.tracesteps, conf.tracesteps)
			else
				cnts = kestrel.findcontours(bin) 
			end
		end
		
		-- remove unwanted contours
		for i, cnt in pairs(cnts) do
			local exp = cnt:extreme()
			local cnt_w = exp[2].x - exp[4].x +1
			local cnt_h = exp[3].y - exp[1].y +1
			local area = cnt:area()
			local solidity = area / (cnt_w * cnt_h)
			local ratio = cnt_w / cnt_h

			if conf.threshold.ratio ~= nil then
				if ratio < (conf.threshold.ratio[1] or 0) or ratio > (conf.threshold.ratio[2] or math.huge) then
					table.remove(cnts, i)
				end
			end

			if conf.threshold.area ~= nil then
				if area < (conf.threshold.area[1] or 0) or area > (conf.threshold.area[2] or math.huge) then
					table.remove(cnts, i)
				end
			end

			if conf.threshold.solidity ~= nil then
				if solidity < (conf.threshold.solidity[1] or 0) or solidity > (conf.threshold.solidity[2] or math.huge) then
					table.remove(cnts, i)
				end
			end
		end
	end
	
	-- pass result to processor function
	if processor(image, cnts or {}) ~= nil then break end

	--[[
	tcp communication
	freeze loop if client is connected
	return when transmission ends
	]]--
	local command = nil
	if client == nil then client = tcp:accept() end	
	
	if client ~= nil then
		command = client:receive()
	end

	-- parse command
	if command == nil then client = nil 
	else
		if command == "quit!" then 
			client:close() 
			client = nil -- end transmission

		elseif command == "stop!" then break -- stop program

		elseif command == "save!" then -- save configuration file
			local file = io.open(conffile, 'w+')
			if file ~= nil then
				file:write("return " .. dump(conf))
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

			kestrel.write_pixelmap(image, "image.ppm")
			kestrel.write_pixelmap(buffer, "contours.ppm")
			os.execute("convert image.ppm contours.ppm +append " .. port .. "result.jpg")
			os.execute("rm image.ppm contours.ppm")
			client:send("done\n")

		elseif command == "restartdevice!" then -- restart device
			loadv4l()
			device:close()
			if conf.width ~= nil and conf.height ~= nil then
				device = kestrel.opendevice(source, conf.width, conf.height)

			else device = kestrel.opendevice(source) end
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

tcp:close()
device:close()
