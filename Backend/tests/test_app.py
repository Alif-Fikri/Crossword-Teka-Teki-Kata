from fastapi.testclient import TestClient

from app import app

client = TestClient(app)


def test_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_start_creates_session():
    payload = {"player_name": "Alice"}
    response = client.post("/start", json=payload)
    assert response.status_code == 200

    data = response.json()
    assert data["player_name"] == "Alice"
    assert "session_id" in data and data["session_id"]
    assert "started_at" in data
    assert "puzzle" in data

    puzzle = data["puzzle"]
    assert puzzle["width"] == 15
    assert puzzle["height"] == 15
    assert len(puzzle["grid"]) == puzzle["height"]
    assert len(puzzle["words"]) > 0


def test_get_session_reuses_existing_session():
    create = client.post("/start", json={"player_name": "Budi"})
    session_id = create.json()["session_id"]

    response = client.get(f"/sessions/{session_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["session_id"] == session_id
    assert data["player_name"] == "Budi"
