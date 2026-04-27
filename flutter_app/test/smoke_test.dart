import 'package:banana_flutter_app/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('app boots into the welcome page', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BananaApp()));

    expect(find.text('AI 生图'), findsOneWidget);
    expect(find.text('开始创作'), findsOneWidget);
    expect(find.text('登录 / 注册'), findsOneWidget);
  });
}
