import 'package:flutter/material.dart';

import '../../core/themes/theme.dart';
import '../../core/themes/tokens.g.dart';
import '../../core/ui/foulala_icon.dart';

/// Choix de la ville dans une feuille du bas. Renvoie la ville choisie, ou null.
Future<String?> showCityPicker(BuildContext context, {required List<String> cities, String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text('Choisir une ville', style: FoulalaText.display(26)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                "L'app n'a pas besoin de votre position pour lister les manifs.",
                style: FoulalaText.body(15, color: FoulalaColors.textMuted, height: 1.4),
              ),
            ),
            if (cities.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Text('Aucune manif publiée pour le moment.', style: FoulalaText.body(16)),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    for (final city in cities)
                      ListTile(
                        minTileHeight: 52,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                        leading: FoulalaIcon(FoulalaIcons.pin, color: FoulalaColors.brand[1], strokeWidth: 2.4),
                        title: Text(city, style: FoulalaText.body(17, weight: 700)),
                        trailing: city == current ? const FoulalaIcon(FoulalaIcons.check, strokeWidth: 2.6) : null,
                        selected: city == current,
                        onTap: () => Navigator.of(context).pop(city),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
