import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'widgets.dart';

class RolePicker extends StatelessWidget {
  const RolePicker({super.key, this.onPicked});
  final VoidCallback? onPicked;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Column(children: [
      for (final u in app.engine.users())
        ChoiceTile(
          title: u.role.label,
          subtitle: u.role == Role.provider ? u.name : u.role.blurb,
          selected: app.user.id == u.id,
          onTap: () {
            app.setUser(u);
            onPicked?.call();
          },
        ),
    ]);
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    Widget theme(String label, IconData icon, ThemeMode m) => ChoiceTile(
          title: label,
          subtitle: switch (m) { ThemeMode.light => 'Light background', ThemeMode.dark => 'Dark background, easier on the eyes at night', ThemeMode.system => 'Follow this device' },
          selected: app.themeMode == m,
          onTap: () => app.setTheme(m),
        );
    return PageBody(children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
      const SectionTitle('Appearance'),
      theme('System default', Icons.brightness_auto, ThemeMode.system),
      theme('Light', Icons.light_mode, ThemeMode.light),
      theme('Dark', Icons.dark_mode, ThemeMode.dark),
      const SectionTitle('Text size'),
      for (final (label, v) in const [('Standard', 1.0), ('Large', 1.15), ('Extra large', 1.3)])
        ChoiceTile(title: label, subtitle: '${(v * 100).round()}% of your device text size', selected: app.textScale == v, onTap: () => app.setTextScale(v)),
      const SectionTitle('Motion'),
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.xs),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reduce motion'),
          subtitle: const Text('Switch screens instantly instead of animating.'),
          value: app.reduceMotion,
          onChanged: app.setReduceMotion,
        ),
      ),
      const SectionTitle('Role'),
      const Text('Sign-in is not switched on in this version. Choose the role you want to work as.'),
      const SizedBox(height: Gap.s),
      const RolePicker(),
      const SectionTitle('Privacy and data use'),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Where your information is kept', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: Gap.xs),
          Text('Referral records are kept in a database on this device. Nothing is sent over the internet.'),
          SizedBox(height: Gap.s),
          Text('What to put in a note', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: Gap.xs),
          Text('Keep notes short and practical. Do not enter names, phone numbers, addresses or medical history.'),
          SizedBox(height: Gap.s),
          Text('Who can see a referral', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: Gap.xs),
          Text('The young person, the support worker who created it, and the provider at the receiving facility. Administrators see counts and activity, not personal details.'),
        ]),
      ),
      const SectionTitle('Version'),
      const Panel(child: KV('YouthCare Connect', 'Version $appVersion (build $appBuild)')),
    ]);
  }
}
