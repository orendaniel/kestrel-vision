## Kestrel vision program

Kestrel vision is a scriptable vision program based on Kestrel vision library.

Kestrel vision library
https://gitlab.com/oren_daniel/kestrel-lib


## Dependencies

Kestrel (libv4l, lua)

ImageMagick

v4l2-ctl

lua socket

Python

flask

shelljob



## Using Kestrel

Firstly write you lua script for example:

function processor(image, contours)
	for i, cnt in pairs(contours) do
		C = cnt:center()
		print(C.x, C.y)
	end
end

return processor


Then write your config file (.lua file)
you can leave it empty and configure kestrel later 
or you can write it yourself.

A human readable config file can be found in the examples folder.

now run:

./kestrel.py <config file> <video source> <communication port> <web port>

for example

./kestrel.py ~/conf.lua /dev/video0 8080 80

Now kestrel is running.

You can open your browser and go the link:

http://<ip_address_of_your_computer>:<web port>

and you will see the output of your program.

the output of shoot! (see Commands) can be viewed in:

http://<ip_address_of_your_computer>:<web port>/image

There is no need to refresh the web page after a shoot! command,
the page will refresh itself automatically.

Now open netcat (for unix) or telnet (for windows) and connect to
the communication port.

netcat <ip_address_of_your_computer> <communication port>

And you can now enter commands to kestrel.

# Commands

stop! --> stops kestrel

save! --> save current configure (overwrittes config file)

shoot! --> returns a jpg of the image taken by the camera and the contours selected

restartdevice! --> restarts the device and reloads v4l settings

loadv4l! --> reloads v4l settings and sets FPS

the config table "conf" is a global variable and it can be accessed by you or your script.


Any other command is executed as a lua command
so for example you can change the camera resolution by:

return conf.width -- get current value

return conf.height

conf.width = 320

conf.height = 240

restartdevice!

shoot!


# Temporary Files

This program consists of two parts: a lua part and python part.

The lua part runs the vision processor, handles the config file, etc. 
While the python part handles the web front end, and receives communication from user.

The two parts "talk" using a unix domain socket. 

You will also notice that Kestrel creates a temporary folder (by default at /tmp/kestrel),
which contains the socket file and the output of shoot!.
Kestrel deletes them when you send a stop! command or when the program quits (if processor returns non nil).

However if the program is terminated unexpectedly it will not delete them.
 
