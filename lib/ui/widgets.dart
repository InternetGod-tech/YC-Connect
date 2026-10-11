import 'package:flutter/material.dart';

import '../core/theme.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String fmtDateTime(DateTime d) => '${fmtDate(d)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

void snack(BuildContext c, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.of(c);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? Sem.danger(c).bg : null,
    action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
  ));
}

Future<bool> confirm(BuildContext c, {required String title, required String body, required String action, bool destructive = false}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error, foregroundColor: Theme.of(ctx).colorScheme.onError) : null,
          child: Text(action),
        ),
      ],
    ),
  );
  return r ?? false;
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 880});
  final List<Widget> children;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(padding: const EdgeInsets.fromLTRB(Gap.m, Gap.m, Gap.m, Gap.xl), children: children),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Gap.l, bottom: Gap.s),
        child: Row(children: [
          Expanded(child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleLarge))),
          if (trailing != null) trailing!,
        ]),
      );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(Gap.m), this.onTap, this.tone, this.semanticLabel});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Sem? tone;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tone?.bg ?? cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone == null ? cs.outlineVariant : tone!.fg.withValues(alpha: 0.4)),
      ),
      child: child,
    );
    final w = onTap == null
        ? box
        : Material(
            color: Colors.transparent,
            child: InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap, child: box),
          );
    return Padding(padding: const EdgeInsets.only(bottom: Gap.s + 2), child: semanticLabel == null ? w : Semantics(label: semanticLabel, container: true, button: onTap != null, child: ExcludeSemantics(child: w)));
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.icon, required this.sem});
  final String label;
  final IconData icon;
  final Sem sem;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: sem.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: sem.fg.withValues(alpha: 0.35))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: sem.fg),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: TextStyle(color: sem.fg, fontWeight: FontWeight.w700, fontSize: 13))),
        ]),
      );
}

class ReferralStatusChip extends StatelessWidget {
  const ReferralStatusChip(this.status, this.labels, {super.key});
  final String status;
  final Map<String, String> labels;
  @override
  Widget build(BuildContext context) {
    final (icon, sem) = statusStyle(status);
    return StatusChip(label: labels[status] ?? status, icon: icon, sem: sem(context));
  }
}

class ServiceStatusChip extends StatelessWidget {
  const ServiceStatusChip(this.status, this.labels, {super.key});
  final String status;
  final Map<String, String> labels;
  @override
  Widget build(BuildContext context) {
    final (icon, sem) = serviceStatusStyle(status);
    return StatusChip(label: labels[status] ?? status, icon: icon, sem: sem(context));
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xl, horizontal: Gap.m),
        child: Column(children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: Gap.m),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Gap.xs),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: Gap.m), action!],
        ]),
      );
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.icon = Icons.info_outline, this.tone});
  final String text;
  final IconData icon;
  final Sem? tone;
  @override
  Widget build(BuildContext context) {
    final s = tone ?? Sem.info(context);
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.s),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: s.fg, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: s.fg, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

/// A single-choice row: tap target >= 56dp, selected state shown by icon and bold text.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({super.key, required this.title, this.subtitle, required this.selected, required this.onTap, this.enabled = true});
  final String title;
  final String? subtitle;
  final bool selected, enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      button: true,
      label: title,
      hint: subtitle,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: Gap.s),
          child: Material(
            color: selected ? cs.primaryContainer : Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1)),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: enabled ? onTap : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: 10),
                  child: Row(children: [
                    Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: enabled ? cs.primary : cs.outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: enabled ? null : cs.outline)),
                        if (subtitle != null) Text(subtitle!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key});
  final String k, v;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Semantics(
          label: '$k: $v',
          child: ExcludeSemantics(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 120, child: Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
              Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      );
}

InputDecoration fieldDeco(String label, {String? hint, String? helper}) =>
    InputDecoration(labelText: label, hintText: hint, helperText: helper, border: const OutlineInputBorder(), helperMaxLines: 2);

class Logo extends StatelessWidget {
  const Logo({super.key, this.height = 72});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Image.asset('assets/brand/youthcare_logo.png', height: height, semanticLabel: 'YouthCare Connect logo', filterQuality: FilterQuality.high),
      );
}
