// ignore_for_file: avoid_print

import 'dart:math';
import 'package:get/get.dart';

import 'package:koyden_sehire/core/errors/app_exception.dart';
import 'package:koyden_sehire/services/farmer_product_repository.dart';
import 'package:koyden_sehire/models/product_form_config.dart';
import 'package:koyden_sehire/models/farmer_product_model.dart';

class ProductFormController extends GetxController {
  final FarmerProductRepository _repo;
  ProductFormController(this._repo);

  final Rx<ProductFormData> data = const ProductFormData().obs;
  final RxBool isSubmitting = false.obs;
  final RxBool isUploadingImage = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool saved = false.obs;

  final RxnString productId = RxnString();
  final RxList<String> imageKeys = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    productId.value = _generateUuid();
  }

  void hydrate(FarmerProductModel m) {
    productId.value = m.id;
    imageKeys.value = m.imageUrls.map((url) => _extractKey(url)).toList();
    data.value = ProductFormData(
      title: m.title,
      description: m.description,
      price: m.price.toString(),
      unit: m.unit,
      city: m.city,
      district: m.district,
      village: m.village,
      categoryId: m.categoryId,
      stockStatus: m.stockStatus,
      imageUrls: m.imageUrls,
    );
  }

  void patch(ProductFormData Function(ProductFormData) updater) {
    data.value = updater(data.value);
  }

  void reset() {
    data.value = const ProductFormData();
    productId.value = _generateUuid();
    imageKeys.clear();
    isSubmitting.value = false;
    isUploadingImage.value = false;
    errorMessage.value = null;
    saved.value = false;
  }

  Future<bool> uploadImage(
    List<int> bytes, {
    String filename = 'photo.jpg',
    String contentType = 'image/jpeg',
  }) async {
    isUploadingImage.value = true;
    errorMessage.value = null;
    try {
      final pId = productId.value ?? _generateUuid();
      if (productId.value == null) {
        productId.value = pId;
      }
      final result = await _repo.uploadProductImage(
        pId,
        bytes,
        contentType: contentType,
      );
      data.value = data.value.copyWith(imageUrls: [...data.value.imageUrls, result.url]);
      imageKeys.add(result.key);
      return true;
    } on AppException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e, stack) {
      print('[uploadImage] Error: $e');
      print('[uploadImage] Stack trace: $stack');
      errorMessage.value = 'Görsel yüklenemedi: $e';
      return false;
    } finally {
      isUploadingImage.value = false;
    }
  }

  void removeImage(int index) {
    final list = [...data.value.imageUrls]..removeAt(index);
    data.value = data.value.copyWith(imageUrls: list);
    if (index < imageKeys.length) {
      imageKeys.removeAt(index);
    }
  }

  /// Reorders the uploaded images. Keeps [imageKeys] in lockstep with
  /// [ProductFormData.imageUrls] since the keys (in order, first = cover) are
  /// what gets submitted for a new product.
  void reorderImages(int oldIndex, int newIndex) {
    final urls = [...data.value.imageUrls];
    if (oldIndex < 0 || oldIndex >= urls.length) return;
    // onReorderItem reports newIndex already adjusted for the removed item.

    final url = urls.removeAt(oldIndex);
    urls.insert(newIndex, url);
    data.value = data.value.copyWith(imageUrls: urls);

    if (oldIndex < imageKeys.length) {
      final key = imageKeys.removeAt(oldIndex);
      imageKeys.insert(newIndex.clamp(0, imageKeys.length), key);
    }
  }

  Future<bool> submit({String? editingId}) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      if (editingId == null) {
        final pId = productId.value ?? _generateUuid();
        await _repo.complete(pId, data.value, imageKeys);
      } else {
        await _repo.update(editingId, data.value);
      }
      saved.value = true;
      return true;
    } on AppException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Kaydedilemedi';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  String _generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;
    final hex = values.map((val) => val.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-${hex.sublist(10, 16).join()}';
  }

  String _extractKey(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return url;
    }
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      final index = pathSegments.indexOf('products');
      if (index != -1) {
        return pathSegments.sublist(index).join('/');
      }
      final altIndex = pathSegments.indexOf('product-images');
      if (altIndex != -1) {
        return pathSegments.sublist(altIndex).join('/');
      }
      return uri.path;
    } catch (_) {
      return url;
    }
  }
}
