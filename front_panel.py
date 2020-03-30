#!/usr/bin/python3

import flask
from flask import send_file
from shelljob import proc
import sys

front_panel = flask.Flask(__name__)

conf_file = sys.argv[1]
source = sys.argv[2]
comm_port = sys.argv[3]
web_port = sys.argv[4]

group = proc.Group()
process = group.run(["bash", "-c", "./main.lua {} {} {}".format(conf_file, source, comm_port)])

#show program output
@front_panel.route('/')
def stream():
	def read():
		while group.is_pending():
			lines = group.readlines()
			for proc, line in lines:
				yield line

	return flask.Response(read(), mimetype= 'text/plain')

#show image
@front_panel.route('/result')
def get_image():
	try:
		return send_file(str(comm_port) + 'result.jpg', mimetype='image/jpg')
	except:
		return "please use \"shoot!\" command to get a picture"

if __name__ == "__main__":
	front_panel.run(host="0.0.0.0", port=int(web_port))
	
