from flask import Flask, request
import pymysql

try:
    import config
except Exception:
    print ("Please make config.py file and copy contents from dev info file")

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
    cursor = connection.cursor()
    try:
        cursor.execute("INSERT INTO device_registration OUTPUT Inserted.device_id DEFAULT VALUES;")
        return cursor.fetchone()
    except Exception as e:
        print ("Device Registration failed, Error:", e)
        return False

def UpdateGPS(device_id, covid_status, latitude, longitude ):
    global connection
    connection.ping(reconnect=True)
    cursor = connection.cursor()
    query = "INSERT INTO device_registration (device_id, covid_status, latitude, longitude) VALUES (device_id=%s, covid_status=%s, latitude=%s, longitude=%s)"
    try:
        cursor.execute(query,( device_id, covid_status, latitude, longitude))
    except Exception as e:
        print ("Update GPS failed, Error:", e)


    


app.run(debug=True)
