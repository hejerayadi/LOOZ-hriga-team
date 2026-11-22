// What the farmer does to the outline (step 1), with undo and redo:
// corners tapped one by one, a shape drawn with the finger, corners moved,
// the size typed, everything erased. No screen here (tested alone).
import '../../data/orchard_service.dart';
import 'geometry.dart';

/// What still stops the "next" button.
enum OutlineProblem {
  /// Not closed yet (or nothing drawn).
  open,

  /// Smaller than an orchard can be.
  tooSmall,

  /// Two sides cross.
  crossing,
}

/// An orchard is at least 100 m² (the database itself accepts 10 m²).
const minOrchardArea = 100.0;

class OutlineEditor {
  /// [photo] = where the photo of a sketch is on the grid ("من صورة"):
  /// it is stretched with the shape when the size is typed. null = no photo
  /// (the hand drawing: nothing changes).
  OutlineEditor([List<OrchardPoint> start = const [], Bounds? photo])
    : _points = List.of(start),
      _closed = start.length >= 3,
      _photo = photo;

  List<OrchardPoint> _points;
  bool _closed;
  Bounds? _photo;
  final _undo = <(List<OrchardPoint>, bool, Bounds?)>[];
  final _redo = <(List<OrchardPoint>, bool, Bounds?)>[];

  List<OrchardPoint> get points => List.unmodifiable(_points);

  /// The photo's place on the grid (metres), or null.
  Bounds? get photo => _photo;
  bool get closed => _closed;
  bool get isEmpty => _points.isEmpty;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void _remember() {
    _undo.add((List.of(_points), _closed, _photo));
    _redo.clear();
  }

  /// Tap (corners mode): one more corner.
  void addCorner(OrchardPoint p) {
    if (_closed) return;
    _remember();
    _points.add(p);
  }

  /// true = [p] is near the first corner and the shape can be closed.
  bool nearFirst(OrchardPoint p, double radius) =>
      !_closed && _points.length >= 3 && distance(p, _points.first) <= radius;

  /// Closes the shape (the last corner joins the first).
  void close() {
    if (_closed || _points.length < 3) return;
    _remember();
    _closed = true;
  }

  /// The finger drew a shape (already cleaned: closed, straight sides).
  void setShape(List<OrchardPoint> shape) {
    _remember();
    _points = List.of(shape);
    _closed = true;
  }

  /// The corner nearest to [p], within [radius] (metres); null = none.
  int? cornerAt(OrchardPoint p, double radius) {
    int? best;
    var bestDistance = radius;
    for (final (i, q) in _points.indexed) {
      final d = distance(p, q);
      if (d <= bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  /// A corner is moved: one undo step for the whole move.
  void startMove() => _remember();
  void moveCorner(int index, OrchardPoint p) => _points[index] = p;

  /// The size typed (metres): the shape is stretched to it.
  void scaleTo(double width, double length) {
    if (_points.length < 3) return;
    _remember();
    final photo = _photo;
    if (photo != null) {
      // The same stretch as the shape (see scaleToSize).
      final b = boundsOf(_points);
      final sx = b.width > 0 ? width / b.width : 1.0;
      final sz = b.length > 0 ? length / b.length : 1.0;
      final c = b.center;
      _photo = Bounds(
        (photo.minX - c.x) * sx,
        (photo.minZ - c.z) * sz,
        (photo.maxX - c.x) * sx,
        (photo.maxZ - c.z) * sz,
      );
    }
    _points = scaleToSize(_points, width, length);
  }

  /// Everything erased ("امسح"). Can be undone.
  void erase() {
    if (_points.isEmpty) return;
    _remember();
    _points = [];
    _closed = false;
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add((List.of(_points), _closed, _photo));
    _restore(_undo.removeLast());
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add((List.of(_points), _closed, _photo));
    _restore(_redo.removeLast());
  }

  void _restore((List<OrchardPoint>, bool, Bounds?) state) {
    _points = state.$1;
    _closed = state.$2;
    _photo = state.$3;
  }

  OutlineProblem? get problem {
    if (!_closed || _points.length < 3) return OutlineProblem.open;
    // Crossing first: the area of a crossed shape means nothing (its two
    // halves cancel out).
    if (edgesCross(_points)) return OutlineProblem.crossing;
    if (polygonArea(_points) < minOrchardArea) return OutlineProblem.tooSmall;
    return null;
  }

  /// The outline as saved: centred at (0, 0), to the centimetre.
  List<OrchardPoint> get saved => rounded(centered(_points));
}
