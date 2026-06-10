import os
from datetime import date, datetime
from decimal import Decimal
from typing import Any, Dict, Iterable, List, Optional, Sequence

import pymysql
from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from starlette.requests import Request

from auth import (
    LoginRequest,
    TokenResponse,
    authenticate_user,
    get_current_user,
    require_roles,
    token_response,
)
from db import get_connection


app = FastAPI(title="Hospital Outpatient Registration API")


def _cors_origins() -> List[str]:
    raw = os.getenv("CORS_ORIGINS", "*").strip()
    if raw == "*":
        return ["*"]
    return [origin.strip() for origin in raw.split(",") if origin.strip()]


app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins(),
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class RegistrationCreate(BaseModel):
    patient_id: int
    department_id: int
    doctor_id: int
    visit_date: date


@app.post("/api/auth/login", response_model=TokenResponse)
def login(payload: LoginRequest) -> TokenResponse:
    user = authenticate_user(payload.username.strip(), payload.password)
    if not user:
        raise HTTPException(
            status_code=401,
            detail={"message": "用户名或密码错误"},
            headers={"WWW-Authenticate": "Bearer"},
        )
    return token_response(user)


@app.get("/api/auth/me")
def get_me(current_user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    return current_user


@app.post("/api/auth/logout")
def logout() -> Dict[str, str]:
    return {"message": "退出登录成功"}


def _db_error_message(exc: pymysql.MySQLError) -> str:
    if len(exc.args) >= 2:
        return f"数据库错误：{exc.args[1]}"
    return f"数据库错误：{str(exc)}"


def _db_error_status_code(exc: pymysql.MySQLError) -> int:
    error_code = exc.args[0] if exc.args else None
    if error_code in {1048, 1062, 1452, 1644, 3819}:
        return 400
    return 500


@app.exception_handler(pymysql.MySQLError)
async def mysql_exception_handler(
    request: Request, exc: pymysql.MySQLError
) -> JSONResponse:
    return JSONResponse(
        status_code=_db_error_status_code(exc),
        content={"message": _db_error_message(exc)},
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    if isinstance(exc.detail, dict) and "message" in exc.detail:
        content = exc.detail
    else:
        content = {"message": str(exc.detail)}
    return JSONResponse(status_code=exc.status_code, content=content)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={"message": "请求参数校验失败", "errors": exc.errors()},
    )


def _json_value(value: Any) -> Any:
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return float(value)
    return value


def _json_row(row: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    if row is None:
        return {}
    return {key: _json_value(value) for key, value in row.items()}


def _json_rows(rows: Iterable[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [_json_row(row) for row in rows]


def fetch_one(sql: str, params: Sequence[Any] = ()) -> Dict[str, Any]:
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(sql, params)
            return _json_row(cursor.fetchone())
    finally:
        conn.close()


def fetch_all(sql: str, params: Sequence[Any] = ()) -> List[Dict[str, Any]]:
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(sql, params)
            return _json_rows(cursor.fetchall())
    finally:
        conn.close()


def _missing_procedure(exc: pymysql.MySQLError) -> bool:
    return bool(exc.args and exc.args[0] == 1305)


@app.get("/api/dashboard/summary")
def get_dashboard_summary() -> Dict[str, Any]:
    return fetch_one(
        """
        SELECT
            (SELECT COUNT(*) FROM departments) AS department_count,
            (SELECT COUNT(*) FROM doctors) AS doctor_count,
            (SELECT COUNT(*) FROM patients) AS patient_count,
            (SELECT COUNT(*) FROM registrations) AS registration_count,
            (
                SELECT IFNULL(SUM(total_amount), 0)
                FROM prescriptions
                WHERE status <> '已作废'
            ) AS prescription_amount
        """
    )


@app.get("/api/departments")
def get_departments() -> List[Dict[str, Any]]:
    return fetch_all(
        """
        SELECT
            department_id,
            department_name,
            description,
            location,
            remaining_quota
        FROM departments
        ORDER BY department_id ASC
        """
    )


@app.get("/api/doctors")
def get_doctors(
    keyword: Optional[str] = Query(default=None),
    department_id: Optional[int] = Query(default=None),
) -> List[Dict[str, Any]]:
    conditions: List[str] = []
    params: List[Any] = []

    if keyword:
        like_keyword = f"%{keyword}%"
        conditions.append(
            """
            (
                doc.name LIKE %s
                OR doc.phone LIKE %s
                OR doc.title LIKE %s
                OR dept.department_name LIKE %s
            )
            """
        )
        params.extend([like_keyword, like_keyword, like_keyword, like_keyword])

    if department_id is not None:
        conditions.append("doc.department_id = %s")
        params.append(department_id)

    where_sql = f"WHERE {' AND '.join(conditions)}" if conditions else ""

    return fetch_all(
        f"""
        SELECT
            doc.doctor_id,
            doc.name,
            doc.gender,
            doc.title,
            doc.department_id,
            dept.department_name,
            doc.phone,
            doc.registration_fee
        FROM doctors doc
        JOIN departments dept ON doc.department_id = dept.department_id
        {where_sql}
        ORDER BY doc.doctor_id ASC
        """,
        params,
    )


@app.get("/api/patients")
def get_patients(keyword: Optional[str] = Query(default=None)) -> List[Dict[str, Any]]:
    conditions: List[str] = []
    params: List[Any] = []

    if keyword:
        like_keyword = f"%{keyword}%"
        conditions.append("(name LIKE %s OR phone LIKE %s OR id_card LIKE %s)")
        params.extend([like_keyword, like_keyword, like_keyword])

    where_sql = f"WHERE {' AND '.join(conditions)}" if conditions else ""

    return fetch_all(
        f"""
        SELECT
            patient_id,
            name,
            gender,
            dob,
            created_at
        FROM patients
        {where_sql}
        ORDER BY patient_id ASC
        """,
        params,
    )


@app.get("/api/registrations")
def get_registrations() -> List[Dict[str, Any]]:
    return fetch_all(
        """
        SELECT
            r.registration_id,
            r.patient_id,
            p.name AS patient_name,
            r.doctor_id,
            doc.name AS doctor_name,
            r.department_id,
            dept.department_name,
            r.reg_time,
            r.visit_date,
            r.queue_number,
            r.fee,
            r.status
        FROM registrations r
        JOIN patients p ON r.patient_id = p.patient_id
        JOIN doctors doc ON r.doctor_id = doc.doctor_id
        JOIN departments dept ON r.department_id = dept.department_id
        ORDER BY r.visit_date DESC, r.reg_time DESC, r.registration_id DESC
        """
    )


@app.post("/api/registrations", status_code=201)
def create_registration(
    payload: RegistrationCreate,
    current_user: Dict[str, Any] = Depends(require_roles("admin", "doctor")),
) -> Dict[str, Any]:
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            try:
                result = _create_registration_with_procedure(cursor, payload)
                conn.commit()
                return result
            except pymysql.MySQLError as exc:
                conn.rollback()
                if not _missing_procedure(exc):
                    raise

                result = _create_registration_with_insert(cursor, payload)
                conn.commit()
                return result
    except HTTPException:
        conn.rollback()
        raise
    except pymysql.MySQLError:
        conn.rollback()
        raise
    finally:
        conn.close()


def _create_registration_with_procedure(
    cursor: pymysql.cursors.DictCursor, payload: RegistrationCreate
) -> Dict[str, Any]:
    cursor.execute("SET @register_msg = ''")
    cursor.execute(
        "CALL sp_auto_register(%s, %s, %s, %s, @register_msg)",
        (
            payload.patient_id,
            payload.department_id,
            payload.doctor_id,
            payload.visit_date,
        ),
    )

    while cursor.nextset():
        pass

    cursor.execute(
        "SELECT @register_msg AS message, LAST_INSERT_ID() AS registration_id"
    )
    row = cursor.fetchone() or {}
    message = row.get("message") or "挂号成功"
    registration_id = row.get("registration_id")

    if not str(message).startswith("挂号成功"):
        raise HTTPException(status_code=400, detail={"message": message})

    if not registration_id:
        cursor.execute(
            """
            SELECT registration_id
            FROM registrations
            WHERE patient_id = %s
              AND department_id = %s
              AND doctor_id = %s
              AND visit_date = %s
            ORDER BY registration_id DESC
            LIMIT 1
            """,
            (
                payload.patient_id,
                payload.department_id,
                payload.doctor_id,
                payload.visit_date,
            ),
        )
        registration_row = cursor.fetchone() or {}
        registration_id = registration_row.get("registration_id")

    return {
        "message": message,
        "registration_id": int(registration_id) if registration_id else None,
    }


def _create_registration_with_insert(
    cursor: pymysql.cursors.DictCursor, payload: RegistrationCreate
) -> Dict[str, Any]:
    cursor.execute(
        """
        INSERT INTO registrations(
            patient_id,
            department_id,
            doctor_id,
            visit_date,
            fee,
            status
        )
        SELECT
            %s,
            %s,
            %s,
            %s,
            registration_fee,
            '待就诊'
        FROM doctors
        WHERE doctor_id = %s
          AND department_id = %s
        """,
        (
            payload.patient_id,
            payload.department_id,
            payload.doctor_id,
            payload.visit_date,
            payload.doctor_id,
            payload.department_id,
        ),
    )

    if cursor.rowcount == 0:
        raise HTTPException(
            status_code=400,
            detail={"message": "挂号失败：医生不存在或医生所属科室与挂号科室不一致"},
        )

    registration_id = cursor.lastrowid
    cursor.execute(
        """
        SELECT queue_number
        FROM registrations
        WHERE registration_id = %s
        """,
        (registration_id,),
    )
    row = cursor.fetchone() or {}
    queue_number = row.get("queue_number")

    return {
        "message": f"挂号成功，排队号为：{queue_number}",
        "registration_id": int(registration_id),
    }


@app.get("/api/prescriptions")
def get_prescriptions() -> List[Dict[str, Any]]:
    return fetch_all(
        """
        SELECT
            pre.prescription_id,
            p.name AS patient_name,
            dept.department_name,
            doc.name AS doctor_name,
            pre.diagnosis,
            pre.prescription_content AS medicine_name,
            pre.prescription_content,
            pre.total_amount,
            pre.status,
            pre.created_at
        FROM prescriptions pre
        JOIN patients p ON pre.patient_id = p.patient_id
        JOIN doctors doc ON pre.doctor_id = doc.doctor_id
        JOIN registrations r ON pre.registration_id = r.registration_id
        JOIN departments dept ON r.department_id = dept.department_id
        ORDER BY pre.created_at DESC, pre.prescription_id DESC
        """
    )


@app.get("/api/statistics/departments")
def get_department_statistics() -> List[Dict[str, Any]]:
    return fetch_all(
        """
        SELECT
            dept.department_id,
            dept.department_name,
            COUNT(r.registration_id) AS registration_count
        FROM departments dept
        LEFT JOIN registrations r
            ON dept.department_id = r.department_id
           AND r.status <> '已取消'
        GROUP BY dept.department_id, dept.department_name
        ORDER BY registration_count DESC, dept.department_id ASC
        """
    )


@app.get("/api/statistics/doctors")
def get_doctor_statistics() -> List[Dict[str, Any]]:
    return fetch_all(
        """
        SELECT
            doc.doctor_id,
            doc.name AS doctor_name,
            dept.department_name,
            COUNT(r.registration_id) AS registration_count
        FROM doctors doc
        JOIN departments dept ON doc.department_id = dept.department_id
        LEFT JOIN registrations r
            ON doc.doctor_id = r.doctor_id
           AND r.status <> '已取消'
        GROUP BY doc.doctor_id, doc.name, dept.department_name
        ORDER BY registration_count DESC, doc.doctor_id ASC
        """
    )
