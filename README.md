##Kestrel vision program

Kestrel vision is a scriptable vision program based on kestrel vision library.

Kestrel vision library
https://gitlab.com/oren_daniel/kestrel-lib


##Dependencies

Kestrel (libv4l, lua 5.3)

ImageMagick

v4l2-ctl


front panel also requires:

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
or you can write it yourself, however you must create it

Now you can simply run main.lua using:

./main.lua config_file video_source communication_port

for example

./main.lua ~/conf.lua /dev/video0 8080

And kestrel is now running.
 
you can communicate with it be connecting to the TCP port with netcat in unix or telnet in windows.

for example

netcat address communication_port

the program will now stop execution and wait for your commands, as long as you are connected.

#list of commands
-----------------

stop! --> stops kestrel

quit! --> end transmission and returns control to kestrel

save! --> save current configure (overwrittes config_file)

shoot! --> returns a jpg of the image taken by the camera and the contours selected

restartdevice! --> restarts the device and reloads v4l settings


the config table conf is a global variable and it can be accessed from 
your script or by using you.


##Running the web front panel


Although you can run main.lua as a standalone script, it is recommended that you would use the front panel.

The front panel is used to view the output of your program
so if for example, you used the print command in you script it
will redirect it to the front panel.

you can view the image taken by shoot! command from the front panel as well.

you can run the front panel by:

./front_panel.py config_file video_source communication_port web_port

for example

./front_panel.py ~/conf.lua /dev/video0 8080 80

you can now view the output of your program from the browser by going to the link

http://your_process_ip_address:web_port/

and view the output of shoot! in

http://your_process_ip_address:web_port/result

