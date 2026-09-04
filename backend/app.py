"""Flask-SocketIO backend for the InterTaxi real-time taxi application.

Drivers post trips (announcements) which are stored in SQLite and broadcast
to all connected passengers. Passengers can search active trips and book
seats on them.

Run with:
    python app.py
"""

import eventlet
eventlet.monkey_patch()
import os
import logging
import uuid
from flask import Flask, request, render_template_string
from flask_socketio import SocketIO, emit
from models import db, Trip

# ---------------------------------------------------------------------------
# App & DB setup
# ---------------------------------------------------------------------------
app = Flask(__name__)
basedir = os.path.abspath(os.path.dirname(__file__))

# Prefer DATABASE_URL (e.g. Render PostgreSQL) so data survives redeploys on
# the ephemeral Render filesystem; fall back to a local SQLite file.
database_url = os.environ.get('DATABASE_URL', '').strip()
if database_url.startswith('postgres://'):
    # Older SQLAlchemy versions reject the `postgres://` scheme.
    database_url = database_url.replace('postgres://', 'postgresql://', 1)
app.config['SQLALCHEMY_DATABASE_URI'] = database_url or (
    'sqlite:///' + os.path.join(basedir, 'intertaxi.db')
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db.init_app(app)


def create_tables():
    """Create tables if they do not exist (idempotent).

    Runs at import time so it also executes under gunicorn (`app:app`),
    not only via `python app.py`.
    """
    with app.app_context():
        db.create_all()


create_tables()

# Роҳи асосии сервер, то дар браузер хатогӣ надиҳад
@app.route('/')
def home():
    return {"status": "online", "message": "InterTaxi Backend is running!"}, 200

socketio = SocketIO(app, cors_allowed_origins='*', async_mode='eventlet')

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# REST endpoints
# ---------------------------------------------------------------------------
@app.route('/')
def index():
    """Show all trips in a simple HTML page for debugging."""
    trips = Trip.query.order_by(Trip.created_at.desc()).all()
    html = '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>InterTaxi - Trips</title>
        <meta http-equiv="refresh" content="5">
        <style>
            body { font-family: Arial; margin: 20px; background: #f5f5f5; }
            h1 { color: #0066FF; }
            .trip { background: white; padding: 15px; margin: 10px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .route { font-size: 18px; font-weight: bold; }
            .details { color: #666; margin-top: 5px; }
            .status { display: inline-block; padding: 3px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }
            .active { background: #4CAF50; color: white; }
            .booked { background: #999; color: white; }
            .empty { text-align: center; padding: 40px; color: #999; }
            .stats { background: #0066FF; color: white; padding: 10px 15px; border-radius: 8px; margin-bottom: 20px; }
        </style>
    </head>
    <body>
        <h1>🚗 InterTaxi - Live Trips</h1>
        <div class="stats">
            Total trips: ''' + str(len(trips)) + ''' | Auto-refresh: 5s
        </div>
        <a href="/api/trips" style="color:#0066FF;">View JSON API</a>
        <hr>
    '''
    if not trips:
        html += '<div class="empty"><h2>No trips posted yet</h2><p>Post a trip from the Flutter app and refresh this page</p></div>'
    else:
        for t in trips:
            html += f'''
            <div class="trip">
                <span class="status {'active' if t.status == 'active' else 'booked'}">{t.status.upper()}</span>
                <div class="route">📍 {t.from_location} → {t.to_location}</div>
                <div class="details">
                    💰 Price: {t.price} Somoni &nbsp;|&nbsp; 🪑 Seats: {t.available_seats}<br>
                    🕐 Departure: {t.departure_time}<br>
                    👤 Driver: {t.driver_name or 'N/A'} &nbsp;|&nbsp; 📞 {t.driver_phone or 'N/A'}
                </div>
            </div>
            '''
    html += '</body></html>'
    return render_template_string(html)


def _create_trip(data, fallback_driver_id='rest'):
    """Validate payload and persist a new trip announcement.

    Shared by the Socket.IO ``post_trip`` handler and the REST
    ``POST /api/trips`` endpoint so both paths behave identically.

    Returns a ``(trip_or_None, error_or_None)`` tuple.
    """
    if not isinstance(data, dict):
        return None, 'Invalid payload — expected JSON object'

    required = ['from_location', 'to_location', 'departure_time', 'price', 'available_seats']
    missing = [f for f in required if f not in data or not str(data[f]).strip()]
    if missing:
        return None, f'Missing required fields: {", ".join(missing)}'

    try:
        price = int(data['price'])
        seats = int(data['available_seats'])
        if price <= 0 or seats <= 0:
            raise ValueError
    except (ValueError, TypeError):
        return None, 'Price and available_seats must be positive integers'

    trip = Trip(
        driver_id=data.get('driver_id', fallback_driver_id),
        driver_name=data.get('driver_name', '').strip(),
        driver_phone=data.get('driver_phone', '').strip(),
        from_location=data['from_location'].strip(),
        to_location=data['to_location'].strip(),
        departure_time=data['departure_time'],
        price=price,
        available_seats=seats,
        status='active',
    )
    db.session.add(trip)
    db.session.commit()
    return trip, None


@app.route('/api/trips', methods=['GET'])
def get_trips_rest():
    """Return all active trips as JSON."""
    trips = Trip.query.filter_by(status='active').order_by(Trip.created_at.desc()).all()
    return {'trips': [t.to_dict() for t in trips]}, 200


@app.route('/api/trips', methods=['POST'])
def create_trip_rest():
    """Create a trip announcement via a plain HTTP POST (JSON body).

    This is the REST fallback used by the Flutter app so driver
    announcements reach the backend (and the web UI at ``/``) even when
    no Socket.IO connection is active.
    """
    data = request.get_json(silent=True) or {}
    trip, error = _create_trip(data)
    if error:
        return {'error': error}, 400
    logger.info(
        f'REST trip posted: {trip.id} | '
        f'{trip.from_location} -> {trip.to_location}'
    )
    # Notify connected passengers in real time as well.
    socketio.emit('new_trip', trip.to_dict())
    return {'trip': trip.to_dict()}, 201


@app.route('/api/trips/search', methods=['GET'])
def search_trips_rest():
    """Search active trips by from/to location (case-insensitive partial match)."""
    from_loc = request.args.get('from', '').strip()
    to_loc = request.args.get('to', '').strip()
    query = Trip.query.filter_by(status='active')
    if from_loc:
        query = query.filter(Trip.from_location.ilike(f'%{from_loc}%'))
    if to_loc:
        query = query.filter(Trip.to_location.ilike(f'%{to_loc}%'))
    trips = query.order_by(Trip.departure_time.asc()).all()
    return {'trips': [t.to_dict() for t in trips]}, 200


@app.route('/api/trips/<trip_id>/book', methods=['POST'])
def book_trip_rest(trip_id):
    """Book one seat on a trip (REST fallback)."""
    trip = Trip.query.get(trip_id)
    if not trip:
        return {'error': 'Trip not found'}, 404
    if trip.status != 'active' or trip.available_seats <= 0:
        return {'error': 'No seats available'}, 400
    trip.available_seats -= 1
    if trip.available_seats == 0:
        trip.status = 'booked'
    db.session.commit()
    socketio.emit('trip_updated', trip.to_dict())
    return {'trip': trip.to_dict()}, 200


@app.route('/api/health', methods=['GET'])
def health():
    """Health check endpoint for Render / uptime monitors."""
    return {
        'status': 'ok',
        'active_trips': Trip.query.filter_by(status='active').count(),
    }, 200


# ---------------------------------------------------------------------------
# Socket.IO events
# ---------------------------------------------------------------------------
@socketio.on('connect')
def handle_connect():
    """Send the current list of active trips to the newly connected client."""
    logger.info(f'Client connected: {request.sid}')
    trips = Trip.query.filter_by(status='active').order_by(Trip.created_at.desc()).all()
    emit('trips_list', {'trips': [t.to_dict() for t in trips]})


@socketio.on('disconnect')
def handle_disconnect():
    logger.info(f'Client disconnected: {request.sid}')


@socketio.on('post_trip')
def handle_post_trip(data):
    """Driver posts a new trip announcement.

    Expected payload:
        driver_id, driver_name, driver_phone,
        from_location, to_location, departure_time,
        price (int), available_seats (int)
    """
    logger.info(f'📥 post_trip received: {data}')

    trip, error = _create_trip(data, fallback_driver_id=request.sid)
    if error:
        emit('error', {'message': error})
        return

    logger.info(f'New trip posted: {trip.id} | {trip.from_location} -> {trip.to_location}')

    # Broadcast to ALL connected clients (including the poster)
    emit('new_trip', trip.to_dict(), broadcast=True)


@socketio.on('get_trips')
def handle_get_trips(data=None):
    """Return active trips, optionally filtered by from/to location.

    Optional payload:
        from (str): partial origin match
        to (str): partial destination match
    """
    query = Trip.query.filter_by(status='active')

    if isinstance(data, dict):
        from_filter = data.get('from', '').strip()
        to_filter = data.get('to', '').strip()
        if from_filter:
            query = query.filter(Trip.from_location.ilike(f'%{from_filter}%'))
        if to_filter:
            query = query.filter(Trip.to_location.ilike(f'%{to_filter}%'))

    trips = query.order_by(Trip.departure_time.asc()).all()
    emit('trips_list', {'trips': [t.to_dict() for t in trips]})


@socketio.on('book_trip')
def handle_book_trip(data):
    """Passenger books one seat on a trip.

    Expected payload:
        trip_id (str)
        passenger_name (str, optional)
        passenger_phone (str, optional)
    """
    if not isinstance(data, dict):
        emit('error', {'message': 'Invalid payload — expected JSON object'})
        return

    trip_id = data.get('trip_id', '').strip()
    if not trip_id:
        emit('error', {'message': 'trip_id is required'})
        return

    trip = Trip.query.get(trip_id)
    if not trip:
        emit('error', {'message': 'Trip not found'})
        return

    if trip.status != 'active' or trip.available_seats <= 0:
        emit('error', {'message': 'No seats available on this trip'})
        return

    trip.available_seats -= 1
    if trip.available_seats == 0:
        trip.status = 'booked'
    db.session.commit()

    logger.info(
        f'Trip {trip.id} booked by {data.get("passenger_name", "unknown")} — '
        f'{trip.available_seats} seat(s) remaining'
    )

    # Confirm to the booker
    emit('booking_confirmed', {
        'trip_id': trip.id,
        'trip': trip.to_dict(),
        'passenger_name': data.get('passenger_name', ''),
        'passenger_phone': data.get('passenger_phone', ''),
    })

    # Broadcast updated trip to everyone so lists stay in sync
    emit('trip_updated', trip.to_dict(), broadcast=True)


# ---------------------------------------------------------------------------
# Legacy order events (kept so the older order-based screens keep working)
# ---------------------------------------------------------------------------
@socketio.on('new_order')
def handle_new_order(data):
    """Broadcast a passenger ride request to all drivers."""
    if not isinstance(data, dict):
        emit('error', {'message': 'Invalid payload — expected JSON object'})
        return
    order = dict(data)
    if not order.get('order_id'):
        order['order_id'] = str(uuid.uuid4())
    socketio.emit('new_order', order)


@socketio.on('accept_order')
def handle_accept_order(data):
    """Broadcast that a driver accepted an order."""
    if isinstance(data, dict):
        socketio.emit('accept_order', dict(data))


@socketio.on('update_location')
def handle_update_location(data):
    """Relay driver GPS updates to everyone else (location streams)."""
    if isinstance(data, dict):
        socketio.emit('update_location', dict(data), skip_sid=request.sid)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == '__main__':
    print('\n' + '='*60)
    print('  InterTaxi Flask Server Started!')
    print('  Web UI:     http://localhost:5000')
    print('  API:       http://localhost:5000/api/trips')
    print('  Socket.IO: http://localhost:5000')
    print('='*60 + '\n')

    port = int(os.environ.get("PORT", 5000))
    socketio.run(app, host='0.0.0.0', port=port, debug=False)