function processor(image, contours)
	for i, cnt in pairs(contours) do
		C = cnt:center()
		print(C.x, C.y)
	end
end

return processor
