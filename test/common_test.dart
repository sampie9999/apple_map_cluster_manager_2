// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_cluster_manager_2/src/common.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

void main() {
  group('test get_distance of coordinates', () {
    test('should get dist of between 600m and 800m on call with close coordinates', () {
      const start = LatLng(52.421327, 10.623056);
      const end = LatLng(52.42748887594039, 10.623379056822062);
      final utils = DistUtils();
     
      final dist = utils.getDistanceFromLatLonInKm(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );

      expect(dist >= 0.6 && dist <= 0.8, true);
    });

    test('should get dist of between 75km and 80km on call with wider coordinates', () {
      const start = LatLng(52.45175365359977, 10.679139941065786);
      const end = LatLng(51.7578902763405, 10.74257578002594);
      final utils = DistUtils();
     
      final dist = utils.getDistanceFromLatLonInKm(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );

      expect(dist >= 75 && dist <= 80, true);
    });

    test('should map distance of 77km with zoomLevel to ', () {
      const start = LatLng(52.45175365359977, 10.679139941065786);
      const end = LatLng(51.7578902763405, 10.74257578002594);
      final utils = DistUtils();

      final dist = utils.getLatLonDist(start, end, 16);

      expect(dist >= 75 / 2.387 * 1000 && dist <= 80 / 2.387 * 1000, true);
    });
  });
}
