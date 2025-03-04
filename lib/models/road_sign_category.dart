import 'road_sign.dart';

class RoadSignCategory {
  final String id;
  final String title;
  final String iconUrl;
  final String description;
  final List<RoadSign> signs;

  RoadSignCategory({
    required this.id,
    required this.title,
    required this.iconUrl,
    required this.description,
    required this.signs,
  });
}