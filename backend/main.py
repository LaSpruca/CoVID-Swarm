from flask import Flask
import pymysql

try:
    import config
except Exception:
    print("Please make config file")

app = Flask("CoVID-SWARM")


@app.route("/location/<int:device_id>", methods=["POST"])
def update_location(device_id: int):
    return "Not Implemented"


def setupDB():
    # SQL code goes here
