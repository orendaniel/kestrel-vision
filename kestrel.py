#!/usr/bin/python3

'''
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
'''

import flask
from shelljob import proc

import sys
import os
import threading
import socket
import time

BUFFER= 4096
PATH_PREFIX = "/tmp/kestrel/"
REFRESH_RATE = 1 #seconds

web = flask.Flask(__name__)

conf_file = sys.argv[1]
source = sys.argv[2]
comm_port = sys.argv[3]
web_port = sys.argv[4]

#unique temporary folder for communication
communication_path = PATH_PREFIX + str(time.time())
os.system("mkdir -p " + communication_path)

#start process
group = proc.Group()
process = group.run(["bash", "-c", "./main.lua {} {} {}".format(conf_file, source, communication_path)])

#connect to unix socket
try:
	unix_client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
	#try to connect
	while True: 		
		if os.path.exists(communication_path + "/socket"):
			unix_client.connect(communication_path + "/socket")
			break

except Exception as e:
	print(e)
	print("cannot open unix socket")
	exit(1)

#start tcp server
try:
	tcp_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	tcp_socket.bind(("0.0.0.0", int(comm_port)))
	tcp_socket.listen(1)
except Exception as e:
	print(e)
	print("cannot open tcp socket")
	exit(1)

#receive messages from tcp and redirect them to unix socket
#then return the result
def communication():
	client = None
	msg = None
	while True:
		if client == None:
			client, _ = tcp_socket.accept()

		if client != None:
			msg = client.recv(BUFFER)
			if not msg:
				client = None
			else:
				unix_client.send(msg)
				answer = unix_client.recv(BUFFER)
				if answer.decode("utf-8").strip("\n").strip(" ") == "stopped":
					os.system("rm -r " + communication_path)
					print("stopped")
					break

				client.send(answer)

		time.sleep(REFRESH_RATE)

#run communication() in parrallel
thread = threading.Thread(target=communication, args=())
thread.daemon = True
thread.start()

#show program output
@web.route('/')
def stream():
	def read():
		while group.is_pending():
			lines = group.readlines()
			for proc, line in lines:
				yield line

	return flask.Response(read(), mimetype= 'text/plain')

#stream result.jpg
def image_gen():
	while True:
		time.sleep(REFRESH_RATE)
		frame = b''
		if os.path.exists(communication_path + '/result.jpg'):
			with open(communication_path + '/result.jpg', 'rb') as file:
				frame = file.read()
		yield b'--frame\r\nContent-Type: image/jpeg\r\n\r\n' + frame + b'\r\n'

@web.route('/image')
def video_feed():
	return flask.Response(image_gen(), mimetype='multipart/x-mixed-replace; boundary=frame')
	
if __name__ == "__main__":
	web.run(host="0.0.0.0", port=int(web_port))
