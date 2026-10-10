import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../domain/engine.dart';
import '../domain/models.dart';
import 'referrals.dart';
import 'widgets.dart';

class FindServicesScreen extends StatefulWidget {
  const FindServicesScreen({super.key});
  @override
  State<FindServicesScreen> createState() => _FindServicesScreenState();
}

class _FindServicesScreenState extends State<FindServicesScreen> {
  String? _category;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final e = app.engine;
    final worker = app.user.role == Role.worker;
    var list = e.directory(category: _category);
    final q = _q.trim().toLowerCase();
    if (q.isNotEmpty) list = list.where((s) => '${s.facilityName} ${s.district} ${s.province}'.toLowerCase().contains(q)).toList();
    return PageBody(children: [
      Text(worker ? 'Create a request' : 'Find services', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: Gap.xs),
      Text(worker ? 'Choose the service that fits the young person, then complete the request.' : 'Choose the kind of support you are looking for.'),
      const SizedBox(height: Gap.m),
      Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
        ChoiceChip(label: const Text('All support'), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
        for (final c in e.categories()) ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = c)),
      ]),
      const SizedBox(height: Gap.m),
      TextField(decoration: fieldDeco('Search by place or facility').copyWith(prefixIcon: const Icon(Icons.search)), onChanged: (v) => setState(() => _q = v)),
      const SizedBox(height: Gap.m),
      if (list.isEmpty)
        EmptyState(
          icon: Icons.search_off,
          title: 'No services found',
          message: _category == null ? 'Nothing matches your search. Try a different place.' : 'No service is taking requests for "$_category" ${q.isEmpty ? 'yet' : 'in that place'}. Try another kind of support or search term.',
        )
      else
        for (final s in list) _ServiceCard(s),
    ]);
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard(this.s);
  final ServiceEntry s;
  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(header: true, child: Text(s.facilityName, style: Theme.of(context).textTheme.titleMedium)),
        Text('${s.category} · ${s.district}, ${s.province}'),
        const SizedBox(height: Gap.s),
        KV('Who it is for', s.eligibility),
        KV('When', s.availability),
        const SizedBox(height: Gap.s),
        ServiceStatusChip(s.status, serviceStatusLabels),
        const SizedBox(height: Gap.m),
        FilledButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => RequestScreen(service: s))),
          child: const Text('Request this service'),
        ),
      ]),
    );
  }
}

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key, required this.service});
  final ServiceEntry service;
  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _note = TextEditingController();
  final _key = 'req-${DateTime.now().microsecondsSinceEpoch}';
  String _pref = 'self';
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (_busy) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    final app = AppScope.of(context);
    setState(() => _busy = true);
    try {
      final (id, dup) = app.engine.createReferral(app.user, widget.service.id, subjectCode: _code.text, note: _note.text, contactPref: _pref, idemKey: _key);
      app.refresh();
      if (dup) snack(context, 'There is already an open request for this service. Showing it now.');
      Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => ReferralDetailScreen(id: id, justCreated: !dup)));
    } on DomainError catch (err) {
      setState(() => _busy = false);
      snack(context, err.message, error: true);
    } catch (_) {
      setState(() => _busy = false);
      snack(context, 'Something went wrong and nothing was sent. Please try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final worker = app.user.role == Role.worker;
    final s = widget.service;
    return Scaffold(
      appBar: AppBar(title: const Text('Request a service')),
      body: Form(
        key: _form,
        child: PageBody(maxWidth: 640, children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.facilityName, style: Theme.of(context).textTheme.titleMedium),
              Text('${s.category} · ${s.district}'),
              Text(s.availability),
            ]),
          ),
          if (worker) ...[
            const SectionTitle('Young person'),
            TextFormField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')), LengthLimitingTextInputFormatter(16)],
              decoration: fieldDeco('Young person code', helper: 'Use your programme code, such as YTH-0007. Do not enter a name.'),
              validator: (v) => RegExp(r'^[A-Za-z0-9-]{4,16}$').hasMatch(v?.trim() ?? '') ? null : 'Enter a code of 4 to 16 letters, digits or hyphens.',
            ),
          ] else ...[
            const SectionTitle('How should the service reach you?'),
            ChoiceTile(title: 'Contact me directly', subtitle: 'The service will get in touch with you.', selected: _pref == 'self', onTap: () => setState(() => _pref = 'self')),
            ChoiceTile(title: 'Through a support worker', subtitle: 'A support worker helps arrange the visit.', selected: _pref == 'worker', onTap: () => setState(() => _pref = 'worker')),
          ],
          const SectionTitle('Anything the service should know? (optional)'),
          TextFormField(
            controller: _note,
            maxLength: 500,
            minLines: 3,
            maxLines: 5,
            decoration: fieldDeco('Short note', helper: 'Keep it practical, such as the best days to attend. Please do not include medical history.'),
          ),
          const SizedBox(height: Gap.m),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Sending…' : 'Send request')),
          const SizedBox(height: Gap.m),
          Notice('If you are in immediate danger, contact local emergency services. This app cannot send emergency help.', icon: Icons.emergency_outlined, tone: Sem.warning(context)),
        ]),
      ),
    );
  }
}
