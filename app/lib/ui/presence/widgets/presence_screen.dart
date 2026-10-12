import 'package:flutter/material.dart';

import '../../../domain/models/presence_report.dart';
import '../../../domain/presence/check_presence.dart' show maxAccuracyM;
import '../../../domain/repositories/location_reader.dart';
import '../../core/format.dart';
import '../../core/themes/theme.dart';
import '../../core/themes/tokens.g.dart';
import '../../core/ui/foulala_icon.dart';
import '../../core/ui/round_button.dart';
import '../../core/ui/route_sketch.dart';
import '../view_models/presence_view_model.dart';

/// Écran « J'y suis ! » (maquette design/maquettes/Presence.dc.html).
class PresenceScreen extends StatelessWidget {
  const PresenceScreen({super.key, required this.viewModel});

  final PresenceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final event = viewModel.event;
    final t = event.cause.theme;
    final state = viewModel.state;
    final report = switch (state) {
      Sent(:final report) || Queued(:final report) => report,
      _ => null,
    };

    return Scaffold(
      backgroundColor: t.soft,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  RoundButton(
                    icon: FoulalaIcons.arrowLeft,
                    label: 'Retour à la manif',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(event.title, style: FoulalaText.body(16, weight: 700), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  _Headline(state: state, t: t, bufferM: event.bufferM),
                  const SizedBox(height: 16),
                  if (state is! Checking && state is! NoLocation && state is! Closed && state is! Rejected) ...[
                    _SketchCard(viewModel: viewModel, report: report),
                    const SizedBox(height: 16),
                  ],
                  if (report != null) _Payload(report: report, title: event.title, queued: state is Queued, t: t),
                  if (state is NotInZone || state is Imprecise) _Tips(bufferM: event.bufferM, t: t),
                ],
              ),
            ),
            _Actions(viewModel: viewModel, t: t),
          ],
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.state, required this.t, required this.bufferM});

  final PresenceState state;
  final CauseTheme t;
  final int bufferM;

  @override
  Widget build(BuildContext context) {
    final (icon, iconBg, iconFg, title, text) = switch (state) {
      Checking() => (
        FoulalaIcons.locate,
        Colors.white,
        t.deep,
        'Vérification…',
        'Lecture de votre position, une seule fois. Elle reste sur ce téléphone.',
      ),
      Sent(:final present) => (
        FoulalaIcons.check,
        t.primary,
        Colors.white,
        'Présence comptée !',
        present == null
            ? 'Merci ! Appuyer à nouveau ne vous compte pas deux fois.'
            : 'Merci ! Vous faites partie des ${formatCount(present)} présents vérifiés. '
                  'Appuyer à nouveau ne vous compte pas deux fois.',
      ),
      Queued() => (
        FoulalaIcons.wifiOff,
        t.deep,
        Colors.white,
        'En attente de réseau',
        'Vous êtes bien dans le cortège. Votre jeton est gardé sur ce téléphone et partira tout seul '
            'dès que le réseau revient, jusqu\'à 24 h après la manif.',
      ),
      NotInZone(:final distanceM) => (
        FoulalaIcons.locate,
        Colors.white,
        t.deep,
        'Pas encore dans le cortège',
        'Vous êtes à environ ${formatDistance(distanceM)} de la zone. Rapprochez-vous du parcours, '
            'puis réessayez. Rien n\'a été envoyé.',
      ),
      Imprecise(:final accuracyM) => (
        FoulalaIcons.locate,
        Colors.white,
        t.deep,
        'Position trop imprécise',
        'Le GPS est précis à ${accuracyM.round()} m, il en faut ${maxAccuracyM.round()}. '
            'Attendez quelques secondes à découvert, puis réessayez. Rien n\'a été envoyé.',
      ),
      Closed() => (
        FoulalaIcons.clock,
        Colors.white,
        t.deep,
        'Hors du créneau',
        'On ne peut dire « J’y suis » que pendant la manif, et dès 30 min avant le début. Rien n\'a été envoyé.',
      ),
      Rejected() => (
        FoulalaIcons.clock,
        Colors.white,
        t.deep,
        'Présence refusée',
        'Le serveur n\'accepte plus de présence pour cette manif (terminée ou annulée).',
      ),
      NoLocation(:final problem) => (
        FoulalaIcons.locate,
        Colors.white,
        t.deep,
        'Position indisponible',
        switch (problem) {
          LocationProblem.serviceDisabled =>
            'La localisation est désactivée sur ce téléphone. Activez-la, puis réessayez.',
          LocationProblem.denied => 'Foulala a besoin de votre position, une seule fois, pour vérifier sur ce téléphone que vous êtes dans la zone. Elle n\'est jamais envoyée.',
          LocationProblem.deniedForever => 'L\'accès à la position est refusé. Autorisez-le dans les réglages : la position est vérifiée sur ce téléphone et jamais envoyée.',
          LocationProblem.timeout => 'Le GPS n\'a pas répondu à temps. Placez-vous à découvert, puis réessayez.',
        },
      ),
    };

    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: state is Checking
                ? SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: t.deep, strokeWidth: 3))
                : FoulalaIcon(icon, size: 34, color: iconFg, strokeWidth: 2.6),
          ),
          const SizedBox(height: 14),
          Text(title, style: FoulalaText.display(36, height: 1.02, letterSpacing: -0.03)),
          const SizedBox(height: 10),
          Text(text, style: FoulalaText.body(16, height: 1.45, color: const Color(0xFF3D3A52))),
        ],
      ),
    );
  }
}

class _SketchCard extends StatelessWidget {
  const _SketchCard({required this.viewModel, required this.report});

  final PresenceViewModel viewModel;
  final PresenceReport? report;

  @override
  Widget build(BuildContext context) {
    final event = viewModel.event;
    final t = event.cause.theme;
    final fix = viewModel.fix;
    final state = viewModel.state;
    final segment = report?.segment;

    final caption = switch (state) {
      NotInZone(:final distanceM, :final accuracyM) => (
        '≈ ${formatDistance(distanceM)}',
        ' de la zone · GPS à ${accuracyM.round()} m près',
      ),
      Imprecise(:final accuracyM) => ('GPS à ${accuracyM.round()} m près', ''),
      _ when segment != null => ('Tronçon ${segment.number} sur ${segment.count}', ''),
      _ => ('Zone de présence', ' · ±${event.bufferM} m'),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(FoulalaRadius.card),
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(
              height: 150,
              child: ColoredBox(
                color: const Color(0xFFEEF0E8),
                child: RouteSketch(
                  route: event.route!,
                  zone: event.zone,
                  theme: t,
                  you: fix?.point,
                  padding: const EdgeInsets.all(18),
                  semanticLabel: state is NotInZone
                      ? 'Votre position, en dehors de la zone du cortège'
                      : 'Votre position et la zone du cortège',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: caption.$1, style: FoulalaText.body(14, weight: 800)),
                          TextSpan(text: caption.$2),
                        ],
                      ),
                      style: FoulalaText.body(14),
                    ),
                  ),
                  if (fix != null) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: FoulalaColors.text, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('Vous', style: FoulalaText.body(13, weight: 600, color: FoulalaColors.textMuted)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Ce qui part du téléphone » : exactement le contenu du PresenceReport, rien de plus.
class _Payload extends StatelessWidget {
  const _Payload({required this.report, required this.title, required this.queued, required this.t});

  final PresenceReport report;
  final String title;
  final bool queued;
  final CauseTheme t;

  @override
  Widget build(BuildContext context) {
    final segment = report.segment;
    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: FoulalaText.body(14, color: FoulalaColors.textMuted)),
          ),
          Expanded(child: value),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(FoulalaRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'CE QUI PART DU TÉLÉPHONE',
                  style: FoulalaText.body(13, weight: 800, letterSpacing: 13 * 0.08, color: t.deep),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: queued ? const Color(0xFFEDECF3) : t.soft,
                  borderRadius: BorderRadius.circular(FoulalaRadius.chip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FoulalaIcon(
                      queued ? FoulalaIcons.clock : FoulalaIcons.check,
                      size: 13,
                      color: queued ? FoulalaColors.text : t.deep,
                      strokeWidth: 2.6,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      queued ? 'En file d\'attente' : 'Envoyé',
                      style: FoulalaText.body(12, weight: 800, color: queued ? FoulalaColors.text : t.deep),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          row('Manif', Text(title, style: FoulalaText.body(14, weight: 700))),
          row('Jeton', Text(report.token.short, style: FoulalaText.mono(14))),
          row(
            'Créneau',
            Text(formatRange(report.slot.start, report.slot.end), style: FoulalaText.body(14, weight: 700)),
          ),
          row('Tronçon', Text(segment == null ? '—' : '${segment.number}', style: FoulalaText.body(14, weight: 700))),
          const SizedBox(height: 12),
          const _Dashed(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoulalaIcon(FoulalaIcons.lock, size: 18, color: t.deep),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Reste ici : ',
                        style: FoulalaText.body(14, weight: 700, color: FoulalaColors.text),
                      ),
                      const TextSpan(text: 'votre position GPS, votre identité, l\'heure exacte.'),
                    ],
                  ),
                  style: FoulalaText.body(14, height: 1.4, color: const Color(0xFF3D3A52)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dashed extends StatelessWidget {
  const _Dashed();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Row(
      children: List.generate(
        (c.maxWidth / 8).floor(),
        (i) => Container(width: 4, height: 2, margin: const EdgeInsets.only(right: 4), color: FoulalaColors.border),
      ),
    ),
  );
}

class _Tips extends StatelessWidget {
  const _Tips({required this.bufferM, required this.t});

  final int bufferM;
  final CauseTheme t;

  @override
  Widget build(BuildContext context) {
    Widget tip(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 7, right: 10),
            decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(text, style: FoulalaText.body(15, height: 1.4, color: const Color(0xFF3D3A52))),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(FoulalaRadius.card)),
      child: Column(
        children: [
          tip('La zone couvre $bufferM m de part et d\'autre du parcours.'),
          tip('Entre les immeubles, le GPS peut se tromper : attendez quelques secondes à découvert.'),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.viewModel, required this.t});

  final PresenceViewModel viewModel;
  final CauseTheme t;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;
    final (FoulalaIcons? icon, String label, VoidCallback? onPressed) = switch (state) {
      Checking() => (null, 'Vérification…', null),
      Sent() || Closed() || Rejected() => (null, 'Retour à la manif', () => Navigator.of(context).maybePop()),
      Queued() => (FoulalaIcons.refresh, 'Réessayer l\'envoi', viewModel.retrySending),
      NoLocation(problem: LocationProblem.deniedForever) => (null, 'Ouvrir les réglages', viewModel.openSettings),
      NotInZone() || Imprecise() || NoLocation() => (FoulalaIcons.refresh, 'Réessayer', viewModel.run),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: t.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FoulalaRadius.button)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[FoulalaIcon(icon, color: Colors.white, strokeWidth: 2.4), const SizedBox(width: 8)],
              Text(label, style: FoulalaText.display(19, color: onPressed == null ? null : Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
