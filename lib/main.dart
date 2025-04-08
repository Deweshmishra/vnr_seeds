import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Location Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _selectedPoints = [];
  final Set<Polygon> _polygons = {};

  double _totalDistance = 0.0;
  double _area = 0.0;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _checkAndRequestLocation();
  }

  Future<void> _checkAndRequestLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationDialog('Please enable location services to start tracking');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationDialog('Location permissions are denied');
          return;
        } else if (permission == LocationPermission.deniedForever) {
          _showLocationDialog('Location permissions are permanently denied. Please enable them in settings.');
          return;
        }
      }
    } catch (e) {
      print('Error checking/requesting location permission: $e');
      _showLocationDialog('An error occurred while checking location permissions: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Location fetch timed out');
      });

      setState(() {
        _currentPosition = position;
        if (_isTracking) {
          LatLng point = LatLng(position.latitude, position.longitude);
          _selectedPoints.add(point);
          _markers.add(
            Marker(
              markerId: MarkerId(point.toString()),
              position: point,
              infoWindow: InfoWindow(
                title: _selectedPoints.length == 1 ? 'Start Location' : 'Point ${_selectedPoints.length}',
              ),
            ),
          );
        }
      });

      mapController.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    } catch (e) {
      print('Error getting current location: $e');
      _showLocationDialog('Failed to get current location: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _startTracking() async {
    await _checkAndRequestLocation();
    if (_currentPosition == null) {
      await _getCurrentLocation();
    }
    if (_currentPosition == null) return;

    setState(() {
      _isTracking = true;
      _selectedPoints.clear();
      _markers.clear();
      _polylines.clear();
      _totalDistance = 0.0;
      _area = 0.0;
    });
    await _getCurrentLocation();
  }

  Future<void> _addMarker() async {
    if (!_isTracking) return;
    await _getCurrentLocation();
  }

  void _stopTracking() {
    setState(() {
      _isTracking = false;
    });
    _calculateDistanceAndArea();

    if (_selectedPoints.length >= 2) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('path'),
          points: _selectedPoints,
          color: Colors.blue,
          width: 5,
        ),
      );
    }

    if (_selectedPoints.length >= 3) {
      _polygons.add(
        Polygon(
          polygonId: const PolygonId('area'),
          points: _selectedPoints,
          fillColor: Colors.blue.withOpacity(0.2),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      );
    }
  }


  void _calculateDistanceAndArea() {
    if (_selectedPoints.length < 2) {
      _totalDistance = 0.0;
      _area = 0.0;
      return;
    }


    double totalDistance = 0.0;
    for (int i = 0; i < _selectedPoints.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        _selectedPoints[i].latitude,
        _selectedPoints[i].longitude,
        _selectedPoints[i + 1].latitude,
        _selectedPoints[i + 1].longitude,
      );
    }


    double area = 0.0;
    if (_selectedPoints.length >= 3) {
      area = _calculateArea(_selectedPoints);

    }

    setState(() {
      _totalDistance = totalDistance / 1000;
      _area = area / 1000000;
    });
  }

  double _calculateArea(List<LatLng> points) {
    if (points.length < 3) return 0.0;

    const double earthRadius = 6371000; // in meters

    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      LatLng p1 = points[i];
      LatLng p2 = points[(i + 1) % points.length];

      double lat1 = p1.latitude * math.pi / 180;
      double lon1 = p1.longitude * math.pi / 180;
      double lat2 = p2.latitude * math.pi / 180;
      double lon2 = p2.longitude * math.pi / 180;

      area += (lon2 - lon1) * (2 + math.sin(lat1) + math.sin(lat2));
    }

    area = area * earthRadius * earthRadius / 2.0;
    return area.abs(); // in square meters
  }


  void _showLocationDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Issue'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Tracker')),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(target: LatLng(0, 0), zoom: 2),
            markers: _markers,
            polylines: _polylines,
            polygons: _polygons, // ← ADD THIS LINE
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (!_isTracking && (_totalDistance > 0 || _area > 0))
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.white,
                    child: Text(
                      'Total Distance: ${_totalDistance.toStringAsFixed(2)} km\n'
                          'Area: ${_area.toStringAsFixed(2)} sq km\n'
                          'Points Marked: ${_selectedPoints.length}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _isTracking ? null : _startTracking,
                      child: const Text('Start'),
                    ),
                    ElevatedButton(
                      onPressed: _isTracking ? _addMarker : null,
                      child: const Text('Mark Point'),
                    ),
                    ElevatedButton(
                      onPressed: _isTracking ? _stopTracking : null,
                      child: const Text('Stop'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
