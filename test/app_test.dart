import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youthcare_connect/core/controller.dart';
import 'package:youthcare_connect/data/app_db.dart';
import 'package:youthcare_connect/domain/engine.dart';
import 'package:youthcare_connect/main.dart';

Future<AppController> _controller() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final engine = Engine(AppDb.inMemory(), File('assets/data/directory.json').readAsStringSync())..seed();
  return AppController(engine, prefs, Directory.systemTemp.path);
}

void main() {
  testWidgets('Home is reachable from any screen and screens really change', (t) async {
    final c = await _controller();
    await t.pumpWidget(YouthCareApp(c));
    await t.pumpAndSettle();
    expect(find.textContaining('Get to the right service'), findsOneWidget);

    await t.tap(find.text('Find services').last);
    await t.pumpAndSettle();
    expect(find.textContaining('Choose the kind of support'), findsOneWidget);
    expect(find.textContaining('Get to the right service'), findsNothing);

    await t.tap(find.byTooltip('Go to Home'));
    await t.pumpAndSettle();
    expect(find.textContaining('Get to the right service'), findsOneWidget);
  });

  testWidgets('category choice updates the service list', (t) async {
    final c = await _controller();
    await t.pumpWidget(YouthCareApp(c));
    await t.tap(find.text('Find services').last);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Substance use support'));
    await t.pumpAndSettle();
    expect(find.text('Mbare Community Health Hub'), findsOneWidget);
    expect(find.text('Harare Youth Counselling Centre'), findsNothing);
  });

  testWidgets('theme choice is applied and saved', (t) async {
    final c = await _controller();
    await t.pumpWidget(YouthCareApp(c));
    await t.tap(find.text('Settings').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Dark'));
    await t.pumpAndSettle();
    expect(c.themeMode, ThemeMode.dark);
    expect(Theme.of(t.element(find.byType(Scaffold).first)).brightness, Brightness.dark);
    expect((await SharedPreferences.getInstance()).getString('theme'), 'dark');
  });

  testWidgets('About page shows founder, credits and logos', (t) async {
    final handle = t.ensureSemantics();
    final c = await _controller();
    await t.pumpWidget(YouthCareApp(c));
    await t.tap(find.text('About').last);
    await t.pumpAndSettle();
    expect(find.text('About YouthCare Connect'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Rarami Raren Mukuni'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.bySemanticsLabel(RegExp('Photograph of Thembinkosi Mhindi')), findsOneWidget);
    handle.dispose();
  });
}
