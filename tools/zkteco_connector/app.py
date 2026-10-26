from __future__ import annotations

import os
import secrets
from datetime import datetime
from typing import Any

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# Bind ONLY to 127.0.0.1 when launching. Never expose this service to the LAN.
API_TOKEN = os.environ.get("SILSILA_ZK_TOKEN", "").strip()
if len(API_TOKEN) < 24:
    raise RuntimeError("Set SILSILA_ZK_TOKEN to a random secret of at least 24 characters.")

ALLOWED_ORIGINS = [
    item.strip()
    for item in os.environ.get(
        "SILSILA_ALLOWED_ORIGINS",
        "https://silsilafoodstuffs-creator.github.io,http://localhost:5000,http://127.0.0.1:5000",
    ).split(",")
    if item.strip()
]

app = FastAPI(title="Silsila Local ZKTeco Connector", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)


def require_token(authorization: str | None = Header(default=None)) -> None:
    expected = f"Bearer {API_TOKEN}"
    if not authorization or not secrets.compare_digest(authorization, expected):
        raise HTTPException(status_code=401, detail="رمز موصل سلسلة غير صحيح.")


class DeviceRequest(BaseModel):
    ip: str = Field(min_length=7, max_length=45)
    port: int = Field(default=4370, ge=1, le=65535)
    comm_key: int = Field(default=0, ge=0, le=2147483647)
    timeout: int = Field(default=8, ge=2, le=30)


def _connect(req: DeviceRequest):
    # Import lazily so the service can start with a useful error if dependency is absent.
    try:
        from zk import ZK
    except ImportError as exc:
        raise HTTPException(status_code=500, detail="مكتبة pyzk غير مثبتة. شغّل install.bat.") from exc

    zk = ZK(req.ip, port=req.port, timeout=req.timeout, password=req.comm_key, force_udp=False, ommit_ping=True)
    try:
        connection = zk.connect()
        return zk, connection
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"فشل بروتوكول الاتصال بجهاز البصمة: {type(exc).__name__}: {exc}") from exc


@app.get("/health")
def health(_: None = Depends(require_token)) -> dict[str, Any]:
    return {"ok": True, "service": "silsila-zkteco-local", "version": "0.1.0"}


@app.post("/device/test")
def test_device(req: DeviceRequest, _: None = Depends(require_token)) -> dict[str, Any]:
    zk, connection = _connect(req)
    try:
        try:
            serial = connection.get_serialnumber()
        except Exception:
            serial = None
        try:
            device_name = connection.get_device_name()
        except Exception:
            device_name = None
        try:
            firmware = connection.get_firmware_version()
        except Exception:
            firmware = None
        return {
            "ok": True,
            "ip": req.ip,
            "port": req.port,
            "serial_number": serial,
            "device_name": device_name,
            "firmware_version": firmware,
            "tested_at": datetime.now().astimezone().isoformat(),
        }
    finally:
        try:
            connection.disconnect()
        except Exception:
            pass


@app.post("/attendance/pull")
def pull_attendance(req: DeviceRequest, _: None = Depends(require_token)) -> dict[str, Any]:
    zk, connection = _connect(req)
    try:
        try:
            records = connection.get_attendance()
        except Exception as exc:
            raise HTTPException(status_code=502, detail=f"اتصل الجهاز لكن تعذرت قراءة الحركات: {type(exc).__name__}: {exc}") from exc
        items = []
        for record in records:
            timestamp = getattr(record, "timestamp", None)
            items.append({
                "employee_code": str(getattr(record, "user_id", "") or ""),
                "timestamp": timestamp.isoformat() if timestamp else None,
                "status": getattr(record, "status", None),
                "punch": getattr(record, "punch", None),
            })
        return {
            "ok": True,
            "ip": req.ip,
            "count": len(items),
            "records": items,
            "warning": "هذه استجابة قراءة فقط؛ لم تُحفظ السجلات في قاعدة بيانات سلسلة بعد.",
        }
    finally:
        try:
            connection.disconnect()
        except Exception:
            pass
