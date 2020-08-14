from flask import Flask, request, jsonify
import pymysql

try:
    import config
except Exception:
    print("Please make config.py file and copy contents from dev info file")

app = Flask("CoVID-SWARM")


@app.route("/location/<int:device_id>", methods=['POST', 'GET'])
def location(device_id: int):
    if request.method == 'POST':
        # For JSON Payload
        payload = request.get_json(force=True)
        if payload is None:
            return '', 204

        longitude = payload["longitude"]
        latitude = payload["latitude"]
        covid_status = payload["covid_status"]

        if not update_GPS(device_id, covid_status, latitude, longitude):
            return '', 500

        # Update location
        # return "Longitude: {}, Latitude: {}, Covid: {}".format(longitude, latitude, covid_status), 200
        return '', 200
    elif request.method == 'GET':

        # Get last location
        return "GET"

    # No content since didn't supply body
    return '', 204


connection = pymysql.connect(
    host=config.host,
    user=config.username,
    password=config.password,
    port=config.port,
    database=config.database
)


def reg_device():
    global connection
    connection.ping(reconnect=True)
    cursor = connection.cursor()
    try:
        cursor.execute("INSERT INTO device_registration OUTPUT Inserted.device_id DEFAULT VALUES;")
        connection.commit()
        return cursor.fetchone()
    except Exception as e:
        print("Device Registration failed, Error:", e)
        return False


def update_GPS(device_id, covid_status, latitude, longitude):
    print(device_id, covid_status, latitude, longitude)
    global connection
    connection.ping(reconnect=True)
    cursor = connection.cursor()
    query = "INSERT INTO locations (device_id, covid_status, latitude, longitude) VALUES (%s, %s, %s, %s)"
    try:
        cursor.execute(query, (device_id, covid_status, latitude, longitude))
        connection.commit()
        return True
    except Exception as e:
        print("Update GPS failed, Error:", e)
        return False

def get_GPS():
    global connection
    connection.ping(reconnect=True)
    cursor = connection.cursor(dict)
    query = "SELECT covid_status, latitude, longitude FROM locations"
    try:
        cursor.execute(query)
        result = cursor.fetchall()
        print("Result:",result)
        return result
    except Exception as e:
        print("Get GPS failed, Error:", e)
        return False

app.run(debug=True)
