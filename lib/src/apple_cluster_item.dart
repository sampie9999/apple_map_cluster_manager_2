import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter_cluster_manager_2/flutter_cluster_manager_2.dart';

mixin AppleClusterItem {
  LatLng get location;

  String? _geohash;
  String get geohash => _geohash ??= AppleGeohash.encode(
        latLng: location,
        codeLength: AppleClusterManager.precision,
      );
}
