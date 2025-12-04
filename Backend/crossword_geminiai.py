#!/usr/bin/env python3
import random
import re
import csv
import unicodedata
from typing import List, Dict, Optional
from google import genai
import json

# ===========================
# KONFIGURASI GEMINI
# ===========================
API_KEY = "AIzaSyBg-W47zl17lvMfzz9M4Cy7hnf0UKCiGpg"  # ganti dengan API key kamu
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
    up = text.upper()
    if any(f in up for f in forbid):
        return ""
    return re.sub(r"\s+", " ", text).strip()

# ===========================
# CROSSWORD ENGINE ACak
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
            for i, ch in enumerate(word):
                ex = self.grid[r][c+i]
                if ex and ex != ch: return False
            return True
        if d == "down":
            if r + len(word) > self.h: return False
            for i, ch in enumerate(word):
                ex = self.grid[r+i][c]
                if ex and ex != ch: return False
            return True
        return False

    def place(self, word: str, r: int, c: int, d: str):
        if d == "across":
            for i, ch in enumerate(word): self.grid[r][c+i] = ch
        else:
            for i, ch in enumerate(word): self.grid[r+i][c] = ch
        self.words.append({"word": word, "row": r, "col": c, "dir": d})

    def build_random(self, wordlist: List[str]):
        for w in wordlist:
            word_grid = grid_word_from_display(w)
            placed = False
            attempts = 0
            while not placed and attempts < 200:  # max percobaan
                r = random.randint(0, self.h-1)
                c = random.randint(0, self.w-1)
                d = random.choice(["across","down"])
                if self.can_place(word_grid, r, c, d):
                    self.place(word_grid, r, c, d)
                    placed = True
                attempts += 1
            if not placed:
                # fallback: tempatkan di baris berikutnya horizontal
                for rr in range(self.h):
                    if self.can_place(word_grid, rr, 0, "across"):
                        self.place(word_grid, rr, 0, "across")
                        break
        return self.grid

    def display(self):
        for row in self.grid:
            print("".join(ch if ch else "." for ch in row))

# ===========================
# GENERATE CLUES VIA GEMINI 2.5 FLASH (TEXT)
# ===========================
def generate_clues(words: List[str]) -> Dict[str,str]:
    """
    Meminta Gemini 2.5 Flash membuat definisi untuk daftar kata teknologi.
    Ambil langsung dari teks model, format: "KATA: definisi".
    """
    prompt = (
        "Buat definisi singkat (5–12 kata) untuk setiap istilah teknologi berikut. "
        "Format setiap baris: 'KATA: definisi'. "
        f"Daftar kata: {', '.join(words)}"
    )

    clues = {}
    try:
        response = client.models.generate_content(
            model=MODEL,
            contents=prompt
        )
        raw_text = response.text

        # parsing baris
        for line in raw_text.splitlines():
            if ":" in line:
                key, val = line.split(":", 1)
                clues[key.strip().upper()] = sanitize_clue(val.strip())

        # fallback jika kata tidak ditemukan
        for w in words:
            if w.upper() not in clues:
                clues[w.upper()] = f"Clue pending: {w}"

        return clues
    except Exception as e:
        print(f"Gagal generate clue dari Gemini: {e}")
        return {w.upper(): f"Clue pending: {w}" for w in words}

# ===========================
# EXPORT CSV
# ===========================
def export_csv(name: str, cw: Crossword, clues: Dict[str,str]):
    with open(name,"w",newline="",encoding="utf8") as f:
        writer = csv.writer(f)
        writer.writerow(["WORD","ROW","COL","DIR","CLUE"])
        for itm in cw.words:
            writer.writerow([
                itm["word"], itm["row"], itm["col"], itm["dir"],
                clues.get(itm["word"].upper(), f"Clue pending: {itm['word']}")
            ])

# ===========================
# EXPORT JSON
# ===========================

def export_json(name: str, cw: Crossword, clues: Dict[str,str]):
    data = {
        "gridData": ["".join(ch if ch else "." for ch in row) for row in cw.grid],
        "words": cw.words,          # tetap menyimpan word + posisi + arah
        "clues": list(clues.values())  # hanya definisi, urutannya sesuai cw.words
    }
    with open(name, "w", encoding="utf8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

# ===========================
# MAIN BUILDER
# ===========================
def build_crossword(words_raw: List[str], w=10, h=10, max_words=10, csv_file: Optional[str]=None):
    # normalisasi & unik
    displays = [normalize_display_word(x) for x in words_raw if x and str(x).strip()]
    uniq = []
    seen = set()
    for d in displays:
        u = d.upper()
        if u not in seen:
            uniq.append(d)
            seen.add(u)
    selected = uniq[:max_words]

    # generate clue
    clues = generate_clues(selected)
    grid_words = [grid_word_from_display(d) for d in selected]

    # build grid acak
    cw = Crossword(w, h)
    cw.build_random(grid_words)

    # export CSV
    if csv_file:
        export_csv(csv_file, cw, clues)

    return cw, clues, grid_words

# ===========================
# CONTOH RUN
# ===========================
if __name__=="__main__":
    words = [
        "API", "Cloud", "Docker", "Kubernetes", "Token", "DevOps", "Cache", "SQL", 
        "Frontend", "Backend", "Git", "CI/CD", "Microservice", "Virtualization", 
        "Container", "Serverless", "Database", "Firewall", "Encryption", "LoadBalancer"
    ]

    # Grid diperbesar jadi 15x15 agar semua kata muat
    cw, clues, answers = build_crossword(words, w=15, h=15, max_words=20, csv_file="crossword_words_15x15.csv")

    # Simpan ke JSON
    export_json("crossword_words_15x15.json", cw, clues)

    print("\nCrossword 15x15 acak selesai!\n")
    cw.display()
    print("\nContoh clue:")
    for k, v in clues.items():
        print(f"- {k}: {v}")

    print("\nCSV 'crossword_words_15x15.csv' sudah dibuat dengan semua kata, posisi, arah, dan clue.")
    print("JSON 'crossword_words_15x15.json' sudah dibuat dengan grid, clue, dan posisi kata.")
