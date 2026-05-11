from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List
import hashlib
import json
import os
import tarfile


class OpsBackupService:
    service_name = "TRFMC_OPERATIONAL_BACKUP_RECOVERY_CONTROL_V0_21"

    def __init__(self):
        self.runtime_root = Path("/runtime")
        self.backup_root = self.runtime_root / "backups"
        self.backup_root.mkdir(parents=True, exist_ok=True)

    def now(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def status(self) -> Dict[str, Any]:
        db = self.runtime_root / "trfmc.db"
        vault = self.runtime_root / "evidence_vault"
        backups = self.list_backups()["backups"]

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "runtime_root": str(self.runtime_root),
            "backup_root": str(self.backup_root),
            "sqlite_db": {
                "path": str(db),
                "exists": db.exists(),
                "size_bytes": db.stat().st_size if db.exists() else 0,
                "sha256": self._sha256(db) if db.exists() else None,
            },
            "evidence_vault": {
                "path": str(vault),
                "exists": vault.exists(),
                "file_count": self._count_files(vault) if vault.exists() else 0,
                "size_bytes": self._dir_size(vault) if vault.exists() else 0,
            },
            "backup_count": len(backups),
            "latest_backup": backups[0] if backups else None,
            "scope": "runtime-only from backend container; full project backup is handled by scripts/trfmc_backup_project.sh on host",
        }

    def create_runtime_backup(self) -> Dict[str, Any]:
        ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        name = f"trfmc_runtime_backup_v21_{ts}"
        archive_path = self.backup_root / f"{name}.tar.gz"
        manifest_path = self.backup_root / f"{name}_manifest.json"

        included = []
        candidates = [
            self.runtime_root / "trfmc.db",
            self.runtime_root / "evidence_vault",
        ]

        with tarfile.open(archive_path, "w:gz") as tar:
            for item in candidates:
                if item.exists():
                    arcname = item.relative_to(self.runtime_root)
                    tar.add(item, arcname=str(arcname))
                    included.append(str(item))

        manifest = {
            "service": self.service_name,
            "timestamp": self.now(),
            "backup_type": "RUNTIME_BACKUP",
            "archive": str(archive_path),
            "manifest": str(manifest_path),
            "included": included,
            "archive_size_bytes": archive_path.stat().st_size if archive_path.exists() else 0,
            "archive_sha256": self._sha256(archive_path) if archive_path.exists() else None,
            "runtime_root": str(self.runtime_root),
            "notes": [
                "This backup includes runtime/trfmc.db and runtime/evidence_vault when present.",
                "It does not include source code; use scripts/trfmc_backup_project.sh on host for full project backup.",
                "Restore should be manual and deliberate; do not overwrite a live DB without stopping the stack.",
            ],
        }

        manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "status": "CREATED",
            "backup": manifest,
        }

    def list_backups(self) -> Dict[str, Any]:
        records = []

        for archive in sorted(self.backup_root.glob("trfmc_runtime_backup_v21_*.tar.gz"), reverse=True):
            manifest = archive.with_name(archive.stem.replace(".tar", "") + "_manifest.json")
            data = None
            if manifest.exists():
                try:
                    data = json.loads(manifest.read_text(encoding="utf-8"))
                except Exception:
                    data = None

            records.append({
                "archive": str(archive),
                "name": archive.name,
                "size_bytes": archive.stat().st_size,
                "sha256": self._sha256(archive),
                "manifest": str(manifest) if manifest.exists() else None,
                "created_hint": archive.name.replace("trfmc_runtime_backup_v21_", "").replace(".tar.gz", ""),
                "data": data,
            })

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "backup_root": str(self.backup_root),
            "count": len(records),
            "backups": records,
        }

    def latest_manifest(self) -> Dict[str, Any]:
        backups = self.list_backups()["backups"]
        if not backups:
            return {
                "service": self.service_name,
                "timestamp": self.now(),
                "status": "EMPTY",
                "message": "No runtime backup has been created yet.",
            }

        latest = backups[0]
        if latest.get("data"):
            return latest["data"]

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "status": "MANIFEST_UNAVAILABLE",
            "latest": latest,
        }

    def _sha256(self, path: Path) -> str:
        h = hashlib.sha256()
        with path.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        return h.hexdigest()

    def _count_files(self, path: Path) -> int:
        return sum(1 for p in path.rglob("*") if p.is_file())

    def _dir_size(self, path: Path) -> int:
        total = 0
        for p in path.rglob("*"):
            if p.is_file():
                total += p.stat().st_size
        return total
