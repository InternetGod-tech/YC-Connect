enum Role { youth, worker, provider, admin }

extension RoleLabel on Role {
  String get label => switch (this) {
        Role.youth => 'Young person',
        Role.worker => 'Support worker',
        Role.provider => 'Service provider',
        Role.admin => 'Programme administrator',
      };
  String get blurb => switch (this) {
        Role.youth => 'Find a service, request a referral and follow it step by step.',
        Role.worker => 'Create requests on behalf of a young person and keep each handoff moving.',
        Role.provider => 'Respond to referrals, record attendance and complete follow-up.',
        Role.admin => 'Review programme figures, manage the directory and check the activity log.',
      };
}

class AppUser {
  const AppUser({required this.id, required this.name, required this.role, this.facilityId, this.subjectCode});
  final String id, name;
  final Role role;
  final String? facilityId, subjectCode;
}

class DomainError implements Exception {
  DomainError(this.code, this.message);
  final int code;
  final String message;
  @override
  String toString() => message;
}

const statuses = ['pending', 'accepted', 'rerouted', 'attended', 'follow_up_due', 'completed', 'declined'];

const statusLabels = {
  'pending': 'Sent, waiting for a reply',
  'accepted': 'Accepted',
  'rerouted': 'Passed to another service',
  'attended': 'Visit recorded',
  'follow_up_due': 'Follow-up due',
  'completed': 'Completed',
  'declined': 'Not accepted',
};

const serviceStatusLabels = {
  'draft': 'Draft',
  'pending': 'Pending verification',
  'verified': 'Verified',
  'unavailable': 'Unavailable',
};

const outcomeLabels = {
  'service_received': 'Service received',
  'ongoing_support': 'Ongoing support in place',
  'unable_to_contact': 'Unable to make contact',
};

const actionLabels = {
  'accept': 'Accept referral',
  'reroute': 'Pass to another service',
  'decline': 'Decline referral',
  'attend': 'Record attendance',
  'no_show': 'Record missed visit',
  'complete_followup': 'Complete follow-up',
};

class ActionSpec {
  const ActionSpec(this.from, this.to, this.roles);
  final Set<String> from;
  final String to;
  final Set<Role> roles;
}

const actionSpecs = <String, ActionSpec>{
  'accept': ActionSpec({'pending', 'rerouted'}, 'accepted', {Role.provider}),
  'reroute': ActionSpec({'pending', 'rerouted', 'accepted'}, 'rerouted', {Role.provider}),
  'decline': ActionSpec({'pending', 'rerouted'}, 'declined', {Role.provider}),
  'attend': ActionSpec({'accepted'}, 'attended', {Role.provider}),
  'no_show': ActionSpec({'accepted'}, 'follow_up_due', {Role.provider}),
  'complete_followup': ActionSpec({'follow_up_due'}, 'completed', {Role.provider, Role.worker}),
};

class Referral {
  Referral({
    required this.id,
    required this.subjectCode,
    required this.serviceId,
    required this.facilityId,
    required this.facilityName,
    required this.category,
    required this.status,
    required this.note,
    required this.contactPref,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, serviceId, facilityId, facilityName, category, status, contactPref, createdBy, createdAt, updatedAt;
  final String? subjectCode, note;
  DateTime get created => DateTime.parse(createdAt).toLocal();
  DateTime get updated => DateTime.parse(updatedAt).toLocal();
  bool get isClosed => status == 'completed' || status == 'declined';
}

class Followup {
  Followup({required this.referralId, required this.subjectCode, required this.ownerName, required this.dueAt, this.completedAt, this.outcome, required this.overdue});
  final String referralId, ownerName, dueAt;
  final String? subjectCode, completedAt, outcome;
  final bool overdue;
  DateTime get due => DateTime.parse(dueAt).toLocal();
}

class ServiceEntry {
  ServiceEntry({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.province,
    required this.district,
    required this.category,
    required this.eligibility,
    required this.availability,
    required this.status,
    required this.needsReview,
  });
  final String id, facilityId, facilityName, province, district, category, eligibility, availability, status;
  final bool needsReview;
  bool get acceptingRequests => status == 'verified' || status == 'pending';
}

class HistoryEvent {
  HistoryEvent({required this.ts, required this.action, required this.actor, required this.to, this.reason});
  final String ts, action, actor;
  final String? to, reason;
  DateTime get time => DateTime.parse(ts).toLocal();
}

class AuditEntry {
  AuditEntry({required this.ts, required this.actor, required this.action, required this.resource, this.from, this.to, required this.outcome});
  final String ts, actor, action, resource, outcome;
  final String? from, to;
  DateTime get time => DateTime.parse(ts).toLocal();
}

class Dashboard {
  Dashboard({
    required this.total,
    required this.byStatus,
    required this.unresolved,
    required this.completedRate,
    required this.followupTotal,
    required this.followupDone,
    required this.followupOpen,
    required this.followupOverdue,
    required this.followupRate,
    required this.medianHoursToService,
    required this.serviceStatus,
    required this.servicesNeedingReview,
    required this.byProvince,
    required this.recent,
  });
  final int total, unresolved, followupTotal, followupDone, followupOpen, followupOverdue, servicesNeedingReview;
  final Map<String, int> byStatus, serviceStatus;
  final double? completedRate, followupRate, medianHoursToService;
  final List<(String, int, int)> byProvince; // name, total, completed
  final List<AuditEntry> recent;
}

/// Who owns the next move on a referral.
enum Owner { youth, worker, provider, nobody }
