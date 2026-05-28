import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/core/api/api_endpoints.dart';
import 'package:koyden_sehire/models/product_model.dart';
import 'package:koyden_sehire/services/favorites_repository.dart';

// --- mock ---

class MockApiClient extends Mock implements ApiClient {}

// A fake ProductModel for response parsing.
Map<String, dynamic> _fakeProductJson(String id) => {
      'id': id,
      'farmer_id': 'farmer-001',
      'title': 'Test Ürün $id',
      'description': 'Açıklama',
      'price': 15.0,
      'unit': 'kg',
      'city': 'İzmir',
      'district': 'Bornova',
      'status': 'active',
      'stock_status': 'available',
    };

void main() {
  late MockApiClient mockApi;
  late FavoritesRepository repo;

  setUp(() {
    mockApi = MockApiClient();
    repo = FavoritesRepository(mockApi);
  });

  group('FavoritesRepository', () {
    test('list() returns parsed list of ProductModels', () async {
      final fakeEnvelope = {
        'data': [
          _fakeProductJson('p-001'),
          _fakeProductJson('p-002'),
        ]
      };

      when(() => mockApi.get<List<ProductModel>>(
            ApiEndpoints.customerFavorites,
            parse: any(named: 'parse'),
          )).thenAnswer((inv) async {
        final parse = inv.namedArguments[#parse]
            as List<ProductModel> Function(dynamic);
        return parse(fakeEnvelope);
      });

      final result = await repo.list();

      expect(result, hasLength(2));
      expect(result.first.id, 'p-001');
      expect(result.last.id, 'p-002');
    });

    test('add() calls POST on correct endpoint', () async {
      const productId = 'p-003';

      when(() => mockApi.post<void>(
            ApiEndpoints.customerFavoriteById(productId),
            parse: any(named: 'parse'),
          )).thenAnswer((_) async {});

      await expectLater(repo.add(productId), completes);

      verify(() => mockApi.post<void>(
            ApiEndpoints.customerFavoriteById(productId),
            parse: any(named: 'parse'),
          )).called(1);
    });

    test('remove() calls DELETE on correct endpoint', () async {
      const productId = 'p-004';

      when(() => mockApi.delete<void>(
            ApiEndpoints.customerFavoriteById(productId),
            parse: any(named: 'parse'),
          )).thenAnswer((_) async {});

      await expectLater(repo.remove(productId), completes);

      verify(() => mockApi.delete<void>(
            ApiEndpoints.customerFavoriteById(productId),
            parse: any(named: 'parse'),
          )).called(1);
    });

    test('list() returns empty list when data is null', () async {
      final fakeEnvelope = {'data': null};

      when(() => mockApi.get<List<ProductModel>>(
            ApiEndpoints.customerFavorites,
            parse: any(named: 'parse'),
          )).thenAnswer((inv) async {
        final parse = inv.namedArguments[#parse]
            as List<ProductModel> Function(dynamic);
        return parse(fakeEnvelope);
      });

      final result = await repo.list();
      expect(result, isEmpty);
    });
  });
}
