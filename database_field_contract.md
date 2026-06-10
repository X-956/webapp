# 医院门诊挂号管理系统数据库字段约定

数据库名：hospital_outpatient

## 1. departments 科室表
| 字段 | 类型 | 说明 | 前端用途 |
|---|---|---|---|
| department_id | INT PK | 科室ID | 科室主键、筛选条件 |
| department_name | VARCHAR(50) UNIQUE | 科室名称 | 页面展示、搜索 |
| description | TEXT | 科室描述 | 详情展示 |
| location | VARCHAR(100) | 科室位置 | 页面展示 |
| remaining_quota | INT | 今日剩余号源 | Dashboard、挂号校验 |
| created_at | TIMESTAMP | 创建时间 | 可选展示 |

## 2. patients 患者表
| 字段 | 类型 | 说明 | 前端用途 |
|---|---|---|---|
| patient_id | INT PK | 患者ID | 患者主键、挂号表单选择 |
| name | VARCHAR(50) | 患者姓名 | 展示、搜索 |
| gender | ENUM | 性别 | 展示 |
| dob | DATE | 出生日期 | 展示、年龄计算 |
| phone | VARCHAR(20) UNIQUE | 手机号 | 管理员可见 |
| id_card | VARCHAR(18) UNIQUE | 身份证号 | 敏感字段，不在普通页面直接展示 |
| address | VARCHAR(255) | 地址 | 敏感字段，不在普通页面直接展示 |
| created_at | TIMESTAMP | 注册时间 | 可选展示 |

## 3. doctors 医生表
| 字段 | 类型 | 说明 | 前端用途 |
|---|---|---|---|
| doctor_id | INT PK | 医生ID | 医生主键、挂号表单选择 |
| name | VARCHAR(50) | 医生姓名 | 展示、搜索 |
| gender | ENUM | 性别 | 展示 |
| title | ENUM | 职称 | 展示、筛选 |
| department_id | INT FK | 所属科室ID | 科室筛选、联表 |
| phone | VARCHAR(20) UNIQUE | 手机号 | 展示 |
| registration_fee | DECIMAL | 挂号费 | 挂号表单自动带出 |
| created_at | TIMESTAMP | 入职时间 | 可选展示 |

## 4. registrations 挂号记录表
| 字段 | 类型 | 说明 | 前端用途 |
|---|---|---|---|
| registration_id | INT PK | 挂号单ID | 记录主键 |
| patient_id | INT FK | 患者ID | 关联患者 |
| department_id | INT FK | 科室ID | 关联科室 |
| doctor_id | INT FK | 医生ID | 关联医生 |
| reg_time | DATETIME | 挂号创建时间 | 展示 |
| visit_date | DATE | 预约就诊日期 | 挂号表单 |
| queue_number | INT | 排队号 | 展示 |
| fee | DECIMAL | 挂号费 | 展示 |
| status | ENUM | 挂号状态 | 展示、筛选 |

## 5. prescriptions 处方表
| 字段 | 类型 | 说明 | 前端用途 |
|---|---|---|---|
| prescription_id | INT PK | 处方ID | 记录主键 |
| registration_id | INT FK | 挂号记录ID | 关联挂号 |
| patient_id | INT FK | 患者ID | 关联患者 |
| doctor_id | INT FK | 医生ID | 关联医生 |
| diagnosis | VARCHAR(255) | 临床诊断 | 展示 |
| prescription_content | TEXT | 处方内容 | 展示 |
| total_amount | DECIMAL | 处方金额 | 统计、展示 |
| status | ENUM | 处方状态 | 展示、筛选 |
| created_at | TIMESTAMP | 开方时间 | 展示 |

## 6. 建议后端接口字段

### GET /api/dashboard/summary
返回：department_count, doctor_count, patient_count, registration_count, prescription_amount

### GET /api/departments
返回：department_id, department_name, description, location, remaining_quota

### GET /api/doctors
返回：doctor_id, name, gender, title, department_id, department_name, phone, registration_fee

### GET /api/patients
普通页面返回：patient_id, name, gender, dob, created_at
管理员页面可额外返回：phone, id_card, address

### GET /api/registrations
返回：registration_id, patient_name, department_name, doctor_name, visit_date, queue_number, fee, status

### POST /api/registrations
请求：patient_id, department_id, doctor_id, visit_date
建议后端调用存储过程 sp_auto_register，不要手写普通 INSERT。

### GET /api/prescriptions
返回：prescription_id, patient_name, department_name, doctor_name, diagnosis, prescription_content, total_amount, status, created_at
