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

    expect(find.text('今天做什么'), findsOneWidget);
    expect(find.text('今天吃什么'), findsOneWidget);
    expect(find.text('今天去哪'), findsOneWidget);
    expect(find.text('今天穿什么'), findsOneWidget);
    expect(find.text('今天联系谁'), findsOneWidget);
    expect(find.text('赛博乞讨'), findsOneWidget);
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
}
