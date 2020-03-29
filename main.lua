#!/usr/bin/lua5.3

kestrel = require "kestrel"
local socket = require "socket"

local conffile = arg[1]
local source = arg[2]
local port = arg[3]

local conf = {}
local device = nil
local processor = function(image, contours) end

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
	elseif type(t) == "number" or type(t) == "boolean" or type(t) == "string" then
		return tostring(t)
	else return "nil" end
end

local function tokenize(command) 
	local tokens = {}
	for t in string.gmatch(command, "[^%s]+") do
		table.insert(tokens, t)
	end
	return tokens
end

local function cdrstr(str, d) -- cdr as in lisp
	local res = str
	for i=1,d do res, _ = res:gsub("^.-%s", "", 1) end
	return res
end

if io.open(conffile, 'r') ~= nil then
	conf = dofile(conffile)
end

if conf.width ~= nil and conf.height ~= nil then
	device = kestrel.opendevice(source, conf.width, conf.height)
else
	device = kestrel.opendevice(source)
end

if conf.fps ~= nil then os.execute("v4l2-ctl -d ".. source .. " -p " .. tostring(conf.fps)) end

if conf.v4l ~= nil then
	for i, v in pairs(conf.v4l) do
		os.execute("v4l2-ctl -d " .. source .. " -c " .. i .. "=" .. tostring(v))
	end
end

if conf.processorfile ~= nil then
	if io.open(conf.processorfile, 'r') ~= nil then
		processor = dofile(conf.processorfile)
	end
end

local tcp = socket.tcp()
assert(tcp:bind("localhost", port))
assert(tcp:listen())
tcp:settimeout(0)
local client

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
			if (conf.tracesteps or 0) > 0 then 
				cnts = kestrel.findcontours(bin, conf.tracesteps, conf.tracesteps)
			else
				cnts = kestrel.findcontours(bin) 
			end
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
	print(os.time())


	-- tcp communication
	local command = nil
	if client == nil then client = tcp:accept() end	
	
	if client ~= nil then
		command = client:receive()
	end
	if command == nil then client = nil 
	else
		print(command)
		local tokens = tokenize(command)
		if command == "quit" then client = nil 
		elseif command == "stop" then break

		elseif command == "save" then
			local file = io.open(conffile, "w+")
			file:write("return" .. dump(conf))
			file:close()
			client:send("done\n")

		elseif tokens[1] == "shoot" then
			local path
			path, _ = cdrstr(command)
			if path ~= "" and path:sub(1, 1) == '/' then
				local w
				local h
				_, w, h = image:shape()
				local buffer = kestrel.newimage(1, w, h)
				if cnts ~= nil then
					for i=1,#cnts do
						for _, p in pairs(cnts[i]:totable()) do buffer:setat(1, p.x, p.y, 255) end
					end
				end
				kestrel.write_pixelmap(image, path .. "/image.ppm")
				kestrel.write_pixelmap(buffer, path .. "/contours.ppm")
				os.execute("convert " .. path .. "/image.ppm " .. path .. "/image.jpg")
				os.execute("convert " .. path .. "/contours.ppm " .. path .. "/contours.jpg")
				client:send("done\n")
			end

		elseif tokens[1] == "set" then
			if tokens[2] == "v4l" then
				conf.v4l[tokens[3]] = load("return " .. cdrstr(cdrstr(cdrstr(command))))()
			elseif tokens[2] == "thresh" then
				conf.threshold[tokens[3]] = load("return " .. cdrstr(command, 3))()
			else
				conf[tokens[2]] = load("return " .. cdrstr(command, 2))()
			end
			client:send("done\n")

		elseif tokens[1] == "get" then
			if tokens[2] == "v4l" then
				print(dump(conf.v4l[tokens[3]]))
				client:send(dump(conf.v4l[tokens[3]]) .. "\n")
			elseif tokens[2] == "thresh" then
				if tokens[4] == "@" then
					local index= tonumber(tokens[3])
					print(dump(conf.threshold[tokens[5]][index]))
					client:send(dump(conf.threshold[tokens[5]][index]) .. "\n")
				else
					print(dump(conf.threshold[tokens[3]]))
					client:send(dump(conf.threshold[tokens[3]]) .. "\n")
				end
			else
				print(dump(conf[tokens[2]]))
				client:send(dump(conf[tokens[2]]) .. "\n")
			end
		end
	end
end

tcp:close()
device:close()
