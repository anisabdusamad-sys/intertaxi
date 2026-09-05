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
import unicodedata
import uuid
from datetime import datetime, timezone

from flask import Flask, jsonify, request
from flask_socketio import SocketIO, emit
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import inspect, text

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

    # UUID string primary key — matches the rows already stored on the
    # production database (Render), e.g. "42192e1f-788e-4312-a057-...".
    id = db.Column(
        db.String(64),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    driver_id = db.Column(db.String(64), index=True, nullable=False)
    driver_name = db.Column(db.String(120), default="", nullable=False)
    driver_phone = db.Column(db.String(32), default="", nullable=False)
    from_location = db.Column(db.String(120), nullable=False)
    to_location = db.Column(db.String(120), nullable=False)
    price = db.Column(db.Integer, default=0, nullable=False)
    available_seats = db.Column(db.Integer, default=0, nullable=False)
    departure_time = db.Column(db.String(32), default="", nullable=False)
    duration_minutes = db.Column(db.Integer, default=0, nullable=False)
    car_brand = db.Column(db.String(80), default="", nullable=False)
    car_model = db.Column(db.String(80), default="", nullable=False)
    car_color = db.Column(db.String(40), default="", nullable=False)
    car_plate = db.Column(db.String(40), default="", nullable=False)
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
            "duration_minutes": self.duration_minutes,
            "car_brand": self.car_brand,
            "car_model": self.car_model,
            "car_color": self.car_color,
            "car_plate": self.car_plate,
            "status": self.status,
            "created_at": self.created_at.isoformat() if self.created_at else "",
        }


with app.app_context():
    db.create_all()
    existing_columns = {column["name"] for column in inspect(db.engine).get_columns("trips")}
    new_columns = {
        "duration_minutes": "INTEGER DEFAULT 0 NOT NULL",
        "car_brand": "VARCHAR(80) DEFAULT '' NOT NULL",
        "car_model": "VARCHAR(80) DEFAULT '' NOT NULL",
        "car_color": "VARCHAR(40) DEFAULT '' NOT NULL",
        "car_plate": "VARCHAR(40) DEFAULT '' NOT NULL",
    }
    for column_name, definition in new_columns.items():
        if column_name not in existing_columns:
            db.session.execute(
                text(f"ALTER TABLE trips ADD COLUMN {column_name} {definition}")
            )
    db.session.commit()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _broadcast_trip_deleted(trip_id) -> None:
    """Tells every connected client (drivers AND passengers) that a trip
    was removed so their lists update in real time."""
    socketio.emit("trip_deleted", {"id": str(trip_id)})


def _delete_trip_by_id(trip_id) -> bool:
    """Deletes a trip by its id. IDs are UUID strings (e.g.
    "42192e1f-788e-4312-a057-5ecc4129748a"), but any value is accepted —
    it is only used as an exact lookup key. Returns True when the trip
    existed and was removed."""
    key = str(trip_id).strip() if trip_id is not None else ""
    if not key:
        return False
    trip = db.session.get(Trip, key)
    if trip is None:
        return False
    db.session.delete(trip)
    db.session.commit()
    _broadcast_trip_deleted(key)
    return True

# ---------------------------------------------------------------------------
# REST endpoints
# ---------------------------------------------------------------------------

@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({"ok": True})


def _normalize_location(value: str) -> str:
    """Normalizes route names before applying the passenger route filter."""
    return " ".join(
        unicodedata.normalize("NFC", str(value or "")).casefold().split()
    )


def _filter_trips_by_route(trips, from_loc: str, to_loc: str):
    normalized_from = _normalize_location(from_loc)
    normalized_to = _normalize_location(to_loc)
    return [
        trip
        for trip in trips
        if (not normalized_from
            or _normalize_location(trip.from_location) == normalized_from)
        and (not normalized_to
             or _normalize_location(trip.to_location) == normalized_to)
    ]


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
    trips = _filter_trips_by_route(
        query.order_by(Trip.created_at.desc()).all(), from_loc, to_loc
    )
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
        duration_minutes=int(payload.get("duration_minutes") or 0),
        car_brand=str(payload.get("car_brand", "")),
        car_model=str(payload.get("car_model", "")),
        car_color=str(payload.get("car_color", "")),
        car_plate=str(payload.get("car_plate", "")),
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
        duration_minutes=int(data.get("duration_minutes") or 0),
        car_brand=str(data.get("car_brand", "")),
        car_model=str(data.get("car_model", "")),
        car_color=str(data.get("car_color", "")),
        car_plate=str(data.get("car_plate", "")),
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
    trips = _filter_trips_by_route(
        query.order_by(Trip.created_at.desc()).all(), from_loc, to_loc
    )
    emit("trips_list", {"trips": [t.to_dict() for t in trips]})


@socketio.on("book_trip")
def handle_book_trip(data):
    """Passenger books a seat on a trip."""
    data = data or {}
    trip_key = str(data.get("trip_id", "") or "").strip()
    trip = db.session.get(Trip, trip_key) if trip_key else None
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
        return {"ok": True, "id": str(trip_id)}
    return {"ok": False, "error": "Trip not found"}


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    socketio.run(app, host="0.0.0.0", port=port, debug=False)

