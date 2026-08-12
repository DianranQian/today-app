import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:today_app/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TodayApp());
    await tester.pumpAndSettle();
  }

  testWidgets('框架入口页显示四个子应用', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('What to Do'), findsOneWidget);
    expect(find.text('今天吃什么'), findsOneWidget);
    expect(find.text('今天去哪'), findsOneWidget);
    expect(find.text('今天穿什么'), findsOneWidget);
    expect(find.text('今天联系谁'), findsOneWidget);
    expect(find.text('今天待办'), findsOneWidget);
  });

  testWidgets('点击进入吃什么子应用', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('今天吃什么'));
    await tester.pumpAndSettle();

    // 子应用首页可见（随机按钮 + 底部导航）
    expect(find.text('随机选一个！'), findsOneWidget);
    expect(find.text('菜单'), findsOneWidget);
    expect(find.text('附近'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('主框架有工具/计划 Tab，计划页可切换', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('工具'), findsOneWidget);
    expect(find.text('计划'), findsOneWidget);

    // 切到计划 Tab：条件切换重建页面，显示空状态
    await tester.tap(find.text('计划'));
    await tester.pumpAndSettle();
    expect(find.text('计划清单'), findsOneWidget);
    expect(find.textContaining('还没有计划'), findsOneWidget);
  });

  testWidgets('主页显示打赏入口（Android）', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('What to Do v0.1.0 · ♥ 支持一下'), findsOneWidget);
  });
}
