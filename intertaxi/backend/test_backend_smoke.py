"""Quick smoke test for backend/app.py (delete endpoints + trip_deleted broadcast)."""
import sys

sys.path.insert(0, "backend")

from app import app, db, socketio, Trip  # noqa: E402

client = app.test_client()
with app.app_context():
    db.drop_all()
    db.create_all()

# 1) POST a trip via REST
r = client.post(
    "/api/trips",
    json={
        "driver_id": "992000000000",
        "driver_name": "Сафиали",
        "driver_phone": "992000000000",
        "from_location": "Кӯлоб",
        "to_location": "Душанбе",
        "price": 120,
        "available_seats": 3,
        "departure_time": "2026-09-05T08:00:00",
    },
)
assert r.status_code == 201, r.status_code
trip = r.get_json()["trip"]
trip_id = trip["id"]
print("POST /api/trips ->", r.status_code, "id:", trip_id)

# 2) Socket.IO client connects and should receive trip_deleted broadcast
sio_client = socketio.test_client(app)
sio_client.get_received()  # drain connect events

# 3) DELETE via Socket.IO 'delete_trip'
sio_client.emit("delete_trip", {"trip_id": str(trip_id)})
received = sio_client.get_received()
deleted_events = [e for e in received if e["name"] == "trip_deleted"]
ack = [e for e in received if e["name"] == "delete_trip_response"]
assert deleted_events, "no trip_deleted broadcast received"
payload = deleted_events[0]["args"]
assert payload == [{"id": trip_id}], payload
print("Socket delete_trip ack:", ack[0]["args"] if ack else "(implicit)")
print("trip_deleted broadcast payload:", payload)

# 4) Verify DB is empty
r = client.get("/api/trips")
assert r.get_json()["trips"] == []
print("GET /api/trips after socket delete ->", r.get_json()["trips"])

# 5) Recreate and delete via REST
r = client.post(
    "/api/trips",
    json={
        "driver_id": "d2",
        "driver_name": "Driver 2",
        "driver_phone": "992111111111",
        "from_location": "Восеъ",
        "to_location": "Хуҷанд",
        "price": 80,
        "available_seats": 2,
    },
)
trip2 = r.get_json()["trip"]
r = client.delete(f"/api/trips/{trip2['id']}")
assert r.status_code == 200, r.status_code
print("DELETE /api/trips/%s ->" % trip2["id"], r.status_code, r.get_json())

# trip_deleted broadcast for the REST delete
events = sio_client.get_received()
rest_deleted = [e for e in events if e["name"] == "trip_deleted"]
assert rest_deleted and rest_deleted[0]["args"] == [{"id": trip2["id"]}]
print("trip_deleted broadcast after REST delete:", rest_deleted[0]["args"])

# 6) DELETE a missing trip -> 404
r = client.delete("/api/trips/99999")
assert r.status_code == 404
print("DELETE missing trip ->", r.status_code)

# 7) delete_trip socket handler with bad id -> no broadcast, error ack
sio_client.emit("delete_trip", {"trip_id": "abc"})
events = sio_client.get_received()
bad_deleted = [e for e in events if e["name"] == "trip_deleted"]
assert not bad_deleted, "invalid id must NOT broadcast trip_deleted"
print("Socket delete_trip with bad id -> no trip_deleted broadcast (OK)")

# 8) delete_trip with a valid id via a fresh socket client: trip vanishes and
#    the trip_deleted broadcast reaches ALL connected clients
sio_client2 = socketio.test_client(app)
sio_client2.get_received()
client.post(
    "/api/trips",
    json={
        "driver_id": "d3",
        "driver_name": "Driver 3",
        "driver_phone": "992222222222",
        "from_location": "Кӯлоб",
        "to_location": "Душанбе",
        "price": 100,
        "available_seats": 4,
    },
)
trips = client.get("/api/trips").get_json()["trips"]
sio_client.emit("delete_trip", {"trip_id": trips[0]["id"]})
events2 = sio_client2.get_received()
broadcast = [e for e in events2 if e["name"] == "trip_deleted"]
assert broadcast and broadcast[0]["args"] == [{"id": trips[0]["id"]}], events2
print("trip_deleted reached the 2nd connected client:", broadcast[0]["args"])

print("ALL BACKEND TESTS PASSED")
