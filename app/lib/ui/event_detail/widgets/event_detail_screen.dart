import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/event.dart';
import '../../../domain/repositories/support_repository.dart';
import '../../counter/counter_route.dart';
import '../../core/format.dart';
import '../../core/themes/theme.dart';
import '../../core/themes/tokens.g.dart';
import '../../core/ui/foulala_icon.dart';
import '../../core/ui/round_button.dart';
import '../../core/ui/route_sketch.dart';
import '../../presence/presence_route.dart';
import '../view_models/event_detail_view_model.dart';

/// Ouvre le détail d'une manif. Le ViewModel vit le temps de l'écran.
Route<void> eventDetailRoute(String eventId) => MaterialPageRoute(
      builder: (context) => ChangeNotifierProvider(
        create: (context) => EventDetailViewModel(
          eventId: eventId,
          events: context.read(),
          presence: context.read(),
          supports: context.read(),
        )
          ..load(),
        child: Consumer<EventDetailViewModel>(builder: (_, vm, _) => EventDetailScreen(viewModel: vm)),
      ),
    );

/// Détail d'une manif (maquette design/maquettes/Detail.dc.html).
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.viewModel});

  final EventDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final summary = viewModel.summary;
    if (summary == null) {
      return Scaffold(
        body: SafeArea(
          child: Stack(children: [
            Center(
              child: viewModel.failed
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Impossible de charger la manif.', style: FoulalaText.body(16)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: viewModel.load, child: const Text('Réessayer')),
                    ])
                  : const CircularProgressIndicator(),
            ),
            const Positioned(top: 12, left: 16, child: _Back()),
          ]),
        ),
      );
    }

    final event = summary.event;
    final t = event.cause.theme;
    final now = viewModel.now;

    return Scaffold(
      backgroundColor: t.soft,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: viewModel.load,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _Header(event: event),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _Chip(
                            background: t.primary,
                            color: Colors.white,
                            icon: FoulalaIcons.forCause(event.cause),
                            label: t.label,
                          ),
                          if (event.isCancelled)
                            const _Chip(background: FoulalaColors.text, color: Colors.white, label: 'Annulée')
                          else if (event.isLive(now))
                            _Chip(background: Colors.white, color: FoulalaColors.text, dot: t.primary, label: 'En direct'),
                          if (event.declared)
                            _Chip(background: Colors.white, color: t.deep, icon: FoulalaIcons.check, label: 'Déclarée'),
                        ]),
                        const SizedBox(height: 13),
                        Text(event.title, style: FoulalaText.display(34, height: 1.02, letterSpacing: -0.03)),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'par '),
                            TextSpan(text: event.organizer, style: FoulalaText.body(15, weight: 700, color: FoulalaColors.text)),
                            TextSpan(text: ' · ${formatDay(event.startsAt, now: now)}'),
                          ]),
                          style: FoulalaText.body(15, color: FoulalaColors.textMuted),
                        ),
                        const SizedBox(height: 13),
                        Row(children: [
                          Expanded(child: _Tile(t: t, icon: FoulalaIcons.clock, label: 'Horaires', value: formatRange(event.startsAt, event.endsAt))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Tile(
                              t: t,
                              icon: FoulalaIcons.route,
                              label: 'Parcours',
                              value: event.route == null ? '—' : formatDistance(event.route!.lengthM),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Tile(
                              t: t,
                              icon: FoulalaIcons.people,
                              label: 'Présents',
                              value: '≥ ${formatCount(summary.count.present)}',
                              valueColor: t.deep,
                            ),
                          ),
                        ]),
                        if (viewModel.hasCounter) ...[
                          const SizedBox(height: 8),
                          _CounterLink(event: event, live: event.isLive(now)),
                        ],
                        if (event.description != null) ...[
                          const SizedBox(height: 13),
                          Text(event.description!, style: FoulalaText.body(16, height: 1.4)),
                        ],
                        if (event.demands.isNotEmpty) ...[
                          const SizedBox(height: 13),
                          _Demands(demands: event.demands, t: t),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _ActionBar(viewModel: viewModel, event: event),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final t = event.cause.theme;
    final top = MediaQuery.paddingOf(context).top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(FoulalaRadius.sheet)),
      child: Container(
        height: 250 + top,
        color: const Color(0xFFEEF0E8),
        child: Stack(
          children: [
            if (event.route != null)
              Positioned.fill(
                top: top + 56,
                bottom: 8,
                child: RouteSketch(
                  route: event.route!,
                  zone: event.zone,
                  theme: t,
                  padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
                  semanticLabel: 'Schéma du parcours avec la zone de présence',
                ),
              ),
            // Bande décorative aux couleurs de la cause.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 8,
              child: Row(children: [for (final c in t.stripe) Expanded(child: ColoredBox(color: c))]),
            ),
            Positioned(top: top + 12, left: 16, child: const _Back()),
            Positioned(
              left: 14,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(FoulalaRadius.chip),
                  boxShadow: [BoxShadow(color: FoulalaColors.text.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 16,
                    height: 10,
                    decoration: BoxDecoration(color: t.mid, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 8),
                  Text('Zone de présence · ±${event.bufferM} m', style: FoulalaText.body(13, weight: 700)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) => RoundButton(
        icon: FoulalaIcons.arrowLeft,
        label: 'Retour',
        onPressed: () => Navigator.of(context).maybePop(),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.background, required this.color, required this.label, this.icon, this.dot});

  final Color background;
  final Color color;
  final String label;
  final FoulalaIcons? icon;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Container(
        height: 30,
        padding: EdgeInsets.only(left: icon != null || dot != null ? 9 : 12, right: 12),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(FoulalaRadius.chip)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[FoulalaIcon(icon!, size: 16, color: color, strokeWidth: 2.4), const SizedBox(width: 6)],
          if (dot != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label, style: FoulalaText.body(14, weight: 800, color: color)),
        ]),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.t, required this.icon, required this.label, required this.value, this.valueColor});

  final CauseTheme t;
  final FoulalaIcons icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: FoulalaIcon(icon, size: 16, color: t.deep),
          ),
          const SizedBox(height: 6),
          Text(label, style: FoulalaText.body(12, weight: 600, color: FoulalaColors.textMuted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: FoulalaText.body(15, weight: 800, color: valueColor ?? FoulalaColors.text)),
          ),
        ]),
      );
}

class _Demands extends StatelessWidget {
  const _Demands({required this.demands, required this.t});

  final List<String> demands;
  final CauseTheme t;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(FoulalaRadius.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            header: true,
            child: Text('REVENDICATIONS', style: FoulalaText.body(13, weight: 800, letterSpacing: 13 * 0.08, color: t.deep)),
          ),
          for (var i = 0; i < demands.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('${i + 1}', style: FoulalaText.display(14, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(demands[i], style: FoulalaText.body(16, weight: 600, height: 1.3)),
                  ),
                ),
              ]),
            ),
        ]),
      );
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.viewModel, required this.event});

  final EventDetailViewModel viewModel;
  final Event event;

  @override
  Widget build(BuildContext context) {
    final t = event.cause.theme;
    final state = viewModel.presenceButton;
    final (String title, String? subtitle) = switch (state) {
      PresenceButton.open => ('J’y suis !', null),
      PresenceButton.notYet => ('J’y suis', 'Dès ${formatTime(event.opensAt)} le jour J'),
      PresenceButton.over => ('Terminée', null),
      PresenceButton.cancelled => ('Annulée', null),
      PresenceButton.unavailable => ('J’y suis', 'Parcours indisponible'),
    };
    final enabled = state == PresenceButton.open;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(FoulalaRadius.sheet)),
        boxShadow: [BoxShadow(color: FoulalaColors.text.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (viewModel.pending)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Votre présence attend le réseau : elle partira toute seule.',
              style: FoulalaText.body(14, weight: 700, color: t.deep),
              textAlign: TextAlign.center,
            ),
          ),
        Row(children: [
          if (viewModel.canSupport) ...[
            Expanded(flex: 10, child: _SupportButton(viewModel: viewModel, t: t)),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 13,
            child: SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: enabled
                ? () async {
                    await Navigator.of(context).push(presenceRoute(event));
                    await viewModel.load();
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: t.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFEDECF3),
              disabledForegroundColor: const Color(0xFF4D4A63),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FoulalaRadius.button)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (enabled) ...[const FoulalaIcon(FoulalaIcons.pin, color: Colors.white, strokeWidth: 2.4), const SizedBox(width: 8)],
                Text(title, style: FoulalaText.display(20, color: enabled ? Colors.white : const Color(0xFF4D4A63))),
              ]),
              if (subtitle != null) Text(subtitle, style: FoulalaText.body(12, weight: 600, color: const Color(0xFF4D4A63))),
            ]),
          ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const FoulalaIcon(FoulalaIcons.lock, size: 15, color: FoulalaColors.textMuted),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Position vérifiée sur ce téléphone, jamais envoyée.',
              style: FoulalaText.body(13, color: FoulalaColors.textMuted),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Ouvre le compteur détaillé (maquette Compteur).
class _CounterLink extends StatelessWidget {
  const _CounterLink({required this.event, required this.live});

  final Event event;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final t = event.cause.theme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(counterRoute(event)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              if (live) ...[
                Container(width: 8, height: 8, decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  live ? 'Compteur en direct' : 'Voir le compteur',
                  style: FoulalaText.body(15, weight: 800, color: t.deep),
                ),
              ),
              Text('arrivées, tronçons', style: FoulalaText.body(13, color: FoulalaColors.textMuted)),
              const SizedBox(width: 6),
              FoulalaIcon(FoulalaIcons.arrowRight, size: 18, color: t.deep),
            ]),
          ),
        ),
      ),
    );
  }
}

/// « Je soutiens » : sans GPS, à tout moment avant l'annulation. Un soutien ne se retire pas :
/// il est anonyme, le serveur ne sait pas de quel téléphone il vient.
class _SupportButton extends StatelessWidget {
  const _SupportButton({required this.viewModel, required this.t});

  final EventDetailViewModel viewModel;
  final CauseTheme t;

  Future<void> _onPressed(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (viewModel.supported) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Votre soutien est compté. Il est anonyme : il ne peut pas être retiré.'),
      ));
      return;
    }
    final outcome = await viewModel.support();
    final message = switch (outcome) {
      SupportOutcome.sent => 'Merci ! Votre soutien est compté. La manif rejoint « Mes soutiens ».',
      SupportOutcome.offline => 'Pas de réseau : réessayez dans un moment.',
      SupportOutcome.rejected => "Cette manif n'accepte plus de soutiens.",
      null => null,
    };
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final supported = viewModel.supported;
    final color = supported ? Colors.white : t.deep;
    return Semantics(
      toggled: supported,
      child: SizedBox(
        height: 56,
        child: FilledButton(
          onPressed: viewModel.supporting ? null : () => _onPressed(context),
          style: FilledButton.styleFrom(
            backgroundColor: supported ? t.deep : t.soft,
            foregroundColor: color,
            disabledBackgroundColor: t.soft,
            disabledForegroundColor: t.deep,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FoulalaRadius.button)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (viewModel.supporting)
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: t.deep))
            else
              FoulalaIcon(FoulalaIcons.heart, size: 20, color: color, strokeWidth: 2.4, filled: supported),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                supported ? 'Soutenu' : 'Je soutiens',
                style: FoulalaText.body(17, weight: 800, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
