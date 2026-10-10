import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'about.dart';
import 'admin.dart';
import 'followups.dart';
import 'home.dart';
import 'referrals.dart';
import 'services.dart';
import 'settings.dart';
import 'widgets.dart';

typedef Go = void Function(String key);

class Dest {
  const Dest(this.key, this.label, this.icon, this.selectedIcon, this.builder, {this.primary = true});
  final String key, label;
  final IconData icon, selectedIcon;
  final Widget Function(Go go) builder;
  final bool primary;
}

List<Dest> destinationsFor(Role r) {
  final home = Dest('home', 'Home', Icons.home_outlined, Icons.home, (go) => r == Role.admin ? const AdminOverview() : HomeScreen(go: go));
  final settings = Dest('settings', 'Settings', Icons.settings_outlined, Icons.settings, (go) => const SettingsScreen(), primary: false);
  final about = Dest('about', 'About', Icons.info_outline, Icons.info, (go) => const AboutScreen(), primary: false);
  switch (r) {
    case Role.youth:
      return [
        home,
        Dest('services', 'Find services', Icons.search, Icons.search, (go) => const FindServicesScreen()),
        Dest('referrals', 'My referrals', Icons.assignment_outlined, Icons.assignment, (go) => const ReferralsScreen()),
        settings,
        about,
      ];
    case Role.worker:
      return [
        home,
        Dest('services', 'New request', Icons.add_circle_outline, Icons.add_circle, (go) => const FindServicesScreen()),
        Dest('referrals', 'Referrals', Icons.assignment_outlined, Icons.assignment, (go) => const ReferralsScreen()),
        Dest('followups', 'Follow-up', Icons.event_repeat, Icons.event_repeat, (go) => const FollowupsScreen()),
        settings,
        about,
      ];
    case Role.provider:
      return [
        home,
        Dest('referrals', 'Inbox', Icons.inbox_outlined, Icons.inbox, (go) => const ReferralsScreen()),
        Dest('followups', 'Follow-up', Icons.event_repeat, Icons.event_repeat, (go) => const FollowupsScreen()),
        settings,
        about,
      ];
    case Role.admin:
      return [
        home,
        Dest('directory', 'Directory', Icons.domain_outlined, Icons.domain, (go) => const AdminDirectory()),
        Dest('referrals', 'Referrals', Icons.assignment_outlined, Icons.assignment, (go) => const ReferralsScreen()),
        Dest('activity', 'Activity', Icons.history, Icons.history, (go) => const AdminActivity()),
        Dest('data', 'Data', Icons.storage_outlined, Icons.storage, (go) => const AdminData(), primary: false),
        settings,
        about,
      ];
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  String? _userId;

  void _goKey(List<Dest> d, String key) {
    final i = d.indexWhere((x) => x.key == key);
    if (i >= 0) setState(() => _i = i);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (_userId != app.user.id) {
      _userId = app.user.id;
      _i = 0;
    }
    final dests = destinationsFor(app.user.role);
    if (_i >= dests.length) _i = 0;
    final d = dests[_i];
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 760;
    final content = KeyedSubtree(key: ValueKey('${app.user.id}-${d.key}'), child: d.builder((k) => _goKey(dests, k)));

    final appBar = AppBar(
      title: Text(d.key == 'home' && app.user.role != Role.admin ? 'YouthCare Connect' : d.key == 'home' ? 'Programme overview' : d.label),
      actions: [
        if (_i != 0) IconButton(tooltip: 'Go to Home', icon: const Icon(Icons.home_outlined), onPressed: () => setState(() => _i = 0)),
        wide
            ? Padding(
                padding: const EdgeInsets.only(right: Gap.s),
                child: TextButton.icon(icon: const Icon(Icons.swap_horiz), label: Text(app.user.role.label), onPressed: () => showRoleSheet(context)),
              )
            : IconButton(tooltip: 'Switch role. Current role: ${app.user.role.label}', icon: const Icon(Icons.swap_horiz), onPressed: () => showRoleSheet(context)),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(children: [
          SafeArea(
            child: NavigationRail(
              extended: width >= 1100,
              selectedIndex: _i,
              labelType: width >= 1100 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() => _i = i),
              leading: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Logo(height: 48)),
              destinations: [
                for (final x in dests) NavigationRailDestination(icon: Icon(x.icon), selectedIcon: Icon(x.selectedIcon), label: Text(x.label)),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
          Expanded(child: content),
        ]),
      );
    }

    final primary = dests.where((x) => x.primary).toList();
    final hasMore = dests.any((x) => !x.primary);
    final cur = dests[_i];
    final selected = cur.primary ? primary.indexOf(cur) : primary.length;
    return Scaffold(
      appBar: appBar,
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) {
          if (i < primary.length) {
            setState(() => _i = dests.indexOf(primary[i]));
          } else {
            _showMore(context, dests);
          }
        },
        destinations: [
          for (final x in primary) NavigationDestination(icon: Icon(x.icon), selectedIcon: Icon(x.selectedIcon), label: x.label),
          if (hasMore) const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }

  void _showMore(BuildContext context, List<Dest> dests) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final x in dests.where((x) => !x.primary))
            ListTile(
              minTileHeight: 56,
              leading: Icon(x.icon),
              title: Text(x.label),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _i = dests.indexOf(x));
              },
            ),
          const SizedBox(height: Gap.s),
        ]),
      ),
    );
  }
}

void showRoleSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text('Switch role', style: Theme.of(ctx).textTheme.titleLarge)),
          const SizedBox(height: Gap.xs),
          const Text('Each role has its own workspace and sees only what that role is permitted to see.'),
          const SizedBox(height: Gap.m),
          RolePicker(onPicked: () => Navigator.pop(ctx)),
        ]),
      ),
    ),
  );
}
