# Crossword

Proyek ini terdiri dari aplikasi Flutter dan layanan backend sederhana untuk memainkan teka-teki silang bertema teknologi. Backend menyediakan puzzle dan clue melalui API agar aplikasi mobile dapat langsung memulai permainan setelah pemain memasukkan nama.

## Backend API (Python / FastAPI)

### Menjalankan secara lokal

```bash
cd Backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app:app --reload
```

Server akan berjalan di `http://127.0.0.1:8000` dan otomatis menyediakan dokumentasi interaktif di `/docs`.

### Endpoints utama

| HTTP | Path                     | Deskripsi                                           |
| ---- | ------------------------ | --------------------------------------------------- |
| GET  | `/health`                | Pengecekan status sederhana.                        |
| GET  | `/puzzle`                | Mengambil puzzle default (grid, posisi kata, clue). |
| POST | `/start`                 | Memulai sesi baru, membutuhkan `player_name`.       |
| GET  | `/sessions/{session_id}` | Mengambil ulang data sesi yang sudah dimulai.       |

Contoh payload untuk memulai permainan:

```json
{
  "player_name": "Petenteng"
}
```

Respons mencakup `session_id`, `started_at`, dan detail puzzle agar aplikasi Flutter dapat langsung menampilkan papan permainan.

## Aplikasi Flutter

Direktori `lib/` berisi implementasi Flutter. Ikuti dokumentasi resmi [Flutter](https://docs.flutter.dev/) untuk membangun dan menjalankan aplikasi pada platform pilihan Anda.
