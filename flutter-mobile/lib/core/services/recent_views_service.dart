import 'package:get/get.dart';

enum RecentViewType { product, farmer }

class RecentViewEntry {
  final String id;
  final String title;
  final String? imageUrl;
  final RecentViewType type;

  const RecentViewEntry({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.type,
  });
}

class RecentViewsService extends GetxService {
  static const int _maxItems = 10;

  final RxList<RecentViewEntry> items = <RecentViewEntry>[].obs;

  void addProduct({
    required String id,
    required String title,
    String? imageUrl,
  }) {
    _add(RecentViewEntry(
      id: id,
      title: title,
      imageUrl: imageUrl,
      type: RecentViewType.product,
    ));
  }

  void addFarmer({
    required String id,
    required String title,
    String? imageUrl,
  }) {
    _add(RecentViewEntry(
      id: id,
      title: title,
      imageUrl: imageUrl,
      type: RecentViewType.farmer,
    ));
  }

  void _add(RecentViewEntry entry) {
    items.removeWhere((e) => e.id == entry.id && e.type == entry.type);
    items.insert(0, entry);
    if (items.length > _maxItems) items.removeLast();
  }
}
