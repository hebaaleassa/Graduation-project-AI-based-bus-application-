import 'dart:async';
import 'package:flutter/material.dart';
import '../api_service.dart';
import 'qr_scanner_screen.dart';

class BusDetailsScreen extends StatefulWidget {
  final String busNumber;
  final String route;
  final int available;
  final BusData busData;
  final String userId;
  final double? delayMinutes;
  final VoidCallback? onSeatBooked;

  const BusDetailsScreen({
    super.key,
    required this.busNumber,
    required this.route,
    required this.available,
    required this.busData,
    required this.userId,
    this.delayMinutes,
    this.onSeatBooked,
  });

  @override
  State<BusDetailsScreen> createState() => _BusDetailsScreenState();
}

class _BusDetailsScreenState extends State<BusDetailsScreen> {
  static const int capacity = 50;

  late BusData _liveBus;
  late int availableSeats;
  late int occupiedSeats;

  List<String> _stops = [];
  String? _selectedStop;

  bool _loadingStops = true;
  bool _loadingArrival = false;
  bool _trackingNextBus = false;

  double? _displayMinutes;
  String? _arrivalError;

  Timer? _liveBusTimer;
  Timer? _countdownTimer;

  final WeatherData _weather = const WeatherData(
    temperature: 22,
    precipitation: 0,
    rain: 0,
    cloudcover: 40,
    windspeed: 12,
  );

// for bad weather testing
  //  final WeatherData _weather = const WeatherData(
  //   temperature: 16,
  //   precipitation:15,
  //   rain: 15,
  //   cloudcover: 100,
  //   windspeed: 30,
  // );
    


  int h = DateTime.now().hour;

  String _getDelayReason() {
    final bool rainDelay =
        _weather.rain > 2 ||
        _weather.precipitation > 2;

    final bool trafficDelay =
        (h >= 7 && h <= 9) ||
        (h >= 16 && h <= 18);

    if (rainDelay && trafficDelay) {
      return "⚠️ Delay expected due to heavy rain and traffic congestion.";
    }

    if (rainDelay) {
      return "🌧️ Arrival time may be longer due to heavy rain.";
    }

    if (trafficDelay) {
      return "🚗 Heavy traffic detected during rush hour.";
    }

    return "✓ No major delays expected.";
  }


  @override
  void initState() {
    super.initState();

    _liveBus = widget.busData;
    availableSeats = widget.available;
    occupiedSeats = capacity - availableSeats;

    _loadStops();

    _liveBusTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshLiveBus(),
    );
  }

  @override
  void dispose() {
    _liveBusTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshLiveBus() async {
    final state = await ApiService.fetchBusState(_liveBus.publishedLineName);

    if (!mounted || state == null) return;

    setState(() {
      _liveBus = widget.busData.withLiveState(state);

      final available = state['available_seats'];
      final passengers = state['current_passengers'];

      if (available is num) {
        availableSeats = available.toInt().clamp(0, capacity);
      }

      if (passengers is num) {
        occupiedSeats = passengers.toInt().clamp(0, capacity);
      } else {
        occupiedSeats = capacity - availableSeats;
      }
    });
  }

  Future<void> _loadStops() async {
    setState(() {
      _loadingStops = true;
    });

    final stops = await ApiService.fetchStops(
      lineName: _liveBus.publishedLineName,
      directionRef: _liveBus.directionRef,
    );

    if (!mounted) return;

    setState(() {
      _stops = stops;
      _loadingStops = false;
    });
  }

  Future<void> _predictArrivalToStop() async 
  {
    if (_selectedStop == null) return;

    _countdownTimer?.cancel();

    setState(() {
      _loadingArrival = true;
      _displayMinutes = null;
      _arrivalError = null;
      _trackingNextBus = false;
    });

    final result = await ApiService.predictArrivalToStop(
      bus: _liveBus,
      destinationStop: _selectedStop!,
      hour: h,
      weather: _weather,
      nextBus: false,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final minutes = (result['predicted_eta_minutes'] as num).toDouble();

      setState(() {
        _displayMinutes = minutes;
        _loadingArrival = false;
      });

      _startCountdown();
    } else {
      setState(() {
        _arrivalError = result['error']?.toString() ?? 'Prediction failed';
        _loadingArrival = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();

    bool notified30Seconds = false;

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (!mounted || _displayMinutes == null) return;

        setState(() {
          _displayMinutes = _displayMinutes! - (1 / 60);
        });

        if (!notified30Seconds &&
            _displayMinutes! <= 0.5 &&
            _displayMinutes! > 0) {
          notified30Seconds = true;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🚌 Bus will arrive in 30 seconds"),
              backgroundColor: Colors.orange,
            ),
          );
        }

        if (_displayMinutes! <= 0) {
          timer.cancel();

          setState(() {
            _displayMinutes = 0;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _trackingNextBus
                    ? "✅ The next bus has arrived"
                    : "✅ Bus has arrived",
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          if (!_trackingNextBus) {
            await Future.delayed(const Duration(seconds: 2));
            await _predictNextBusAfterArrival();
          }
        }
      },
    );
  }

  Future<void> _predictNextBusAfterArrival() async {
    if (_selectedStop == null) return;

    final result = await ApiService.predictArrivalToStop(
      bus: _liveBus,
      destinationStop: _selectedStop!,
      hour: DateTime.now().hour,
      weather: _weather,
      nextBus: true,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final minutes = (result['predicted_eta_minutes'] as num).toDouble();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "🚌 Another bus is coming in ${minutes.toStringAsFixed(1)} minutes",
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );

      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      setState(() {
        _trackingNextBus = true;
        _displayMinutes = minutes;
      });

      _startCountdown();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['error']?.toString() ??
                "Could not predict the next bus arrival.",
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _bookSeat() async {
    final result = await ApiService.bookSeat(
      _liveBus.publishedLineName,
      widget.userId,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final newAvailable = result['available_seats'];
      final newPassengers = result['current_passengers'];

      setState(() {
        availableSeats = newAvailable is num
            ? newAvailable.toInt().clamp(0, capacity)
            : availableSeats;

        occupiedSeats = newPassengers is num
            ? newPassengers.toInt().clamp(0, capacity)
            : capacity - availableSeats;
      });

      widget.onSeatBooked?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? "Seat booked"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']?.toString() ?? "Booking failed"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatCountdown(double minutes) {
    if (minutes <= 0) {
      return _trackingNextBus ? "Next bus arrived" : "Bus has arrived";
    }

    if (minutes < 1) {
      final seconds = (minutes * 60).round();
      return "Arriving in $seconds seconds";
    }

    final mins = minutes.floor();
    final secs = ((minutes - mins) * 60).round();

    return "Arriving in ${mins}m ${secs.toString().padLeft(2, '0')}s";
  }

  Color _countdownColor(double minutes) {
    if (minutes <= 0) return Colors.green;
    if (minutes <= 3) return Colors.orange;
    return const Color(0xFF0A2A66);
  }

  @override
  Widget build(BuildContext context) {
    final occupancyRate = occupiedSeats / capacity;

    return Scaffold
    (
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2A66),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text("Bus ${widget.busNumber} Details"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column
        (
          children: [
            _headerCard(),
            const SizedBox(height: 14),
            _seatCard(occupancyRate),
            const SizedBox(height: 14),
            _arrivalPredictionCard(),
            const SizedBox(height: 14),
            _seatGrid(),
            const SizedBox(height: 12),
            _actionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2A66),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.route,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Bus ${widget.busNumber}",
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            "Current next stop: ${_liveBus.nextStopPointName}",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            "${_liveBus.distanceFromStop.toStringAsFixed(0)} m • ${_liveBus.arrivalProximityText}",
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _seatCard(double occupancyRate) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Seat Availability",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A2A66),
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: occupancyRate,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              occupancyRate > 0.8 ? Colors.red : const Color(0xFF0A2A66),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Available seats: $availableSeats / $capacity",
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Occupied seats: $occupiedSeats",
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrivalPredictionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Predict Arrival to Your Stop",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A2A66),
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingStops)
            const Center(child: CircularProgressIndicator())
          else if (_stops.isEmpty)
            const Text(
              "No stops found for this route.",
              style: TextStyle(color: Colors.grey),
            )
          else
            DropdownButtonFormField<String>
            (
              value: _selectedStop,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: "Destination stop",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: _stops.map((stop) {
                return DropdownMenuItem(
                  value: stop,
                  child: Text(stop, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                _countdownTimer?.cancel();

                setState(() {
                  _selectedStop = value;
                  _displayMinutes = null;
                  _arrivalError = null;
                  _trackingNextBus = false;
                });
              },
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_loadingArrival || _selectedStop == null)
                  ? null
                  : _predictArrivalToStop,
              icon: _loadingArrival
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.smart_toy_rounded),
              label: const Text("Predict with AI"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2A66),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_arrivalError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _arrivalError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (_displayMinutes != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _countdownColor(_displayMinutes!).withOpacity(0.4),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _trackingNextBus
                          ? "Next bus prediction"
                          : "Current bus prediction",
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatCountdown(_displayMinutes!),
                      style: TextStyle(
                        color: _countdownColor(_displayMinutes!),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Destination: $_selectedStop",
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getDelayReason(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _getDelayReason().startsWith("✓")
                            ? Colors.green
                            : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _seatGrid() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: GridView.builder(
        itemCount: capacity,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 10,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (_, index) {
          final occupied = index < occupiedSeats;

          return Container(
            decoration: BoxDecoration(
              color: occupied ? Colors.blueGrey : Colors.greenAccent.shade400,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.event_seat,
              size: 12,
              color: occupied ? Colors.white54 : Colors.green.shade900,
            ),
          );
        },
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: availableSeats > 0 ? _bookSeat : null,
            icon: const Icon(Icons.person_add),
            label: const Text("Book Seat"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2A66),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final success = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QRScannerScreen(
                    userId: widget.userId,
                    expectedLineName: _liveBus.publishedLineName,
                    onCheckInSuccess: _refreshLiveBus,
                  ),
                ),
              );

              if (success == true) {
                await _refreshLiveBus();
                widget.onSeatBooked?.call();
              }
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text("QR Scan"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0A2A66),
              side: const BorderSide(color: Color(0xFF0A2A66)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}
