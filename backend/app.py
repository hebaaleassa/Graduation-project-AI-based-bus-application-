from flask import Flask, request, jsonify
from flask_cors import CORS

import os
import json
from datetime import datetime

import sqlite3
import joblib
import pandas as pd
import numpy as np
# import database_setup


app = Flask(__name__)
CORS(app)

ARRIVAL_MODEL_PATH = "bus_arrival_random_forest.pkl"
ROUTE_SEQUENCE_PATH = "route_sequences.json"
# BOOKINGS_FILE = "bookings.json"

BUS_CAPACITY = 50

arrival_model = None

DB_NAME = "bus_app.db"

def load_route_sequences_from_db():
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT route_key, stop_order, stop_name
        FROM route_stops
        ORDER BY route_key, stop_order
    """)

    rows = cursor.fetchall()
    conn.close()

    routes = {}

    for row in rows:
        route_key = row["route_key"]
        if route_key not in routes:
            routes[route_key] = []
        routes[route_key].append(row["stop_name"])

    return routes

def get_db_connection():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id TEXT,
            email TEXT UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS bookings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        line_name TEXT NOT NULL,
        booked INTEGER DEFAULT 0,
        checked_in INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        checked_in_at TIMESTAMP,
        UNIQUE(user_id, line_name)
    )
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS bus_states (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        line_name TEXT UNIQUE NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        next_stop TEXT NOT NULL,
        distance_from_stop REAL NOT NULL,
        proximity_text TEXT NOT NULL,
        current_passengers INTEGER DEFAULT 0,
        available_seats INTEGER DEFAULT 50,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS route_stops (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    route_key TEXT NOT NULL,
    stop_order INTEGER NOT NULL,
    stop_name TEXT NOT NULL,
    UNIQUE(route_key, stop_order)
    )
    """)
    conn.commit()
    conn.close()
    
def seed_users():
    students = [
        ("202210654", "heba@philadelphia.edu.jo"),
        ("202210001", "yara@philadelphia.edu.jo"),
        ("202210028", "sara@philadelphia.edu.jo"),
        ("202210131", "maha@philadelphia.edu.jo")
    ]

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.executemany("""
        INSERT OR IGNORE INTO users (student_id, email)
        VALUES (?, ?)
    """, students)

    conn.commit()
    conn.close()

def seed_bus_states():
    initial_buses = [
        ("B8", 40.616104, -74.0311, "4 AV/97 ST", 555, "< 1 stop away", 0, 50),
        ("B64", 40.5908, -74.15834, "STILLWELL AV/W 15 PL", 1540, "< 1 stop away", 0, 50),
        ("B65", 40.88601, -73.912647, "SMITH ST/FULTON ST", 231, "at stop", 0, 50),
        ("B68", 40.668, -73.729348, "STILLWELL TERMINAL BUS LOOP", 350, "< 1 stop away", 0, 50),
        ("Bx10", 40.86813, -73.893032, "E 206 ST/BAINBRIDGE AV", 11, "at stop", 0, 50),
    ]

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.executemany("""
        INSERT OR IGNORE INTO bus_states (
            line_name,
            lat,
            lng,
            next_stop,
            distance_from_stop,
            proximity_text,
            current_passengers,
            available_seats
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, initial_buses)

    conn.commit()
    conn.close()


def refresh_bus_seats_from_bookings():
    conn = get_db_connection()
    cursor = conn.cursor()

    for line in bus_states:
        cursor.execute("""
            SELECT COUNT(*) AS used
            FROM bookings
            WHERE line_name = ?
            AND (booked = 1 OR checked_in = 1)
        """, (line,))

        row = cursor.fetchone()
        used = row["used"] if row else 0

        available = max(BUS_CAPACITY - used, 0)

        bus_states[line]["current_passengers"] = min(used, BUS_CAPACITY)
        bus_states[line]["available_seats"] = available

        cursor.execute("""
            UPDATE bus_states
            SET current_passengers = ?,
                available_seats = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE line_name = ?
        """, (
            bus_states[line]["current_passengers"],
            available,
            line
        ))

    conn.commit()
    conn.close()


if os.path.exists(ARRIVAL_MODEL_PATH):
    arrival_model = joblib.load(ARRIVAL_MODEL_PATH)
    print("[OK] Arrival model loaded.")
else:
    print("[WARNING] bus_arrival_random_forest.pkl not found.")


route_sequences = {}


prediction_cache = {}

def load_bus_states_from_db():
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT line_name, lat, lng, next_stop, distance_from_stop,
               proximity_text, current_passengers, available_seats
        FROM bus_states
    """)

    rows = cursor.fetchall()
    conn.close()

    states = {}

    for row in rows:
        states[row["line_name"]] = {
            "lat": row["lat"],
            "lng": row["lng"],
            "next_stop": row["next_stop"],
            "distance_from_stop": row["distance_from_stop"],
            "proximity_text": row["proximity_text"],
            "current_passengers": row["current_passengers"],
            "available_seats": row["available_seats"],
        }

    return states

bus_states = {}



def get_route_key(line, direction):
    return f"{str(line)}_{str(direction)}"


def seed_route_stops_from_json():
    if not os.path.exists(ROUTE_SEQUENCE_PATH):
        print("[WARNING] route_sequences.json not found.")
        return

    with open(ROUTE_SEQUENCE_PATH, "r", encoding="utf-8") as f:
        routes = json.load(f)

    conn = get_db_connection()
    cursor = conn.cursor()

    for route_key, stops in routes.items():
        for index, stop in enumerate(stops):
            cursor.execute("""
                INSERT OR IGNORE INTO route_stops (route_key, stop_order, stop_name)
                VALUES (?, ?, ?)
            """, (route_key, index, stop))

    conn.commit()
    conn.close()

def rush_hour_from_hour(hour):
    hour = int(hour)
    return int((7 <= hour <= 9) or (16 <= hour <= 18))


def get_user_id_from_request():
    data = request.get_json(silent=True) or {}
    user_id = str(data.get("user_id", "")).strip()

    if not user_id:
        return None

    return user_id


def make_booking_key(user_id, line_name):
    return f"{user_id}_{line_name}"


def predict_segment_time(
    line,
    direction,
    from_stop,
    to_stop,
    arrival_proximity_text,
    distance_from_stop,
    latitude,
    longitude,
    hour,
    temperature,
    precipitation,
    rain,
    cloudcover,
    windspeed
):
    if arrival_model is None:
        raise Exception("Arrival model is not loaded.")

    hour = int(hour)
    dayofweek = datetime.now().weekday()

    rush_hour = rush_hour_from_hour(hour)
    weekend = int(dayofweek >= 5)
    far_status = int(float(distance_from_stop) > 250)

    rain = float(rain)
    precipitation = float(precipitation)
    windspeed = float(windspeed)
    cloudcover = float(cloudcover)
    temperature = float(temperature)

    heavy_rain = int(rain > 2)

    bad_weather = int(
        rain > 0 or
        precipitation > 0 or
        windspeed > 25
    )

    traffic_score = (
        rush_hour * 2.0 +
        weekend * 0.5 +
        heavy_rain * 2.0 +
        bad_weather * 1.5 +
        rain * 1.5 +
        precipitation * 1.5 +
        windspeed * 0.10 +
        cloudcover * 0.02
    )

    traffic_factor = 1 + (traffic_score / 10)

    adjusted_distance = float(distance_from_stop) * traffic_factor
    distance_log = np.log1p(float(distance_from_stop))

    row = pd.DataFrame([{
        "PublishedLineName": str(line),
        "DirectionRef": str(direction),
        "NextStopPointName": str(from_stop),
        "ArrivalProximityText": str(arrival_proximity_text),

        "AdjustedDistance": float(adjusted_distance),
        "DistanceLog": float(distance_log),

        "hour": int(hour),
        "dayofweek": int(dayofweek),
        "RushHour": int(rush_hour),
        "Weekend": int(weekend),
        "FarStatus": int(far_status),

        "temperature": float(temperature),
        "precipitation": float(precipitation),
        "rain": float(rain),
        "cloudcover": float(cloudcover),
        "windspeed": float(windspeed),

        "HeavyRain": int(heavy_rain),
        "BadWeather": int(bad_weather),
        "TrafficScore": float(traffic_score),
        "TrafficFactor": float(traffic_factor),
    }])

    seconds = float(arrival_model.predict(row)[0])
    # if rush_hour == 1:
    #     seconds = seconds * 1.5

    return max(seconds, 0)



@app.route("/login", methods=["POST"])
def login():
    data = request.get_json()
    email = data.get("email", "").strip().lower()

    if not email:
        return jsonify({
            "success": False,
            "message": "Email is required"
        }), 400

    if not email.endswith("@philadelphia.edu.jo"):
        return jsonify({
            "success": False,
            "message": "Please use your university email"
        }), 401

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, student_id, email
        FROM users
        WHERE email = ?
    """, (email,))

    user = cursor.fetchone()
    conn.close()

    if user is None:
        return jsonify({
            "success": False,
            "message": "This student email is not registered"
        }), 401

    return jsonify({
        "success": True,
        "message": "Login successful",
        "user": {
            "id": user["id"],
            "student_id": user["student_id"],
            "email": user["email"]
        }
    })


@app.route("/bus_state/<line_name>", methods=["GET"])
def bus_state(line_name):
    line_name = str(line_name)

    refresh_bus_seats_from_bookings()

    if line_name not in bus_states:
        return jsonify({"error": f"Unknown line: {line_name}"}), 404

    return jsonify(bus_states[line_name])

@app.route("/book_seat/<line_name>", methods=["POST"])
def book_seat(line_name):
    line_name = str(line_name)

    if line_name not in bus_states:
        return jsonify({
            "success": False,
            "error": f"Unknown line: {line_name}"
        }), 404

    user_id = get_user_id_from_request()

    if not user_id:
        return jsonify({
            "success": False,
            "error": "user_id is required"
        }), 400

    refresh_bus_seats_from_bookings()

    if bus_states[line_name]["available_seats"] <= 0:
        return jsonify({
            "success": False,
            "error": "No seats available",
            "available_seats": 0,
            "current_passengers": bus_states[line_name]["current_passengers"]
        }), 400

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id
        FROM bookings
        WHERE user_id = ?
        AND line_name = ?
    """, (user_id, line_name))

    existing = cursor.fetchone()

    if existing:
        conn.close()
        return jsonify({
            "success": True,
            "message": "Seat already booked for this user",
            "already_booked": True,
            "available_seats": bus_states[line_name]["available_seats"],
            "current_passengers": bus_states[line_name]["current_passengers"]
        })

    cursor.execute("""
        INSERT INTO bookings (user_id, line_name, booked, checked_in)
        VALUES (?, ?, 1, 0)
    """, (user_id, line_name))

    conn.commit()
    conn.close()

    refresh_bus_seats_from_bookings()

    return jsonify({
        "success": True,
        "message": "Seat booked successfully",
        "available_seats": bus_states[line_name]["available_seats"],
        "current_passengers": bus_states[line_name]["current_passengers"]
    })

@app.route("/check_in/<line_name>", methods=["POST"])
def check_in(line_name):
    line_name = str(line_name)

    if line_name not in bus_states:
        return jsonify({
            "success": False,
            "error": f"Unknown line: {line_name}"
        }), 404

    user_id = get_user_id_from_request()

    if not user_id:
        return jsonify({
            "success": False,
            "error": "user_id is required"
        }), 400

    refresh_bus_seats_from_bookings()

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, checked_in
        FROM bookings
        WHERE user_id = ?
        AND line_name = ?
    """, (user_id, line_name))

    booking = cursor.fetchone()

    if booking:
        if booking["checked_in"] == 1:
            conn.close()
            return jsonify({
                "success": True,
                "message": "User already checked in",
                "already_checked_in": True,
                "available_seats": bus_states[line_name]["available_seats"],
                "current_passengers": bus_states[line_name]["current_passengers"]
            })

        cursor.execute("""
            UPDATE bookings
            SET checked_in = 1,
                checked_in_at = CURRENT_TIMESTAMP
            WHERE id = ?
        """, (booking["id"],))

        conn.commit()
        conn.close()

        refresh_bus_seats_from_bookings()

        return jsonify({
            "success": True,
            "message": "Checked in using existing booking. Seat count did not decrease again.",
            "available_seats": bus_states[line_name]["available_seats"],
            "current_passengers": bus_states[line_name]["current_passengers"]
        })

    if bus_states[line_name]["available_seats"] <= 0:
        conn.close()
        return jsonify({
            "success": False,
            "error": "No seats available",
            "available_seats": 0,
            "current_passengers": bus_states[line_name]["current_passengers"]
        }), 400

    cursor.execute("""
        INSERT INTO bookings (user_id, line_name, booked, checked_in, checked_in_at)
        VALUES (?, ?, 0, 1, CURRENT_TIMESTAMP)
    """, (user_id, line_name))

    conn.commit()
    conn.close()

    refresh_bus_seats_from_bookings()

    return jsonify({
        "success": True,
        "message": "Checked in without previous booking",
        "available_seats": bus_states[line_name]["available_seats"],
        "current_passengers": bus_states[line_name]["current_passengers"]
    })

@app.route("/stops/<line_name>/<direction>", methods=["GET"])
def get_stops(line_name, direction):
    route_key = get_route_key(line_name, direction)

    if route_key not in route_sequences:
        return jsonify({
            "error": "Route not found",
            "route_key": route_key,
            "stops": []
        }), 404

    sequence = route_sequences[route_key]
    state = bus_states.get(str(line_name))

    if state is None:
        return jsonify({
            "error": "Bus state not found",
            "stops": []
        }), 404

    current_stop = state["next_stop"]

    if current_stop not in sequence:
        return jsonify({
            "error": "Current stop not found in route",
            "current_stop": current_stop,
            "stops": []
        }), 400

    current_index = sequence.index(current_stop)
    remaining_stops = sequence[current_index:]

    return jsonify({
        "line": line_name,
        "direction": direction,
        "current_stop": current_stop,
        "stops": remaining_stops
    })


@app.route("/predict_to_stop", methods=["POST"])
def predict_to_stop():
    data = request.get_json(force=True)

    required = [
        "PublishedLineName",
        "DirectionRef",
        "current_stop",
        "destination_stop",
        "hour",
        "ArrivalProximityText",
        "DistanceFromStop",
        "latitude",
        "longitude",
        "temperature",
        "precipitation",
        "rain",
        "cloudcover",
        "windspeed"
    ]

    missing = [field for field in required if field not in data]

    if missing:
        return jsonify({
            "success": False,
            "error": "Missing required fields",
            "missing": missing
        }), 400

    try:
        now = datetime.now()

        line = str(data["PublishedLineName"])
        direction = str(data["DirectionRef"])
        current_stop = str(data["current_stop"])
        destination_stop = str(data["destination_stop"])

        hour = int(data["hour"])

        arrival_proximity_text = str(data["ArrivalProximityText"])
        distance_from_stop = float(data["DistanceFromStop"])
        latitude = float(data["latitude"])
        longitude = float(data["longitude"])

        temperature = float(data["temperature"])
        precipitation = float(data["precipitation"])
        rain = float(data["rain"])
        cloudcover = float(data["cloudcover"])
        windspeed = float(data["windspeed"])

        next_bus = bool(data.get("next_bus", False))

        if next_bus:
            distance_from_stop = 1500
            arrival_proximity_text = "< 1 stop away"

        route_key = get_route_key(line, direction)

        if route_key not in route_sequences:
            return jsonify({
                "success": False,
                "error": "Route not found",
                "route_key": route_key
            }), 404

        sequence = route_sequences[route_key]

        if current_stop not in sequence:
            return jsonify({
                "success": False,
                "error": "Current stop not found in route",
                "current_stop": current_stop
            }), 400

        if destination_stop not in sequence:
            return jsonify({
                "success": False,
                "error": "Destination stop not found in route",
                "destination_stop": destination_stop
            }), 400

        current_index = sequence.index(current_stop)
        destination_index = sequence.index(destination_stop)

        if destination_index < current_index:
            return jsonify({
                "success": False,
                "error": "Destination is behind the bus"
            }), 400

        cache_type = "next_bus" if next_bus else "current_bus"
        cache_key = f"{cache_type}_{line}_{direction}_{current_stop}_{destination_stop}"

        if cache_key in prediction_cache:
            cached = prediction_cache[cache_key]
            elapsed_seconds = (now - cached["created_at"]).total_seconds()
            remaining_seconds = cached["total_seconds"] - elapsed_seconds

            if remaining_seconds > 0:
                return jsonify({
                    "success": True,
                    "from_stop": current_stop,
                    "destination_stop": destination_stop,
                    "segments_count": cached["segments_count"],
                    "predicted_eta_seconds": round(remaining_seconds, 1),
                    "predicted_eta_minutes": round(remaining_seconds / 60, 2),
                    "travel_eta_minutes": round(remaining_seconds / 60, 2),
                    "rush_hour": rush_hour_from_hour(hour),
                    "cached": True,
                    "next_bus": next_bus,
                    "segments": cached["segments"]
                })

            del prediction_cache[cache_key]

        total_seconds = 0
        segments = []

        if destination_index == current_index:
            total_seconds = predict_segment_time(
                line=line,
                direction=direction,
                from_stop=current_stop,
                to_stop=destination_stop,
                arrival_proximity_text=arrival_proximity_text,
                distance_from_stop=distance_from_stop,
                latitude=latitude,
                longitude=longitude,
                hour=hour,
                temperature=temperature,
                precipitation=precipitation,
                rain=rain,
                cloudcover=cloudcover,
                windspeed=windspeed
            )

            total_seconds = max(total_seconds, 20)

            segments.append({
                "from_stop": current_stop,
                "to_stop": destination_stop,
                "seconds": round(total_seconds, 1),
                "minutes": round(total_seconds / 60, 2)
            })

        else:
            selected_stops = sequence[current_index:destination_index + 1]

            for i in range(len(selected_stops) - 1):
                from_stop = selected_stops[i]
                to_stop = selected_stops[i + 1]

                segment_seconds = predict_segment_time(
                    line=line,
                    direction=direction,
                    from_stop=from_stop,
                    to_stop=to_stop,
                    arrival_proximity_text=arrival_proximity_text,
                    distance_from_stop=distance_from_stop,
                    latitude=latitude,
                    longitude=longitude,
                    hour=hour,
                    temperature=temperature,
                    precipitation=precipitation,
                    rain=rain,
                    cloudcover=cloudcover,
                    windspeed=windspeed
                )

                segment_seconds = max(segment_seconds, 20)
                total_seconds += segment_seconds

                segments.append({
                    "from_stop": from_stop,
                    "to_stop": to_stop,
                    "seconds": round(segment_seconds, 1),
                    "minutes": round(segment_seconds / 60, 2)
                })

                distance_from_stop = 80
                arrival_proximity_text = "approaching"

        prediction_cache[cache_key] = {
            "total_seconds": total_seconds,
            "created_at": now,
            "segments_count": len(segments),
            "segments": segments
        }

        return jsonify({
            "success": True,
            "from_stop": current_stop,
            "destination_stop": destination_stop,
            "segments_count": len(segments),
            "predicted_eta_seconds": round(total_seconds, 1),
            "predicted_eta_minutes": round(total_seconds / 60, 2),
            "travel_eta_minutes": round(total_seconds / 60, 2),
            "rush_hour": rush_hour_from_hour(hour),
            "cached": False,
            "next_bus": next_bus,
            "segments": segments
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


# if __name__ == "__main__":
#     app.run(host="0.0.0.0", port=5000, debug=True)

if __name__ == "__main__":
    init_db()
    seed_users()
    seed_bus_states()
    seed_route_stops_from_json()
    route_sequences = load_route_sequences_from_db()
    bus_states = load_bus_states_from_db()
    refresh_bus_seats_from_bookings()
    app.run(host="0.0.0.0", port=5000, debug=True)
