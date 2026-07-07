import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../api_service.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
 {
  final _emailController = TextEditingController();

  Future<void> _submit() async {
  final email = _emailController.text.trim().toLowerCase();

  if (email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please enter your email"),
      ),
    );
    return;
  }

  final result = await ApiService.login(email);

  if (result["success"] == true) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          userId: result["user"]["student_id"],
          email: result["user"]["email"]
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result["message"]),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SingleChildScrollView(
        child: Column
        (
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 70, bottom: 30),
              decoration: const BoxDecoration
              (
                color: Color(0xFF0A2A66),
                borderRadius: BorderRadius.only
                (
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/philadelphia_logo.png',
                    height: 70,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bus Tracking System',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Philadelphia University',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // CARD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Login",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A2A66),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // EMAIL
                    const Text("Email",
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A2A66))),
                    const SizedBox(height: 6),

                    TextField(
                      controller: _emailController,
                    //   keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'your@philadelphia.edu.jo',
                        prefixIcon: const Icon(Icons.email_outlined,
                            color: Color(0xFF0A2A66)),
                        filled: true,
                        fillColor: const Color(0xFFF6F8FC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 44),

                    // BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2A66),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
