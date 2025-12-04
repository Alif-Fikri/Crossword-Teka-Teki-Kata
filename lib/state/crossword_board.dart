class CellPosition {
  const CellPosition(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CellPosition && other.row == row && other.col == col;
  }

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

class BoardCell {
  BoardCell({
    required this.row,
    required this.col,
    this.isBlock = false,
    this.solution = '',
    this.acrossWordIndex,
    this.downWordIndex,
    String? entry,
  }) : entry = entry ?? '';

  final int row;
  final int col;
  final bool isBlock;
  final String solution;
  final int? acrossWordIndex;
  final int? downWordIndex;
  String entry;

  bool get isEditable => !isBlock;
  bool get isFilled => entry.isNotEmpty;
  bool get isCorrect => entry.toUpperCase() == solution.toUpperCase();

  BoardCell copyWith({String? entry}) {
    return BoardCell(
      row: row,
      col: col,
      isBlock: isBlock,
      solution: solution,
      acrossWordIndex: acrossWordIndex,
      downWordIndex: downWordIndex,
      entry: entry ?? this.entry,
    );
  }
}
