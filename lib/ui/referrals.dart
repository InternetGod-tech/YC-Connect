import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../domain/engine.dart';
import '../domain/models.dart';
import 'widgets.dart';

String ownerText(Role viewer, Owner o) {
  switch (o) {
    case Owner.nobody:
      return 'No action needed';
    case Owner.youth:
      return viewer == Role.youth ? 'You' : 'The young person';
    case Owner.worker:
      return viewer == Role.worker ? 'You' : viewer == Role.youth ? 'Your support worker' : 'The support worker';
    case Owner.provider:
      return viewer == Role.provider ? 'You' : 'The service provider';
  }
}

String nextStepText(Role viewer, Referral r) {
  if (viewer == Role.youth) {
    return switch (r.status) {
      'pending' => 'Your request was sent. The service has not answered yet.',
      'accepted' => 'The service accepted your referral. Please go along when they contact you.',
      'rerouted' => 'Your request was passed to another service that fits better. They will look at it next.',
      'attended' => 'Your visit was recorded. A follow-up check-in is being set up.',
      'follow_up_due' => 'A follow-up check-in is due. Someone will be in touch to see how things went.',
      'completed' => 'This referral is closed. You can start a new request any time.',
      _ => 'This service could not take your request. You can choose another service from Find services.',
    };
  }
  return switch (r.status) {
    'pending' => 'Waiting for the service provider to accept, pass on or decline.',
    'accepted' => 'Accepted. Record attendance once the young person has been seen.',
    'rerouted' => 'Passed on. The new facility needs to accept, pass on or decline.',
    'attended' => 'Visit recorded. A follow-up task has been created.',
    'follow_up_due' => 'Follow-up is due. Complete it with an outcome to close this referral.',
    'completed' => 'Closed. Follow-up outcome recorded.',
    _ => 'Declined. The young person needs help choosing another service.',
  };
}

String eventLabel(String action) => switch (action) {
      'referral.create' => 'Request sent',
      'referral.accept' => 'Accepted by the service',
      'referral.reroute' => 'Passed to another service',
      'referral.decline' => 'Not accepted',
      'referral.attend' => 'Visit recorded',
      'referral.no_show' => 'Missed visit recorded',
      'referral.complete_followup' => 'Follow-up completed',
      'followup.create' => 'Follow-up scheduled',
      'directory.status' => 'Service status changed',
      'directory.add' => 'Service added',
      'directory.edit' => 'Service edited',
      _ => action,
    };

class ReferralsScreen extends StatefulWidget {
  const ReferralsScreen({super.key});
  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  String _filter = 'action';
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final u = app.user;
    final e = app.engine;
    final staff = u.role == Role.provider || u.role == Role.worker;
    final title = switch (u.role) { Role.youth => 'My referrals', Role.worker => 'Referrals you created', Role.provider => 'Referral inbox', Role.admin => 'Referral oversight' };
    final all = e.listReferrals(u);
    bool needs(Referral r) => u.role == Role.youth ? e.nextOwner(r) == Owner.youth : e.allowedActions(u, r).isNotEmpty;
    final filters = <(String, String)>[
      if (u.role != Role.admin) ('action', u.role == Role.youth ? 'Needs me' : 'Needs action'),
      ('open', 'Open'),
      ('closed', 'Closed'),
      ('all', 'All'),
    ];
    if (!filters.any((f) => f.$1 == _filter)) _filter = 'open';
    var list = all.where((r) => switch (_filter) { 'action' => needs(r), 'open' => !r.isClosed, 'closed' => r.isClosed, _ => true }).toList();
    final q = _q.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) => '${r.id} ${r.category} ${r.facilityName} ${r.subjectCode ?? ''}'.toLowerCase().contains(q)).toList();
    }
    return PageBody(children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: Gap.m),
      if (all.length > 4 || u.role == Role.admin)
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.s),
          child: TextField(
            decoration: fieldDeco(staff || u.role == Role.admin ? 'Search by reference, service or facility' : 'Search your referrals').copyWith(prefixIcon: const Icon(Icons.search)),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
      Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
        for (final f in filters)
          ChoiceChip(
            label: Text(f.$2),
            selected: _filter == f.$1,
            onSelected: (_) => setState(() => _filter = f.$1),
          ),
      ]),
      const SizedBox(height: Gap.m),
      if (list.isEmpty)
        EmptyState(
          icon: Icons.assignment_outlined,
          title: all.isEmpty ? 'No referrals yet' : 'Nothing matches this view',
          message: all.isEmpty
              ? (u.role == Role.youth ? 'When you request a service, it will appear here with its progress.' : 'Referrals will appear here as they arrive.')
              : 'Try a different filter or clear your search.',
        )
      else
        for (final r in list) ReferralCard(r),
    ]);
  }
}

class ReferralCard extends StatelessWidget {
  const ReferralCard(this.r, {super.key});
  final Referral r;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final role = app.user.role;
    final owner = ownerText(role, app.engine.nextOwner(r));
    return Panel(
      onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ReferralDetailScreen(id: r.id))),
      semanticLabel: 'Referral ${r.id}, ${r.category}, ${statusLabels[r.status]}. Next action: $owner. Updated ${fmtDate(r.updated)}.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.id, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          const Icon(Icons.chevron_right),
        ]),
        const SizedBox(height: Gap.xs),
        Text('${r.category} · ${r.facilityName}'),
        const SizedBox(height: Gap.s),
        ReferralStatusChip(r.status, statusLabels),
        const SizedBox(height: Gap.s),
        Text('Next action: $owner', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('Updated ${fmtDate(r.updated)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
      ]),
    );
  }
}

class ReferralDetailScreen extends StatelessWidget {
  const ReferralDetailScreen({super.key, required this.id, this.justCreated = false});
  final String id;
  final bool justCreated;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final u = app.user;
    final e = app.engine;
    Referral r;
    try {
      r = e.getReferral(u, id);
    } on DomainError catch (err) {
      return Scaffold(appBar: AppBar(title: const Text('Referral')), body: EmptyState(icon: Icons.lock_outline, title: 'Not available', message: err.message));
    }
    final hist = e.history(u, id);
    final fus = e.followups(u).where((f) => f.referralId == id).toList();
    final actions = e.allowedActions(u, r);
    final owner = ownerText(u.role, e.nextOwner(r));
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Referral')),
      body: PageBody(children: [
        if (justCreated) Notice('Request sent. Keep this reference to check progress: ${r.id}', icon: Icons.check_circle_outline, tone: Sem.success(context)),
        Row(children: [
          Expanded(child: SelectableText(r.id, style: Theme.of(context).textTheme.headlineSmall)),
          IconButton(
            tooltip: 'Copy reference',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: r.id));
              if (context.mounted) snack(context, 'Reference copied');
            },
          ),
        ]),
        const SizedBox(height: Gap.s),
        Align(alignment: Alignment.centerLeft, child: ReferralStatusChip(r.status, statusLabels)),
        const SectionTitle('What happens next'),
        Panel(
          tone: r.isClosed ? null : Sem.info(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Next action: $owner', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: Gap.xs),
            Text(nextStepText(u.role, r)),
          ]),
        ),
        if (actions.isNotEmpty) ...[
          const SectionTitle('Actions'),
          Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
            for (final a in actions)
              (a == actions.first ? FilledButton(onPressed: () => _act(context, r, a), child: Text(actionLabels[a]!)) : OutlinedButton(onPressed: () => _act(context, r, a), child: Text(actionLabels[a]!))),
          ]),
        ],
        const SectionTitle('Details'),
        Panel(
          child: Column(children: [
            KV('Service', r.category),
            KV('Facility', r.facilityName),
            if (u.role != Role.admin) KV('Contact', r.contactPref == 'worker' ? 'Through a support worker' : 'Directly with the young person'),
            if (r.subjectCode != null && u.role != Role.youth) KV('Young person', r.subjectCode!),
            KV('Sent', fmtDateTime(r.created)),
            KV('Last update', fmtDateTime(r.updated)),
            if ((r.note ?? '').isNotEmpty && u.role != Role.youth) KV('Note', r.note!),
          ]),
        ),
        if (fus.isNotEmpty) ...[
          const SectionTitle('Follow-up'),
          for (final f in fus)
            Panel(
              tone: f.overdue ? Sem.danger(context) : null,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.completedAt != null ? 'Completed: ${outcomeLabels[f.outcome] ?? ''}' : f.overdue ? 'Overdue since ${fmtDate(f.due)}' : 'Due ${fmtDate(f.due)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (u.role != Role.youth) Text('Owner: ${f.ownerName}'),
              ]),
            ),
        ],
        const SectionTitle('History'),
        for (var i = 0; i < hist.length; i++) _TimelineRow(hist[i], last: i == hist.length - 1, color: cs.primary),
      ]),
    );
  }

  Future<void> _act(BuildContext context, Referral r, String action) async {
    final app = AppScope.of(context);
    final e = app.engine;
    Map<String, String?>? res;
    switch (action) {
      case 'accept':
      case 'attend':
      case 'no_show':
        final msg = switch (action) {
          'accept' => 'Accept this referral for ${r.category}? The young person will see that it was accepted.',
          'attend' => 'Record that the young person attended? A 7-day follow-up task will be created.',
          _ => 'Record a missed visit? A 7-day follow-up task will be created.',
        };
        if (!await confirm(context, title: actionLabels[action]!, body: msg, action: 'Confirm')) return;
        res = {};
      case 'decline':
        res = await showModalBottomSheet<Map<String, String?>>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _ActionSheet(title: 'Decline referral', help: 'Give a short reason. The young person will see it, so keep it clear and kind.', reasonLabel: 'Reason', submit: 'Decline referral'),
        );
      case 'reroute':
        final options = e.directory(category: r.category).where((s) => s.facilityId != r.facilityId && s.acceptingRequests).toList();
        res = await showModalBottomSheet<Map<String, String?>>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _ActionSheet(title: 'Pass to another service', help: 'Choose a service that fits better and say why.', reasonLabel: 'Reason', services: options, submit: 'Pass on'),
        );
      case 'complete_followup':
        res = await showModalBottomSheet<Map<String, String?>>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => const _ActionSheet(title: 'Complete follow-up', help: 'Record how the follow-up went.', outcomes: true, submit: 'Complete follow-up'),
        );
    }
    if (res == null || !context.mounted) return;
    try {
      final to = e.transition(app.user, r.id, action, reason: res['reason'], toServiceId: res['service'], outcome: res['outcome']);
      app.refresh();
      if (context.mounted) snack(context, 'Updated: ${statusLabels[to]}');
    } on DomainError catch (err) {
      if (context.mounted) snack(context, err.message, error: true);
    }
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(this.ev, {required this.last, required this.color});
  final HistoryEvent ev;
  final bool last;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ev.to == null ? '' : ' → ${statusLabels[ev.to] ?? ev.to}';
    return Semantics(
      label: '${eventLabel(ev.action)}$state, ${ev.actor}, ${fmtDateTime(ev.time)}${ev.reason != null ? ', reason: ${ev.reason}' : ''}',
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 24,
              child: Column(children: [
                const SizedBox(height: 4),
                Icon(Icons.circle, size: 12, color: color),
                if (!last) Expanded(child: Container(width: 2, color: cs.outlineVariant)),
              ]),
            ),
            const SizedBox(width: Gap.s),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Gap.m),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(eventLabel(ev.action), style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (ev.to != null) Text(statusLabels[ev.to] ?? ev.to!),
                  if (ev.reason != null) Text('Reason: ${ev.reason}'),
                  Text('${ev.actor} · ${fmtDateTime(ev.time)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ActionSheet extends StatefulWidget {
  const _ActionSheet({required this.title, required this.help, required this.submit, this.reasonLabel, this.services, this.outcomes = false});
  final String title, help, submit;
  final String? reasonLabel;
  final List<ServiceEntry>? services;
  final bool outcomes;
  @override
  State<_ActionSheet> createState() => _ActionSheetState();
}

class _ActionSheetState extends State<_ActionSheet> {
  final _reason = TextEditingController();
  String? _service, _outcome, _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.services != null && _service == null) return setState(() => _error = 'Choose a service to continue.');
    if (widget.outcomes && _outcome == null) return setState(() => _error = 'Choose an outcome to continue.');
    if (widget.reasonLabel != null && _reason.text.trim().isEmpty) return setState(() => _error = 'Add a short reason to continue.');
    Navigator.pop(context, {'reason': _reason.text.trim(), 'service': _service, 'outcome': _outcome});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.m),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: Gap.xs),
            Text(widget.help),
            const SizedBox(height: Gap.m),
            if (widget.services != null) ...[
              if (widget.services!.isEmpty)
                const Notice('No other service in this category is taking requests right now. Ask a programme administrator to review the directory, or decline with a reason.', icon: Icons.info_outline)
              else
                for (final s in widget.services!)
                  ChoiceTile(title: s.facilityName, subtitle: '${s.district} · ${s.availability}', selected: _service == s.id, onTap: () => setState(() => _service = s.id)),
              const SizedBox(height: Gap.s),
            ],
            if (widget.outcomes) ...[
              for (final o in outcomeLabels.entries) ChoiceTile(title: o.value, selected: _outcome == o.key, onTap: () => setState(() => _outcome = o.key)),
              const SizedBox(height: Gap.s),
            ],
            if (widget.reasonLabel != null)
              TextField(controller: _reason, maxLength: 200, minLines: 2, maxLines: 4, decoration: fieldDeco(widget.reasonLabel!), onChanged: (_) => setState(() => _error = null)),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: Gap.s), child: Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)))),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: Gap.s),
              Expanded(flex: 2, child: FilledButton(onPressed: _submit, child: Text(widget.submit))),
            ]),
          ]),
        ),
      ),
    );
  }
}
