import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'smashscreen.dart';
import 'dart:async'; // For Timer, StreamSubscription

class LiveDutyScreen extends StatefulWidget {
  const LiveDutyScreen({super.key});

  @override
  State<LiveDutyScreen> createState() => _LiveDutyScreenState();
}

class _LiveDutyScreenState extends State<LiveDutyScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  // bool _mapReady = false;

  // Controls whether we auto-recenter on location updates
  bool _followUser = true;

  late AnimationController _animationController;
  late Animation<double> _animation;
  late Socket socket;
  StreamSubscription<Position>? _locationSubscription;
  bool _isReconnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _reconnectDelay = 5000; // milliseconds

  // Emergency request related variables
  bool _showEmergencyRequest = false;
  bool _emergencyAccepted = false;

  // Dynamic emergency data from event:
  LatLng? _emergencyLatLng;
  String? _currentEmergencyId;
  String _estimatedDistance = "";
  String _estimatedTime = "";

  // Timer to auto-hide notification after 2 minutes
  Timer? _notificationTimer;

  // Markers and Circles
  final Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();

    // Set up the pulsing animation controller (will drive circle radius)
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();

    // Animate from 0 to 1; we'll scale this to a suitable radius in meters
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Listen to animation ticks: if an emergency location is set, update circle radius
    _animationController.addListener(() {
      if (_emergencyLatLng != null &&
          (_showEmergencyRequest || _emergencyAccepted)) {
        // Choose a max radius in meters for the pulsing effect. Adjust as needed.
        const double maxRadiusMeters = 100.0;
        double fraction = _animation.value; // 0.0 to 1.0
        double radius = fraction * maxRadiusMeters;
        final Circle pulseCircle = Circle(
          circleId: CircleId('emergency_pulse'),
          center: _emergencyLatLng!,
          radius: radius,
          fillColor:
              (_emergencyAccepted
                  ? Colors.red.withAlpha(77)
                  : Colors.orange.withAlpha(77)),
          strokeColor: Colors.transparent,
        );
        setState(() {
          _circles = {pulseCircle};
        });
      }
    });

    _initializeSocket();
    _startLocationUpdates();

    // Temporarily skip custom marker asset loading.
    // We'll use defaultMarkerWithHue instead.
  }

  Future<void> _initializeSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    socket = io(
      'http://10.0.2.2:4000/api',
      OptionBuilder()
          .disableAutoConnect()
          .setTransports(['websocket'])
          .setExtraHeaders({
            'Authorization': 'Bearer $token',
          })
          .build(),
    );

    socket.onConnect((_) {
      if (kDebugMode) {
        print('Socket connected');
      }
      _reconnectAttempts = 0;
      _isReconnecting = false;

      if (_currentPosition != null) {
        if (kDebugMode) {
          print('Sending initial location on socket connect');
        }
        socket.emitWithAck(
          'myLocationUpdate',
          {
            'lat': _currentPosition!.latitude,
            'lang': _currentPosition!.longitude,
            'timestamp': DateTime.now().toIso8601String(),
          },
          ack: (data) {
            if (kDebugMode) {
              print('Initial location update acknowledged: $data');
            }
          },
        );
      } else {
        _getInitialLocation();
      }
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

    // Listen for emergencyAssignment event
    socket.on('emergencyAssignment', (data) {
      if (kDebugMode) {
        print('Received emergencyAssignment: $data');
      }
      _handleEmergencyAssignment(data);
    });

    socket.connect();
  }

  void _tryReconnect() {
    if (!_isReconnecting) {
      _isReconnecting = true;
      _reconnectAttempts++;
      int currentDelay = _reconnectDelay;
      if (kDebugMode) {
        print(
          'Attempting to reconnect (attempt #$_reconnectAttempts) in ${currentDelay / 1000} seconds',
        );
      }
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(milliseconds: currentDelay), () {
        if (!socket.connected) {
          if (kDebugMode) {
            print('Reconnecting to socket...');
          }
          socket.disconnect();
          socket.connect();
          _isReconnecting = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    socket.disconnect();
    _locationSubscription?.cancel();
    _reconnectTimer?.cancel();
    _notificationTimer?.cancel();
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
      _locationSubscription?.cancel();
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        final newPosition = LatLng(position.latitude, position.longitude);

        bool firstFix = _currentPosition == null;
        setState(() {
          _currentPosition = newPosition;
        });

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

        // Recenter only if first fix or if user requested follow (_followUser true)
        if (_mapController != null && (firstFix || _followUser)) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(newPosition, 14),
          );
        }
      });
    }
  }

  void _getInitialLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      );

      final newPosition = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = newPosition;
      });

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
              print('Initial location update acknowledged: $data');
            }
          },
        );
      }

      // Center map if ready
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 14),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting initial location: $e');
      }
    }
  }

  // ===========================
  // Emergency handling methods
  // ===========================

  void _handleEmergencyAssignment(dynamic data) {
    // Expecting data to be a Map with keys: lat, lng, distance, time, emergencyId
    try {
      final parsedLat =
          (data['lat'] is num)
              ? data['lat'].toDouble()
              : double.parse(data['lat'].toString());
      final parsedLng =
          (data['lng'] is num)
              ? data['lng'].toDouble()
              : double.parse(data['lng'].toString());
      final distance = data['distance']?.toString() ?? "";
      final eta = data['time']?.toString() ?? "";
      final id = data['emergencyId']?.toString() ?? "";

      final newLatLng = LatLng(parsedLat, parsedLng);

      // Cancel any existing notification timer
      _notificationTimer?.cancel();

      setState(() {
        _emergencyLatLng = newLatLng;
        _estimatedDistance = distance;
        _estimatedTime = eta;
        _currentEmergencyId = id;
        _showEmergencyRequest = true;
        _emergencyAccepted = false;

        // Update markers: clear previous emergency marker if any, then add new
        _markers.removeWhere((m) => m.markerId.value == 'emergency');
        _markers.add(
          Marker(
            markerId: MarkerId('emergency'),
            position: newLatLng,
            // Use default marker with orange hue
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
          ),
        );

        // Also reset circles; animation listener will add pulsing circle
        _circles.removeWhere((c) => c.circleId.value == 'emergency_pulse');
      });

      // Start timer to auto-hide after 2 minutes if not accepted/rejected
      _notificationTimer = Timer(Duration(minutes: 2), () {
        _onEmergencyTimeout();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing emergencyAssignment data: $e');
      }
    }
  }

  void _onEmergencyTimeout() {
    // If still showing and not accepted, clear UI
    if (!_emergencyAccepted && _showEmergencyRequest) {
      if (kDebugMode) {
        print('Emergency notification timed out, hiding UI.');
      }
      setState(() {
        _showEmergencyRequest = false;
        // Remove marker and circle
        _markers.removeWhere((m) => m.markerId.value == 'emergency');
        _circles.removeWhere((c) => c.circleId.value == 'emergency_pulse');
      });
    }
    _notificationTimer?.cancel();
    _notificationTimer = null;
  }

  void _acceptEmergency() {
    if (_emergencyLatLng == null || _currentEmergencyId == null) {
      return;
    }
    _notificationTimer?.cancel();
    _notificationTimer = null;
    if (kDebugMode) {
      print('Accepting emergency with id $_currentEmergencyId');
    }
    setState(() {
      _showEmergencyRequest = false;
      _emergencyAccepted = true;
      _markers.removeWhere((m) => m.markerId.value == 'emergency');
      _markers.add(
        Marker(
          markerId: MarkerId('emergency'),
          position: _emergencyLatLng!,
          // Use default marker with red hue
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      // Circle remains; its color changes via animation listener using _emergencyAccepted
    });
    socket.emit('emergencyAccepted', {
      'emergencyId': _currentEmergencyId,
      'acceptedAt': DateTime.now().toIso8601String(),
    });
  }

  void _rejectEmergency() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    if (kDebugMode) {
      print('Rejecting emergency id $_currentEmergencyId');
    }
    setState(() {
      _showEmergencyRequest = false;
      _emergencyAccepted = false;
      _markers.removeWhere((m) => m.markerId.value == 'emergency');
      _circles.removeWhere((c) => c.circleId.value == 'emergency_pulse');
      _emergencyLatLng = null;
      _currentEmergencyId = null;
      _estimatedDistance = "";
      _estimatedTime = "";
    });
  }

  // Recenter button handler
  void _onRecenterPressed() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 14),
      );
      setState(() {
        _followUser = true;
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
                  GoogleMap(
                    onMapCreated: (controller) {
                      _mapController = controller;
                      // _mapReady = true;
                      // Center initially if we already have location
                      if (_currentPosition != null) {
                        _mapController!.moveCamera(
                          CameraUpdate.newLatLngZoom(_currentPosition!, 14),
                        );
                      }
                    },
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition!,

                      zoom: 14,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    markers: _markers,
                    circles: _circles,
                    onCameraMoveStarted: () {
                      // User interacted with map -> stop auto-follow
                      if (_followUser) {
                        setState(() {
                          _followUser = false;
                        });
                      }
                    },
                    // You can enable map UI settings as desired:
                    zoomControlsEnabled: false,
                    zoomGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                  ),

                  // Emergency request banner at top
                  if (_showEmergencyRequest)
                    Positioned(
                      top: 40,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(blurRadius: 5, color: Colors.black26),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _estimatedDistance.isNotEmpty
                                    ? 'Emergency request - $_estimatedDistance away'
                                    : 'Emergency request',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  onPressed: _acceptEmergency,
                                ),
                                SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.cancel, color: Colors.red),
                                  onPressed: _rejectEmergency,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Route details overlay (shown when emergency is accepted)
                  if (_emergencyAccepted)
                    Positioned(
                      bottom: 100,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Emergency Route',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                Icon(Icons.warning, color: Colors.red),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      'Distance',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Text(
                                      _estimatedDistance,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      'ETA',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Text(
                                      _estimatedTime,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      'Traffic',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Text(
                                      'Moderate',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Via Main St → First Ave → Hospital Rd',
                                        style: TextStyle(
                                          color: Colors.blue.shade800,
                                        ),
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

                  // Bottom "You are available" or "Responding to Emergency" card
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
                            _emergencyAccepted
                                ? 'Responding to Emergency'
                                : 'You are now available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  _emergencyAccepted
                                      ? Colors.red
                                      : Colors.green,
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
                            child: Text(
                              _emergencyAccepted
                                  ? 'Cancel Response'
                                  : 'Go Offline',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Recenter FAB
                  if (_currentPosition != null)
                    Positioned(
                      bottom: 100,
                      right: 16,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: _onRecenterPressed,
                        tooltip: 'Recenter on my location',
                        child: Icon(Icons.my_location),
                      ),
                    ),
                ],
              ),
    );
  }
}
