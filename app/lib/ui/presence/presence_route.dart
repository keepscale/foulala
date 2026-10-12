import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/event.dart';
import 'view_models/presence_view_model.dart';
import 'widgets/presence_screen.dart';

/// Ouvre l'écran « J'y suis ! » et lance la vérification tout de suite.
Route<void> presenceRoute(Event event) => MaterialPageRoute(
      builder: (context) => ChangeNotifierProvider(
        create: (context) => PresenceViewModel(
          event: event,
          presence: context.read(),
          location: context.read(),
          events: context.read(),
        )..run(),
        child: Consumer<PresenceViewModel>(builder: (_, vm, _) => PresenceScreen(viewModel: vm)),
      ),
    );
