import 'package:flutter_test/flutter_test.dart';

import 'package:wadai/main.dart';

void main() {
  testWidgets('ホームから定番話題を開ける', (tester) async {
    await tester.pumpWidget(const WadaiApp());
    await tester.pumpAndSettle();

    expect(find.text('WADEE'), findsOneWidget);
    expect(find.text('定番話題'), findsOneWidget);
    expect(find.text('お気に入り'), findsWidgets);

    await tester.tap(find.text('定番話題'));
    await tester.pumpAndSettle();

    expect(find.text('話題を探す'), findsWidgets);
    expect(find.text('最近ハマっていること'), findsOneWidget);
  });
}
