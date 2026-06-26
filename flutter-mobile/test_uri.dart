// ignore_for_file: avoid_print

void main() {
  final baseUrl = Uri.parse('http://10.0.2.2:8080/api/v1');
  const path = '/otp/send';
  print(baseUrl.resolve(path).toString());
}
