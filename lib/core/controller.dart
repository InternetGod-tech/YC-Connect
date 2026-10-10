import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/engine.dart';
import '../domain/models.dart';

const appVersion = '1.0.0';
const appBuild = '1';

class AppController extends ChangeNotifier {
  AppController(this.engine, this._prefs, this.backupDir) {
    themeMode = ThemeMode.values.firstWhere((m) => m.name == _prefs.getString('theme'), orElse: () => ThemeMode.system);
    textScale = _prefs.getDouble('textScale') ?? 1.0;
    reduceMotion = _prefs.getBool('reduceMotion') ?? false;
    _user = _resolveUser(_prefs.getString('user'));
  }

  final Engine engine;
  final SharedPreferences _prefs;
  final String backupDir;
  late ThemeMode themeMode;
  late double textScale;
  late bool reduceMotion;
  late AppUser _user;

  AppUser get user => _user;

  AppUser _resolveUser(String? id) {
    final all = engine.users();
    return all.firstWhere((u) => u.id == id, orElse: () => all.firstWhere((u) => u.role == Role.youth, orElse: () => all.first));
  }

  void setTheme(ThemeMode m) {
    themeMode = m;
    _prefs.setString('theme', m.name);
    notifyListeners();
  }

  void setTextScale(double v) {
    textScale = v;
    _prefs.setDouble('textScale', v);
    notifyListeners();
  }

  void setReduceMotion(bool v) {
    reduceMotion = v;
    _prefs.setBool('reduceMotion', v);
    notifyListeners();
  }

  void setUser(AppUser u) {
    _user = u;
    _prefs.setString('user', u.id);
    notifyListeners();
  }

  /// Call after any change to stored records so every screen re-reads.
  void refresh() => notifyListeners();

  // ---- local data management ----
  String backup() {
    Directory(backupDir).createSync(recursive: true);
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final name = 'youthcare-${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}${two(n.second)}.db';
    final path = '$backupDir${Platform.pathSeparator}$name';
    engine.store.backupTo(path);
    return path;
  }

  List<File> backups() {
    final d = Directory(backupDir);
    if (!d.existsSync()) return [];
    final l = d.listSync().whereType<File>().where((f) => f.path.endsWith('.db')).toList();
    l.sort((a, b) => b.path.compareTo(a.path));
    return l;
  }

  void restore(String path) {
    engine.store.restoreFrom(path);
    _user = _resolveUser(_user.id);
    notifyListeners();
  }

  void resetData() {
    engine.reset();
    _user = _resolveUser(_user.id);
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);
  static AppController of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
