// ignore_for_file: avoid_print, empty_catches

import 'package:dio/dio.dart';

Future<void> testUrl(String baseUrl, String path) async {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      print('baseUrl=$baseUrl path=$path => ${options.uri}');
      handler.reject(DioException(requestOptions: options, message: 'Stop'));
    }
  ));
  try {
    await dio.post(path);
  } catch (e) {}
}

void main() async {
  await testUrl('http://10.0.2.2:8080/api/v1', '/otp/send');
  await testUrl('http://10.0.2.2:8080/api/v1/', '/otp/send');
  await testUrl('http://10.0.2.2:8080/api', '/otp/send');
  await testUrl('http://10.0.2.2:8080', '/api/otp/send');
}
