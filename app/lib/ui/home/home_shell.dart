import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/repositories/presence_repository.dart';
import '../core/themes/theme.dart';
import '../core/themes/tokens.g.dart';
import '../core/ui/foulala_icon.dart';
import '../events/view_models/events_view_model.dart';
import '../events/widgets/events_screen.dart';
import '../privacy/privacy_screen.dart';
import '../supports/supports_screen.dart';
import '../supports/view_models/supports_view_model.dart';

/// Écran principal : trois onglets, barre de navigation en bas (maquette Main).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  late final EventsViewModel _events = EventsViewModel(events: context.read(), cities: context.read())..load();
  late final SupportsViewModel _supports = SupportsViewModel(supports: context.read())..load();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Présences en attente de réseau : renvoyées au démarrage et à chaque retour dans l'app.
    _flushPending();
    _lifecycle = AppLifecycleListener(onResume: _flushPending);
  }

  void _flushPending() {
    context.read<PresenceRepository>().flushPending(now: DateTime.now()).catchError((Object _) {});
  }

  void _select(int tab) {
    // Un soutien a pu être ajouté depuis le détail d'une manif.
    if (tab == 1) _supports.load();
    setState(() => _tab = tab);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _events.dispose();
    _supports.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            EventsScreen(viewModel: _events),
            SupportsScreen(viewModel: _supports),
            const PrivacyScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _NavBar(selected: _tab, onSelected: _select),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const _items = [
    (FoulalaIcons.list, 'Manifs'),
    (FoulalaIcons.heart, 'Mes soutiens'),
    (FoulalaIcons.shield, 'Vie privée'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FoulalaColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: FoulalaColors.text.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(child: _NavItem(icon: _items[i].$1, label: _items[i].$2, selected: i == selected, onTap: () => onSelected(i))),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final FoulalaIcons icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? FoulalaColors.text : FoulalaColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FoulalaIcon(icon, color: color, strokeWidth: selected ? 2.2 : 2),
            const SizedBox(height: 3),
            Text(label, style: FoulalaText.body(12, weight: selected ? 800 : 600, color: color)),
            const SizedBox(height: 3),
            // Onglet actif : les trois couleurs de la marque, en plus du texte en gras.
            SizedBox(
              height: 4,
              child: selected
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final c in FoulalaColors.brand)
                        Container(
                          width: 6,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
                        ),
                    ])
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
