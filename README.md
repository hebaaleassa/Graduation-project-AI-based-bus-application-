# AI Bus Arrival & Seat Booking Application

## Overview

This project is an AI-powered bus arrival prediction application designed to help students and passengers estimate bus arrival times more accurately and manage seat availability.

The system predicts the Estimated Time of Arrival (ETA) of a bus to a selected stop using machine learning. It also includes seat booking functionality, allowing users to reserve seats and track available capacity.

## Features

* Predicts bus arrival time using an AI model
* Shows the current bus location and next stop
* Allows users to select a destination stop
* Calculates ETA from the current bus position to the selected stop
* Displays only the remaining stops in the route
* Seat booking system with available seat tracking
* QR code check-in support
* Real-time countdown for bus arrival
* Weather and traffic-related features included in prediction
* Mobile application interface built with Flutter

## AI Model

The application uses a Random Forest Regression model to predict bus ETA.

The model was trained using bus transportation data combined with weather data. The prediction considers several features such as:

* Bus route
* Direction
* Current stop
* Distance from stop
* Bus latitude and longitude
* Time of day
* Day of week
* Rush hour status
* Weekend status
* Weather conditions
* Temperature
* Rain
* Wind speed
* Cloud cover

The final ETA is calculated by predicting the travel time between route segments and summing the predicted times from the current bus stop to the selected destination stop.

## Datasets Used

Two datasets were used in this project:

1. **New York City Bus Dataset**
   Contains real-time bus information such as route name, current location, next stop, expected arrival time, and distance from stop.

2. **New York City Weather Dataset**
   Contains weather information such as temperature, precipitation, rain, wind speed, and cloud cover.

The datasets were merged based on date and time to create a combined dataset suitable for training the AI model.

## Technologies Used

### Frontend

* Flutter
* Dart

### Backend

* Python
* Flask
* REST API

### Machine Learning

* Scikit-learn
* Pandas
* NumPy
* Random Forest Regressor

### Data Storage

* JSON files
* Local persistence for booking data

## Main API Endpoints

| Endpoint                    | Description                                                   |
| --------------------------- | ------------------------------------------------------------- |
| `/health`                   | Checks if the backend server is running                       |
| `/bus_state/<line>`         | Returns the current state of a specific bus line              |
| `/all_bus_states`           | Returns the current state of all buses                        |
| `/stops/<line>/<direction>` | Returns the stops for a specific route and direction          |
| `/predict_to_stop`          | Predicts ETA from the current bus location to a selected stop |
| `/book_seat/<line>`         | Books a seat on a selected bus line                           |
| `/update_bus`               | Updates the simulated bus state                               |

## How the System Works

1. The user opens the mobile application.
2. The app displays available bus lines.
3. The user selects a bus line.
4. The system retrieves the current bus state from the backend.
5. The user selects a destination stop from the remaining stops.
6. The AI model predicts the ETA to that stop.
7. The app displays the countdown timer.
8. The user can book a seat if seats are available.
9. The QR code can be used for check-in without reducing the seat count twice.

## Project Goal

The goal of this project is to improve the public transportation experience by providing more accurate bus arrival predictions and easier seat management.

Instead of relying only on fixed schedules, the system uses AI to consider real-time route, distance, time, and weather-related factors. This helps users make better decisions and reduces uncertainty while waiting for transportation.

## Future Improvements

* Connect the system to real live bus GPS data
* Improve model accuracy using more real-time traffic data
* Add user authentication
* Add push notifications
* Add admin dashboard for bus operators
* Support more routes and cities
* Deploy the backend API online

## Author

Developed as a graduation project by Heba Aleassa.
