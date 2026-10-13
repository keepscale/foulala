import 'package:flutter/material.dart';

import '../../domain/models/event.dart';
import '../core/themes/theme.dart';
import '../core/themes/tokens.g.dart';
import '../core/ui/foulala_icon.dart';
import '../event_detail/widgets/event_detail_screen.dart';
import '../events/widgets/event_row.dart';
import 'view_models/supports_view_model.dart';

/// Manifs soutenues depuis ce téléphone. La liste vit sur le téléphone : le serveur ne reçoit
/// qu'un jeton par soutien et ne sait pas qui soutient quoi.
class SupportsScreen extends StatelessWidget {
  const SupportsScreen({super.key, required this.viewModel});

  final SupportsViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => RefreshIndicator(
          onRefresh: viewModel.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Text('Mes soutiens', style: FoulalaText.display(38, height: 1, letterSpacing: -0.03)),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: FoulalaIcon(FoulalaIcons.lock, size: 16, color: FoulalaColors.textMuted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cette liste reste sur votre téléphone : le serveur ne sait pas qui soutient quoi.',
                    style: FoulalaText.body(15, height: 1.4, color: FoulalaColors.textMuted),
                  ),
                ),
              ]),
              if (viewModel.loaded && viewModel.isEmpty) ...[
                const SizedBox(height: 28),
                const _Empty(),
              ],
              if (viewModel.upcoming.isNotEmpty) ..._group(context, 'À venir et en cours', viewModel.upcoming),
              if (viewModel.past.isNotEmpty) ..._group(context, 'Terminées', viewModel.past),
            ],
          ),
        ),
      );

  List<Widget> _group(BuildContext context, String title, List<Event> events) => [
        const SizedBox(height: 24),
        Semantics(header: true, child: Text(title, style: FoulalaText.display(22))),
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: EventRow(
              summary: EventSummary(e, EventCount.zero),
              now: viewModel.now,
              showCount: false,
              onTap: () async {
                await Navigator.of(context).push(eventDetailRoute(e.id));
                await viewModel.load();
              },
            ),
          ),
      ];
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(color: FoulalaColors.surface, borderRadius: BorderRadius.circular(FoulalaRadius.card)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FoulalaIcon(FoulalaIcons.heart, size: 26, color: Color(0xFFFF5FA2), strokeWidth: 2.4),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pas encore de soutien. Sur le détail d’une manif, appuyez sur « Je soutiens » : '
              'pas besoin d’y être, ni de GPS.',
              style: FoulalaText.body(16, height: 1.4),
            ),
          ),
        ]),
      );
}
