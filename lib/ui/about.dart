import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import 'widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return PageBody(maxWidth: 760, children: [
      const Align(alignment: Alignment.centerLeft, child: Logo(height: 96)),
      const SizedBox(height: Gap.l),
      Semantics(header: true, child: Text('About YouthCare Connect', style: t.displaySmall)),
      const SizedBox(height: Gap.s),
      Text('Youth Health Referral & Continuity Platform', style: t.titleMedium?.copyWith(color: cs.primary)),
      const SectionTitle('What it does'),
      const Text('YouthCare Connect helps a young person move from needing support to receiving it. They find a service, send a request, and see who needs to act next, until the follow-up is recorded and the referral is closed. Support workers and providers use the same record, so a referral does not disappear between services.'),
      const SectionTitle('Why it exists'),
      const Text('Getting from recognising a need to completing follow-up can involve several services and no single place to see progress. We believe fragmentation between services is a root cause, and we are testing that with stakeholder conversations and a mapped service pathway. YouthCare Connect starts in Zimbabwe.'),
      const SectionTitle('HackLab'),
      const Text('Category 1: Holistic Youth Health & Well-being.'),
      const SectionTitle('Founder and team lead'),
      LayoutBuilder(builder: (context, c) {
        final photo = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset('assets/brand/founder.jpg', width: 220, height: 275, fit: BoxFit.cover, semanticLabel: 'Photograph of Thembinkosi Mhindi, project founder and team lead'),
        );
        final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text('Thembinkosi Mhindi', style: t.headlineSmall)),
          const SizedBox(height: Gap.xs),
          Text('Project Founder & Team Lead', style: const TextStyle(fontWeight: FontWeight.w700)),
          const Text('Sole Software and Technical Lead'),
          const SizedBox(height: Gap.s),
          const Text('Responsible for product architecture, implementation, integration, security, testing and technical maintenance of YouthCare Connect under the MYTHOSPRIME technology portfolio.'),
        ]);
        return c.maxWidth > 560
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [photo, const SizedBox(width: Gap.l), Expanded(child: text)])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [photo, const SizedBox(height: Gap.m), text]);
      }),
      const SectionTitle('The team'),
      const _Member('Thembinkosi Mhindi', 'Founder, Team Lead and sole Technical Lead', 'Architecture, software, security, testing and deployment.'),
      const _Member('Takunda Guniwisi', 'Mental-health and social-work specialist', 'Psychosocial workflow, safeguarding input and stakeholder validation.'),
      const _Member('Praymore Kusena', 'Arts and communications', 'Youth-facing communication, evidence and presentation support.'),
      const _Member('Rarami Raren Mukuni', 'Design and presentation', 'Visual communication and presentation input.'),
      const SectionTitle('Names, side by side'),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          KV('YouthCare Connect', 'The product, and the HackLab team project.'),
          KV('PROJECT-CORE', 'The engineering codename for the software.'),
          KV('MYTHOSPRIME', 'The technology portfolio the software is built under.'),
        ]),
      ),
      const SizedBox(height: Gap.m),
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Image.asset('assets/brand/mythosprime_logo.png', height: 110, semanticLabel: 'MYTHOSPRIME logo'),
        ),
      ),
      const SectionTitle('Version'),
      const Panel(child: KV('Version', '$appVersion (build $appBuild)')),
      OutlinedButton.icon(
        icon: const Icon(Icons.description_outlined),
        label: const Text('Open-source licences'),
        onPressed: () => showLicensePage(context: context, applicationName: 'YouthCare Connect', applicationVersion: appVersion),
      ),
    ]);
  }
}

class _Member extends StatelessWidget {
  const _Member(this.name, this.role, this.contribution);
  final String name, role, contribution;
  @override
  Widget build(BuildContext context) => Panel(
        semanticLabel: '$name. $role. $contribution',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          Text(role, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: Gap.xs),
          Text(contribution),
        ]),
      );
}
