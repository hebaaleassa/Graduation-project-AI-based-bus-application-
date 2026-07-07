import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api_service.dart';

class QRScannerScreen extends StatefulWidget {
  final String userId;
  final String? expectedLineName;
  final VoidCallback? onCheckInSuccess;

  const QRScannerScreen({
    super.key,
    required this.userId,
    this.expectedLineName,
    this.onCheckInSuccess,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();

  bool _scanned = false;
  bool _checkingIn = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final rawValue = barcode.rawValue ?? barcode.displayValue;

    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() => _scanned = true);
    _controller.stop();

    try {
      final decoded = jsonDecode(rawValue.trim());

      final String busId = decoded['bus_id']?.toString() ?? '';
      final String route = decoded['route']?.toString() ?? '';
      final String checkin = decoded['checkin']?.toString() ?? '';

      if (busId.isEmpty || route.isEmpty || !checkin.startsWith('CHECKIN_')) {
        _showErrorSheet('Invalid bus QR code.');
        return;
      }

      if (widget.expectedLineName != null &&
          widget.expectedLineName!.isNotEmpty &&
          widget.expectedLineName != busId) {
        _showErrorSheet(
          'This QR is for bus $busId, but you selected ${widget.expectedLineName}.',
        );
        return;
      }

      _showCheckinSheet(
        busNumber: busId,
        routeName: route,
      );
    } catch (e) {
      _showErrorSheet('Invalid QR format.');
    }
  }

  Future<void> _confirmCheckIn({
    required String busNumber,
    required String routeName,
  }) async {
    if (_checkingIn) return;

    setState(() {
      _checkingIn = true;
    });

    final result = await ApiService.checkIn(
      busNumber,
      widget.userId,
    );

    if (!mounted) return;

    setState(() {
      _checkingIn = false;
    });

  if (result['success'] == true) {
  widget.onCheckInSuccess?.call();

  // Navigator.pop(context); // close bottom sheet
  Navigator.pop(this.context, true); // back to Bus Details

  return;
}
     else {
      Navigator.pop(context);

      _showErrorSheet(
        result['error']?.toString() ?? 'Check-in failed.',
      );
    }
  }

  void _showCheckinSheet({
    required String busNumber,
    required String routeName,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bus Found!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A2A66),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confirm your check-in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8FC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _infoRow(
                            Icons.directions_bus,
                            'Bus',
                            busNumber,
                          ),
                          const Divider(height: 18),
                          _infoRow(
                            Icons.route,
                            'Route',
                            routeName,
                          ),
                          const Divider(height: 18),
                          _infoRow(
                            Icons.person,
                            'User',
                            widget.userId,
                          ),
                          const Divider(height: 18),
                          _infoRow(
                            Icons.qr_code,
                            'QR Status',
                            'Valid',
                            valueColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _checkingIn
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(
                                color: Color(0xFF0A2A66),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Color(0xFF0A2A66),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _checkingIn
                                ? null
                                : () async {
                                    await _confirmCheckIn(
                                            busNumber: busNumber,
                                            routeName: routeName,
                                          );

                                    await _confirmCheckIn(
                                      busNumber: busNumber,
                                      routeName: routeName,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A2A66),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _checkingIn
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                   'Confirm Check-in',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).then((_) {
      if (!mounted) return;

      setState(() {
        _scanned = false;
        _checkingIn = false;
      });

      _controller.start();
    });
  }

  void _showErrorSheet(String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Invalid QR Code',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);

                      setState(() {
                        _scanned = false;
                        _checkingIn = false;
                      });

                      _controller.start();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2A66),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Bus QR Code'),
        backgroundColor: const Color(0xFF0A2A66),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      _corner(top: 0, left: 0),
                      _corner(top: 0, right: 0, flipX: true),
                      _corner(bottom: 0, left: 0, flipY: true),
                      _corner(
                        bottom: 0,
                        right: 0,
                        flipX: true,
                        flipY: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Point camera at the bus QR code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _corner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool flipX = false,
    bool flipY = false,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(
            flipX ? -1.0 : 1.0,
            flipY ? -1.0 : 1.0,
          ),
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Color(0xFF0A2A66),
                width: 4,
              ),
              left: BorderSide(
                color: Color(0xFF0A2A66),
                width: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF0A2A66),
          size: 20,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF0A2A66),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}