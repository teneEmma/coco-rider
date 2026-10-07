/// Main cities with the coordinates of their centre. Used until a map picker is added:
/// the driver picks the city and types a landmark ("Carrefour Ndokoti", "Total Mvan").
class CameroonCity {
  final String name;
  final double latitude;
  final double longitude;

  const CameroonCity(this.name, this.latitude, this.longitude);
}

class CameroonCities {
  static const all = [
    CameroonCity('Douala', 4.0511, 9.7679),
    CameroonCity('Yaoundé', 3.8480, 11.5021),
    CameroonCity('Bafoussam', 5.4781, 10.4176),
    CameroonCity('Bamenda', 5.9631, 10.1591),
    CameroonCity('Buea', 4.1527, 9.2410),
    CameroonCity('Limbé', 4.0186, 9.2043),
    CameroonCity('Kribi', 2.9404, 9.9101),
    CameroonCity('Edéa', 3.8000, 10.1333),
    CameroonCity('Nkongsamba', 4.9547, 9.9404),
    CameroonCity('Dschang', 5.4500, 10.0667),
    CameroonCity('Kumba', 4.6363, 9.4469),
    CameroonCity('Ebolowa', 2.9000, 11.1500),
    CameroonCity('Bertoua', 4.5772, 13.6848),
    CameroonCity('Ngaoundéré', 7.3167, 13.5833),
    CameroonCity('Garoua', 9.3000, 13.4000),
    CameroonCity('Maroua', 10.5956, 14.3247),
  ];

  /// The city whose centre is closest to the position (flat-earth approximation, fine at this scale).
  static CameroonCity nearest(double latitude, double longitude) {
    double distance(CameroonCity c) {
      final dLat = c.latitude - latitude;
      final dLng = (c.longitude - longitude) * 0.99; // cos(~8°N), Cameroon's mid latitude
      return dLat * dLat + dLng * dLng;
    }

    return all.reduce((a, b) => distance(a) <= distance(b) ? a : b);
  }

  static const _accents = {'à': 'a', 'â': 'a', 'ä': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u'};

  /// "Yaoundé" → "yaounde", to compare city names whatever the case and accents (as the API does).
  static String fold(String text) =>
      text.trim().toLowerCase().split('').map((c) => _accents[c] ?? c).join();

  static CameroonCity? byName(String name) {
    for (final city in all) {
      if (city.name.toLowerCase() == name.trim().toLowerCase()) return city;
    }
    return null;
  }
}
