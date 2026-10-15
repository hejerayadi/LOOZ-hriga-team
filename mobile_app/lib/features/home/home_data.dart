// FAKE data for the "Mon verger" page. Edit freely.
// Later, this will come from the sensors / backend.
import '../../core/enums.dart';

/// One almond tree.
class Tree {
  const Tree({required this.name, required this.variety, required this.health});

  final String name;
  final String variety;
  final StatusLevel health;
}

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

// ----- The fake values -----

const int fakeTreeCount = 120;

const StatusLevel fakeOrchardHealth = StatusLevel.good;

const Weather fakeWeather = Weather(temperature: 27, humidity: 38, sunny: true);

const List<Tree> fakeTrees = [
  Tree(name: 'Arbre 3', variety: 'Ferragnès', health: StatusLevel.good),
  Tree(name: 'Arbre 7', variety: 'Achak', health: StatusLevel.warning),
  Tree(name: 'Arbre 12', variety: 'Ferraduel', health: StatusLevel.danger),
  Tree(name: 'Arbre 18', variety: 'Ferragnès', health: StatusLevel.good),
];
