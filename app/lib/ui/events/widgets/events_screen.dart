import 'package:flutter/material.dart';

import '../../core/themes/theme.dart';
import '../../core/themes/tokens.g.dart';
import '../../core/ui/foulala_icon.dart';
import '../../core/ui/logo.dart';
import '../../event_detail/widgets/event_detail_screen.dart';
import '../view_models/events_view_model.dart';
import 'cause_filter_bar.dart';
import 'city_picker.dart';
import 'event_row.dart';
import 'live_event_card.dart';

/// Liste des manifs d'une ville (maquette design/maquettes/Main.dc.html).
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.viewModel});

  final EventsViewModel viewModel;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _pickerShown = false;

  EventsViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    vm.addListener(_askCityOnFirstLaunch);
  }

  @override
  void dispose() {
    vm.removeListener(_askCityOnFirstLaunch);
    super.dispose();
  }

  /// Premier lancement : aucune ville enregistrée, on propose d'en choisir une.
  void _askCityOnFirstLaunch() {
    if (_pickerShown || !vm.needsCity || vm.failed) return;
    _pickerShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickCity());
  }

  /// Détail d'une manif ; au retour, les compteurs sont relus.
  Future<void> _open(String eventId) async {
    await Navigator.of(context).push(eventDetailRoute(eventId));
    await vm.refresh();
  }

  Future<void> _pickCity() async {
    final city = await showCityPicker(context, cities: vm.availableCities, current: vm.city);
    if (city != null) await vm.selectCity(city);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final now = DateTime.now();
        final live = vm.live;
        final upcoming = vm.upcoming;
        final past = vm.past;
        final empty = live.isEmpty && upcoming.isEmpty && past.isEmpty;

        return RefreshIndicator(
          onRefresh: vm.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(city: vm.city, onPickCity: _pickCity)),
              if (vm.causes.length > 1)
                SliverPadding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  sliver: SliverToBoxAdapter(
                    child: CauseFilterBar(causes: vm.causes, selected: vm.filter, onSelected: vm.setFilter),
                  ),
                ),
              if (vm.failed && empty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Message(
                    title: 'Pas de réseau ?',
                    text: 'Impossible de charger les manifs.',
                    action: 'Réessayer',
                    onAction: vm.refresh,
                  ),
                )
              else if (vm.loading && empty)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
              else if (vm.city != null && empty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Message(
                    title: 'Rien de prévu',
                    text: 'Aucune manif publiée à ${vm.city} pour le moment.',
                    action: 'Changer de ville',
                    onAction: _pickCity,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverList.list(children: [
                    if (live.isNotEmpty) ...[
                      const _SectionTitle('En ce moment'),
                      for (final s in live) ...[
                        LiveEventCard(summary: s, onTap: () => _open(s.event.id)),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (upcoming.isNotEmpty) ...[
                      const _SectionTitle('À venir'),
                      for (final s in upcoming) ...[
                        EventRow(summary: s, now: now, onTap: () => _open(s.event.id)),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (past.isNotEmpty) ...[
                      const _SectionTitle('Terminées'),
                      for (final s in past) ...[
                        EventRow(summary: s, now: now, onTap: () => _open(s.event.id)),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.city, required this.onPickCity});

  final String? city;
  final VoidCallback onPickCity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const FoulalaLogo(),
              Semantics(
                button: true,
                label: city == null ? 'Choisir une ville' : 'Changer de ville, ville actuelle : $city',
                excludeSemantics: true,
                child: Material(
                  color: FoulalaColors.surface,
                  shape: const StadiumBorder(),
                  elevation: 1,
                  shadowColor: FoulalaColors.text.withValues(alpha: 0.12),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: onPickCity,
                    child: SizedBox(
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 14),
                        child: Row(children: [
                          FoulalaIcon(FoulalaIcons.pin, size: 18, color: FoulalaColors.brand[1], strokeWidth: 2.4),
                          const SizedBox(width: 6),
                          Text(city ?? 'Ville', style: FoulalaText.body(16, weight: 700)),
                          const SizedBox(width: 6),
                          const FoulalaIcon(FoulalaIcons.chevronDown, size: 16, strokeWidth: 2.4),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(city == null ? 'Manifs' : 'Manifs à $city', style: FoulalaText.display(38, height: 1, letterSpacing: -0.03)),
          const SizedBox(height: 12),
          Text(
            "Choisissez une ville : l'app n'a pas besoin de votre position pour lister les manifs.",
            style: FoulalaText.body(15, height: 1.4, color: FoulalaColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
        child: Semantics(
          header: true,
          child: Text(
            text.toUpperCase(),
            style: FoulalaText.body(13, weight: 800, letterSpacing: 13 * 0.08, color: FoulalaColors.textMuted),
          ),
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.text, required this.action, required this.onAction});

  final String title;
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: FoulalaText.display(26), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(text, style: FoulalaText.body(16, color: FoulalaColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: const StadiumBorder(),
                textStyle: FoulalaText.body(16, weight: 700),
              ),
              child: Text(action),
            ),
          ],
        ),
      );
}
