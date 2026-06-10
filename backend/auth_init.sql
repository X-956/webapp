-- ==========================================================
-- 医院门诊挂号管理系统应用层登录账号初始化脚本
-- 执行顺序：先执行项目根目录下的 database_final.sql，再执行本脚本。
-- 本脚本可重复执行。
-- ==========================================================

USE hospital_outpatient;

CREATE TABLE IF NOT EXISTS app_users (
    user_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '应用登录用户ID',
    username VARCHAR(50) NOT NULL UNIQUE COMMENT '登录用户名',
    password_hash VARCHAR(255) NOT NULL COMMENT 'bcrypt密码哈希',
    role ENUM('admin', 'doctor', 'readonly') NOT NULL COMMENT '应用角色',
    display_name VARCHAR(50) NOT NULL COMMENT '显示名称',
    related_doctor_id INT NULL COMMENT '关联医生ID',
    is_active TINYINT(1) NOT NULL DEFAULT 1 COMMENT '账号是否启用',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    CONSTRAINT fk_app_users_doctor FOREIGN KEY (related_doctor_id)
        REFERENCES doctors(doctor_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='应用层登录账号表';

-- 演示账号通过 create_demo_users.py 写入，脚本会生成 bcrypt 哈希。
-- 默认账号：
-- admin / Admin123! / admin / 系统管理员
-- doctor01 / Doctor123! / doctor / 张医生 / related_doctor_id=1
-- readonly / Readonly123! / readonly / 只读访客

GRANT SELECT, INSERT, UPDATE ON hospital_outpatient.app_users TO 'app_user'@'localhost';

FLUSH PRIVILEGES;
