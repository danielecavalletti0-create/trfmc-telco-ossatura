from datetime import datetime, timezone
import time

def now_utc() -> datetime:
    return datetime.now(timezone.utc)

def monotonic_ns() -> int:
    return time.monotonic_ns()
