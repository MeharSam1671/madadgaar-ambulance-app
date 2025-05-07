import 'package:flutter/material.dart';
import 'dart:async';
import 'locationscreen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Alignment _alignment = Alignment.centerLeft;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Start ambulance animation after slight delay
    Timer(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _alignment = Alignment.centerRight;
        });
      }
    });

    // Navigate to LiveDutyScreen after delay, only once
    Timer(Duration(seconds: 5), () {
      if (!_navigated) {
        _navigated = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LiveDutyScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated ambulance movement
          Container(
            height: 150,
            child: AnimatedAlign(
              alignment: _alignment,
              duration: Duration(seconds: 3),
              curve: Curves.easeInOut,
              child: Image.asset(
                'assets/ambulance.gif',
                height: 100,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'MadadGaar',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your Emergency Companion',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 30),
          CircularProgressIndicator(
            color: Colors.red.shade400,
          ),
        ],
      ),
    );
  }
}
