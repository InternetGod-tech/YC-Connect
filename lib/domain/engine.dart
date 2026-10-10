import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../data/app_db.dart';
import 'models.dart';

String _iso(DateTime d) => '${d.toUtc().toIso8601String().split('.').first}Z';

/// All referral rules live here: state machine, permissions, validation,
/// audit and aggregate indicators. The UI never writes SQL.
class Engine {
  Engine(this.store, this.seedJson);
  final AppDb store;
  final String seedJson;

  Database get _db => store.db;
  DateTime _now() => DateTime.now().toUtc();

  T _tx<T>(T Function() f) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final r = f();
      _db.execute('COMMIT');
      return r;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _audit(String actor, String action, String resource, Map<String, Object?> detail, [DateTime? ts]) {
    _db.execute('INSERT INTO audit(ts,actor,action,resource,outcome,detail) VALUES(?,?,?,?,?,?)',
        [_iso(ts ?? _now()), actor, action, resource, 'ok', jsonEncode(detail)]);
  }

  // ---------- users & seed ----------
  List<AppUser> users() => _db.select('SELECT * FROM users ORDER BY rowid').map(_user).toList();

  AppUser? user(String id) {
    final r = _db.select('SELECT * FROM users WHERE id=?', [id]);
    return r.isEmpty ? null : _user(r.first);
  }

  AppUser _user(Row r) => AppUser(
        id: r['id'] as String,
        name: r['name'] as String,
        role: Role.values.byName(r['role'] as String),
        facilityId: r['facility_id'] as String?,
        subjectCode: r['subject_code'] as String?,
      );

  void seed() {
    final cfg = jsonDecode(seedJson) as Map<String, dynamic>;
    final n = _now();
    _tx(() {
      store.createSchema();
      var i = 0;
      for (final c in cfg['categories'] as List) {
        _db.execute('INSERT INTO categories VALUES(?,?)', [c, i++]);
      }
      for (final f in cfg['facilities'] as List) {
        _db.execute('INSERT INTO facilities VALUES(?,?,?,?,?)',
            [f['id'], f['name'], f['province'], f['district'], _iso(n.subtract(Duration(days: (f['reviewed_days_ago'] ?? 0) as int)))]);
      }
      for (final s in cfg['services'] as List) {
        _db.execute('INSERT INTO services VALUES(?,?,?,?,?,?)',
            [s['id'], s['facility'], s['category'], s['eligibility'], s['availability'], s['status']]);
      }
      for (final u in cfg['users'] as List) {
        _db.execute('INSERT INTO users VALUES(?,?,?,?,?)', [u['id'], u['name'], u['role'], u['facility'], u['subject_code']]);
      }
      _seedActivity(n);
    });
  }

  void _seedActivity(DateTime n) {
    final youth = user('u_youth')!, worker = user('u_worker')!, sak = user('u_prov_sak')!, hyc = user('u_prov_hyc')!;
    DateTime at(int d) => n.subtract(Duration(days: d));
    String mk(AppUser u, String svc, String? subj, int d, {String pref = 'self'}) =>
        _create(u, svc, subjectCode: subj, contactPref: pref, ts: at(d)).$1;
    void go(AppUser u, String id, String a, int d, {String? reason, String? to, String? outcome}) =>
        _transition(u, id, a, reason: reason, toServiceId: to, outcome: outcome, ts: at(d));
    mk(youth, 'S3', null, 1);
    var r = mk(worker, 'S2', 'YTH-0002', 3);
    go(sak, r, 'accept', 2);
    r = mk(worker, 'S3', 'YTH-0003', 2);
    go(sak, r, 'reroute', 1, to: 'S4', reason: 'A counsellor at another centre has capacity this week');
    r = mk(worker, 'S3', 'YTH-0004', 14);
    go(sak, r, 'accept', 13);
    go(sak, r, 'attend', 10);
    r = mk(worker, 'S2', 'YTH-0005', 20);
    go(sak, r, 'accept', 19);
    go(sak, r, 'attend', 17);
    go(worker, r, 'complete_followup', 11, outcome: 'service_received');
    r = mk(worker, 'S5', 'YTH-0006', 7);
    go(hyc, r, 'decline', 6, reason: 'Outside the service age range');
  }

  /// Deletes all records and restores the starting directory and activity.
  void reset() => seed();

  // ---------- directory ----------
  List<String> categories() => _db.select('SELECT name FROM categories ORDER BY sort').map((r) => r['name'] as String).toList();

  List<ServiceEntry> directory({String? category, bool includeHidden = false}) {
    final cutoff = _iso(_now().subtract(const Duration(days: 180)));
    final where = <String>[];
    final args = <Object?>[];
    if (category != null) {
      where.add('s.category=?');
      args.add(category);
    }
    if (!includeHidden) where.add("s.status IN ('verified','pending')");
    final rows = _db.select(
        'SELECT s.*, f.name fname, f.province, f.district, f.reviewed_at FROM services s JOIN facilities f ON f.id=s.facility_id'
        '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'} ORDER BY f.province, f.name, s.category',
        args);
    return rows
        .map((r) => ServiceEntry(
              id: r['id'] as String,
              facilityId: r['facility_id'] as String,
              facilityName: r['fname'] as String,
              province: (r['province'] ?? '') as String,
              district: (r['district'] ?? '') as String,
              category: r['category'] as String,
              eligibility: (r['eligibility'] ?? '') as String,
              availability: (r['availability'] ?? '') as String,
              status: r['status'] as String,
              needsReview: r['status'] != 'verified' || (r['reviewed_at'] as String).compareTo(cutoff) < 0,
            ))
        .toList();
  }

  List<(String, String)> facilities() => _db.select('SELECT id,name FROM facilities ORDER BY name').map((r) => (r['id'] as String, r['name'] as String)).toList();

  void _requireAdmin(AppUser u) {
    if (u.role != Role.admin) throw DomainError(403, 'Only a programme administrator can change the directory.');
  }

  void setServiceStatus(AppUser admin, String serviceId, String status) {
    _requireAdmin(admin);
    if (!serviceStatusLabels.containsKey(status)) throw DomainError(400, 'Choose a valid status.');
    final s = _db.select('SELECT facility_id FROM services WHERE id=?', [serviceId]);
    if (s.isEmpty) throw DomainError(404, 'Service not found.');
    _tx(() {
      _db.execute('UPDATE services SET status=? WHERE id=?', [status, serviceId]);
      if (status == 'verified') _db.execute('UPDATE facilities SET reviewed_at=? WHERE id=?', [_iso(_now()), s.first['facility_id']]);
      _audit(admin.id, 'directory.status', serviceId, {'to': status});
    });
  }

  String saveService(AppUser admin,
      {String? id, required String facilityId, required String category, required String eligibility, required String availability, required String status}) {
    _requireAdmin(admin);
    if (!categories().contains(category)) throw DomainError(400, 'Choose a category from the list.');
    if (_db.select('SELECT 1 FROM facilities WHERE id=?', [facilityId]).isEmpty) throw DomainError(400, 'Choose a facility.');
    if (!serviceStatusLabels.containsKey(status)) throw DomainError(400, 'Choose a valid status.');
    if (eligibility.trim().length > 120 || availability.trim().length > 120) throw DomainError(400, 'Keep eligibility and availability under 120 characters.');
    return _tx(() {
      var sid = id;
      if (sid == null) {
        final n = (_db.select("SELECT COUNT(*) n FROM services").first['n'] as int) + 1;
        sid = 'S$n';
        while (_db.select('SELECT 1 FROM services WHERE id=?', [sid]).isNotEmpty) {
          sid = 'S${++n}';
        }
        _db.execute('INSERT INTO services VALUES(?,?,?,?,?,?)', [sid, facilityId, category, eligibility.trim(), availability.trim(), status]);
      } else {
        _db.execute('UPDATE services SET facility_id=?, category=?, eligibility=?, availability=?, status=? WHERE id=?',
            [facilityId, category, eligibility.trim(), availability.trim(), status, sid]);
      }
      _audit(admin.id, id == null ? 'directory.add' : 'directory.edit', sid, {'to': status});
      return sid;
    });
  }

  // ---------- referrals ----------
  bool _visible(AppUser u, Row r) => switch (u.role) {
        Role.provider => r['facility_id'] == u.facilityId,
        Role.worker => r['created_by'] == u.id,
        Role.youth => r['subject_code'] == u.subjectCode,
        Role.admin => false,
      };

  Referral _ref(Row r, {bool hideSubject = false}) => Referral(
        id: r['id'] as String,
        subjectCode: hideSubject ? null : r['subject_code'] as String,
        serviceId: r['service_id'] as String,
        facilityId: r['facility_id'] as String,
        facilityName: r['fname'] as String,
        category: r['category'] as String,
        status: r['status'] as String,
        note: hideSubject ? null : r['note'] as String?,
        contactPref: r['contact_pref'] as String,
        createdBy: r['created_by'] as String,
        createdAt: r['created_at'] as String,
        updatedAt: r['updated_at'] as String,
      );

  static const _refSelect = 'SELECT r.*, f.name fname FROM referrals r JOIN facilities f ON f.id=r.facility_id';

  Referral getReferral(AppUser u, String id) {
    final rows = _db.select('$_refSelect WHERE r.id=?', [id]);
    if (rows.isEmpty) throw DomainError(404, 'Referral not found.');
    if (u.role == Role.admin) return _ref(rows.first, hideSubject: true);
    if (!_visible(u, rows.first)) throw DomainError(404, 'Referral not found.');
    return _ref(rows.first);
  }

  List<Referral> listReferrals(AppUser u) {
    switch (u.role) {
      case Role.admin:
        return _db.select('$_refSelect ORDER BY r.updated_at DESC, r.seq DESC').map((r) => _ref(r, hideSubject: true)).toList();
      case Role.provider:
        return _db.select('$_refSelect WHERE r.facility_id=? ORDER BY r.updated_at DESC, r.seq DESC', [u.facilityId]).map(_ref).toList();
      case Role.worker:
        return _db.select('$_refSelect WHERE r.created_by=? ORDER BY r.updated_at DESC, r.seq DESC', [u.id]).map(_ref).toList();
      case Role.youth:
        return _db.select('$_refSelect WHERE r.subject_code=? ORDER BY r.updated_at DESC, r.seq DESC', [u.subjectCode]).map(_ref).toList();
    }
  }

  static final _codeRe = RegExp(r'^[A-Z0-9-]{4,16}$');

  /// Returns (referralId, wasDuplicate).
  (String, bool) createReferral(AppUser u, String serviceId, {String? subjectCode, String? note, String contactPref = 'self', String? idemKey}) =>
      _tx(() => _create(u, serviceId, subjectCode: subjectCode, note: note, contactPref: contactPref, idemKey: idemKey));

  (String, bool) _create(AppUser u, String serviceId,
      {String? subjectCode, String? note, String contactPref = 'self', String? idemKey, DateTime? ts}) {
    ts ??= _now();
    if (u.role != Role.youth && u.role != Role.worker) throw DomainError(403, 'Your role cannot create referrals.');
    final sv = _db.select('SELECT s.*, f.id fid FROM services s JOIN facilities f ON f.id=s.facility_id WHERE s.id=?', [serviceId]);
    if (sv.isEmpty) throw DomainError(400, 'Choose a service from the directory.');
    final svc = sv.first;
    if (svc['status'] != 'verified' && svc['status'] != 'pending') {
      throw DomainError(409, 'That service is not taking new requests right now. Please choose another.');
    }
    final text = (note ?? '').trim();
    if (text.length > 500) throw DomainError(400, 'Keep the note to 500 characters or fewer.');
    if (contactPref != 'self' && contactPref != 'worker') throw DomainError(400, 'Choose how you would like to be contacted.');
    late final String subj;
    if (u.role == Role.youth) {
      subj = u.subjectCode!;
    } else {
      subj = (subjectCode ?? '').trim();
      if (!_codeRe.hasMatch(subj)) throw DomainError(400, 'The young person code must be 4 to 16 capital letters, digits or hyphens.');
      contactPref = 'worker';
    }
    if (idemKey != null && idemKey.length > 64) throw DomainError(400, 'Invalid request key.');
    final ikey = idemKey == null ? null : '${u.id}:$idemKey';
    if (ikey != null) {
      final d = _db.select('SELECT id FROM referrals WHERE idem_key=?', [ikey]);
      if (d.isNotEmpty) return (d.first['id'] as String, true);
    }
    final d2 = _db.select(
        "SELECT id FROM referrals WHERE subject_code=? AND service_id=? AND created_by=? AND status NOT IN ('completed','declined')",
        [subj, serviceId, u.id]);
    if (d2.isNotEmpty) return (d2.first['id'] as String, true);
    _db.execute(
        'INSERT INTO referrals(subject_code,service_id,facility_id,category,status,note,contact_pref,created_by,idem_key,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)',
        [subj, serviceId, svc['facility_id'], svc['category'], 'pending', text, contactPref, u.id, ikey, _iso(ts), _iso(ts)]);
    final seq = _db.lastInsertRowId;
    final id = 'YC-${ts.year}-${seq.toString().padLeft(5, '0')}';
    _db.execute('UPDATE referrals SET id=? WHERE seq=?', [id, seq]);
    _audit(u.id, 'referral.create', id, {'from': null, 'to': 'pending', 'service': serviceId}, ts);
    return (id, false);
  }

  List<String> allowedActions(AppUser u, Referral r) =>
      actionSpecs.entries.where((e) => e.value.from.contains(r.status) && e.value.roles.contains(u.role)).map((e) => e.key).toList();

  String transition(AppUser u, String id, String action, {String? reason, String? toServiceId, String? outcome}) =>
      _tx(() => _transition(u, id, action, reason: reason, toServiceId: toServiceId, outcome: outcome));

  String _transition(AppUser u, String id, String action, {String? reason, String? toServiceId, String? outcome, DateTime? ts}) {
    ts ??= _now();
    final spec = actionSpecs[action];
    if (spec == null) throw DomainError(404, 'Unknown action.');
    if (!spec.roles.contains(u.role)) throw DomainError(403, 'Your role cannot do this.');
    final r = getReferral(u, id);
    if (!spec.from.contains(r.status)) {
      throw DomainError(409, 'You cannot ${action.replaceAll('_', ' ')} a referral that is ${r.status.replaceAll('_', ' ')}.');
    }
    final why = (reason ?? '').trim();
    if (why.length > 200) throw DomainError(400, 'Keep the reason to 200 characters or fewer.');
    if ((action == 'decline' || action == 'reroute') && why.isEmpty) throw DomainError(400, 'Give a short reason so the young person understands.');
    final detail = <String, Object?>{'from': r.status, 'to': spec.to};
    if (why.isNotEmpty) detail['reason'] = why;
    final sets = <String, Object?>{};
    if (action == 'reroute') {
      final t = toServiceId == null ? <Row>[] : _db.select('SELECT * FROM services WHERE id=?', [toServiceId]).toList();
      if (t.isEmpty || t.first['facility_id'] == r.facilityId) throw DomainError(400, 'Choose a service at a different facility.');
      if (t.first['status'] != 'verified' && t.first['status'] != 'pending') throw DomainError(409, 'That service is not taking new requests.');
      sets.addAll({'service_id': t.first['id'], 'facility_id': t.first['facility_id'], 'category': t.first['category']});
      detail['to_service'] = t.first['id'];
    }
    if (action == 'complete_followup') {
      if (!outcomeLabels.containsKey(outcome)) throw DomainError(400, 'Choose a follow-up outcome.');
      detail['outcome'] = outcome;
      _db.execute('UPDATE followups SET outcome=?, completed_at=? WHERE referral_id=? AND completed_at IS NULL', [outcome, _iso(ts), id]);
    }
    sets['status'] = spec.to;
    sets['updated_at'] = _iso(ts);
    _db.execute('UPDATE referrals SET ${sets.keys.map((k) => '$k=?').join(',')} WHERE id=?', [...sets.values, id]);
    _audit(u.id, 'referral.$action', id, detail, ts);
    if (action == 'attend' || action == 'no_show') {
      final w = _db.select('SELECT role FROM users WHERE id=?', [r.createdBy]);
      final owner = (w.isNotEmpty && w.first['role'] == 'worker') ? r.createdBy : u.id;
      final due = _iso(ts.add(const Duration(days: 7)));
      _db.execute('INSERT INTO followups(referral_id,owner_id,due_at) VALUES(?,?,?)', [id, owner, due]);
      _db.execute("UPDATE referrals SET status='follow_up_due' WHERE id=?", [id]);
      _audit('system', 'followup.create', id, {'from': spec.to, 'to': 'follow_up_due', 'owner': owner, 'due': due}, ts);
      return 'follow_up_due';
    }
    return spec.to;
  }

  /// Timeline for one referral. Staff see actor names; the young person sees roles.
  List<HistoryEvent> history(AppUser u, String id) {
    getReferral(u, id);
    final rows = _db.select(
        "SELECT a.ts, a.action, a.detail, a.actor, u.name uname, u.role urole FROM audit a LEFT JOIN users u ON u.id=a.actor WHERE a.resource=? AND a.outcome='ok' ORDER BY a.id",
        [id]);
    return rows.map((x) {
      final d = jsonDecode(x['detail'] as String) as Map<String, dynamic>;
      final who = u.role == Role.youth
          ? (x['urole'] == null ? 'Referral system' : Role.values.byName(x['urole'] as String).label)
          : (x['uname'] as String? ?? 'Referral system');
      return HistoryEvent(ts: x['ts'] as String, action: x['action'] as String, actor: who, to: d['to'] as String?, reason: d['reason'] as String?);
    }).toList();
  }

  Owner nextOwner(Referral r) {
    switch (r.status) {
      case 'pending':
      case 'rerouted':
        return Owner.provider;
      case 'accepted':
        return r.contactPref == 'worker' ? Owner.worker : Owner.youth;
      case 'attended':
        return Owner.provider;
      case 'follow_up_due':
        final f = _db.select('SELECT u.role FROM followups f LEFT JOIN users u ON u.id=f.owner_id WHERE f.referral_id=? ORDER BY f.id DESC LIMIT 1', [r.id]);
        return (f.isNotEmpty && f.first['role'] == 'worker') ? Owner.worker : Owner.provider;
      case 'declined':
        return r.contactPref == 'worker' ? Owner.worker : Owner.youth;
      default:
        return Owner.nobody;
    }
  }

  List<Followup> followups(AppUser u) {
    final now = _iso(_now());
    final rows = _db.select(
        'SELECT f.*, r.subject_code, r.facility_id, r.created_by, COALESCE(o.name, f.owner_id) oname FROM followups f JOIN referrals r ON r.id=f.referral_id LEFT JOIN users o ON o.id=f.owner_id ORDER BY (f.completed_at IS NOT NULL), f.due_at');
    return rows.where((r) => _visible(u, r)).map((r) {
      final done = r['completed_at'] as String?;
      return Followup(
        referralId: r['referral_id'] as String,
        subjectCode: u.role == Role.youth ? null : r['subject_code'] as String,
        ownerName: r['oname'] as String,
        dueAt: r['due_at'] as String,
        completedAt: done,
        outcome: r['outcome'] as String?,
        overdue: done == null && (r['due_at'] as String).compareTo(now) < 0,
      );
    }).toList();
  }

  // ---------- admin: aggregates and audit ----------
  Dashboard dashboard() {
    final by = {for (final s in statuses) s: 0};
    for (final r in _db.select('SELECT status, COUNT(*) n FROM referrals GROUP BY status')) {
      by[r['status'] as String] = r['n'] as int;
    }
    final total = by.values.fold<int>(0, (a, b) => a + b);
    final f = _db.select('SELECT COUNT(*) t, COALESCE(SUM(completed_at IS NOT NULL),0) d, COALESCE(SUM(completed_at IS NULL AND due_at < ?),0) o FROM followups', [_iso(_now())]).first;
    final ft = f['t'] as int, fd = f['d'] as int, fo = f['o'] as int;
    final hrs = _db
        .select("SELECT r.created_at c, a.ts t FROM referrals r JOIN audit a ON a.resource=r.id AND a.action='referral.attend' AND a.outcome='ok'")
        .map((x) => DateTime.parse(x['t'] as String).difference(DateTime.parse(x['c'] as String)).inMinutes / 60.0)
        .toList()
      ..sort();
    double? median;
    if (hrs.isNotEmpty) {
      final m = hrs.length ~/ 2;
      median = hrs.length.isOdd ? hrs[m] : (hrs[m - 1] + hrs[m]) / 2;
    }
    final ss = {for (final s in serviceStatusLabels.keys) s: 0};
    for (final r in _db.select('SELECT status, COUNT(*) n FROM services GROUP BY status')) {
      ss[r['status'] as String] = r['n'] as int;
    }
    final review = directory(includeHidden: true).where((s) => s.needsReview && s.status != 'unavailable').length;
    final prov = _db
        .select("SELECT f.province p, COUNT(*) t, SUM(r.status='completed') c FROM referrals r JOIN facilities f ON f.id=r.facility_id GROUP BY f.province ORDER BY t DESC")
        .map((r) => ((r['p'] ?? '') as String, r['t'] as int, (r['c'] ?? 0) as int))
        .toList();
    return Dashboard(
      total: total,
      byStatus: by,
      unresolved: total - by['completed']! - by['declined']!,
      completedRate: total == 0 ? null : by['completed']! / total,
      followupTotal: ft,
      followupDone: fd,
      followupOpen: ft - fd,
      followupOverdue: fo,
      followupRate: ft == 0 ? null : fd / ft,
      medianHoursToService: median,
      serviceStatus: ss,
      servicesNeedingReview: review,
      byProvince: prov,
      recent: auditLog(limit: 6),
    );
  }

  List<AuditEntry> auditLog({int limit = 200}) {
    final rows = _db.select(
        'SELECT a.*, COALESCE(u.name, a.actor) actor_name FROM audit a LEFT JOIN users u ON u.id=a.actor ORDER BY a.id DESC LIMIT ?', [limit]);
    return rows.map((x) {
      final d = jsonDecode(x['detail'] as String) as Map<String, dynamic>;
      return AuditEntry(
        ts: x['ts'] as String,
        actor: x['actor_name'] as String,
        action: x['action'] as String,
        resource: x['resource'] as String,
        from: d['from'] as String?,
        to: d['to'] as String?,
        outcome: x['outcome'] as String,
      );
    }).toList();
  }
}
