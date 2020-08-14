from flask import Flask, request
import pymysql

try:
    import config
except Exception:
    print("Please make config file and copy contents from dev info file")

app = Flask("CoVID-SWARM")


@app.route("/location/<int:device_id>", methods=['POST', 'GET'])
def location(device_id: int):
    if request.method == 'POST':
        # For JSON Payload
        payload = request.get_json(force=True)
        if payload is None:
            return None

        longitude = payload["longitude"]
        latitude = payload["latitude"]

        # Update location
        return "Longitude: {}, Latitude: {}".format(longitude, latitude)
    elif request.method == 'GET':
        # Get last location
        return "GET"

    return "No Request"


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


app.run(debug=True)
