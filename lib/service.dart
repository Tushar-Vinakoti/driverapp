import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // Added Firebase Core import

import 'firebase_options.dart'; // from `flutterfire configure`

StreamSubscription<Position>?
    _positionStreamSubscription; // Declared as top-level variable

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Make onStart async
  // Need to initialize Firebase in the background isolate, only if not already initialized
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (service is AndroidServiceInstance) {
    // Stop service listener
    service.on("stopService").listen((event) {
      _positionStreamSubscription?.cancel(); // Cancel the stream subscription
      service.stopSelf();
    });

    // Show persistent notification
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: "Driver Tracking Active",
      content: "Sharing live location with server...",
    );
  }

  // Geolocator settings to obtain position updates
  final LocationSettings locationSettings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
    intervalDuration: const Duration(seconds: 5),
  );

  // Firebase and location setup
  _positionStreamSubscription =
      Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((position) async {
    // Ensure we have a user (anonymous if not already signed in)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseDatabase.instance.ref("drivers/${user.uid}/location");
      await ref.set({
        "latitude": position.latitude,
        "longitude": position.longitude,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      });
    }
  });
}
