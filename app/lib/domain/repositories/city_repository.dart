/// Ville choisie par l'utilisateur : gardée sur le téléphone, jamais déduite de sa position.
abstract interface class CityRepository {
  Future<String?> getCity();

  Future<void> setCity(String city);
}
