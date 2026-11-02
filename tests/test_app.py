from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_compute_counts_primes_below_n():
    response = client.get("/compute", params={"n": 100})
    assert response.status_code == 200
    body = response.json()
    assert body["n"] == 100
    assert body["primes_found"] == 25  # primos < 100


def test_memory_respects_max_limit():
    response = client.get("/memory", params={"mb": 1000, "hold_seconds": 0})
    assert response.status_code == 200
    body = response.json()
    assert body["clamped_to_max"] is True
    assert body["allocated_mb"] <= 512
