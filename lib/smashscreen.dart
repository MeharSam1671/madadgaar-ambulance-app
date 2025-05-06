import 'package:flutter/material.dart';
import 'dart:async';
import 'locationscreen.dart';  // Your next screen

class SmashScreen extends StatefulWidget {
  const SmashScreen({super.key});

  @override
  _SmashScreenState createState() => _SmashScreenState();
}

class _SmashScreenState extends State<SmashScreen> {
  bool isLoading = false; // Track loading state

  @override
  void initState() {
    super.initState();

    // Start the loading and trigger the movement after some time
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        isLoading = false; // Finish loading
      });

      // Navigate to next screen after loading is done
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LocationScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue, // Background color for the screen
      body: Stack(
        children: [
          // The ambulance icon moving from left to right
          AnimatedPositioned(
            duration: const Duration(seconds: 3),
            curve: Curves.easeInOut,  // Smooth transition for movement
            left: isLoading ? -120 : MediaQuery.of(context).size.width - 120,
            bottom: 100, // Adjust the vertical position
            child: Image.asset(
              'assets/images/ambulance.gif',  // Your ambulance GIF
              width: 120,  // Set the size of the GIF
              height: 120,
            ),
          ),
        ],
      ),
    );
  }
}
