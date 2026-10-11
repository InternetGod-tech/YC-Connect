import 'dart:io';

import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'home.dart';
import 'referrals.dart';
import 'widgets.dart';

String _pct(double? v) => v == null ? '—' : '${(v * 100).round()}%';

class AdminOverview extends StatelessWidget {
  const AdminOverview({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final d = app.engine.dashboard();
    final cs = Theme.of(context).colorScheme;
    return PageBody(children: [
      Text('Programme overview', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: Gap.xs),
      const Text('Counts and rates only. Individual details are not shown here.'),
      const SectionTitle('Referrals'),
      Wrap(spacing: Gap.s, children: [
        Stat('${d.total}', 'Total referrals'),
        Stat('${d.unresolved}', 'Still open'),
        Stat(_pct(d.completedRate), 'Completed'),
        Stat(d.medianHoursToService == null ? '—' : '${d.medianHoursToService!.toStringAsFixed(0)} h', 'Median time to first visit'),
      ]),
      const SectionTitle('Where referrals are now'),
      if (d.total == 0)
        const EmptyState(icon: Icons.assignment_outlined, title: 'No referrals yet', message: 'Counts appear once requests are made.')
      else
        for (final s in statuses)
          _Bar(label: statusLabels[s]!, value: d.byStatus[s]!, total: d.total, status: s),
      const SectionTitle('Follow-up'),
      Wrap(spacing: Gap.s, children: [
        Stat('${d.followupOpen}', 'Open follow-ups'),
        Stat('${d.followupDone}', 'Completed follow-ups'),
        Stat('${d.followupOverdue}', 'Overdue', tone: d.followupOverdue == 0 ? null : Sem.danger(context)),
        Stat(_pct(d.followupRate), 'Follow-up completion'),
      ]),
      const SectionTitle('Service directory'),
      Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
        for (final e in serviceStatusLabels.entries) _CountChip(e.key, e.value, d.serviceStatus[e.key] ?? 0),
      ]),
      const SizedBox(height: Gap.s),
      Text('${d.servicesNeedingReview} service${d.servicesNeedingReview == 1 ? '' : 's'} need verification or a fresh review.', style: TextStyle(color: cs.onSurfaceVariant)),
      const SectionTitle('By province'),
      if (d.byProvince.isEmpty) const Text('No referrals yet.') else
        Panel(
          child: Column(children: [
            for (final p in d.byProvince) KV(p.$1, '${p.$2} referral${p.$2 == 1 ? '' : 's'}, ${p.$3} completed'),
          ]),
        ),
      const SectionTitle('Recent activity'),
      for (final a in d.recent) _AuditRow(a),
    ]);
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.status, this.label, this.n);
  final String status, label;
  final int n;
  @override
  Widget build(BuildContext context) {
    final (icon, sem) = serviceStatusStyle(status);
    return StatusChip(label: '$label: $n', icon: icon, sem: sem(context));
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.total, required this.status});
  final String label, status;
  final int value, total;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, sem) = statusStyle(status);
    final frac = total == 0 ? 0.0 : value / total;
    return Semantics(
      label: '$label: $value of $total, ${(frac * 100).round()} percent',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: Gap.s + 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: sem(context).fg),
              const SizedBox(width: 6),
              Expanded(child: Text(label)),
              Text('$value  (${(frac * 100).round()}%)', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: [
                Container(height: 8, color: cs.surfaceContainerHighest),
                FractionallySizedBox(widthFactor: frac, child: Container(height: 8, color: sem(context).fg)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow(this.a);
  final AuditEntry a;
  @override
  Widget build(BuildContext context) {
    final move = a.to == null ? '' : '${a.from == null ? '' : '${statusLabels[a.from] ?? a.from} → '}${statusLabels[a.to] ?? serviceStatusLabels[a.to] ?? a.to}';
    return Panel(
      semanticLabel: '${eventLabel(a.action)}, ${a.resource}, by ${a.actor}, ${fmtDateTime(a.time)}. $move',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(eventLabel(a.action), style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(a.resource, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        if (move.isNotEmpty) Text(move),
        Text('${a.actor} · ${fmtDateTime(a.time)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
      ]),
    );
  }
}

class AdminActivity extends StatelessWidget {
  const AdminActivity({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final log = app.engine.auditLog();
    return PageBody(children: [
      Text('Activity log', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: Gap.xs),
      const Text('Who did what, and when. Notes and personal details are left out.'),
      const SizedBox(height: Gap.m),
      if (log.isEmpty) const EmptyState(icon: Icons.history, title: 'No activity yet', message: 'Actions on referrals and the directory are recorded here.') else for (final a in log) _AuditRow(a),
      const SizedBox(height: Gap.m),
      Text('This log is stored on this device. It is not a tamper-proof record.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
    ]);
  }
}

// ---------------- Directory ----------------
class AdminDirectory extends StatefulWidget {
  const AdminDirectory({super.key});
  @override
  State<AdminDirectory> createState() => _AdminDirectoryState();
}

class _AdminDirectoryState extends State<AdminDirectory> {
  String? _status;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final all = app.engine.directory(includeHidden: true);
    final list = _status == null ? all : all.where((s) => s.status == _status).toList();
    return PageBody(children: [
      Row(children: [
        Expanded(child: Text('Service directory', style: Theme.of(context).textTheme.headlineMedium)),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add service'),
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ServiceEditScreen())),
        ),
      ]),
      const SizedBox(height: Gap.xs),
      const Text('Only services marked Verified or Pending can receive new requests. Mark a service Verified only after the provider has confirmed its details.'),
      const SizedBox(height: Gap.m),
      Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
        ChoiceChip(label: Text('All (${all.length})'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
        for (final e in serviceStatusLabels.entries)
          ChoiceChip(label: Text('${e.value} (${all.where((s) => s.status == e.key).length})'), selected: _status == e.key, onSelected: (_) => setState(() => _status = e.key)),
      ]),
      const SizedBox(height: Gap.m),
      if (list.isEmpty)
        const EmptyState(icon: Icons.domain_disabled, title: 'No services with this status', message: 'Choose another status or add a service.')
      else
        for (final s in list)
          Panel(
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ServiceEditScreen(existing: s))),
            semanticLabel: '${s.facilityName}, ${s.category}, ${serviceStatusLabels[s.status]}${s.needsReview ? ', needs review' : ''}. Tap to edit.',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.facilityName, style: Theme.of(context).textTheme.titleMedium),
              Text('${s.category} · ${s.district}'),
              const SizedBox(height: Gap.s),
              Wrap(spacing: Gap.s, runSpacing: Gap.xs, children: [
                ServiceStatusChip(s.status, serviceStatusLabels),
                if (s.needsReview && s.status != 'unavailable') StatusChip(label: 'Review due', icon: Icons.rate_review_outlined, sem: Sem.warning(context)),
              ]),
            ]),
          ),
    ]);
  }
}

class ServiceEditScreen extends StatefulWidget {
  const ServiceEditScreen({super.key, this.existing});
  final ServiceEntry? existing;
  @override
  State<ServiceEditScreen> createState() => _ServiceEditScreenState();
}

class _ServiceEditScreenState extends State<ServiceEditScreen> {
  late String? _facility = widget.existing?.facilityId;
  late String? _category = widget.existing?.category;
  late String _status = widget.existing?.status ?? 'draft';
  late final _elig = TextEditingController(text: widget.existing?.eligibility ?? '');
  late final _avail = TextEditingController(text: widget.existing?.availability ?? '');
  String? _error;

  @override
  void dispose() {
    _elig.dispose();
    _avail.dispose();
    super.dispose();
  }

  void _save() {
    final app = AppScope.of(context);
    if (_facility == null || _category == null) {
      setState(() => _error = 'Choose a facility and a category.');
      return;
    }
    try {
      app.engine.saveService(app.user,
          id: widget.existing?.id, facilityId: _facility!, category: _category!, eligibility: _elig.text, availability: _avail.text, status: _status);
      app.refresh();
      Navigator.pop(context);
      snack(context, 'Service saved');
    } on DomainError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final e = app.engine;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add service' : 'Edit service')),
      body: PageBody(maxWidth: 640, children: [
        const SectionTitle('Facility'),
        for (final f in e.facilities()) ChoiceTile(title: f.$2, selected: _facility == f.$1, onTap: () => setState(() => _facility = f.$1)),
        const SectionTitle('Category'),
        for (final c in e.categories()) ChoiceTile(title: c, selected: _category == c, onTap: () => setState(() => _category = c)),
        const SectionTitle('Details'),
        TextField(controller: _elig, maxLength: 120, decoration: fieldDeco('Who it is for', hint: 'Ages 12-24')),
        const SizedBox(height: Gap.s),
        TextField(controller: _avail, maxLength: 120, decoration: fieldDeco('When it is open', hint: 'Weekdays 9:00-17:00')),
        const SectionTitle('Status'),
        for (final s in serviceStatusLabels.entries)
          ChoiceTile(
            title: s.value,
            subtitle: switch (s.key) {
              'draft' => 'Not shown to the public',
              'pending' => 'Shown, details not yet confirmed with the provider',
              'verified' => 'Details confirmed with the provider',
              _ => 'Hidden. Cannot receive new requests',
            },
            selected: _status == s.key,
            onTap: () => setState(() => _status = s.key),
          ),
        if (_error != null) Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.only(bottom: Gap.s), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)))),
        const SizedBox(height: Gap.s),
        FilledButton(onPressed: _save, child: const Text('Save service')),
      ]),
    );
  }
}

// ---------------- Data ----------------
class AdminData extends StatefulWidget {
  const AdminData({super.key});
  @override
  State<AdminData> createState() => _AdminDataState();
}

class _AdminDataState extends State<AdminData> {
  String? _msg;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final backups = app.backups();
    return PageBody(children: [
      Text('Data management', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: Gap.xs),
      const Text('All records are stored in a database on this device.'),
      if (_msg != null) ...[const SizedBox(height: Gap.m), Semantics(liveRegion: true, child: Notice(_msg!, icon: Icons.check_circle_outline, tone: Sem.success(context)))],
      const SectionTitle('Back up'),
      const Text('Saves a copy of every record to a file on this device.'),
      const SizedBox(height: Gap.s),
      FilledButton.icon(
        icon: const Icon(Icons.save_alt),
        label: const Text('Create backup'),
        onPressed: () {
          try {
            final path = app.backup();
            setState(() => _msg = 'Backup saved to $path');
          } catch (_) {
            snack(context, 'The backup could not be saved. Check that the device has free space.', error: true);
          }
        },
      ),
      const SectionTitle('Restore'),
      if (backups.isEmpty)
        const Text('No backups yet.')
      else
        for (final f in backups.take(8))
          Panel(
            child: Row(children: [
              Expanded(child: Text(f.uri.pathSegments.last, style: const TextStyle(fontWeight: FontWeight.w600))),
              OutlinedButton(onPressed: () => _restore(context, app, f), child: const Text('Restore')),
            ]),
          ),
      const SectionTitle('Reset'),
      Panel(
        tone: Sem.danger(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Reset to the starting data', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: Gap.xs),
          const Text('This permanently deletes every referral, follow-up, activity log entry and any directory changes on this device, and reloads the starting directory and sample activity. Create a backup first if you may need the current records.'),
          const SizedBox(height: Gap.m),
          OutlinedButton(
            onPressed: () async {
              if (!await confirm(context, title: 'Delete all records?', body: 'Every referral, follow-up, activity entry and directory change on this device will be deleted. This cannot be undone.', action: 'Delete and reset', destructive: true)) return;
              app.resetData();
              if (mounted) setState(() => _msg = 'Records were reset to the starting data.');
            },
            child: const Text('Reset data'),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _restore(BuildContext context, AppController app, File f) async {
    if (!await confirm(context, title: 'Restore this backup?', body: 'Current records will be replaced by the contents of ${f.uri.pathSegments.last}.', action: 'Restore', destructive: true)) return;
    try {
      app.restore(f.path);
      if (mounted) setState(() => _msg = 'Backup restored.');
    } catch (e) {
      if (context.mounted) snack(context, e is StateError ? e.message : 'The backup could not be restored.', error: true);
    }
  }
}
