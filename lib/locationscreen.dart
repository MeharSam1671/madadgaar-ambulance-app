import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'smashscreen.dart';

class LiveDutyScreen extends StatefulWidget {
  @override
  _LiveDutyScreenState createState() => _LiveDutyScreenState();
}

class _LiveDutyScreenState extends State<LiveDutyScreen> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  LatLng? location;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Set up the pulsing animation
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 80).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _startLocationUpdates();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        final newPosition = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = newPosition;
          location=newPosition;
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLng(newPosition),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: _currentPosition == null
          ? SplashScreen()
          : Stack(
        children: [
          // Google Map without default location dot
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _mapController?.moveCamera(
                CameraUpdate.newLatLngZoom(_currentPosition!, 16),
              );
            },
            initialCameraPosition: CameraPosition(
              target: _currentPosition!,
              zoom: 16,
            ),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            markers: {}, // No markers used
          ),

          // Custom animated green dot at center
          IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (_, __) {
                  return Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: _animation.value,
                          height: _animation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.withOpacity(1 - (_animation.value / 80)),
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom card
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black26)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'You are now available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black,
                    ),
                    child: Text('Go Offline'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
