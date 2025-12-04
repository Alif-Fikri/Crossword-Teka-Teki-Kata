from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import List

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from puzzle_service import CrosswordService, GameSession

BASE_DIR = Path(__file__).parent
PUZZLE_FILE = BASE_DIR / "crossword_words_15x15.json"

service = CrosswordService(PUZZLE_FILE)

app = FastAPI(
    title="Crossword API",
    version="1.0.0",
    description="API sederhana untuk memainkan teka-teki silang teknologi.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class WordModel(BaseModel):
    answer: str
    row: int
    col: int
    direction: str = Field(pattern=r"^(across|down)$", description="Arah penempatan kata")
    clue: str


class PuzzleModel(BaseModel):
    width: int
    height: int
    grid: List[str]
    words: List[WordModel]


class SessionResponse(BaseModel):
    session_id: str
    player_name: str
    started_at: datetime
    puzzle: PuzzleModel


class StartRequest(BaseModel):
    player_name: str = Field(..., min_length=1, max_length=50)


@app.get("/health")
def health_check() -> dict:
    return {"status": "ok"}


@app.get("/puzzle", response_model=PuzzleModel)
def get_puzzle() -> PuzzleModel:
    return _to_puzzle_model(service.puzzle)


@app.post("/start", response_model=SessionResponse)
def start_game(request: StartRequest) -> SessionResponse:
    name = request.player_name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Nama pemain tidak boleh kosong")
    session = service.start_session(name)
    return _to_session_model(session)


@app.get("/sessions/{session_id}", response_model=SessionResponse)
def get_session(session_id: str) -> SessionResponse:
    session = service.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Sesi tidak ditemukan")
    return _to_session_model(session)


def _to_puzzle_model(puzzle) -> PuzzleModel:
    return PuzzleModel(
        width=puzzle.width,
        height=puzzle.height,
        grid=puzzle.grid,
        words=[
            WordModel(
                answer=w.answer,
                row=w.row,
                col=w.col,
                direction=w.direction,
                clue=w.clue,
            )
            for w in puzzle.words
        ],
    )


def _to_session_model(session: GameSession) -> SessionResponse:
    return SessionResponse(
        session_id=session.session_id,
        player_name=session.player_name,
        started_at=session.started_at,
        puzzle=_to_puzzle_model(session.puzzle),
    )
