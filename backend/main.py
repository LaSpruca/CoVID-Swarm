from flask import Flask
import pymysql

try:
    import config
except Exception:
    print ("Please make config file and copy contents from dev info file")

app = Flask("CoVID-SWARM")


@app.route("/location/<int:device_id>", methods=["POST"])
def update_location(device_id: int):
    return "Not Implemented"

connection = pymysql.connect(
        host=config.host,
        user=config.username,
        password=config.password,
        port=config.port,
        database=config.database
        )
def regDevice():
    global connection
    connection.ping(reconnect=True)
    cursor = pymysql.cursors.Cursor(connection)
    
