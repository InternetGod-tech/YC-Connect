import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'referrals.dart';
import 'shell.dart';
import 'widgets.dart';

class Stat extends StatelessWidget {
  const Stat(this.value, this.label, {super.key, this.tone});
  final String value, label;
  final Sem? tone;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 160,
        child: Semantics(
          label: '$label: $value',
          child: ExcludeSemantics(
            child: Panel(
              tone: tone,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
                Text(label),
              ]),
            ),
          ),
        ),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.go});
  final Go go;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final u = app.user;
    final e = app.engine;
    final refs = e.listReferrals(u);
    final open = refs.where((r) => !r.isClosed).toList();
    final fus = e.followups(u);
    final overdue = fus.where((f) => f.overdue).length;
    final dueOpen = fus.where((f) => f.completedAt == null).length;
    final needs = u.role == Role.youth ? open.where((r) => e.nextOwner(r) == Owner.youth).toList() : open.where((r) => e.allowedActions(u, r).isNotEmpty).toList();

    final headline = switch (u.role) {
      Role.youth => 'Get to the right service.\nSee it through.',
      Role.worker => 'Keep every handoff moving.',
      Role.provider => 'Your referral inbox.',
      Role.admin => '',
    };
    final sub = switch (u.role) {
      Role.youth => 'Request a referral, see who needs to act next, and keep track until follow-up is done.',
      Role.worker => 'Create requests with a young person, and see which referrals are waiting on someone.',
      Role.provider => 'Respond to referrals for your facility, record visits and complete follow-up.',
      Role.admin => '',
    };

    return PageBody(children: [
      const Align(alignment: Alignment.centerLeft, child: Logo(height: 84)),
      const SizedBox(height: Gap.l),
      Semantics(header: true, child: Text(headline, style: Theme.of(context).textTheme.displaySmall)),
      const SizedBox(height: Gap.s),
      Text(sub, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: Gap.l),
      Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
        if (u.role == Role.youth || u.role == Role.worker)
          FilledButton.icon(icon: const Icon(Icons.search), label: Text(u.role == Role.youth ? 'Find a service' : 'Create a request'), onPressed: () => go('services')),
        if (u.role == Role.provider) FilledButton.icon(icon: const Icon(Icons.inbox), label: const Text('Open inbox'), onPressed: () => go('referrals')),
        OutlinedButton.icon(
            icon: const Icon(Icons.assignment_outlined), label: Text(u.role == Role.provider ? 'All referrals' : 'My referrals'), onPressed: () => go('referrals')),
        if (u.role != Role.youth) OutlinedButton.icon(icon: const Icon(Icons.event_repeat), label: const Text('Follow-up'), onPressed: () => go('followups')),
      ]),
      const SectionTitle('At a glance'),
      Wrap(spacing: Gap.s, runSpacing: 0, children: [
        Stat('${open.length}', u.role == Role.youth ? 'Open referrals' : 'Open referrals'),
        if (u.role != Role.youth) Stat('${needs.length}', 'Need your action', tone: needs.isEmpty ? null : Sem.warning(context)),
        if (u.role != Role.youth) Stat('$dueOpen', 'Follow-ups open'),
        if (u.role != Role.youth) Stat('$overdue', 'Follow-ups overdue', tone: overdue == 0 ? null : Sem.danger(context)),
      ]),
      SectionTitle(u.role == Role.youth ? 'Where things stand' : 'Needs attention'),
      if (u.role == Role.youth ? open.isEmpty : needs.isEmpty)
        EmptyState(
          icon: Icons.check_circle_outline,
          title: u.role == Role.youth ? 'No open referrals' : 'Nothing is waiting on you',
          message: u.role == Role.youth ? 'When you request a service, you will see its progress here.' : 'New referrals and due follow-ups will show up here.',
        )
      else
        for (final r in (u.role == Role.youth ? open : needs).take(3)) ReferralCard(r),
      if (u.role == Role.youth) ...[
        const SectionTitle('How it works'),
        const _Step(Icons.search, '1. Choose a service', 'Pick the kind of support you need and a service that suits you.'),
        const _Step(Icons.send_outlined, '2. Send your request', 'Add only what is needed. You get a reference number straight away.'),
        const _Step(Icons.timeline, '3. Follow the progress', 'See whether it was accepted, who acts next, and how follow-up went.'),
      ],
      const SizedBox(height: Gap.m),
      Notice('In immediate danger or a medical emergency, contact your local emergency services or go to the nearest clinic. This app records referrals and cannot send emergency help.',
          icon: Icons.emergency_outlined, tone: Sem.warning(context)),
    ]);
  }
}

class _Step extends StatelessWidget {
  const _Step(this.icon, this.title, this.body);
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.m),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: Gap.m),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), Text(body)])),
        ]),
      );
}
