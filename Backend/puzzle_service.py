from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from threading import RLock
from typing import Dict, List
from uuid import uuid4


@dataclass(frozen=True)
class WordPlacement:
    answer: str
    row: int
    col: int
    direction: str
    clue: str


@dataclass(frozen=True)
class Puzzle:
    width: int
    height: int
    grid: List[str]
    words: List[WordPlacement]


@dataclass(frozen=True)
class GameSession:
    session_id: str
    player_name: str
    started_at: datetime
    puzzle: Puzzle


class CrosswordService:
    """Layanan pemuatan puzzle dan manajemen sesi sederhana."""

    def __init__(self, puzzle_path: Path):
        self._lock = RLock()
        self._sessions: Dict[str, GameSession] = {}
        self._puzzle = self._load_puzzle(puzzle_path)

    @property
    def puzzle(self) -> Puzzle:
        return self._puzzle

    def start_session(self, player_name: str) -> GameSession:
        with self._lock:
            session_id = uuid4().hex
            session = GameSession(
                session_id=session_id,
                player_name=player_name,
                started_at=datetime.now(timezone.utc),
                puzzle=self._puzzle,
            )
            self._sessions[session_id] = session
            return session

    def get_session(self, session_id: str) -> GameSession | None:
        with self._lock:
            return self._sessions.get(session_id)

    def _load_puzzle(self, puzzle_path: Path) -> Puzzle:
        if not puzzle_path.exists():
            raise FileNotFoundError(f"File puzzle tidak ditemukan: {puzzle_path}")

        with puzzle_path.open("r", encoding="utf8") as fh:
            data = json.load(fh)

        grid = data.get("gridData", [])
        height = len(grid)
        width = len(grid[0]) if grid else 0

        raw_words: List[Dict] = data.get("words", [])
        clues: List[str] = data.get("clues", [])

        placements: List[WordPlacement] = []

        def _validate(answer: str, row: int, col: int, direction: str) -> None:
            length = len(answer)
            if direction == "across":
                if col < 0 or col + length > width:
                    raise ValueError(
                        f"Word '{answer}' out of horizontal bounds at ({row}, {col})."
                    )
            else:
                if row < 0 or row + length > height:
                    raise ValueError(
                        f"Word '{answer}' out of vertical bounds at ({row}, {col})."
                    )

            for offset, char in enumerate(answer):
                r = row + (offset if direction == "down" else 0)
                c = col + (offset if direction == "across" else 0)
                cell = grid[r][c]
                if cell == ".":
                    continue
                if cell.upper() != char.upper():
                    raise ValueError(
                        "Grid letter mismatch for"
                        f" '{answer}' ({row}, {col}) at offset {offset}:"
                        f" expected '{cell}', got '{char}'."
                    )

        for idx, info in enumerate(raw_words):
            answer = str(info.get("word", "")).upper()
            direction = str(info.get("dir", "across")).strip().lower() or "across"
            row_val = int(info.get("row", 0))
            col_val = int(info.get("col", 0))
            inline_clue = str(info.get("clue", "")).strip()
            fallback_clue = clues[idx] if idx < len(clues) else ""
            clue_text = inline_clue or fallback_clue

            _validate(answer, row_val, col_val, direction)

            placements.append(
                WordPlacement(
                    answer=answer,
                    row=row_val,
                    col=col_val,
                    direction=direction,
                    clue=clue_text,
                )
            )

        return Puzzle(width=width, height=height, grid=grid, words=placements)
