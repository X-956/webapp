import os
from pathlib import Path

import pymysql
from dotenv import load_dotenv


load_dotenv(dotenv_path=Path(__file__).with_name(".env"), override=True)


def _get_port() -> int:
    value = os.getenv("MYSQL_PORT", "3306")
    try:
        return int(value)
    except ValueError:
        return 3306


DB_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "localhost"),
    "port": _get_port(),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", ""),
    "database": os.getenv("MYSQL_DATABASE", "hospital_outpatient"),
    "charset": "utf8mb4",
    "cursorclass": pymysql.cursors.DictCursor,
    "autocommit": False,
}


def get_connection():
    return pymysql.connect(**DB_CONFIG)
