import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'referrals.dart';
import 'widgets.dart';

class FollowupsScreen extends StatelessWidget {
  const FollowupsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final list = app.engine.followups(app.user);
    final overdue = list.where((f) => f.overdue).toList();
    final open = list.where((f) => f.completedAt == null && !f.overdue).toList();
    final done = list.where((f) => f.completedAt != null).toList();
    Widget group(String title, List<Followup> l) => l.isEmpty
        ? const SizedBox.shrink()
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionTitle('$title (${l.length})'), for (final f in l) _Item(f)]);
    return PageBody(children: [
      Text('Follow-up', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: Gap.xs),
      const Text('A follow-up is created after every recorded visit or missed visit, and is due within 7 days.'),
      if (list.isEmpty)
        const EmptyState(icon: Icons.event_available, title: 'No follow-up tasks', message: 'Tasks appear here after a visit or missed visit is recorded.')
      else ...[
        group('Overdue', overdue),
        group('Due soon', open),
        group('Completed', done),
      ],
    ]);
  }
}

class _Item extends StatelessWidget {
  const _Item(this.f);
  final Followup f;
  @override
  Widget build(BuildContext context) {
    final String state;
    final IconData icon;
    final Sem sem;
    if (f.completedAt != null) {
      state = 'Completed: ${outcomeLabels[f.outcome] ?? 'recorded'}';
      icon = Icons.task_alt;
      sem = Sem.success(context);
    } else if (f.overdue) {
      state = 'Overdue since ${fmtDate(f.due)}';
      icon = Icons.warning_amber_rounded;
      sem = Sem.danger(context);
    } else {
      state = 'Due ${fmtDate(f.due)}';
      icon = Icons.event_repeat;
      sem = Sem.warning(context);
    }
    return Panel(
      onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ReferralDetailScreen(id: f.referralId))),
      semanticLabel: 'Follow-up for ${f.referralId}. $state. Owner: ${f.ownerName}.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(f.referralId, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: Gap.s),
        StatusChip(label: state, icon: icon, sem: sem),
        const SizedBox(height: Gap.s),
        if (f.subjectCode != null) Text('Young person: ${f.subjectCode}'),
        Text('Owner: ${f.ownerName}'),
      ]),
    );
  }
}
