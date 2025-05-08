import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class UserUI extends StatelessWidget {
  const UserUI({super.key});

  void _callAmbulance() {
    if (kDebugMode) {
      print("Calling ambulance crew...");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image with low opacity
          Opacity(
            opacity: 0.2,
            child: SizedBox.expand(
              child: Image.asset(
                'assets/ambulance.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Gradient overlay and content
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  const Icon(
                    Icons.add_ic_call_outlined,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Emergency Assistance",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Tap the button below to quickly call an ambulance crew in an emergency.",
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _callAmbulance,
                    icon: const Icon(Icons.local_phone),
                    label: const Text(
                      "Call Ambulance",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
