from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List


class DocsPortalService:
    service_name = "TRFMC_DOCUMENTATION_CONTENT_UPGRADE_V0_28"

    def __init__(self):
        self.docs_root = Path("/app/docs")
        if not self.docs_root.exists():
            self.docs_root = Path("backend/docs") if Path("backend/docs").exists() else Path("docs")

    def now(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def docs(self) -> List[Dict[str, Any]]:
        return [
            {"id": "operator-handbook", "title": "Operator Handbook", "path": "TRFMC_OPERATOR_HANDBOOK.md", "endpoint": "/api/docs/operator-handbook", "description": "Procedure operative principali."},
            {"id": "architecture", "title": "Architecture Current State", "path": "TRFMC_ARCHITECTURE_CURRENT_STATE.md", "endpoint": "/api/docs/architecture", "description": "Architettura corrente."},
            {"id": "backup-restore", "title": "Backup and Restore", "path": "TRFMC_BACKUP_AND_RESTORE.md", "endpoint": "/api/docs/backup-restore", "description": "Backup, restore readiness e drill."},
            {"id": "release-chain", "title": "Release Chain", "path": "TRFMC_RELEASE_CHAIN.md", "endpoint": "/api/docs/release-chain", "description": "Catena release."},
            {"id": "security", "title": "Security Baseline", "path": "TRFMC_SECURITY_BASELINE.md", "endpoint": "/api/docs/security", "description": "Postura sicurezza."},
            {"id": "commands", "title": "Command Reference", "path": "TRFMC_COMMAND_REFERENCE.md", "endpoint": "/api/docs/commands", "description": "Comandi ufficiali."},
        ]

    def index(self) -> Dict[str, Any]:
        documents = []
        for doc in self.docs():
            path = self.docs_root / doc["path"]
            documents.append({
                **doc,
                "exists": path.exists(),
                "size_bytes": path.stat().st_size if path.exists() else 0,
            })
        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "version": "0.28.0",
            "docs_root": str(self.docs_root),
            "count": len(documents),
            "documents": documents,
        }

    def get_doc(self, doc_id: str) -> Dict[str, Any]:
        doc = next((d for d in self.docs() if d["id"] == doc_id), None)
        if not doc:
            raise ValueError(f"Documento non trovato: {doc_id}")
        path = self.docs_root / doc["path"]
        if not path.exists():
            raise ValueError(f"File documento non trovato: {path}")
        content = path.read_text(encoding="utf-8")
        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "version": "0.28.0",
            "document": doc,
            "content_type": "text/markdown",
            "content": content,
            "size_bytes": len(content.encode("utf-8")),
        }
