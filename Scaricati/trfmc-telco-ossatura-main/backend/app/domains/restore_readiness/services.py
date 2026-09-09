from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional
import hashlib
import json
import tarfile


class RestoreReadinessService:
    service_name = "TRFMC_RESTORE_READINESS_DISASTER_RECOVERY_DRILL_V0_22"

    def __init__(self):
        self.runtime_root = Path("/runtime")
        self.backup_root = self.runtime_root / "backups"
        self.db_path = self.runtime_root / "trfmc.db"
        self.vault_path = self.runtime_root / "evidence_vault"

    def now(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def readiness(self) -> Dict[str, Any]:
        backups = self._runtime_backups()
        latest = backups[0] if backups else None

        checks = [
            self._check(
                "RUNTIME_ROOT_EXISTS",
                self.runtime_root.exists(),
                "Runtime root /runtime accessibile dal container backend.",
                {"path": str(self.runtime_root)},
                "CRITICAL",
            ),
            self._check(
                "SQLITE_DB_PRESENT",
                self.db_path.exists(),
                "Database SQLite runtime presente.",
                {
                    "path": str(self.db_path),
                    "size_bytes": self.db_path.stat().st_size if self.db_path.exists() else 0,
                    "sha256": self._sha256(self.db_path) if self.db_path.exists() else None,
                },
                "CRITICAL",
            ),
            self._check(
                "EVIDENCE_VAULT_PRESENT",
                self.vault_path.exists(),
                "Evidence Vault presente nel runtime.",
                {
                    "path": str(self.vault_path),
                    "file_count": self._count_files(self.vault_path) if self.vault_path.exists() else 0,
                    "size_bytes": self._dir_size(self.vault_path) if self.vault_path.exists() else 0,
                },
                "HIGH",
            ),
            self._check(
                "RUNTIME_BACKUP_AVAILABLE",
                len(backups) > 0,
                "Almeno un backup runtime v0.21/v0.22 presente in /runtime/backups.",
                {
                    "backup_root": str(self.backup_root),
                    "backup_count": len(backups),
                    "latest": latest.get("name") if latest else None,
                },
                "CRITICAL",
            ),
            self._check(
                "LATEST_BACKUP_MANIFEST_AVAILABLE",
                bool(latest and latest.get("manifest_exists")),
                "Manifest JSON del backup runtime più recente presente.",
                latest or {},
                "HIGH",
            ),
            self._check(
                "LATEST_BACKUP_HASH_VERIFIED",
                bool(latest and latest.get("sha256_verified")),
                "SHA256 del backup runtime più recente verificato rispetto al manifest.",
                latest or {},
                "CRITICAL",
            ),
            self._check(
                "LATEST_BACKUP_TAR_READABLE",
                bool(latest and latest.get("tar_readable")),
                "Archivio tar.gz del backup runtime più recente leggibile.",
                latest or {},
                "CRITICAL",
            ),
            self._check(
                "LATEST_BACKUP_HAS_DB",
                bool(latest and latest.get("contains_trfmc_db")),
                "Il backup runtime contiene trfmc.db.",
                latest or {},
                "CRITICAL",
            ),
            self._check(
                "LATEST_BACKUP_HAS_EVIDENCE_VAULT",
                bool(latest and latest.get("contains_evidence_vault")),
                "Il backup runtime contiene evidence_vault.",
                latest or {},
                "HIGH",
            ),
        ]

        failed = [c for c in checks if not c["passed"]]

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "mode": "VERIFY_ONLY_NO_RESTORE",
            "overall_status": "READY_FOR_DRY_RUN" if not failed else "ATTENTION_REQUIRED",
            "destructive_actions_enabled": False,
            "checks": checks,
            "summary": {
                "total": len(checks),
                "passed": sum(1 for c in checks if c["passed"]),
                "failed": len(failed),
                "backup_count": len(backups),
                "latest_backup": latest.get("name") if latest else None,
            },
            "next_safe_action": "Run /api/restore/drill for a non-destructive restore simulation.",
        }

    def plan(self) -> Dict[str, Any]:
        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "plan_type": "COLD_RESTORE_MANUAL_PLAN",
            "destructive_actions_enabled": False,
            "principle": "Stop stack first. Never overwrite a live SQLite DB. Verify hash and archive contents before restore.",
            "phases": [
                {
                    "phase": 1,
                    "name": "Pre-restore evidence capture",
                    "commands": [
                        "cd /home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2",
                        "bash scripts/trfmc_status.sh",
                        "bash scripts/trfmc_verify.sh",
                        "bash scripts/trfmc_backup_project.sh",
                    ],
                },
                {
                    "phase": 2,
                    "name": "Stop controlled runtime",
                    "commands": [
                        "bash scripts/trfmc_stop.sh",
                        "sudo docker ps --format 'table {{.Names}}\\t{{.Image}}\\t{{.Status}}\\t{{.Ports}}'",
                        "sudo ss -ltnp | grep -E ':(8000|5173)\\b' || true",
                    ],
                },
                {
                    "phase": 3,
                    "name": "Verify selected backup",
                    "commands": [
                        "ls -lh runtime/backups/",
                        "sha256sum runtime/backups/*.tar.gz",
                        "tar -tzf runtime/backups/<BACKUP>.tar.gz | head -n 80",
                    ],
                },
                {
                    "phase": 4,
                    "name": "Restore to staging directory first",
                    "commands": [
                        "mkdir -p runtime_restore_test",
                        "tar -xzf runtime/backups/<BACKUP>.tar.gz -C runtime_restore_test",
                        "ls -lah runtime_restore_test",
                    ],
                },
                {
                    "phase": 5,
                    "name": "Validate restored DB and vault before replacement",
                    "commands": [
                        "ls -lh runtime_restore_test/trfmc.db",
                        "find runtime_restore_test/evidence_vault -type f | head",
                    ],
                },
                {
                    "phase": 6,
                    "name": "Manual replacement only after validation",
                    "commands": [
                        "mv runtime runtime_before_restore_$(date +%Y%m%d_%H%M%S)",
                        "mkdir -p runtime",
                        "cp -a runtime_restore_test/trfmc.db runtime/",
                        "cp -a runtime_restore_test/evidence_vault runtime/",
                    ],
                },
                {
                    "phase": 7,
                    "name": "Restart and verify",
                    "commands": [
                        "bash scripts/trfmc_start.sh",
                        "bash scripts/trfmc_verify.sh",
                        "curl -s http://127.0.0.1:8000/api/health | python3 -m json.tool",
                    ],
                },
            ],
            "host_dry_run_script": "bash scripts/trfmc_restore_drill.sh",
        }

    def verify_backup(self, archive_name: Optional[str] = None) -> Dict[str, Any]:
        backups = self._runtime_backups()
        if not backups:
            return {
                "service": self.service_name,
                "timestamp": self.now(),
                "status": "NO_BACKUP_FOUND",
                "backup_root": str(self.backup_root),
            }

        selected = None
        if archive_name:
            selected = next((b for b in backups if b["name"] == archive_name), None)
        else:
            selected = backups[0]

        if not selected:
            return {
                "service": self.service_name,
                "timestamp": self.now(),
                "status": "BACKUP_NOT_FOUND",
                "archive_name": archive_name,
                "available": [b["name"] for b in backups],
            }

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "status": "VERIFIED" if selected.get("sha256_verified") and selected.get("tar_readable") else "ATTENTION_REQUIRED",
            "backup": selected,
        }

    def drill(self) -> Dict[str, Any]:
        readiness = self.readiness()
        backups = self._runtime_backups()
        latest = backups[0] if backups else None

        steps = []
        steps.append(self._drill_step("CHECK_RUNTIME_ROOT", self.runtime_root.exists(), str(self.runtime_root)))
        steps.append(self._drill_step("CHECK_DB", self.db_path.exists(), str(self.db_path)))
        steps.append(self._drill_step("CHECK_EVIDENCE_VAULT", self.vault_path.exists(), str(self.vault_path)))
        steps.append(self._drill_step("SELECT_LATEST_RUNTIME_BACKUP", bool(latest), latest.get("archive") if latest else None))

        if latest:
            steps.append(self._drill_step("VERIFY_MANIFEST", latest.get("manifest_exists"), latest.get("manifest")))
            steps.append(self._drill_step("VERIFY_SHA256", latest.get("sha256_verified"), latest.get("sha256")))
            steps.append(self._drill_step("READ_TAR_LIST", latest.get("tar_readable"), latest.get("archive")))
            steps.append(self._drill_step("ASSERT_CONTAINS_DB", latest.get("contains_trfmc_db"), "trfmc.db"))
            steps.append(self._drill_step("ASSERT_CONTAINS_VAULT", latest.get("contains_evidence_vault"), "evidence_vault"))

        ok = all(s["ok"] for s in steps)

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "drill_type": "NON_DESTRUCTIVE_DRY_RUN",
            "destructive_actions_enabled": False,
            "overall_status": "DRY_RUN_PASS" if ok else "DRY_RUN_ATTENTION_REQUIRED",
            "readiness_status": readiness.get("overall_status"),
            "steps": steps,
            "restore_plan_ref": "/api/restore/plan",
            "explicit_non_actions": [
                "No file extraction into live runtime.",
                "No DB overwrite.",
                "No container stop/start from backend API.",
                "No deletion or replacement.",
            ],
        }

    def _runtime_backups(self) -> List[Dict[str, Any]]:
        if not self.backup_root.exists():
            return []

        records = []
        for archive in sorted(self.backup_root.glob("trfmc_runtime_backup_v21_*.tar.gz"), reverse=True):
            records.append(self._inspect_archive(archive))

        for archive in sorted(self.backup_root.glob("trfmc_runtime_backup_v22_*.tar.gz"), reverse=True):
            records.append(self._inspect_archive(archive))

        records.sort(key=lambda x: x.get("mtime", 0), reverse=True)
        return records

    def _inspect_archive(self, archive: Path) -> Dict[str, Any]:
        manifest = self._manifest_for_archive(archive)
        manifest_data = None
        manifest_exists = manifest.exists()

        if manifest_exists:
            try:
                manifest_data = json.loads(manifest.read_text(encoding="utf-8"))
            except Exception as exc:
                manifest_data = {"error": str(exc)}

        sha = self._sha256(archive)
        expected_sha = None
        if isinstance(manifest_data, dict):
            expected_sha = manifest_data.get("archive_sha256")

        tar_readable = False
        members = []
        contains_db = False
        contains_vault = False
        tar_error = None

        try:
            with tarfile.open(archive, "r:gz") as tar:
                members = tar.getnames()
                tar_readable = True
                contains_db = any(m.endswith("trfmc.db") or m == "trfmc.db" for m in members)
                contains_vault = any(m.startswith("evidence_vault") for m in members)
        except Exception as exc:
            tar_error = str(exc)

        return {
            "name": archive.name,
            "archive": str(archive),
            "mtime": archive.stat().st_mtime,
            "size_bytes": archive.stat().st_size,
            "sha256": sha,
            "manifest": str(manifest),
            "manifest_exists": manifest_exists,
            "manifest_data": manifest_data,
            "expected_sha256": expected_sha,
            "sha256_verified": bool(expected_sha and expected_sha == sha),
            "tar_readable": tar_readable,
            "tar_error": tar_error,
            "member_count": len(members),
            "sample_members": members[:40],
            "contains_trfmc_db": contains_db,
            "contains_evidence_vault": contains_vault,
        }

    def _manifest_for_archive(self, archive: Path) -> Path:
        base = archive.name
        if base.endswith(".tar.gz"):
            base = base[:-7]
        return archive.with_name(base + "_manifest.json")

    def _sha256(self, path: Path) -> str:
        h = hashlib.sha256()
        with path.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        return h.hexdigest()

    def _count_files(self, path: Path) -> int:
        return sum(1 for p in path.rglob("*") if p.is_file())

    def _dir_size(self, path: Path) -> int:
        return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())

    def _check(self, check_id: str, passed: bool, description: str, evidence: Dict[str, Any], severity: str) -> Dict[str, Any]:
        return {
            "check_id": check_id,
            "passed": bool(passed),
            "severity": severity,
            "description": description,
            "evidence": evidence,
        }

    def _drill_step(self, name: str, ok: bool, evidence: Any) -> Dict[str, Any]:
        return {
            "step": name,
            "ok": bool(ok),
            "evidence": evidence,
        }
