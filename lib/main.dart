import 'package:ambulance/utils/api_controller.dart';
import 'package:flutter/material.dart';

import 'loginscreen.dart';
void main() {
  ApiController(
    baseUrl: 'http://10.0.2.2:4000/api', // Replace with your API base URL
  );
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ambulance App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // ✅ Use Scaffold directly here, not another MaterialApp
      home: LoginScreen(),
    );
  }
}
