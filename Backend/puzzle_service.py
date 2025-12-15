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

        # Baca file JSON
        with puzzle_path.open("r", encoding="utf8") as fh:
            data = json.load(fh)

        raw_words: List[Dict] = data.get("words", [])
        clues: List[str] = data.get("clues", [])

        # Tentukan ukuran grid berdasarkan kata-kata
        width = max((int(info.get("col", 0)) + len(str(info.get("word", ""))) for info in raw_words), default=0)
        height = max((int(info.get("row", 0)) + len(str(info.get("word", ""))) for info in raw_words), default=0)

        # Buat grid kosong
        grid: List[List[str]] = [["." for _ in range(width)] for _ in range(height)]
        placements: List[WordPlacement] = []

        # Tempatkan kata-kata di grid
        for idx, info in enumerate(raw_words):
            answer = str(info.get("word", "")).upper()
            direction = str(info.get("dir", "across")).strip().lower() or "across"
            row_val = int(info.get("row", 0))
            col_val = int(info.get("col", 0))
            inline_clue = str(info.get("clue", "")).strip()
            fallback_clue = clues[idx] if idx < len(clues) else ""
            clue_text = inline_clue or fallback_clue

            # Tempatkan setiap huruf, pastikan tidak bentrok
            for offset, char in enumerate(answer):
                r = row_val + (offset if direction == "down" else 0)
                c = col_val + (offset if direction == "across" else 0)
                existing = grid[r][c]
                if existing == ".":
                    grid[r][c] = char
                elif existing != char:
                    raise ValueError(
                        f"Conflict di ({r},{c}) untuk kata '{answer}':"
                        f" grid='{existing}' vs kata='{char}'"
                    )

            # Simpan posisi kata
            placements.append(
                WordPlacement(
                    answer=answer,
                    row=row_val,
                    col=col_val,
                    direction=direction,
                    clue=clue_text,
                )
            )

        # Ubah grid menjadi list of strings
        grid_str = ["".join(row) for row in grid]

        return Puzzle(width=width, height=height, grid=grid_str, words=placements)
