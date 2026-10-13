import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/event.dart';
import 'view_models/counter_view_model.dart';
import 'widgets/counter_screen.dart';

/// Ouvre le compteur détaillé d'une manif. En direct, il se met à jour tout seul.
Route<void> counterRoute(Event event) => MaterialPageRoute(
      builder: (context) => ChangeNotifierProvider(
        create: (context) => CounterViewModel(event: event, events: context.read())..load(),
        child: Consumer<CounterViewModel>(builder: (_, vm, _) => CounterScreen(viewModel: vm)),
      ),
    );
