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
	
