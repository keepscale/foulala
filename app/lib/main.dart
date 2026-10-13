import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'data/repositories/city_repository_local.dart';
import 'data/repositories/event_repository_remote.dart';
import 'data/repositories/presence_repository_remote.dart';
import 'data/repositories/support_repository_remote.dart';
import 'data/services/foulala_api.dart';
import 'data/services/geolocator_location_reader.dart';
import 'data/services/local_store.dart';
import 'domain/repositories/city_repository.dart';
import 'domain/repositories/event_repository.dart';
import 'domain/repositories/location_reader.dart';
import 'domain/repositories/presence_repository.dart';
import 'domain/repositories/support_repository.dart';
import 'ui/core/themes/theme.dart';
import 'ui/home/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = FoulalaApi(Uri.parse(apiUrl), apiKey: apiKey);
  final store = LocalStore(SharedPreferencesAsync());

  runApp(
    MultiProvider(
      providers: [
        // L'interface vient du domaine, l'implémentation de la couche data.
        Provider<EventRepository>(create: (_) => EventRepositoryRemote(api)),
        Provider<CityRepository>(create: (_) => CityRepositoryLocal(store)),
        Provider<PresenceRepository>(create: (_) => PresenceRepositoryRemote(api, store)),
        Provider<SupportRepository>(create: (_) => SupportRepositoryRemote(api, store)),
        Provider<LocationReader>(create: (_) => GeolocatorLocationReader()),
      ],
      child: const FoulalaApp(),
    ),
  );
}

class FoulalaApp extends StatelessWidget {
  const FoulalaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foulala',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeShell(),
    );
  }
}
