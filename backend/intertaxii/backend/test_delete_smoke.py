"""Smoke test: trip delete (REST + Socket.IO) with trip_deleted broadcast."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, 'smoke_test.db')
if os.path.exists(DB):
    os.remove(DB)
os.environ['DATABASE_URL'] = 'sqlite:///' + DB

import app as backend  # noqa: E402

client = backend.app.test_client()
sio = backend.socketio.test_client(backend.app)
sio.get_received()  # drain connect trips_list

payload = {
    'driver_id': '999',
    'driver_name': 'Ronanda',
    'driver_phone': '999',
    'from_location': 'Кулоб',
    'to_location': 'Душанбе',
    'departure_time': '2026-09-06T10:00:00',
    'price': 50,
    'available_seats': 4,
}

# 1) Create trip via REST
r = client.post('/api/trips', json=payload)
assert r.status_code == 201, r.status_code
tid = r.get_json()['trip']['id']
print('POST /api/trips -> 201, id:', tid)

# 2) Delete it via REST -> 200 + trip_deleted broadcast
r = client.delete('/api/trips/' + tid)
assert r.status_code == 200, (r.status_code, r.data)
assert r.get_json() == {'ok': True, 'id': tid}, r.get_json()
events = sio.get_received()
deleted = [e for e in events if e['name'] == 'trip_deleted']
assert deleted and deleted[0]['args'] == [{'id': tid}], events
print('DELETE /api/trips/%s -> 200, broadcast:' % tid, deleted[0]['args'])

# 3) Trip must be gone from GET /api/trips
r = client.get('/api/trips')
assert all(t['id'] != tid for t in r.get_json()['trips'])
print('GET /api/trips -> trip gone (OK)')

# 4) Delete again -> 404
r = client.delete('/api/trips/' + tid)
assert r.status_code == 404, r.status_code
print('DELETE again -> 404 (OK)')

# 5) Socket.IO delete_trip path: create, delete via socket, verify broadcast
r = client.post('/api/trips', json=payload)
tid2 = r.get_json()['trip']['id']
sio2 = backend.socketio.test_client(backend.app)
sio2.get_received()
res = sio.emit('delete_trip', {'trip_id': tid2}, callback=True)
assert isinstance(res, dict) and res.get('ok') is True, res
events2 = sio2.get_received()
deleted2 = [e for e in events2 if e['name'] == 'trip_deleted']
assert deleted2 and deleted2[0]['args'] == [{'id': tid2}], events2
print('Socket delete_trip -> ack:', res, '| broadcast:', deleted2[0]['args'])

# 6) Socket delete with unknown id -> ok False, no broadcast
sio2.get_received()
res = sio.emit('delete_trip', {'trip_id': 'no-such-id'}, callback=True)
assert isinstance(res, dict) and res.get('ok') is False, res
assert not [e for e in sio2.get_received() if e['name'] == 'trip_deleted']
print('Socket delete_trip unknown id -> ok=False, no broadcast (OK)')

with backend.app.app_context():
    backend.db.engine.dispose()
os.remove(DB)
print('ALL DELETE SMOKE TESTS PASSED')
