"""Database models for the InterTaxi backend."""

import uuid
from datetime import datetime
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


class Trip(db.Model):
    """Represents a driver's trip announcement.

    Fields:
        id: Unique identifier (UUID string).
        driver_id: Socket.IO user identifier of the posting driver.
        driver_name: Display name of the driver.
        driver_phone: Contact phone number of the driver.
        from_location: Origin city / location name.
        to_location: Destination city / location name.
        departure_time: ISO-8601 datetime string of scheduled departure.
        price: Price per seat (integer, in somoni).
        available_seats: Number of seats currently available.
        status: Either 'active' or 'booked'.
        created_at: Timestamp when the record was created.
    """

    __tablename__ = 'trips'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    driver_id = db.Column(db.String(128), nullable=False, index=True)
    driver_name = db.Column(db.String(128), nullable=False, default='')
    driver_phone = db.Column(db.String(32), nullable=False, default='')
    from_location = db.Column(db.String(256), nullable=False)
    to_location = db.Column(db.String(256), nullable=False)
    departure_time = db.Column(db.String(64), nullable=False)
    price = db.Column(db.Integer, nullable=False, default=0)
    available_seats = db.Column(db.Integer, nullable=False, default=0)
    status = db.Column(db.String(16), nullable=False, default='active')
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    def to_dict(self):
        """Serialize the trip to a plain dictionary for JSON / Socket.IO."""
        return {
            'id': self.id,
            'driver_id': self.driver_id,
            'driver_name': self.driver_name,
            'driver_phone': self.driver_phone,
            'from_location': self.from_location,
            'to_location': self.to_location,
            'departure_time': self.departure_time,
            'price': self.price,
            'available_seats': self.available_seats,
            'status': self.status,
            'created_at': self.created_at.isoformat() if self.created_at else '',
        }
