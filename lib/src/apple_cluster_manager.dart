// ignore_for_file: lines_longer_than_80_chars

import 'dart:math';
import 'dart:ui';

import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple_map;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum ClusterAlgorithm { geoHash, maxDist }

class MaxDistParams {
  MaxDistParams(this.epsilon);

  final double epsilon;
}

// Interface thay thế cho ClusterItem để sử dụng apple_map.LatLng
abstract class AppleClusterItemInterface {
  apple_map.LatLng get location;
  String get geohash;
}

class AppleCluster<T extends AppleClusterItemInterface> {
  AppleCluster(this.items);

  factory AppleCluster.fromItems(List<T> items) => AppleCluster(items);

  final List<T> items;

  bool get isMultiple => items.length > 1;

  int get count => items.length;

  String getId() => items.map((m) => m.geohash).join();

  apple_map.LatLng get location {
    if (items.length == 1) return items.first.location;

    var x = 0.0;
    var y = 0.0;
    var z = 0.0;

    for (final item in items) {
      final lat = item.location.latitude * pi / 180;
      final lng = item.location.longitude * pi / 180;

      x += cos(lat) * cos(lng);
      y += cos(lat) * sin(lng);
      z += sin(lat);
    }

    final length = items.length;
    x = x / length;
    y = y / length;
    z = z / length;

    final centralLng = atan2(y, x);
    final centralSqrt = sqrt(x * x + y * y);
    final centralLat = atan2(z, centralSqrt);

    return apple_map.LatLng(centralLat * 180 / pi, centralLng * 180 / pi);
  }
}

class AppleClusterManager<T extends AppleClusterItemInterface> {
  AppleClusterManager(
      this._items,
      this.updateAnnotations, {
        Future<apple_map.Annotation> Function(AppleCluster<T>)? annotationBuilder,
        this.levels = const [1, 4.25, 6.75, 8.25, 11.5, 14.5, 16.0, 16.5, 20.0],
        this.extraPercent = 0.5,
        this.maxItemsForMaxDistAlgo = 200,
        this.clusterAlgorithm = ClusterAlgorithm.geoHash,
        this.maxDistParams,
        this.stopClusteringZoom,
        double? devicePixelRatio,
      })  : annotationBuilder = annotationBuilder ?? _basicAnnotationBuilder,
        assert(
        levels.length <= precision,
        'Levels length should be less than or equal to precision',
        ),
        devicePixelRatio = devicePixelRatio ??
            WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

  final Future<apple_map.Annotation> Function(AppleCluster<T>) annotationBuilder;
  final int maxItemsForMaxDistAlgo;
  final void Function(Set<apple_map.Annotation>) updateAnnotations;
  final List<double> levels;
  final double extraPercent;
  final ClusterAlgorithm clusterAlgorithm;
  final MaxDistParams? maxDistParams;
  final double? stopClusteringZoom;
  final double devicePixelRatio;
  static const precision = kIsWeb ? 12 : 20;
  apple_map.AppleMapController? _mapController;
  Iterable<T> get items => _items;
  Iterable<T> _items;
  late double _zoom;
  final double _maxLng = 180 - pow(10, -10.0) as double;

  Future<void> setMapController(apple_map.AppleMapController controller, {bool withUpdate = true}) async {
    _mapController = controller;
    _zoom = (await controller.getZoomLevel())!;
    if (withUpdate) updateMap();
  }

  void updateMap() {
    _updateClusters();
  }

  Future<void> _updateClusters() async {
    final mapAnnotations = await getAnnotations();
    final annotations = Set<apple_map.Annotation>.from(await Future.wait(mapAnnotations.map(annotationBuilder)));
    updateAnnotations(annotations);
  }

  void setItems(List<T> newItems) {
    _items = newItems;
    updateMap();
  }

  void addItem(T newItem) {
    _items = List.from([...items, newItem]);
    updateMap();
  }

  void onCameraMove(apple_map.CameraPosition position, {bool forceUpdate = false}) {
    _zoom = position.zoom;
    if (forceUpdate) {
      updateMap();
    }
  }

  Future<List<AppleCluster<T>>> getAnnotations() async {
    if (_mapController == null) return List.empty();

    final mapBounds = await _mapController!.getVisibleRegion();
    final inflatedBounds = switch (clusterAlgorithm) {
      ClusterAlgorithm.geoHash => _inflateBounds(mapBounds),
      _ => mapBounds,
    };

    final visibleItems = items.where((i) => inflatedBounds.contains(i.location)).toList();

    if (stopClusteringZoom != null && _zoom >= stopClusteringZoom!) {
      return visibleItems.map((i) => AppleCluster<T>.fromItems([i])).toList();
    }

    List<AppleCluster<T>> annotations;

    if (clusterAlgorithm == ClusterAlgorithm.geoHash || visibleItems.length >= maxItemsForMaxDistAlgo) {
      final level = _findLevel(levels);
      annotations = _computeClusters(visibleItems, List.empty(growable: true), level: level);
    } else {
      annotations = _computeClustersWithMaxDist(visibleItems, _zoom);
    }

    return annotations;
  }

  apple_map.LatLngBounds _inflateBounds(apple_map.LatLngBounds bounds) {
    var lng = 0.0;
    if (bounds.northeast.longitude < bounds.southwest.longitude) {
      lng = extraPercent * ((180.0 - bounds.southwest.longitude) + (bounds.northeast.longitude + 180));
    } else {
      lng = extraPercent * (bounds.northeast.longitude - bounds.southwest.longitude);
    }

    final lat = extraPercent * (bounds.northeast.latitude - bounds.southwest.latitude);

    final eLng = (bounds.northeast.longitude + lng).clamp(-_maxLng, _maxLng);
    final wLng = (bounds.southwest.longitude - lng).clamp(-_maxLng, _maxLng);

    return apple_map.LatLngBounds(
      southwest: apple_map.LatLng(bounds.southwest.latitude - lat, wLng),
      northeast: apple_map.LatLng(bounds.northeast.latitude + lat, lng != 0 ? eLng : _maxLng),
    );
  }

  int _findLevel(List<double> levels) {
    for (var i = levels.length - 1; i >= 0; i--) {
      if (levels[i] <= _zoom) {
        return i + 1;
      }
    }

    return 1;
  }

  int _getZoomLevel(double zoom) {
    for (var i = levels.length - 1; i >= 0; i--) {
      if (levels[i] <= zoom) {
        return levels[i].toInt();
      }
    }

    return 1;
  }

  List<AppleCluster<T>> _computeClustersWithMaxDist(List<T> inputItems, double zoom) {
    // Simplified MaxDist clustering without ScreenCoordinate
    final clusters = <AppleCluster<T>>[];
    final remainingItems = inputItems.toList();
    final epsilon = maxDistParams?.epsilon ?? 20;

    while (remainingItems.isNotEmpty) {
      final item = remainingItems.removeAt(0);
      final clusterItems = [item];

      for (var i = remainingItems.length - 1; i >= 0; i--) {
        final otherItem = remainingItems[i];
        final distance = _calculateDistance(item.location, otherItem.location);
        if (distance < epsilon / pow(2, zoom)) {
          clusterItems.add(otherItem);
          remainingItems.removeAt(i);
        }
      }

      clusters.add(AppleCluster<T>.fromItems(clusterItems));
    }

    return clusters;
  }

  double _calculateDistance(apple_map.LatLng a, apple_map.LatLng b) {
    const earthRadius = 6371000; // meters
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final deltaLat = (b.latitude - a.latitude) * pi / 180;
    final deltaLng = (b.longitude - a.longitude) * pi / 180;

    final sinDeltaLat = sin(deltaLat / 2);
    final sinDeltaLng = sin(deltaLng / 2);
    final aValue = sinDeltaLat * sinDeltaLat +
        cos(lat1) * cos(lat2) * sinDeltaLng * sinDeltaLng;
    final c = 2 * atan2(sqrt(aValue), sqrt(1 - aValue));

    return earthRadius * c;
  }

  List<AppleCluster<T>> _computeClusters(List<T> inputItems, List<AppleCluster<T>> annotationItems, {int level = 5}) {
    if (inputItems.isEmpty) return annotationItems;
    final nextGeohash = inputItems[0].geohash.substring(0, level);

    final items = inputItems.where((p) => p.geohash.substring(0, level) == nextGeohash).toList();

    annotationItems.add(AppleCluster<T>.fromItems(items));

    final newInputList = List<T>.from(inputItems.where((i) => i.geohash.substring(0, level) != nextGeohash));

    return _computeClusters(newInputList, annotationItems, level: level);
  }

  static Future<apple_map.Annotation> Function(AppleCluster) get _basicAnnotationBuilder => (cluster) async {
    return apple_map.Annotation(
      annotationId: apple_map.AnnotationId(cluster.getId()),
      position: cluster.location,
      onTap: () {
        if (kDebugMode) {
          print(cluster);
        }
      },
      icon: await _getBasicClusterBitmap(
        cluster.isMultiple ? 125 : 75,
        text: cluster.isMultiple ? cluster.count.toString() : null,
      ),
    );
  };

  static Future<apple_map.BitmapDescriptor> _getBasicClusterBitmap(int size, {String? text}) async {
    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint1 = Paint()..color = Colors.red;

    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0, paint1);

    if (text != null) {
      final painter = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
          text: text,
          style: TextStyle(fontSize: size / 3, color: Colors.white, fontWeight: FontWeight.normal),
        )
        ..layout();

      painter.paint(
        canvas,
        Offset(size / 2 - painter.width / 2, size / 2 - painter.height / 2),
      );
    }

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ImageByteFormat.png);

    if (data == null) return apple_map.BitmapDescriptor.defaultAnnotation;

    return apple_map.BitmapDescriptor.fromBytes(data.buffer.asUint8List());
  }
}
