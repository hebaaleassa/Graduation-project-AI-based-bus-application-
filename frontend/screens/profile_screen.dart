import 'package:flutter/material.dart';
import 'login_screen.dart'; // change path if needed

class ProfileScreen extends StatelessWidget {
  // final String role;
  final String userId;
  final String email;

  const ProfileScreen({
    super.key,
    // required this.role,
    required this.userId,
    required this.email,
  });

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2A66),
        foregroundColor: Colors.white,
        title: const Text("Profile"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Color(0xFF0A2A66),
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),

              const SizedBox(height: 16),

              Text(
                userId,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A2A66),
                ),
              ),

              const SizedBox(height: 4),
              const SizedBox(height: 24),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.badge, color: Color(0xFF0A2A66)),
                  title: const Text("User ID"),
                  subtitle: Text(userId),
                ),
              ),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.email, color: Color(0xFF0A2A66)),
                  title: const Text("Email"),
                  subtitle: Text(email),
                ),
              ),

              const Card(
                child: ListTile(
                  leading: Icon(Icons.school, color: Color(0xFF0A2A66)),
                  title: Text("University"),
                  subtitle: Text("Philadelphia University"),
                ),
              ),

              // Card(
              //   child: ListTile(
              //     leading: const Icon(
              //       Icons.directions_bus,
              //       color: Color(0xFF0A2A66),
              //     ),
              //     title: const Text("Bus Access"),
              //     subtitle: Text(
              //       role.toLowerCase() == "student"
              //           ? "Eligible for bus reservations"
              //           : "Administrative access",
              //     ),
              //   ),
              // ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text("Logout"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _logout(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}