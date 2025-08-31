import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'pingmyride_channel',
        initialNotificationTitle: 'PingMyRide',
        initialNotificationContent: 'Tracking bus location…',
      ),
      iosConfiguration: IosConfiguration(),
    );
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  String? busId;
  StreamSubscription<Position>? positionStream;

  service.on("setBusId").listen((event) {
    busId = event?["busId"];
  });

  service.on("stopService").listen((event) async {
    await positionStream?.cancel();
    service.stopSelf();
  });

  // Start listening to location changes
  positionStream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // update when moved at least 10 meters
    ),
  ).listen((Position pos) async {
    if (busId == null) return;

    await FirebaseFirestore.instance.collection("buses").doc(busId).set({
      "latitude": pos.latitude,
      "longitude": pos.longitude,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    });
  });
}
