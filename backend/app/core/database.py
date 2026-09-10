import os
import sqlite3
from pathlib import Path
from contextlib import contextmanager

# Path relativo alla cartella backend/ (backend/runtime/trfmc.db), funziona per
# qualsiasi utente in esecuzione diretta (senza Docker, senza privilegi root).
# Per il deploy via docker-compose, TRFMC_SQLITE_PATH e' impostata esplicitamente
# a /runtime/trfmc.db (vedi docker-compose.yml), dove /runtime e' il volume montato.
_BACKEND_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_DB_PATH = str(_BACKEND_ROOT / "runtime" / "trfmc.db")


def get_db_path() -> Path:
    db_path = Path(os.getenv("TRFMC_SQLITE_PATH", DEFAULT_DB_PATH))
    db_path.parent.mkdir(parents=True, exist_ok=True)
    return db_path


@contextmanager
def get_connection():
    conn = sqlite3.connect(get_db_path())
    conn.row_factory = sqlite3.Row
    try:
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA foreign_keys=ON;")
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
