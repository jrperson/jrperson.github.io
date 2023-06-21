import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocode;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:logger/logger.dart';

class LocationModel extends ChangeNotifier {
  LatLng? here;
  geocode.Placemark? herePlace;
  StreamSubscription<LocationData>? locationStream;
  bool initialLocationSet = false;

  var logger = Logger(
    printer: PrettyPrinter(methodCount: 0),
  );

  /// Requests access to the device location from the user.
  ///
  /// Initializes the location services and requests location
  /// access from the user if not granged.
  /// Returns if location access was granted.
  Future<bool> requestLocationAccess() async {
    // Request location access from user if not permanently denied or already granted
    var permissionGranted = await getPermissionStatus();
    if (permissionGranted == PermissionStatus.notDetermined) {
      permissionGranted = await requestPermission();
    }

    if (permissionGranted == PermissionStatus.authorizedAlways ||
        permissionGranted == PermissionStatus.authorizedWhenInUse) {
      return true;
    } else {
      // Permission not granted
      return false;
    }
  }

  /// Requests location updates from the platform.
  ///
  /// Listeners will be notified about location changes.
  Future<void> requestLocationUpdates() async {
    var permissionGranted = await requestLocationAccess();
    if (permissionGranted) {
      // Handle future location updates
      locationStream ??= onLocationChanged().listen(_updateLocation);

      // Fetch the current location
      var locationData = await getLocation();
      _updateLocation(locationData);
    } else {
      initialLocationSet = true;
      if (locationStream != null) {
        locationStream?.cancel();
        locationStream = null;
      }
      _removeCurrentLocation();
      notifyListeners();
    }
  }

  /// Updates the current location if new location data is available.
  ///
  /// Additionally updates the current address information to match
  /// the new location.
  void _updateLocation(LocationData locationData) {
    if (locationData.latitude != null && locationData.longitude != null) {
      logger.d(
          'Location here: ${locationData.latitude!}, ${locationData.longitude!}');
      here = LatLng(locationData.latitude!, locationData.longitude!);
      initialLocationSet = true;
      getAddress(here!).then((value) {
        herePlace = value;
        notifyListeners();
      });
    } else {
      logger.e('Received invalid location data: $locationData');
    }
    notifyListeners();
  }

  /// Cancels the listening for location updates.
  void cancelLocationUpdates() {
    if (locationStream != null) {
      locationStream?.cancel();
      locationStream = null;
    }
    _removeCurrentLocation();
    notifyListeners();
  }

  /// Resets the currently stored location and address information
  void _removeCurrentLocation() {
    here = null;
    herePlace = null;
  }

  /// Returns the address for a given geolocation (latitude & longitude).
  ///
  /// Only works on mobile platforms with their local APIs.
  static Future<geocode.Placemark?> getAddress(LatLng? location) async {
    if (location == null) {
      return null;
    }
    double lat = location.latitude;
    double lng = location.longitude;

    try {
      List<geocode.Placemark> placemarks =
          await geocode.placemarkFromCoordinates(lat, lng);
      return placemarks.first;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
