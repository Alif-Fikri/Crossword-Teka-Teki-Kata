#!/usr/bin/env python3
import os
import random
import re
import csv
import json
import unicodedata
from typing import List, Dict, Optional, Tuple
from dotenv import load_dotenv
from google import genai

# ===========================
# LOAD ENVIRONMENT
# ===========================
load_dotenv()
API_KEY = os.getenv("GEMINI_API_KEY")
if not API_KEY:
    raise ValueError("Environment variable GEMINI_API_KEY belum diatur.")

MODEL = "gemini-2.5-flash"
client = genai.Client(api_key=API_KEY)

# ===========================
# UTILITIES
# ===========================
def normalize_display_word(s: str) -> str:
    s = unicodedata.normalize("NFKC", (s or "").strip())
    return re.sub(r"\s+", " ", s)

def grid_word_from_display(s: str) -> str:
    s = (s or "").upper().replace("/", "_").replace(" ", "_")
    return re.sub(r"[^A-Z0-9_#+-]", "", s)

def sanitize_clue(txt: Optional[str]) -> str:
    if not txt:
        return ""
    text = str(txt).strip()
    text = re.sub(r"https?://\S+", "", text)
    forbid = ["429", "RATE LIMIT", "QUOTA", "ERROR", "REQUEST"]
    if any(f in text.upper() for f in forbid):
        return ""
    return re.sub(r"\s+", " ", text).strip()

# ===========================
# CROSSWORD ENGINE
# ===========================
class Crossword:
    def __init__(self, w=10, h=10):
        self.w = w
        self.h = h
        self.grid = [[None for _ in range(w)] for _ in range(h)]
        self.words = []

    def can_place(self, word: str, r: int, c: int, d: str) -> bool:
        if d == "across":
            if c + len(word) > self.w: return False
            return all(self.grid[r][c+i] in (None, ch) for i, ch in enumerate(word))
        if d == "down":
            if r + len(word) > self.h: return False
            return all(self.grid[r+i][c] in (None, ch) for i, ch in enumerate(word))
        return False

    def place(self, word: str, r: int, c: int, d: str):
        for i, ch in enumerate(word):
            rr, cc = (r+i, c) if d=="down" else (r, c+i)
            self.grid[rr][cc] = ch
        self.words.append({"word": word, "row": r, "col": c, "dir": d})

    def build_random(self, wordlist: List[str]):
        for w in wordlist:
            word_grid = grid_word_from_display(w)
            placed = False
            attempts = 0
            while not placed and attempts < 200:
                r, c = random.randint(0, self.h-1), random.randint(0, self.w-1)
                d = random.choice(["across","down"])
                if self.can_place(word_grid, r, c, d):
                    self.place(word_grid, r, c, d)
                    placed = True
                attempts += 1
            if not placed:  # fallback ke baris awal
                for rr in range(self.h):
                    if self.can_place(word_grid, rr, 0, "across"):
                        self.place(word_grid, rr, 0, "across")
                        break
        return self.grid

    def display(self):
        for row in self.grid:
            print("".join(ch if ch else "." for ch in row))

# ===========================
# GENERATE CLUES VIA GEMINI
# ===========================
def generate_clues(words: List[str]) -> Dict[str, str]:
    prompt = (
        "Buat definisi singkat (5–12 kata) untuk setiap istilah teknologi berikut. "
        "Format setiap baris: 'KATA: definisi'. "
        f"Daftar kata: {', '.join(words)}"
    )

    clues = {}
    try:
        response = client.models.generate_content(model=MODEL, contents=prompt)
        raw_text = response.text

        for line in raw_text.splitlines():
            if ":" in line:
                key, val = line.split(":", 1)
                clues[key.strip().upper()] = sanitize_clue(val.strip())

        for w in words:
            if w.upper() not in clues:
                clues[w.upper()] = f"Clue pending: {w}"

        return clues
    except Exception as e:
        print(f"Gagal generate clue dari Gemini: {e}")
        return {w.upper(): f"Clue pending: {w}" for w in words}

# ===========================
# EXPORT
# ===========================
def export_csv(name: str, cw: Crossword, clues: Dict[str,str]):
    with open(name, "w", newline="", encoding="utf8") as f:
        writer = csv.writer(f)
        writer.writerow(["WORD","ROW","COL","DIR","CLUE"])
        for itm in cw.words:
            writer.writerow([
                itm["word"], itm["row"], itm["col"], itm["dir"],
                clues.get(itm["word"].upper(), f"Clue pending: {itm['word']}")
            ])

def export_json(name: str, cw: Crossword, clues: Dict[str,str]):
    data = {
        "gridData": ["".join(ch if ch else "." for ch in row) for row in cw.grid],
        "words": cw.words,
        "clues": list(clues.values())
    }
    with open(name, "w", encoding="utf8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

# ===========================
# SMART CROSSWORD (OVERLAP MAX)
# ===========================
class SmartCrossword(Crossword):
    def find_best_positions(self, word: str) -> List[Tuple[int,int,str,int]]:
        """Cari posisi yang memungkinkan dengan overlap maksimal."""
        best_positions = []
        max_overlap = 0
        word = word.upper()
        for r in range(self.h):
            for c in range(self.w):
                for d in ["across","down"]:
                    if not self.can_place(word, r, c, d):
                        continue
                    overlap = sum(
                        1 for i, ch in enumerate(word)
                        if (self.grid[r+i][c] if d=="down" else self.grid[r][c+i]) == ch
                    )
                    if overlap >= max_overlap:
                        if overlap > max_overlap:
                            best_positions.clear()
                            max_overlap = overlap
                        best_positions.append((r, c, d, overlap))
        return best_positions

    def build(self, wordlist: List[str]):
        if not wordlist:
            return
        # Tempatkan kata pertama di tengah horizontal
        first_word = wordlist[0].upper()
        start_row = self.h // 2
        start_col = max(0, (self.w - len(first_word)) // 2)
        self.place(first_word, start_row, start_col, "across")

        # Tempatkan kata berikutnya
        for word in wordlist[1:]:
            positions = self.find_best_positions(word)
            if positions:
                r, c, d, _ = random.choice(positions)
                self.place(word.upper(), r, c, d)
            else:
                # fallback: posisi acak
                placed = False
                for _ in range(100):
                    r, c = random.randint(0, self.h-1), random.randint(0, self.w-1)
                    d = random.choice(["across","down"])
                    if self.can_place(word.upper(), r, c, d):
                        self.place(word.upper(), r, c, d)
                        placed = True
                        break
                if not placed:
                    print(f"Word '{word}' gagal ditempatkan.")

# ===========================
# MAIN BUILDER
# ===========================
def build_crossword(words_raw: List[str], w=10, h=10, max_words=10, csv_file: Optional[str]=None):
    displays = [normalize_display_word(x) for x in words_raw if x and str(x).strip()]
    uniq = []
    seen = set()
    for d in displays:
        u = d.upper()
        if u not in seen:
            uniq.append(d)
            seen.add(u)
    selected = uniq[:max_words]

    clues = generate_clues(selected)
    grid_words = [grid_word_from_display(d) for d in selected]

    cw = SmartCrossword(w, h)
    cw.build(grid_words)

    if csv_file:
        export_csv(csv_file, cw, clues)

    return cw, clues, grid_words

# ===========================
# EXAMPLE RUN
# ===========================
if __name__ == "__main__":
    words = [
        "API", "Cloud", "Docker", "Kubernetes", "Token", "DevOps", "Cache", "SQL", 
        "Frontend", "Backend", "Git", "CI/CD", "Microservice", "Virtualization", 
        "Container", "Serverless", "Database", "Firewall", "Encryption", "LoadBalancer"
    ]

    cw, clues, answers = build_crossword(
        words, w=15, h=15, max_words=20, csv_file="crossword_words_15x15.csv"
    )

    export_json("crossword_words_15x15.json", cw, clues)

    print("\nCrossword 15x15 acak selesai!\n")
    cw.display()
    print("\nContoh clue:")
    for k, v in clues.items():
        print(f"- {k}: {v}")

    print("\nCSV dan JSON sudah dibuat.")
