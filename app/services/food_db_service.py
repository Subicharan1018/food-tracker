import sqlite3
import os
from pathlib import Path
from app.config import settings, logger

class FoodDbService:
    """Service providing SQLite FTS5 queries against the IFCT 2017 Indian Food Composition Database."""

    def __init__(self, db_path: str = None):
        self._db_path = db_path or settings.ifct_db_path
        if not os.path.isabs(self._db_path):
            base = Path(__file__).resolve().parent.parent.parent
            self._db_path = str(base / self._db_path)

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self._db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def is_available(self) -> bool:
        return os.path.exists(self._db_path)

    def search_foods(self, query: str, limit: int = 20) -> list[dict]:
        if not query or not query.strip() or not self.is_available():
            return []
        q = query.strip()
        conn = self._get_connection()
        cur = conn.cursor()
        results = []
        try:
            # 1. Try FTS5 match first for high-relevance ranking
            fts_query = f'"{q}"*'
            cur.execute("""
                SELECT f.* FROM foods f
                JOIN foods_fts fts ON f.rowid = fts.rowid
                WHERE foods_fts MATCH ?
                LIMIT ?
            """, (fts_query, limit))
            rows = cur.fetchall()
            if rows:
                results = [dict(r) for r in rows]
            else:
                # 2. Fallback to LIKE substring search across English & Regional Indian names
                like_q = f"%{q}%"
                cur.execute("""
                    SELECT * FROM foods
                    WHERE name LIKE ?
                       OR tamil_name LIKE ?
                       OR hindi_name LIKE ?
                       OR telugu_name LIKE ?
                       OR scientific_name LIKE ?
                       OR local_names LIKE ?
                    LIMIT ?
                """, (like_q, like_q, like_q, like_q, like_q, like_q, limit))
                results = [dict(r) for r in cur.fetchall()]
        except Exception as e:
            logger.warning("IFCT Food DB search error for '%s': %s", query, e)
            like_q = f"%{q}%"
            cur.execute("SELECT * FROM foods WHERE name LIKE ? LIMIT ?", (like_q, limit))
            results = [dict(r) for r in cur.fetchall()]
        finally:
            conn.close()
        return results

    def get_food_by_code(self, code: str) -> dict | None:
        if not self.is_available():
            return None
        conn = self._get_connection()
        cur = conn.cursor()
        cur.execute("SELECT * FROM foods WHERE code = ?", (code.strip().upper(),))
        row = cur.fetchone()
        conn.close()
        return dict(row) if row else None

    def get_foods_by_group(self, group_name: str, limit: int = 50) -> list[dict]:
        if not self.is_available():
            return []
        conn = self._get_connection()
        cur = conn.cursor()
        cur.execute("SELECT * FROM foods WHERE food_group LIKE ? LIMIT ?", (f"%{group_name}%", limit))
        rows = cur.fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def get_all_food_names(self, limit: int = 200) -> list[str]:
        if not self.is_available():
            return []
        conn = self._get_connection()
        cur = conn.cursor()
        cur.execute("SELECT name, tamil_name, hindi_name FROM foods LIMIT ?", (limit,))
        rows = cur.fetchall()
        conn.close()
        names = []
        for r in rows:
            names.append(r["name"])
            if r["tamil_name"]:
                names.append(f"{r['name']} ({r['tamil_name']})")
        return names

food_db_service = FoodDbService()
