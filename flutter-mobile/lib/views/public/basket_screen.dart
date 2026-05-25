import 'package:flutter/material.dart';

/// Eski sepet ekranı. Artık alt navigasyonda yer almıyor ve route'tan
/// erişilemez; dosya yalnızca derleme uyumluluğu için tutulmaktadır.
class BasketScreen extends StatelessWidget {
  const BasketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.shrink(),
    );
  }
}
