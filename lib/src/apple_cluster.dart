// ignore_for_file: lines_longer_than_80_chars

import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple_map;
import 'package:flutter/foundation.dart';
import 'package:flutter_cluster_manager_2/flutter_cluster_manager_2.dart';

@immutable
class AppleCluster<T extends AppleClusterItem> {
  const AppleCluster(this.items, this.location);

  AppleCluster.fromItems(this.items)
      : location = apple_map.LatLng(
          items.fold<double>(0, (p, c) => p + c.location.latitude) / items.length,
          items.fold<double>(0, (p, c) => p + c.location.longitude) / items.length,
        );

  //location becomes weighted avarage lat lon
  AppleCluster.fromAppleClusters(AppleCluster<T> cluster1, AppleCluster<T> cluster2)
      : items = cluster1.items.toSet()..addAll(cluster2.items.toSet()),
        location = apple_map.LatLng(
          (cluster1.location.latitude * cluster1.count + cluster2.location.latitude * cluster2.count) /
              (cluster1.count + cluster2.count),
          (cluster1.location.longitude * cluster1.count + cluster2.location.longitude * cluster2.count) /
              (cluster1.count + cluster2.count),
        );

  final apple_map.LatLng location;
  final Iterable<T> items;

  /// Get number of clustered items
  int get count => items.length;

  /// True if cluster is not a single item cluster
  bool get isMultiple => items.length > 1;

  /// Basic cluster marker id
  String getId() {
    return '${location.latitude}_${location.longitude}_$count';
  }

  @override
  String toString() {
    return 'AppleCluster of $count $T (${location.latitude}, ${location.longitude})';
  }

  @override
  bool operator ==(Object other) => other is AppleCluster && items == other.items;

  @override
  int get hashCode => items.hashCode;
}
