/// Decoration a reader can stand on their shelf boards.
enum DecorItem {
  plant('🪴', 'Pflanze'),
  cactus('🌵', 'Kaktus'),
  flowers('💐', 'Blumen'),
  candle('🕯️', 'Kerze'),
  mug('☕', 'Tasse'),
  cat('🐈', 'Katze'),
  teddy('🧸', 'Teddy'),
  trophy('🏆', 'Pokal'),
  picture('🖼️', 'Bild'),
  hourglass('⏳', 'Sanduhr'),
  globe('🌍', 'Globus'),
  camera('📷', 'Kamera');

  const DecorItem(this.emoji, this.label);
  final String emoji;
  final String label;
}

/// One piece on board [row], slot [slot] (left to right).
class DecorPiece {
  const DecorPiece(this.item, this.row, this.slot);

  final DecorItem item;
  final int row;
  final int slot;

  /// Same limits as the database check (private.valid_shelf_decor).
  static const maxPieces = 16, maxRow = 49, maxSlot = 5;

  Map<String, dynamic> toJson() => {'i': item.name, 'r': row, 's': slot};

  static DecorPiece? fromJson(Object? json) {
    if (json is! Map) return null;
    final item = DecorItem.values.where((d) => d.name == json['i']).firstOrNull;
    final row = json['r'], slot = json['s'];
    if (item == null || row is! int || slot is! int) return null;
    return DecorPiece(item, row, slot);
  }

  /// Unknown or broken entries are skipped instead of failing the profile.
  static List<DecorPiece> listFromJson(Object? json) => [
    if (json is List)
      for (final e in json) ?fromJson(e),
  ];
}

/// One place on a board: a book, a decoration, or empty.
sealed class ShelfSlot<T> {
  const ShelfSlot(this.row, this.slot);
  final int row;
  final int slot;
}

class BookSlot<T> extends ShelfSlot<T> {
  const BookSlot(this.book, super.row, super.slot);
  final T book;
}

class DecorSlot<T> extends ShelfSlot<T> {
  DecorSlot(this.piece) : super(piece.row, piece.slot);
  final DecorPiece piece;
}

class EmptySlot<T> extends ShelfSlot<T> {
  const EmptySlot(super.row, super.slot);
}

/// Boards of [cols] slots: decoration keeps its place, books fill the other
/// slots in order. At least [minRows] boards and enough for every book and
/// piece, plus [extraRows] empty boards (room to decorate). Pieces in a slot
/// beyond [cols] (placed on a wider screen) are not shown.
List<List<ShelfSlot<T>>> layoutShelf<T>(
  List<T> books,
  List<DecorPiece> decor, {
  required int cols,
  int minRows = 1,
  int extraRows = 0,
}) {
  final pieces = {
    for (final p in decor)
      if (p.slot < cols) (p.row, p.slot): p,
  };
  final lastDecorRow = pieces.keys.fold(-1, (m, k) => k.$1 > m ? k.$1 : m);
  final rows = <List<ShelfSlot<T>>>[];
  var next = 0;
  for (
    var r = 0;
    next < books.length || r <= lastDecorRow || r < minRows;
    r++
  ) {
    rows.add([
      for (var s = 0; s < cols; s++)
        if (pieces[(r, s)] case final piece?)
          DecorSlot<T>(piece)
        else if (next < books.length)
          BookSlot<T>(books[next++], r, s)
        else
          EmptySlot<T>(r, s),
    ]);
  }
  for (var e = 0; e < extraRows; e++) {
    final r = rows.length;
    rows.add([for (var s = 0; s < cols; s++) EmptySlot<T>(r, s)]);
  }
  return rows;
}
