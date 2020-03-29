#!/usr/bin/python3
from flask import Flask, render_template, request, redirect
import socket
import os
import subprocess
import sys
import time

app = Flask(__name__)
#os.popen("lua main.lua /home/pi/Desktop/conf.lua /dev/video0 8080")

'''
config = sys.argv[1]
device = sys.argv[2]
comm = device.split('/')[-1]
comm_path = '/tmp/' + comm
'''

ctrls = []
data = subprocess.run(["v4l2-ctl", "--list-ctrls"], stdout=subprocess.PIPE).stdout.decode("utf-8")
for line in data.splitlines():
	try:
		line = " ".join(line.split())
		tokens = line.split(" ")
		ctrl = {}
		ctrl["name"] = tokens[0]
		ctrl["type"] = tokens[2].replace("(", "").replace(")", "")
		if ctrl["type"] == "bool":
			ctrl["default"] = tokens[4].split("=")[1]
			ctrl["value"] = tokens[5].split("=")[1]
		elif ctrl["type"] == "menu":
			ctrl["min"] = tokens[4].split("=")[1]
			ctrl["max"] = tokens[5].split("=")[1]
			ctrl["step"] = tokens[6].split("=")[1]
			ctrl["value"] = tokens[7].split("=")[1]
		else:
			ctrl["min"] = tokens[4].split("=")[1]
			ctrl["max"] = tokens[5].split("=")[1]
			ctrl["step"] = tokens[6].split("=")[1]
			ctrl["default"] = tokens[7].split("=")[1]
			ctrl["value"] = tokens[8].split("=")[1]
		ctrls.append(ctrl)
	except:
		continue

def ask_for(client, name):
	client.send(("get " + name + "\n").encode("utf-8"))
	answer = client.recv(1024).decode("utf-8").strip(' ').strip('\n')
	if answer == 'nil' or answer == '':
		return None
	else:
		return answer

	client.send(("set " + name + " " + str(value) +" \n").encode("utf-8"))

def send(client, msg):
	client.send(msg.encode("utf-8"))
	client.recv(1024)

@app.route('/', methods=["GET", "POST"])
def index():

	client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	client.connect(("localhost", 8081))

	if request.method == "POST":
		send(client, "set width " + request.form["width"] +" \n")
		send(client, "set height " + request.form["height"] +" \n")
		send(client, "set fps " + request.form["fps"] +" \n")
		send(client, "set tracesteps " + request.form["tracesteps"] +" \n")
		send(client, "set thresh type " + request.form["thresh_type"] +" \n")
		print(request.form["thresh_type"])
		if request.form["thresh_type"] != "nil":
			lower_table = "{" + request.form["lower1"] + ", " + request.form["lower2"] + ", " + request.form["lower3"] + "}"
			upper_table = "{" + request.form["upper1"] + ", " + request.form["upper2"] + ", " + request.form["upper3"] + "}"
			print("set thresh lower " + lower_table +" \n")
			print("set thresh upper " + upper_table +" \n")
			send(client, "set thresh lower " + lower_table +" \n")
			send(client, "set thresh upper " + upper_table +" \n")

		send(client, ("save\n"))

	conf = {}
	conf["width"] = ask_for(client, "width")
	conf["height"] = ask_for(client, "height")
	conf["fps"] = ask_for(client, "fps")
	conf["trace_steps"] = ask_for(client, "tracesteps")

	conf["threshold_type"] = ask_for(client, "thresh type")
	print(conf["threshold_type"])
	
	conf["lower"] = [ask_for(client, "thresh 1 @ lower"), ask_for(client, "thresh 2 @ lower"), ask_for(client, "thresh 3 @ lower")]
	conf["upper"] = [ask_for(client, "thresh 1 @ upper"), ask_for(client, "thresh 2 @ upper"), ask_for(client, "thresh 3 @ upper")]

	conf["ratio"] = [ask_for(client, "thresh 1 @ ratio"), ask_for(client, "thresh 2 @ ratio")]
	conf["area"] = [ask_for(client, "thresh 1 @ area"), ask_for(client, "thresh 2 @ area")]
	conf["solidity"] = [ask_for(client, "thresh 1 @ solidity"), ask_for(client, "thresh 2 @ solidity")]
	client.close()


	return render_template('index.html', conf=conf, v4l=ctrls) 


if __name__ == '__main__':
	app.run(debug=False)
