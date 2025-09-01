import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for defaultTargetPlatform
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';

import 'firebase_options.dart'; // from `flutterfire configure`
import 'service.dart'; // background service entry + configure

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Ensure we always have a signed-in user (anonymous driver session)
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  await initializeService(); // background service config
  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driver App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DriverHomePage(),
    );
  }
}

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  bool isTracking = false;

  Future<void> _requestPermissions() async {
    // Check location services enabled
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable Location Services to track.')),
      );
      await Geolocator.openLocationSettings();
      return;
    }

    // Request location permissions
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission denied forever. Open settings.'),
        ),
      );
      await Geolocator.openAppSettings();
      return;
    }

    // Android 13+ notifications
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> _startTracking() async {
    await _requestPermissions();

    // Sign in anonymous if not already
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }

    try {
      final service = FlutterBackgroundService();
      final started = await service.startService(); // returns bool
      if (started) {
        setState(() => isTracking = true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start tracking service.')),
        );
      }
    } catch (e) {
      debugPrint('Error starting service: $e');
    }
  }

  Future<void> _stopTracking() async {
    try {
      final service = FlutterBackgroundService();
      service.invoke("stopService");
      setState(() => isTracking = false);
    } catch (e) {
      debugPrint("Error stopping service: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '—';
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Tracking')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isTracking ? 'Tracking Active' : 'Tracking Stopped',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text('Driver UID: $uid', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isTracking ? _stopTracking : _startTracking,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(isTracking ? 'Stop Tracking' : 'Start Tracking'),
            ),
          ],
        ),
      ),
    );
  }
}
