
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://your-IP:5000';

  static Future<Map<String, dynamic>?> fetchBusState(String lineName) 
  async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/bus_state/$lineName'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[ApiService] fetchBusState error: $e');
    }

    return null;
  }

  static Future<List<String>> fetchStops({
    required String lineName,
    required String directionRef,
  }) async {
    final response = await http
        .get(Uri.parse('$baseUrl/stops/$lineName/$directionRef'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return List<String>.from(json['stops']);
    }

    return [];
  }

  static Future<Map<String, dynamic>> bookSeat(
    String lineName,
    String userId,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/book_seat/$lineName'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> checkIn(
    String lineName,
    String userId,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/check_in/$lineName'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> predictArrivalToStop({
    required BusData bus,
    required String destinationStop,
    required int hour,
    required WeatherData weather,
    bool nextBus = false,
  }) async {
    final body = {
      'PublishedLineName': bus.publishedLineName,
      'DirectionRef': bus.directionRef,
      'current_stop': bus.nextStopPointName,
      'destination_stop': destinationStop,
      'hour': hour,
      'ArrivalProximityText': bus.arrivalProximityText,
      'DistanceFromStop': bus.distanceFromStop,
      'latitude': bus.latitude,
      'longitude': bus.longitude,
      'temperature': weather.temperature,
      'precipitation': weather.precipitation,
      'rain': weather.rain,
      'cloudcover': weather.cloudcover,
      'windspeed': weather.windspeed,
      'next_bus': nextBus,
    };

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/predict_to_stop'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'predicted_eta_minutes':
              (json['predicted_eta_minutes'] as num).toDouble(),
          'segments': json['segments'],
        };
      }

      return {
        'success': false,
        'error': json['error'] ?? 'Server error',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  static Future<Map<String, dynamic>> login(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
      }),
    );

    return jsonDecode(response.body);
  }
}


class BusData {
  final String publishedLineName;
  final String directionRef;
  final String nextStopPointName;
  final String arrivalProximityText;
  final double distanceFromStop;
  final double latitude;
  final double longitude;


  const BusData({
    required this.publishedLineName,
    required this.directionRef,
    required this.nextStopPointName,
    required this.arrivalProximityText,
    required this.distanceFromStop,
    required this.latitude,
    required this.longitude,
  
  });

  BusData withLiveState(Map<String, dynamic> state) {
    return BusData(
      publishedLineName: publishedLineName,
      directionRef: directionRef,
      nextStopPointName: state['next_stop'] as String,
      arrivalProximityText: state['proximity_text'] as String,
      distanceFromStop: (state['distance_from_stop'] as num).toDouble(),
      latitude: (state['lat'] as num).toDouble(),
      longitude: (state['lng'] as num).toDouble(),
    );
  }
}


class WeatherData {
  final double temperature;
  final double precipitation;
  final double rain;
  final double cloudcover;
  final double windspeed;

  const WeatherData({
    required this.temperature,
    required this.precipitation,
    required this.rain,
    required this.cloudcover,
    required this.windspeed,
  });
}