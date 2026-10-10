import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:youthcare_connect/data/app_db.dart';
import 'package:youthcare_connect/domain/engine.dart';
import 'package:youthcare_connect/domain/models.dart';

String get _seed => File('assets/data/directory.json').readAsStringSync();

Engine make() {
  final e = Engine(AppDb.inMemory(), _seed)..seed();
  return e;
}

void main() {
  late Engine e;
  late AppUser youth, worker, sak, hyc, admin;
  setUp(() {
    e = make();
    youth = e.user('u_youth')!;
    worker = e.user('u_worker')!;
    sak = e.user('u_prov_sak')!;
    hyc = e.user('u_prov_hyc')!;
    admin = e.user('u_admin')!;
  });

  test('seed data is built through the real engine', () {
    final d = e.dashboard();
    expect(d.total, 6);
    expect(d.unresolved, 4);
    expect(d.byStatus['completed'], 1);
    expect(d.followupTotal, 2);
    expect(d.followupDone, 1);
    expect(d.followupOverdue, 1);
  });

  test('creates a referral with a unique reference', () {
    final (id, dup) = e.createReferral(youth, 'S2', idemKey: 'k1');
    expect(dup, isFalse);
    expect(id, matches(RegExp(r'^YC-\d{4}-\d{5}$')));
    final (id2, _) = e.createReferral(worker, 'S1', subjectCode: 'YTH-0009');
    expect(id2, isNot(id));
  });

  test('blocks duplicate submissions', () {
    final (a, _) = e.createReferral(youth, 'S2', idemKey: 'same');
    final (b, dupKey) = e.createReferral(youth, 'S2', idemKey: 'same');
    final (c, dupOpen) = e.createReferral(youth, 'S2', idemKey: 'other');
    expect(dupKey, isTrue);
    expect(dupOpen, isTrue);
    expect([b, c], [a, a]);
    expect(e.dashboard().total, 7);
  });

  test('validates input', () {
    expect(() => e.createReferral(youth, 'NOPE'), throwsA(isA<DomainError>()));
    expect(() => e.createReferral(worker, 'S1', subjectCode: 'bad code!'), throwsA(isA<DomainError>()));
    expect(() => e.createReferral(youth, 'S1', note: 'x' * 501), throwsA(isA<DomainError>()));
    expect(() => e.createReferral(sak, 'S1'), throwsA(predicate((x) => x is DomainError && x.code == 403)));
  });

  test('unavailable services cannot receive new referrals', () {
    expect(() => e.createReferral(youth, 'S11'), throwsA(predicate((x) => x is DomainError && x.code == 409)));
    e.setServiceStatus(admin, 'S1', 'unavailable');
    expect(() => e.createReferral(youth, 'S1'), throwsA(predicate((x) => x is DomainError && x.code == 409)));
    expect(e.directory().any((s) => s.id == 'S1'), isFalse);
  });

  test('full lifecycle with audit history', () {
    final (id, _) = e.createReferral(youth, 'S2');
    expect(e.transition(sak, id, 'accept'), 'accepted');
    expect(e.transition(sak, id, 'attend'), 'follow_up_due');
    expect(e.followups(youth).any((f) => f.referralId == id), isTrue);
    expect(() => e.transition(sak, id, 'complete_followup', outcome: 'nonsense'), throwsA(isA<DomainError>()));
    expect(e.transition(sak, id, 'complete_followup', outcome: 'service_received'), 'completed');
    final actions = e.history(sak, id).map((h) => h.action).toList();
    expect(actions, ['referral.create', 'referral.accept', 'referral.attend', 'followup.create', 'referral.complete_followup']);
    expect(e.getReferral(youth, id).isClosed, isTrue);
  });

  test('reroute moves the referral to another facility', () {
    final (id, _) = e.createReferral(youth, 'S2');
    expect(() => e.transition(sak, id, 'reroute', toServiceId: 'S3', reason: 'same facility'), throwsA(isA<DomainError>()));
    expect(() => e.transition(sak, id, 'reroute', toServiceId: 'S4'), throwsA(isA<DomainError>())); // reason required
    e.transition(sak, id, 'reroute', toServiceId: 'S4', reason: 'Capacity');
    expect(e.getReferral(hyc, id).facilityId, 'F3');
    expect(() => e.getReferral(sak, id), throwsA(isA<DomainError>()));
  });

  test('decline needs a reason and shows it to the young person', () {
    final (id, _) = e.createReferral(youth, 'S2');
    expect(() => e.transition(sak, id, 'decline'), throwsA(isA<DomainError>()));
    e.transition(sak, id, 'decline', reason: 'Outside age range');
    expect(e.history(youth, id).last.reason, 'Outside age range');
    expect(e.nextOwner(e.getReferral(youth, id)), Owner.youth);
  });

  test('every invalid transition is rejected', () {
    final (id, _) = e.createReferral(youth, 'S2');
    for (final a in ['attend', 'no_show', 'complete_followup']) {
      expect(() => e.transition(sak, id, a, outcome: 'service_received'), throwsA(predicate((x) => x is DomainError && x.code == 409)), reason: a);
    }
    e.transition(sak, id, 'accept');
    expect(() => e.transition(sak, id, 'accept'), throwsA(predicate((x) => x is DomainError && x.code == 409)));
    expect(() => e.transition(sak, id, 'decline', reason: 'x'), throwsA(predicate((x) => x is DomainError && x.code == 409)));
  });

  test('roles and record-level access', () {
    final (id, _) = e.createReferral(youth, 'S2');
    expect(() => e.transition(youth, id, 'accept'), throwsA(predicate((x) => x is DomainError && x.code == 403)));
    expect(() => e.transition(worker, id, 'accept'), throwsA(predicate((x) => x is DomainError && x.code == 403)));
    expect(() => e.transition(admin, id, 'accept'), throwsA(predicate((x) => x is DomainError && x.code == 403)));
    expect(() => e.transition(hyc, id, 'accept'), throwsA(predicate((x) => x is DomainError && x.code == 404)));
    expect(() => e.getReferral(worker, id), throwsA(isA<DomainError>())); // worker did not create it
    expect(() => e.setServiceStatus(sak, 'S1', 'verified'), throwsA(predicate((x) => x is DomainError && x.code == 403)));
    expect(e.listReferrals(youth).every((r) => r.subjectCode == 'YTH-0001'), isTrue);
  });

  test('administrators see no personal fields', () {
    final all = e.listReferrals(admin);
    expect(all, isNotEmpty);
    expect(all.every((r) => r.subjectCode == null && r.note == null), isTrue);
    expect(e.followups(admin), isEmpty);
  });

  test('dashboard is calculated from stored records', () {
    final before = e.dashboard();
    final (id, _) = e.createReferral(youth, 'S2');
    e.transition(sak, id, 'accept');
    final after = e.dashboard();
    expect(after.total, before.total + 1);
    expect(after.byStatus['accepted'], before.byStatus['accepted']! + 1);
    e.transition(sak, id, 'no_show');
    expect(e.dashboard().followupOpen, before.followupOpen + 1);
  });

  test('audit records actor, action, resource and transition', () {
    final (id, _) = e.createReferral(youth, 'S2');
    e.transition(sak, id, 'accept');
    final a = e.auditLog().firstWhere((x) => x.action == 'referral.accept' && x.resource == id);
    expect(a.from, 'pending');
    expect(a.to, 'accepted');
    expect(a.actor, sak.name);
  });

  test('directory admin: add, edit, status', () {
    final id = e.saveService(admin, facilityId: 'F5', category: 'Substance use support', eligibility: 'Ages 14-24', availability: 'Mon', status: 'draft');
    expect(e.directory().any((s) => s.id == id), isFalse); // drafts are hidden
    e.setServiceStatus(admin, id, 'verified');
    expect(e.directory().any((s) => s.id == id && s.status == 'verified' && !s.needsReview), isTrue);
    expect(() => e.saveService(admin, facilityId: 'F5', category: 'Bad', eligibility: '', availability: '', status: 'draft'), throwsA(isA<DomainError>()));
  });

  test('no seeded service is marked verified', () {
    expect(e.directory(includeHidden: true).where((s) => s.status == 'verified'), isEmpty);
  });

  test('data persists across restart, backup restores, reset reseeds', () {
    final dir = Directory.systemTemp.createTempSync('yc_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/y.db';
    var eng = Engine(AppDb.open(path), _seed)..seed();
    eng.createReferral(eng.user('u_youth')!, 'S2');
    expect(eng.dashboard().total, 7);
    final bak = '${dir.path}/b.db';
    eng.store.backupTo(bak);
    eng.createReferral(eng.user('u_worker')!, 'S1', subjectCode: 'YTH-0010');
    expect(eng.dashboard().total, 8);
    eng.store.close();

    eng = Engine(AppDb.open(path), _seed);
    expect(eng.dashboard().total, 8); // persisted
    eng.store.restoreFrom(bak);
    expect(eng.dashboard().total, 7); // restored
    eng.reset();
    expect(eng.dashboard().total, 6); // reseeded
    expect(() => eng.store.restoreFrom(path.replaceAll('y.db', 'missing.db')), throwsA(anything));
    eng.store.close();
  });
}
