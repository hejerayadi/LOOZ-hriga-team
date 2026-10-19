// FAKE data for the "Mon verger" page. Edit freely.
// The orchard itself (zones, trees, photos) comes from the same fake data as
// the 3D view (orchard_3d_data.dart), so both screens always agree.
import '../../core/enums.dart';
import '../orchard_3d/orchard_3d_data.dart';

/// Today's weather.
class Weather {
  const Weather({
    required this.temperature,
    required this.humidity,
    required this.sunny,
  });

  final int temperature; // °C
  final int humidity; // %
  final bool sunny;
}

/// A tree that has a photo diagnosis (the only tree-level information).
class TreeWithPhoto {
  const TreeWithPhoto({
    required this.name,
    required this.zoneName,
    required this.photo,
  });

  final String name;
  final String zoneName;
  final TreePhoto photo;
}

// ----- The fake values -----

const Weather fakeWeather = Weather(temperature: 27, humidity: 38, sunny: true);

/// Number of trees in the orchard.
int orchardTreeCount() => fakeTrees().length;

/// Health of the orchard = health of its weakest zone.
StatusLevel orchardHealth() => fakeZones
    .map((zone) => zone.health)
    .reduce((a, b) => a.index >= b.index ? a : b);

/// Trees with a photo diagnosis, newest photo first.
List<TreeWithPhoto> treesWithPhotos() {
  final trees = {for (final tree in fakeTrees()) tree.number: tree};
  final list = [
    for (final photo in latestPhotos().values)
      TreeWithPhoto(
        name: 'Arbre ${photo.treeNumber}',
        zoneName: zoneById(trees[photo.treeNumber]!.zoneId!).name,
        photo: photo,
      ),
  ];
  list.sort((a, b) => b.photo.createdAt.compareTo(a.photo.createdAt));
  return list;
}
