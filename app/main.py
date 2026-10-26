"""CloudRetail: a small analytical event API for a realistic AWS workload."""
import os
from datetime import datetime, timezone
from typing import Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import DateTime, Float, Integer, String, create_engine, func, select
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column


class Base(DeclarativeBase):
    pass


class Sale(Base):
    __tablename__ = "sales"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    store_id: Mapped[str] = mapped_column(String(64), index=True)
    product: Mapped[str] = mapped_column(String(128))
    quantity: Mapped[int] = mapped_column(Integer)
    unit_price: Mapped[float] = mapped_column(Float)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class SaleInput(BaseModel):
    store_id: str = Field(min_length=1, max_length=64)
    product: str = Field(min_length=1, max_length=128)
    quantity: int = Field(gt=0, le=100000)
    unit_price: float = Field(ge=0, le=1e9)


def connection_url() -> str:
    from urllib.parse import quote_plus
    host = os.getenv("DB_HOST", "localhost")
    name = os.getenv("DB_NAME", "cloudretail")
    user = quote_plus(os.getenv("DB_USER", "appadmin"))
    password = quote_plus(os.getenv("DB_PASSWORD", ""))
    port = os.getenv("DB_PORT", "5432")
    return f"postgresql+psycopg://{user}:{password}@{host}:{port}/{name}?sslmode=require"


app = FastAPI(title="CloudRetail AWS - Sales Analytics", version="1.0.0")
_engine = None


def get_engine():
    global _engine
    if _engine is None:
        _engine = create_engine(connection_url(), pool_pre_ping=True)
        Base.metadata.create_all(_engine)
    return _engine


@app.get("/health")
def health():
    # Liveness health check; deliberately independent of DB readiness.
    return {"status": "ok"}


@app.get("/ready")
def readiness():
    try:
        with Session(get_engine()) as session:
            session.execute(select(func.count()).select_from(Sale)).scalar_one()
        return {"status": "ready"}
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@app.post("/sales", status_code=201)
def add_sale(payload: SaleInput):
    with Session(get_engine()) as session:
        record = Sale(
            store_id=payload.store_id,
            product=payload.product,
            quantity=payload.quantity,
            unit_price=payload.unit_price,
            occurred_at=datetime.now(timezone.utc),
        )
        session.add(record)
        session.commit()
        session.refresh(record)
        return {"id": record.id, "store_id": record.store_id}


@app.get("/analytics/summary")
def analytics_summary():
    with Session(get_engine()) as session:
        orders, units, revenue = session.execute(
            select(func.count(Sale.id), func.coalesce(func.sum(Sale.quantity), 0),
                   func.coalesce(func.sum(Sale.quantity * Sale.unit_price), 0))
        ).one()
        return {"transactions": orders, "units_sold": units, "revenue": round(float(revenue), 2)}
