# Scrape updated CoVID data from https://www.stats.govt.nz/experimental/covid-19-data-portal
import requests
import pandas as pd
import pymysql
import calendar
from datetime import datetime

try:
    import config
except Exception:
    print("Please make config.py file and copy contents from dev info file")

current_time = datetime.now()

# Link to download .csv file, update link based on current data
url = 'https://www.health.govt.nz/system/files/documents/pages/covid-cases-15aug20.xlsx'


def download_data():
    data = requests.get(url, allow_redirects=True)

    open('covid_cases_{}.xlsx'.format(str(datetime.date(datetime.now()))),
         'wb').write(data.content)


def get_data():
    csv_file = pd.read_excel(r'covid_cases_{}.xlsx'.format(
        str(datetime.date(datetime.now()))), sheet_name="Confirmed", header=None)
    return csv_file.drop([0, 1, 2, 3])


def get_data_as_json():
    data = get_data()
    json = [{
        "date": datetime.now(),
        "location": ""
    }]

    for row in data.iterrows():
        json.append({
            "date": row[1][0],
            "location": row[1][3]
        })

    # Filter past 20 days for active cases
    filtered_json = [
        x for x in json if (datetime.now() - x['date']).days <= 20
    ]

    # Get rid of null data
    filtered_json = [
        x for x in filtered_json if not x['location'] == ""
    ]

    return filtered_json


connection = pymysql.connect(
    host=config.host,
    user=config.username,
    password=config.password,
    port=config.port,
    database=config.database
)


def clear_data():
    connection.ping(reconnect=True)
    cursor = connection.cursor()
    query = "DELETE FROM covid_cases"
    try:
        cursor.execute(
            query)
        connection.commit()
    except Exception as e:
        print("Could not clear CoVID data, Error:", e)


def upload_data():
    json = get_data_as_json()

    connection.ping(reconnect=True)
    cursor = connection.cursor()
    query = "INSERT INTO covid_cases (date, location) VALUES (%s, %s)"
    for object in json:
        try:
            cursor.execute(
                query, (object["date"], object["location"]))
            connection.commit()
        except Exception as e:
            print("Could not update CoVID data, Error:", e)


# Update data in database
print("Downloading latest data as of " + '{}'.format(
    str(datetime.date(datetime.now()))))
download_data()
print("Uploading data into database")
clear_data()
upload_data()
