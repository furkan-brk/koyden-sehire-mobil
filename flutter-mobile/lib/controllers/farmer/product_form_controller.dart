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

  void hydrate(FarmerProductModel m) {
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
      final url = await _repo.uploadProductImage(
        bytes,
        filename: filename,
        contentType: contentType,
      );
      data.value =
          data.value.copyWith(imageUrls: [...data.value.imageUrls, url]);
      return true;
    } on AppException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Görsel yüklenemedi';
      return false;
    } finally {
      isUploadingImage.value = false;
    }
  }

  void removeImage(int index) {
    final list = [...data.value.imageUrls]..removeAt(index);
    data.value = data.value.copyWith(imageUrls: list);
  }

  Future<bool> submit({String? editingId}) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      if (editingId == null) {
        await _repo.create(data.value);
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
}
