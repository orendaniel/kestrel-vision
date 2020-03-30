#!/usr/bin/python3
from flask import Flask, render_template, request, redirect
import socket
import os
import subprocess
import sys
import time

app = Flask(__name__)

client = None

config = sys.argv[1]
device = sys.argv[2]
port = sys.argv[3]
#os.popen("lua main.lua " + config + " " + device + " " + port)

def get_ctrls():
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
	return ctrls

def ask_for(name):
	try:
		global client
		client.send(("get " + name + "\n").encode("utf-8"))
		answer = client.recv(1024).decode("utf-8").strip(' ').strip('\n')
		return answer
	except:
		return "nil"

def send(msg):
	global client
	client.send(msg.encode("utf-8"))
	client.recv(1024)

@app.route('/', methods=["GET", "POST"])
def index():
	global client	
	client = None
	client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	client.connect(("localhost", int(port)))
	path = os.path.dirname(os.path.realpath(__file__)) + "/static/" + str(port)
	send("shoot " + path + "\n")

	if request.method == "POST":
		send("set width " + (request.form["width"] or "nil") + " \n")
		send("set height " + (request.form["height"] or "nil") + " \n")
		send("set fps " + (request.form["fps"] or "nil") + " \n")
		send("set tracesteps " + (request.form["tracesteps"] or "nil") + " \n")
		send("set thresh type '" + (request.form["thresh_type"] or "nil") + "' \n")

		if request.form["thresh_type"] != "nil":
			lower_table = "{" + (request.form["lower1"] or "0")+ ", " + (request.form["lower2"] or "0") + ", " + (request.form["lower3"] or "0") + "}"
			upper_table = "{" + (request.form["upper1"] or "255") + ", " + (request.form["upper2"] or "255") + ", " + (request.form["upper3"] or "255") + "}"

			ratio_table = "{" + (request.form["ratio1"] or "nil") + ", " + (request.form["ratio2"] or "nil") + "}"
			area_table = "{" + (request.form["area1"] or "nil") + ", " + (request.form["area2"] or "nil") + "}"
			solidity_table = "{" + (request.form["solidity1"] or "nil") + ", " + (request.form["solidity2"] or "nil") + "}"

			send("set thresh lower " + lower_table +" \n")
			send("set thresh upper " + upper_table +" \n")

			send("set thresh ratio " + ratio_table +" \n")
			send("set thresh area " + area_table +" \n")
			send("set thresh solidity " + solidity_table +" \n")
		else:
			send("set threshold nil\n")

		for k, v in request.form.to_dict().items():
			if "v4l " in k:
				send("set v4l " + k.split("v4l ")[1] + " " + v + "\n")

		send("save\n")
		redirect(request.url)

	conf = {}
	conf["width"] = ask_for("width")
	conf["height"] = ask_for("height")
	conf["fps"] = ask_for("fps")
	conf["trace_steps"] = ask_for("tracesteps")

	conf["threshold_type"] = ask_for("thresh type")

	conf["lower"] = [ask_for("thresh 1 @ lower"), ask_for("thresh 2 @ lower"), ask_for("thresh 3 @ lower")]
	conf["upper"] = [ask_for("thresh 1 @ upper"), ask_for("thresh 2 @ upper"), ask_for("thresh 3 @ upper")]

	conf["ratio"] = [ask_for("thresh 1 @ ratio"), ask_for("thresh 2 @ ratio")]
	conf["area"] = [ask_for("thresh 1 @ area"), ask_for("thresh 2 @ area")]
	conf["solidity"] = [ask_for("thresh 1 @ solidity"), ask_for("thresh 2 @ solidity")]

	client.close()

	return render_template('index.html', conf=conf, v4l=get_ctrls(), port=port) 


if __name__ == '__main__':
	app.run(debug=False)
