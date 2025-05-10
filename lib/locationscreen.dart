import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'smashscreen.dart';
import 'dart:async'; // Add this import for StreamSubscription

class LiveDutyScreen extends StatefulWidget {
  const LiveDutyScreen({super.key});

  @override
  State<LiveDutyScreen> createState() => _LiveDutyScreenState();
}

class _LiveDutyScreenState extends State<LiveDutyScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  LatLng? location;
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Socket socket;
  StreamSubscription<Position>? _locationSubscription;
  bool _isReconnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _reconnectDelay = 5000; // milliseconds

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

    _initializeSocket();
    _startLocationUpdates();
  }

  void _initializeSocket() {
    socket = io(
      'https://madadgaar.centralindia.cloudapp.azure.com/api',
      OptionBuilder()
          .disableAutoConnect()
          .setTransports(['websocket'])
          .setExtraHeaders({
            'Authorization':
                'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOjYsInJvbGUiOiJkcml2ZXIiLCJuYW1lIjoiSm9obiBEb2UiLCJhZG1pbiI6dHJ1ZSwiaWF0IjoxNTE2MjM5MDIyfQ.72oAz14YIPftgkhfRN6CTmZXA1xhmiVuN4cfoX92uLE',
          })
          .build(),
    );

    // Set up socket event listeners
    socket.onConnect((_) {
      if (kDebugMode) {
        print('Socket connected');
      }
      // Reset reconnection attempts on successful connection
      _reconnectAttempts = 0;
      _isReconnecting = false;
    });

    socket.onConnectError((data) {
      if (kDebugMode) {
        print('Socket connection error: $data');
      }
      _tryReconnect();
    });

    socket.onDisconnect((_) {
      if (kDebugMode) {
        print('Socket disconnected');
      }
      _tryReconnect();
    });

    socket.on('ping', (data) {
      socket.emit('pong');
      if (kDebugMode) {
        print('Pong emitted');
      }
    });

    // Connect socket
    socket.connect();
  }

  void _tryReconnect() {
    // Only attempt to reconnect if we're not already trying
    if (!_isReconnecting) {
      _isReconnecting = true;
      _reconnectAttempts++;

      // Use a fixed delay of 5 seconds between each retry
      int currentDelay = _reconnectDelay; // 5000 milliseconds

      if (kDebugMode) {
        print(
          'Attempting to reconnect (attempt #$_reconnectAttempts) in ${currentDelay / 1000} seconds',
        );
      }

      // Cancel any existing timer
      _reconnectTimer?.cancel();

      // Set a timer to attempt reconnection with the fixed delay
      _reconnectTimer = Timer(Duration(milliseconds: currentDelay), () {
        if (!socket.connected) {
          if (kDebugMode) {
            print('Reconnecting to socket...');
          }

          // Disconnect first to ensure clean state
          socket.disconnect();

          // Then try to connect again
          socket.connect();

          // Mark that we're no longer in the reconnecting process
          _isReconnecting = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Disconnect the socket when leaving the screen
    socket.disconnect();
    // Cancel any active location stream subscription
    _locationSubscription?.cancel();
    // Cancel reconnect timer if active
    _reconnectTimer?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      // Cancel any existing subscription
      _locationSubscription?.cancel();

      // Create a new subscription
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        final newPosition = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = newPosition;
          location = newPosition;
        });
        
        // Only emit location if socket is connected
        if (socket.connected) {
          socket.emitWithAck(
            'myLocationUpdate',
            {
              'lat': position.latitude,
              'lang': position.longitude,
              'timestamp': DateTime.now().toIso8601String(),
            },
            ack: (data) {
              if (kDebugMode) {
                print('myLocationUpdate emission acknowledged: $data');
              }
            },
          );
        }
        
        _mapController?.animateCamera(CameraUpdate.newLatLng(newPosition));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _currentPosition == null
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
                                    color: Colors.green.withAlpha(
                                      (255 * (1 - (_animation.value / 80)))
                                          .round(),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
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
                        boxShadow: [
                          BoxShadow(blurRadius: 5, color: Colors.black26),
                        ],
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
