##Kestrel vision program

Kestrel vision is a scriptable vision program based on Kestrel vision library.

Kestrel vision library
https://gitlab.com/oren_daniel/kestrel-lib


##Dependencies

Kestrel (libv4l, lua 5.3)

ImageMagick

v4l2-ctl

lua socket

Python

flask

shelljob



##Using Kestrel

Firstly write you lua script for example:

function processor(image, contours)
	for i, cnt in pairs(contours) do
		C = cnt:center()
		print(C.x, C.y)
	end
end

return processor


Then write your config file
you can leave it empty and configure kestrel later 
or you can write it yourself.

A human readable config file can be found in examples folder.

now run:

./kestrel.py <config file> <video source> <communication port> <web port>

for example

./kestrel.py ~/conf.lua /dev/video0 8080 80

Now kestrel is running.

You can now open your browser and go the address:

http://<ip_address_of_your_computer>:<web port>

and you will see the output of your program.

the output of shoot! (see commands later) can be viewed in:

http://<ip_address_of_your_computer>:<web port>/images

now open netcat (for unix) or telnet (for windows) and connect to
the communication port.

netcat <ip_address_of_your_computer> <communication port>

and you can now enter commands to kestrel.

#Commands

stop! --> stops kestrel

save! --> save current configure (overwrittes config file)

shoot! --> returns a jpg of the image taken by the camera and the contours selected

restartdevice! --> restarts the device and reloads v4l settings

loadv4l! --> reloads v4l settings and sets FPS

the config table "conf" is a global variable and it can be accessed by 
your script or manually.


Any other command is executed as a lua command
so for example you can change the camera resolution by:

return conf.width -- get current value

return conf.height

conf.width = 320

conf.height = 240

restartdevice!

shoot!
