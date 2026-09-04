"""
InterTaxi backend — Flask + Flask-SocketIO + SQLAlchemy.

Endpoints / events:
  REST:
    GET    /api/health            -> {"ok": true}
    GET    /api/trips             -> {"trips": [...]} (optional ?from= &to= filter)
    POST   /api/trips             -> create a trip (201)
    DELETE /api/trips/<trip_id>   -> delete trip + broadcast `trip_deleted`

  Socket.IO:
    post_trip   -> creates trip, broadcasts `new_trip`
    get_trips   -> emits `trips_list` back to the requester
    book_trip   -> decrements seats, broadcasts `trip_updated`,
                   acks `booking_confirmed` to the booking passenger
    delete_trip -> deletes trip, broadcasts `trip_deleted` to ALL clients
"""

import os
from datetime import datetime, timezone

from flask import Flask, jsonify, request
from flask_socketio import SocketIO, emit
from flask_sqlalchemy import SQLAlchemy

# ---------------------------------------------------------------------------
# App & extensions
# ---------------------------------------------------------------------------

DB_URI = os.environ.get(
    "DATABASE_URL",
    "sqlite:///" + os.path.join(os.path.dirname(os.path.abspath(__file__)), "trips.db"),
).replace("postgres://", "postgresql://", 1)

app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = DB_URI
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)

socketio = SocketIO(app, cors_allowed_origins="*")


# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------

class Trip(db.Model):
    """A driver's announced trip (эълон)."""

    __tablename__ = "trips"

    id = db.Column(db.Integer, primary_key=True)
    driver_id = db.Column(db.String(64), index=True, nullable=False)
    driver_name = db.Column(db.String(120), default="", nullable=False)
    driver_phone = db.Column(db.String(32), default="", nullable=False)
    from_location = db.Column(db.String(120), nullable=False)
    to_location = db.Column(db.String(120), nullable=False)
    price = db.Column(db.Integer, default=0, nullable=False)
    available_seats = db.Column(db.Integer, default=0, nullable=False)
    departure_time = db.Column(db.String(32), default="", nullable=False)
    status = db.Column(db.String(16), default="active", index=True, nullable=False)
    created_at = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    def to_dict(self):
        """Serializes to the exact JSON shape the Flutter client expects."""
        return {
            "id": self.id,
            "driver_id": self.driver_id,
            "driver_name": self.driver_name,
            "driver_phone": self.driver_phone,
            "from_location": self.from_location,
            "to_location": self.to_location,
            "price": self.price,
            "available_seats": self.available_seats,
            "departure_time": self.departure_time,
            "status": self.status,
            "created_at": self.created_at.isoformat() if self.created_at else "",
        }


with app.app_context():
    db.create_all()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _broadcast_trip_deleted(trip_id: int) -> None:
    """Tells every connected client (drivers AND passengers) that a trip
    was removed so their lists update in real time."""
    socketio.emit("trip_deleted", {"id": trip_id})


def _delete_trip_by_id(trip_id) -> bool:
    """Deletes a trip (accepts int or numeric string). Returns True when the
    trip existed and was removed."""
    try:
        trip_id = int(str(trip_id))
    except (TypeError, ValueError):
        return False
    trip = db.session.get(Trip, trip_id)
    if trip is None:
        return False
    db.session.delete(trip)
    db.session.commit()
    _broadcast_trip_deleted(trip_id)
    return True

# ---------------------------------------------------------------------------
# REST endpoints
# ---------------------------------------------------------------------------

@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({"ok": True})


@app.route("/api/trips", methods=["GET"])
def get_trips():
    """Lists active trips, optionally filtered by the EXACT route.

    `?from=Кулоб&to=Душанбе` returns ONLY trips whose `from_location` and
    `to_location` equal the requested values, so the passenger main screen
    never shows trips created for another route. Only `active` trips are
    returned — deleted rows are gone from the DB and booked ones are hidden,
    therefore a deleted trip can never reappear on refresh.
    """
    query = Trip.query.filter(Trip.status == "active")
    from_loc = request.args.get("from", "").strip()
    to_loc = request.args.get("to", "").strip()
    # STRICT route filtering with `ilike` (case-insensitive exact match):
    # a passenger searching "Кулоб -> Восе" gets ONLY trips whose
    # from_location AND to_location match — never trips for another route.
    if from_loc:
        query = query.filter(Trip.from_location.ilike(from_loc))
    if to_loc:
        query = query.filter(Trip.to_location.ilike(to_loc))
    trips = query.order_by(Trip.created_at.desc()).all()
    return jsonify({"trips": [t.to_dict() for t in trips]})


@app.route("/api/trips", methods=["POST"])
def create_trip():
    payload = request.get_json(silent=True) or {}
    required = ("driver_id", "from_location", "to_location")
    if any(not str(payload.get(field, "")).strip() for field in required):
        return jsonify({"ok": False, "error": "Missing required fields"}), 400

    trip = Trip(
        driver_id=str(payload["driver_id"]),
        driver_name=str(payload.get("driver_name", "")),
        driver_phone=str(payload.get("driver_phone", "")),
        from_location=str(payload["from_location"]),
        to_location=str(payload["to_location"]),
        price=int(payload.get("price") or 0),
        available_seats=int(payload.get("available_seats") or 0),
        departure_time=str(payload.get("departure_time", "")),
        status="active",
    )
    db.session.add(trip)
    db.session.commit()
    socketio.emit("new_trip", trip.to_dict())
    return jsonify({"ok": True, "trip": trip.to_dict()}), 201


@app.route("/api/trips/<string:trip_id>", methods=["DELETE"])
def delete_trip_rest(trip_id: str):
    """Deletes the trip PERMANENTLY from the server database and broadcasts
    `trip_deleted` to ALL connected clients.

    Flow: `_delete_trip_by_id` runs `db.session.delete(trip)` +
    `db.session.commit()`, then `socketio.emit('trip_deleted', {'id': ...})`
    fires to every passenger/driver so the trip instantly disappears from
    all client lists and never reappears on refresh.
    """
    deleted = _delete_trip_by_id(trip_id)
    if not deleted:
        return jsonify({"ok": False, "error": "Trip not found"}), 404
    return jsonify({"ok": True, "id": trip_id})


# ---------------------------------------------------------------------------
# Socket.IO handlers
# ---------------------------------------------------------------------------

@socketio.on("connect")
def on_connect():
    print(f"[socket] client connected: {request.sid}")


@socketio.on("disconnect")
def on_disconnect():
    print(f"[socket] client disconnected: {request.sid}")


@socketio.on("post_trip")
def handle_post_trip(data):
    """Driver publishes a new trip; broadcast it to everyone."""
    data = data or {}
    trip = Trip(
        driver_id=str(data.get("driver_id", data.get("driver_phone", ""))),
        driver_name=str(data.get("driver_name", "")),
        driver_phone=str(data.get("driver_phone", "")),
        from_location=str(data.get("from_location", "")),
        to_location=str(data.get("to_location", "")),
        price=int(data.get("price") or 0),
        available_seats=int(data.get("available_seats") or 0),
        departure_time=str(data.get("departure_time", "")),
        status="active",
    )
    db.session.add(trip)
    db.session.commit()
    socketio.emit("new_trip", trip.to_dict())
    return {"ok": True, "trip": trip.to_dict()}


@socketio.on("get_trips")
def handle_get_trips(data):
    """Passenger requests the active trips (optionally filtered by from/to)."""
    data = data or {}
    query = Trip.query.filter(Trip.status == "active")
    from_loc = str(data.get("from", "")).strip()
    to_loc = str(data.get("to", "")).strip()
    # STRICT route filtering with `ilike` (same as the REST endpoint).
    if from_loc:
        query = query.filter(Trip.from_location.ilike(from_loc))
    if to_loc:
        query = query.filter(Trip.to_location.ilike(to_loc))
    trips = query.order_by(Trip.created_at.desc()).all()
    emit("trips_list", {"trips": [t.to_dict() for t in trips]})


@socketio.on("book_trip")
def handle_book_trip(data):
    """Passenger books a seat on a trip."""
    data = data or {}
    trip = db.session.get(Trip, int(str(data.get("trip_id", "")) or 0))
    if trip is None:
        return {"ok": False, "error": "Trip not found"}
    if trip.available_seats <= 0:
        return {"ok": False, "error": "No seats available"}
    trip.available_seats -= 1
    if trip.available_seats == 0:
        trip.status = "booked"
    db.session.commit()
    socketio.emit("trip_updated", trip.to_dict())
    emit(
        "booking_confirmed",
        {
            "ok": True,
            "trip_id": trip.id,
            "passenger_name": data.get("passenger_name", ""),
        },
    )
    return {"ok": True, "trip": trip.to_dict()}


@socketio.on("delete_trip")
def handle_delete_trip(data):
    """Driver deletes a trip; remove it from the database and broadcast
    `trip_deleted` with {"id": ...} to ALL connected users."""
    trip_id = None
    if isinstance(data, dict):
        trip_id = data.get("trip_id") or data.get("id")
    elif data is not None:
        trip_id = data
    if trip_id is None:
        return {"ok": False, "error": "trip_id is required"}
    deleted = _delete_trip_by_id(trip_id)
    if deleted:
        return {"ok": True, "id": int(str(trip_id))}
    return {"ok": False, "error": "Trip not found"}


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    socketio.run(app, host="0.0.0.0", port=port, debug=False)

