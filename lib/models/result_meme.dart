/// One picture for a result page, as stored in `result_memes/{id}`.
///
/// The picture itself lives in Storage at [storagePath]
/// (`result_memes/<bucket>/<id>.webp`); the document carries what the app
/// needs to choose one and reserve its space.
class ResultMeme {
  const ResultMeme({
    required this.id,
    required this.bucket,
    required this.storagePath,
    required this.width,
    required this.height,
    required this.bytes,
    required this.active,
    required this.order,
  });

  final String id;
  final String bucket;
  final String storagePath;
  final int width;
  final int height;
  final int bytes;
  final bool active;
  final int order;

  factory ResultMeme.fromMap(String id, Map<String, dynamic> data) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    return ResultMeme(
      id: id,
      bucket: data['bucket'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      width: asInt(data['width']),
      height: asInt(data['height']),
      bytes: asInt(data['bytes']),
      active: data['active'] == true,
      order: asInt(data['order']),
    );
  }
}
