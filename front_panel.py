#!/usr/bin/python3

from flask import Flask, render_template, request
import socket
import os

front_panel = Flask(__name__)

os.popen('rm /tmp/socket; ./main.lua conf.lua /dev/video0 /tmp/socket')

@front_panel.route('/', methods = ['POST', 'GET'])
def index():
	'''
	if form.validate_on_submit():
		if 'get_image' in request.form:
			client.send("getimage")
			time.sleep(1)
			os.system("convert image.ppm image.jpg")
			os.system("convert buffer.ppm buffer.jpg")
	'''

			
	return render_template('front_panel.html')

if __name__ == '__main__':
	front_panel.run(host='0.0.0.0')

