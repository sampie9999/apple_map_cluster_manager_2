import 'package:apple_maps_cluster_manager_2/google_maps_cluster_manager_2.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart' hide ClusterManager;

mixin ClusterItem {
  LatLng get location;

  String? _geohash;
  String get geohash => _geohash ??= Geohash.encode(
        latLng: location,
        codeLength: ClusterManager.precision,
      );
}
