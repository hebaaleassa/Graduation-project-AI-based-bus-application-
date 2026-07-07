// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

import 'bus_details_screen.dart';
import 'qr_scanner_screen.dart';
import 'profile_screen.dart';
import '../api_service.dart';

class _BusDef {
  final String busNumber;
  final String route;
  final BusData busData;

  const _BusDef({
    required this.busNumber,
    required this.route,
    required this.busData,
  });
}

const List<_BusDef> _buses = [
  _BusDef(
    busNumber: "1",
    route: "Zarqa Line",
    busData: BusData(
      publishedLineName: "B8",
      directionRef: "0",
      nextStopPointName: "4 AV/97 ST",
      arrivalProximityText: "approaching",
      distanceFromStop: 300,
      latitude: 40.616104,
      longitude: -74.0311,
    ),
  ),
  _BusDef(
    busNumber: "15",
    route: "Sweileh Line",
    busData: BusData(
      publishedLineName: "B64",
      directionRef: "0",
      nextStopPointName: "STILLWELL AV/W 15 PL",
      arrivalProximityText: "approaching",
      distanceFromStop: 150,
      latitude: 40.5908,
      longitude: -74.15834,
    ),
  ),
  _BusDef(
    busNumber: "3",
    route: "Irbid Line",
    busData: BusData(
      publishedLineName: "B65",
      directionRef: "0",
      nextStopPointName: "SMITH ST/FULTON ST",
      arrivalProximityText: "at stop",
      distanceFromStop: 463,
      latitude: 40.88601,
      longitude: -73.912647,
    ),
  ),
  _BusDef(
    busNumber: "4",
    route: "Jerash Line",
    busData: BusData(
      publishedLineName: "B68",
      directionRef: "0",
      nextStopPointName: "STILLWELL TERMINAL BUS LOOP",
      arrivalProximityText: "< 1 stop away",
      distanceFromStop: 966,
      latitude: 40.668,
      longitude: -73.729348,
    ),
  ),
  _BusDef(
    busNumber: "5",
    route: "Ajloun Line",
    busData: BusData(
      publishedLineName: "Bx10",
      directionRef: "0",
      nextStopPointName: "E 206 ST/BAINBRIDGE AV",
      arrivalProximityText: "at stop",
      distanceFromStop: 11,
      latitude: 40.86813,
      longitude: -73.893032,
    ),
  ),
];

class HomeScreen extends StatelessWidget {
  final String userId;
  final String email;
  const HomeScreen({
    super.key,
    required this.userId,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2A66),
        actions: 
        [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(
                builder: (_) => QRScannerScreen(
                  userId: userId,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Color(0xFFFFC107)),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  userId: userId,
                  email: email,
                ),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          Container
          (
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: Colors.white,
            child: Column(
              children: [
                Image.asset("assets/images/philadelphia_logo.png", height: 65),
                const SizedBox(height: 8),
                const Text(
                  "Bus Tracking System",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A2A66),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Seat Availability & Bus list",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          Container
          (
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.white,
            child: Text(
              "Logged in as: $userId",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ),

          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: _buses.length,
              itemBuilder: (_, i) => BusCard(
                def: _buses[i],
                userId: userId,
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            color: const Color(0xFF0A2A66),
            child: const Text(
              "© 2026 Bus Tracking System - Graduation Project",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class BusCard extends StatefulWidget {
  final _BusDef def;
  final String userId;

  const BusCard({
    super.key,
    required this.def,
    required this.userId,
  });

  @override
  State<BusCard> createState() => _BusCardState();
}

class _BusCardState extends State<BusCard> {
  static const int _capacity = 50;

  late BusData _liveBus;

  int _availableSeats = _capacity;
  int _occupiedSeats = 0;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();

    _liveBus = widget.def.busData;

    _fetchLiveBus();

    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchLiveBus(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveBus() async 
  {
    final liveState = await ApiService.fetchBusState(
      widget.def.busData.publishedLineName,
    );

    if (!mounted) return;

    if (liveState != null) 
    {
      setState(() {
        _liveBus = widget.def.busData.withLiveState(liveState);

        final available = liveState['available_seats'];
        final passengers = liveState['current_passengers'];

        _availableSeats = available is num
            ? available.toInt().clamp(0, _capacity)
            : _availableSeats;

        _occupiedSeats = passengers is num
            ? passengers.toInt().clamp(0, _capacity)
            : _capacity - _availableSeats;
      });
    }
  }

  Future<void> _onSeatBooked() async {
    await _fetchLiveBus();
  }

  Widget _seatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.13),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.def;
    final occupancy = _occupiedSeats / _capacity;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusDetailsScreen(
              busNumber: d.busNumber,
              route: d.route,
              available: _availableSeats,
              busData: _liveBus,
              delayMinutes: null,
              onSeatBooked: _onSeatBooked,
              userId: widget.userId,
            ),
          ),
        );

        if (!mounted) return;
        await _fetchLiveBus();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A2A66),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bus ${d.busNumber}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              d.route,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24, height: 18),
            Row(
              children: [
                _seatChip(
                  icon: Icons.event_seat_rounded,
                  label: "Available",
                  value: "$_availableSeats",
                  color: _availableSeats > 10
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                ),
                const SizedBox(width: 10),
                _seatChip(
                  icon: Icons.people_alt_rounded,
                  label: "Occupied",
                  value: "$_occupiedSeats",
                  color: Colors.amberAccent,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: occupancy,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                  occupancy > 0.8 ? Colors.redAccent : Colors.greenAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}












