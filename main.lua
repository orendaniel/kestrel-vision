#!/usr/bin/lua5.3

kestrel = require "kestrel"
local unixsocket = require "socket.unix"

local conffile = arg[1]
local source = arg[2]
local comm = arg[3]

local conf = {}
local device = nil
local processor = function(image, contours) end

local socket = assert(unixsocket())
assert(socket:bind(comm .. 'socket'))
assert(socket:listen())
local conn = assert(socket:accept())
conn:settimeout(0)

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
			if nested ~= nil then
				s = s .. '[' .. k .. '] = ' .. nested .. ', '
			end
		end
		return s .. '} '
	elseif type(t) == "number" or type(t) == "boolean" or type(t) == "string" then
		return tostring(t)
	end
end

local function tokenize(command) 
	local tokens = {}
	for t in string.gmatch(command, "[^%s]+") do
		table.insert(tokens, t)
	end
	return tokens
end

if io.open(conffile, 'r') ~= nil then
	conf = dofile(conffile)
end

if conf.width ~= nil and conf.height ~= nil then
	device = kestrel.opendevice(source, conf.width, conf.height)
else
	device = kestrel.opendevice(source)
end

if conf.fps ~= nil then os.execute("v4l2-ctl -p " .. tostring(conf.fps)) end

if conf.v4l ~= nil then
	for i, v in pairs(conf.v4l) do
		os.execute("v4l2-ctl -d " .. source .. " -c " .. i .. "=" .. tostring(v))
	end
end

if conf.processorfile ~= nil then
	processor = dofile(conf.processorfile)
end

while true do
	local image = device:readframe()
	local bin = nil
	local cnts = nil
	
	if conf.threshold ~= nil then
		local cnts = {}
		if conf.threshold.type == "rgb" then
			bin = image:inrange(conf.threshold.lower or {}, conf.threshold.upper or {})

		elseif conf.threshold.type == "hsv" then
			local hsv = kestrel.rgb_to_hsv(image)
			bin = hsv:inrange(conf.threshold.lower or {}, conf.threshold.upper or {})

		elseif conf.threshold.type == "gray" then
			local gray = kestrel.grayscale(image)
			bin = hsv:inrange(conf.threshold.lower or {}, conf.threshold.upper or {})
		end

		if bin ~= nil then
			cnts = kestrel.findcontours(bin, conf.tracesteps or 3, conf.tracesteps or 3)
		end
		
		for i, cnt in pairs(cnts) do
			local exp = cnt:extreme()
			local cnt_w = exp[2].x - exp[4].x
			local cnt_h = exp[3].y - exp[1].y
			local area = cnt:area()

			if conf.threshold.ratio ~= nil then
				local ratio = cnt_w / cnt_h
				if ratio < (conf.threshold.ratio[1] or 0) or ratio > (conf.threshold.ratio[2] or math.huge) then
					cnts[i] = nil
				end
			end

			if conf.threshold.area ~= nil then
				if area < (conf.threshold.area[1] or 0) or area > (conf.threshold.area[2] or math.huge) then
					cnts[i] = nil
				end
			end

			if conf.threshold.solidity ~= nil then
				local solidity = area / (cnt_w * cnt_h)
				if solidity < (conf.threshold.solidity[1] or 0) or solidity > (conf.threshold.solidity[2] or math.huge) then
					cnts[i] = nil
				end
			end
		end
	end

	if processor(image, cnts or {}) ~= nil then break end
	
	-- receive commands from unix port
	local command = conn:receive()
	if command ~= nil then
		local tokens = tokenize(command)
		if command == "getimage" then
			kestrel.write_pixelmap(image, comm .. "image.ppm")
			os.execute("convert " .. comm .. "image.ppm " .. comm .. "image.png")

			_, w, h = image:shape()
			local buffer = kestrel.newimage(1, w, h)
			if cnts ~= nil then
				for c=1,#(cnts or {}) do
					for i, p in pairs(cnts[c]:totable()) do
						buffer:setat(1, p.x, p.y, 255)
					end
				end
			end
			kestrel.write_pixelmap(buffer, comm .. "contours.ppm")
			os.execute("convert " .. comm .. "contours.ppm " .. comm .. "contours.png")

		elseif command == "saveconfig" then
			local file = io.open(conffile, 'w+')
			file:write('return ' .. dump(conf))
			file:close()

		elseif command == "exit" then
			break

		elseif tokens[1] == 'set' and tokens[2] ~= nil and tokens[3] ~= nil then
			conf[tokens[2]] = load('return ' .. tokens[3])()

			if tokens[2] == 'fps' then os.execute("v4l2-ctl -p " .. tostring(conf.fps)) end

		elseif tokens[1] == 'setv4l' and tokens[2] ~= nil and tokens[3] ~= nil then
			if conf.v4l == nil then conf.v4l = {} end
			conf.v4l[tokens[2]] = tokens[3]
			os.execute("v4l2-ctl -d " .. source .. " -c " .. tokens[2] .. "=" .. tostring(tokens[3]))

		elseif tokens[1] == 'setthresh' and tokens[2] ~= nil and tokens[3] ~= nil then
			if conf.threshold == nil then conf.threshold = {} end
			conf.threshold[tokens[2]] = load('return ' .. tokens[3])()

		elseif tokens[1] == 'get' then
			conn:send((conf[tokens[2]] or 'nil').. '\n')

		elseif tokens[1] == 'getv4l' then
			if conf.v4l == nil then conf.v4l = {} end
			conn:send(conf.v4l[tokens[2]] .. '\n')

		elseif tokens[1] == 'getthresh' then
			if conf.threshold == nil then conf.threshold = {} end
			conn:send(conf.threshold[tokens[2]] .. '\n')

		elseif tokens[1] == 'cleanthresh' then 
			conf.threshold = nil

		elseif tokens[1] == 'cleanv4l' then 
			conf.v4l = nil

		end
	end
end

device:close()
