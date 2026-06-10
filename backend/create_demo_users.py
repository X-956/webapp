from typing import Dict, List, Optional

import pymysql

from auth import hash_password
from db import get_connection


DEMO_USERS: List[Dict[str, Optional[object]]] = [
    {
        "username": "admin",
        "password": "Admin123!",
        "role": "admin",
        "display_name": "系统管理员",
        "related_doctor_id": None,
    },
    {
        "username": "doctor01",
        "password": "Doctor123!",
        "role": "doctor",
        "display_name": "张医生",
        "related_doctor_id": 1,
    },
    {
        "username": "readonly",
        "password": "Readonly123!",
        "role": "readonly",
        "display_name": "只读访客",
        "related_doctor_id": None,
    },
]


def upsert_demo_users() -> None:
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            for user in DEMO_USERS:
                cursor.execute(
                    """
                    INSERT INTO app_users(
                        username,
                        password_hash,
                        role,
                        display_name,
                        related_doctor_id,
                        is_active
                    )
                    VALUES(%s, %s, %s, %s, %s, 1)
                    ON DUPLICATE KEY UPDATE
                        password_hash = VALUES(password_hash),
                        role = VALUES(role),
                        display_name = VALUES(display_name),
                        related_doctor_id = VALUES(related_doctor_id),
                        is_active = VALUES(is_active)
                    """,
                    (
                        user["username"],
                        hash_password(str(user["password"])),
                        user["role"],
                        user["display_name"],
                        user["related_doctor_id"],
                    ),
                )
        conn.commit()
    except pymysql.MySQLError:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    try:
        upsert_demo_users()
    except pymysql.MySQLError as exc:
        error_code = exc.args[0] if exc.args else None
        if error_code in {1142, 1146}:
            print("初始化失败：请先使用 root 执行 backend/auth_init.sql。")
            print('示例：cmd /c "mysql -u root -p < backend\\auth_init.sql"')
        else:
            print(f"初始化失败：{exc}")
        raise SystemExit(1) from exc

    print("演示账号已初始化：admin、doctor01、readonly")
