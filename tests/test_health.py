from fastapi.testclient import TestClient
from app.main import app


def test_liveness():
    response = TestClient(app).get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_reject_invalid_sale():
    response = TestClient(app).post("/sales", json={"store_id": "casa", "product": "a", "quantity": -1, "unit_price": 20})
    assert response.status_code == 422
