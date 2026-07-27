import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:koyden_sehire/core/utils/share_helper.dart';

/// share_plus 10.x'in platform kanalı.
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Paylaş butonunu barındıran minimal ekran; ShareHelper'a butonun
  /// context'ini verir (gerçek çağrı yerlerindeki kullanımın aynısı).
  Widget harness(String text) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ShareHelper.shareText(context, text),
              child: const Text('Paylaş'),
            ),
          ),
        ),
      );

  tearDown(() {
    messenger.setMockMethodCallHandler(_shareChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('paylaşım açılırsa panoya kopyalamaz, uyarı göstermez',
      (tester) async {
    final shareCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      shareCalls.add(call);
      return 'dev.fluttercommunity.plus/share/success';
    });
    var clipboardWrites = 0;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboardWrites++;
      return null;
    });

    await tester.pumpWidget(harness('link'));
    await tester.tap(find.text('Paylaş'));
    await tester.pumpAndSettle();

    expect(shareCalls, hasLength(1));
    expect(shareCalls.single.arguments['text'], 'link');
    expect(clipboardWrites, 0);
    expect(find.textContaining('panoya kopyalandı'), findsNothing);
  });

  testWidgets('paylaşım hata verirse panoya kopyalar ve kullanıcıyı uyarır',
      (tester) async {
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      throw PlatformException(code: 'error', message: 'Share failed');
    });
    Object? copied;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = call.arguments['text'];
      }
      return null;
    });

    await tester.pumpWidget(harness('https://koydensehire.netlify.app/x'));
    await tester.tap(find.text('Paylaş'));
    await tester.pumpAndSettle();

    expect(copied, 'https://koydensehire.netlify.app/x');
    expect(find.textContaining('panoya kopyalandı'), findsOneWidget);
  });
}
