import '../../domain/repositories/city_repository.dart';
import '../services/local_store.dart';

/// Ville choisie, gardée dans le stockage local du téléphone.
class CityRepositoryLocal implements CityRepository {
  CityRepositoryLocal(this._store);

  final LocalStore _store;

  @override
  Future<String?> getCity() => _store.getCity();

  @override
  Future<void> setCity(String city) => _store.setCity(city);
}
