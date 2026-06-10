-- ==========================================================
-- 医院门诊挂号管理系统数据库脚本
-- 数据库平台：MySQL 8.0+
-- 说明：本脚本包含建库建表、测试数据、DML、DQL、完整性、安全性、视图、存储过程、函数和触发器。
-- ==========================================================

-- ----------------------------------------------------------
-- 1. 创建数据库与初始化环境
-- ----------------------------------------------------------
CREATE DATABASE IF NOT EXISTS hospital_outpatient
DEFAULT CHARACTER SET utf8mb4
DEFAULT COLLATE utf8mb4_unicode_ci;

USE hospital_outpatient;

SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW IF EXISTS v_registration_summary;
DROP VIEW IF EXISTS v_public_patients;
DROP TRIGGER IF EXISTS trg_before_registration_insert;
DROP TRIGGER IF EXISTS trg_after_registration_insert;
DROP FUNCTION IF EXISTS fn_get_doctor_reg_count;
DROP PROCEDURE IF EXISTS sp_auto_register;
DROP TABLE IF EXISTS prescriptions;
DROP TABLE IF EXISTS registrations;
DROP TABLE IF EXISTS doctors;
DROP TABLE IF EXISTS patients;
DROP TABLE IF EXISTS departments;
SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------
-- 2. 创建表结构
-- ----------------------------------------------------------

-- 表1：科室表
CREATE TABLE departments (
    department_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '科室ID',
    department_name VARCHAR(50) NOT NULL UNIQUE COMMENT '科室名称',
    description TEXT COMMENT '科室描述',
    location VARCHAR(100) NOT NULL DEFAULT '门诊楼' COMMENT '所在位置',
    remaining_quota INT NOT NULL DEFAULT 50 COMMENT '今日剩余号源',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    CONSTRAINT chk_departments_quota CHECK (remaining_quota >= 0)
) ENGINE=InnoDB COMMENT='科室信息表';

-- 表2：患者表
CREATE TABLE patients (
    patient_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '患者ID',
    name VARCHAR(50) NOT NULL COMMENT '患者姓名',
    gender ENUM('男', '女', '其他') NOT NULL COMMENT '性别',
    dob DATE NOT NULL COMMENT '出生日期',
    phone VARCHAR(20) NOT NULL UNIQUE COMMENT '联系电话',
    id_card VARCHAR(18) NOT NULL UNIQUE COMMENT '身份证号',
    address VARCHAR(255) COMMENT '家庭住址',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '注册时间',
    CONSTRAINT chk_patients_id_card_len CHECK (CHAR_LENGTH(id_card) = 18)
) ENGINE=InnoDB COMMENT='患者信息表';

-- 表3：医生表
CREATE TABLE doctors (
    doctor_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '医生ID',
    name VARCHAR(50) NOT NULL COMMENT '医生姓名',
    gender ENUM('男', '女') NOT NULL COMMENT '性别',
    title ENUM('主任医师', '副主任医师', '主治医师', '住院医师') NOT NULL COMMENT '职称',
    department_id INT NOT NULL COMMENT '所属科室ID',
    phone VARCHAR(20) UNIQUE COMMENT '联系电话',
    registration_fee DECIMAL(10, 2) NOT NULL DEFAULT 20.00 COMMENT '医生挂号费',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入职时间',
    CONSTRAINT chk_doctors_fee CHECK (registration_fee >= 0),
    CONSTRAINT fk_doctors_department FOREIGN KEY (department_id)
        REFERENCES departments(department_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='医生信息表';

-- 表4：挂号记录表
CREATE TABLE registrations (
    registration_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '挂号单ID',
    patient_id INT NOT NULL COMMENT '患者ID',
    department_id INT NOT NULL COMMENT '挂号科室ID',
    doctor_id INT NOT NULL COMMENT '挂号医生ID',
    reg_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '挂号时间',
    visit_date DATE NOT NULL COMMENT '预约就诊日期',
    queue_number INT COMMENT '排队号码',
    fee DECIMAL(10, 2) NOT NULL COMMENT '挂号费',
    status ENUM('待就诊', '就诊中', '已完成', '已取消', '已过期') NOT NULL DEFAULT '待就诊' COMMENT '挂号状态',
    CONSTRAINT chk_registrations_fee CHECK (fee >= 0),
    CONSTRAINT chk_registrations_queue CHECK (queue_number IS NULL OR queue_number > 0),
    CONSTRAINT fk_registrations_patient FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_registrations_department FOREIGN KEY (department_id)
        REFERENCES departments(department_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_registrations_doctor FOREIGN KEY (doctor_id)
        REFERENCES doctors(doctor_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='门诊挂号记录表';

-- 表5：处方表
CREATE TABLE prescriptions (
    prescription_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '处方ID',
    registration_id INT NOT NULL COMMENT '关联的挂号记录ID',
    patient_id INT NOT NULL COMMENT '患者ID',
    doctor_id INT NOT NULL COMMENT '开方医生ID',
    diagnosis VARCHAR(255) NOT NULL COMMENT '临床诊断',
    prescription_content TEXT NOT NULL COMMENT '处方内容',
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00 COMMENT '处方总金额',
    status ENUM('待缴费', '已缴费', '已取药', '已作废') NOT NULL DEFAULT '待缴费' COMMENT '处方状态',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '开方时间',
    CONSTRAINT chk_prescriptions_amount CHECK (total_amount >= 0),
    CONSTRAINT fk_prescriptions_registration FOREIGN KEY (registration_id)
        REFERENCES registrations(registration_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_prescriptions_patient FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_prescriptions_doctor FOREIGN KEY (doctor_id)
        REFERENCES doctors(doctor_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='处方记录表';

-- ----------------------------------------------------------
-- 3. 触发器、函数、存储过程
-- ----------------------------------------------------------
DELIMITER //

-- 触发器1：插入挂号前检查医生与科室是否匹配、号源是否充足，并自动生成排队号
CREATE TRIGGER trg_before_registration_insert
BEFORE INSERT ON registrations
FOR EACH ROW
BEGIN
    DECLARE v_doctor_dept_id INT;
    DECLARE v_quota INT;
    DECLARE v_next_queue INT;

    SELECT department_id INTO v_doctor_dept_id
    FROM doctors
    WHERE doctor_id = NEW.doctor_id;

    IF v_doctor_dept_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '挂号失败：医生不存在';
    END IF;

    IF v_doctor_dept_id <> NEW.department_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '挂号失败：医生所属科室与挂号科室不一致';
    END IF;

    IF NEW.status <> '已取消' THEN
        SELECT remaining_quota INTO v_quota
        FROM departments
        WHERE department_id = NEW.department_id;

        IF v_quota <= 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '挂号失败：该科室号源不足';
        END IF;
    END IF;

    IF NEW.queue_number IS NULL THEN
        SELECT IFNULL(MAX(queue_number), 0) + 1 INTO v_next_queue
        FROM registrations
        WHERE department_id = NEW.department_id
          AND visit_date = NEW.visit_date
          AND status <> '已取消';

        SET NEW.queue_number = v_next_queue;
    END IF;
END //

-- 触发器2：插入有效挂号后扣减科室剩余号源
CREATE TRIGGER trg_after_registration_insert
AFTER INSERT ON registrations
FOR EACH ROW
BEGIN
    IF NEW.status <> '已取消' THEN
        UPDATE departments
        SET remaining_quota = remaining_quota - 1
        WHERE department_id = NEW.department_id;
    END IF;
END //

-- 函数：统计某医生在指定日期的有效挂号数量
CREATE FUNCTION fn_get_doctor_reg_count(p_doctor_id INT, p_date DATE)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_count
    FROM registrations
    WHERE doctor_id = p_doctor_id
      AND visit_date = p_date
      AND status <> '已取消';

    RETURN v_count;
END //

-- 存储过程：自动挂号，包含参数、条件判断、事务控制
CREATE PROCEDURE sp_auto_register(
    IN p_patient_id INT,
    IN p_department_id INT,
    IN p_doctor_id INT,
    IN p_visit_date DATE,
    OUT p_out_msg VARCHAR(100)
)
BEGIN
    DECLARE v_fee DECIMAL(10, 2);
    DECLARE v_queue_number INT;
    DECLARE v_quota INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_out_msg = '挂号失败：请检查患者、科室、医生或号源信息';
    END;

    START TRANSACTION;

    SELECT remaining_quota INTO v_quota
    FROM departments
    WHERE department_id = p_department_id
    FOR UPDATE;

    IF v_quota <= 0 THEN
        ROLLBACK;
        SET p_out_msg = '挂号失败：该科室号源不足';
    ELSE
        SELECT registration_fee INTO v_fee
        FROM doctors
        WHERE doctor_id = p_doctor_id
          AND department_id = p_department_id
        FOR UPDATE;

        INSERT INTO registrations(patient_id, department_id, doctor_id, visit_date, fee, status)
        VALUES(p_patient_id, p_department_id, p_doctor_id, p_visit_date, v_fee, '待就诊');

        SET v_queue_number = LAST_INSERT_ID();

        COMMIT;

        SELECT queue_number INTO v_queue_number
        FROM registrations
        WHERE registration_id = LAST_INSERT_ID();

        SET p_out_msg = CONCAT('挂号成功，排队号为：', v_queue_number);
    END IF;
END //

DELIMITER ;

-- ----------------------------------------------------------
-- 4. 插入测试数据
-- ----------------------------------------------------------

INSERT INTO departments(department_id, department_name, description, location, remaining_quota) VALUES
(1, '内科', '负责常见内科疾病、慢性病和综合性疾病诊疗', '门诊楼2层A区', 50),
(2, '外科', '负责外伤、急腹症及常规手术相关疾病诊疗', '门诊楼3层A区', 40),
(3, '儿科', '负责儿童常见病、多发病及生长发育相关诊疗', '门诊楼2层B区', 60),
(4, '妇产科', '负责妇科疾病、孕产妇保健及产前咨询', '门诊楼4层A区', 50),
(5, '骨科', '负责骨骼、关节、脊柱及运动损伤相关诊疗', '门诊楼3层B区', 35),
(6, '眼科', '负责视力、眼表、眼底及常见眼病诊疗', '门诊楼5层A区', 45),
(7, '耳鼻咽喉科', '负责耳、鼻、咽喉相关疾病诊疗', '门诊楼5层B区', 40),
(8, '口腔科', '负责牙体牙髓、牙周及口腔修复诊疗', '门诊楼1层B区', 40),
(9, '皮肤科', '负责皮肤、毛发、甲病及过敏性疾病诊疗', '门诊楼4层B区', 50),
(10, '中医科', '负责中医内科、针灸、调理及康复咨询', '门诊楼6层A区', 30),
(11, '肿瘤科', '负责肿瘤筛查、随访和综合治疗咨询', '门诊楼6层B区', 30);

INSERT INTO patients(patient_id, name, gender, dob, phone, id_card, address) VALUES
(1, '张伟', '男', '1985-04-12', '13800000001', '11010519850412001X', '北京市朝阳区'),
(2, '王芳', '女', '1990-07-22', '13800000002', '11010519900722002X', '北京市海淀区'),
(3, '李娜', '女', '1992-11-05', '13800000003', '11010519921105003X', '上海市浦东新区'),
(4, '刘洋', '男', '1988-01-30', '13800000004', '11010519880130004X', '广州市天河区'),
(5, '陈建国', '男', '1965-09-15', '13800000005', '11010519650915005X', '深圳市南山区'),
(6, '赵强', '男', '1978-12-12', '13800000006', '11010519781212006X', '成都市武侯区'),
(7, '黄蓉', '女', '1995-03-08', '13800000007', '11010519950308007X', '杭州市西湖区'),
(8, '周杰', '男', '2000-05-20', '13800000008', '11010520000520008X', '南京市玄武区'),
(9, '吴秀英', '女', '1955-08-14', '13800000009', '11010519550814009X', '武汉市武昌区'),
(10, '孙悦', '女', '2010-06-01', '13800000010', '11010520100601001X', '天津市南开区'),
(11, '马晓东', '男', '1972-02-18', '13800000011', '11010519720218011X', '苏州市姑苏区'),
(12, '何静', '女', '1983-10-09', '13800000012', '11010519831009012X', '无锡市滨湖区');

INSERT INTO doctors(doctor_id, name, gender, title, department_id, phone, registration_fee) VALUES
(1, '赵明', '男', '主任医师', 1, '13600000001', 50.00),
(2, '钱丽', '女', '副主任医师', 2, '13600000002', 40.00),
(3, '孙洁', '女', '主治医师', 3, '13600000003', 30.00),
(4, '李国强', '男', '主任医师', 5, '13600000004', 80.00),
(5, '周文', '男', '主治医师', 10, '13600000005', 30.00),
(6, '吴敏', '女', '住院医师', 6, '13600000006', 20.00),
(7, '郑海', '男', '主任医师', 11, '13600000007', 100.00),
(8, '王倩', '女', '副主任医师', 4, '13600000008', 60.00),
(9, '冯涛', '男', '主治医师', 7, '13600000009', 30.00),
(10, '陈雪', '女', '主治医师', 8, '13600000010', 30.00),
(11, '林晨', '男', '副主任医师', 1, '13600000011', 40.00),
(12, '唐佳', '女', '主治医师', 9, '13600000012', 30.00);

INSERT INTO registrations(registration_id, patient_id, department_id, doctor_id, visit_date, queue_number, fee, status) VALUES
(1, 1, 1, 1, CURDATE(), 1, 50.00, '已完成'),
(2, 2, 2, 2, CURDATE(), 1, 40.00, '就诊中'),
(3, 10, 3, 3, CURDATE(), 1, 30.00, '待就诊'),
(4, 5, 5, 4, CURDATE(), 1, 80.00, '已完成'),
(5, 9, 10, 5, CURDATE(), 1, 30.00, '已完成'),
(6, 4, 6, 6, CURDATE(), 1, 20.00, '已完成'),
(7, 3, 8, 10, CURDATE(), 1, 30.00, '已取消'),
(8, 6, 11, 7, DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 100.00, '待就诊'),
(9, 7, 4, 8, DATE_ADD(CURDATE(), INTERVAL 1 DAY), 1, 60.00, '待就诊'),
(10, 8, 7, 9, CURDATE(), 1, 30.00, '待就诊'),
(11, 11, 9, 12, CURDATE(), 1, 30.00, '已完成'),
(12, 12, 1, 11, DATE_ADD(CURDATE(), INTERVAL 2 DAY), 1, 40.00, '待就诊');

INSERT INTO prescriptions(prescription_id, registration_id, patient_id, doctor_id, diagnosis, prescription_content, total_amount, status) VALUES
(1, 1, 1, 1, '高血压', '硝苯地平缓释片 30mg x 1盒；阿司匹林肠溶片 100mg x 1瓶', 120.50, '已取药'),
(2, 1, 1, 1, '高脂血症', '阿托伐他汀钙片 20mg x 1盒', 85.00, '已取药'),
(3, 4, 5, 4, '腰椎间盘突出', '塞来昔布胶囊 0.2g x 1盒；甲钴胺片 0.5mg x 2盒', 156.00, '已缴费'),
(4, 5, 9, 5, '气血两虚', '八珍颗粒 x 2盒；黄芪口服液 x 1盒', 98.00, '已取药'),
(5, 6, 4, 6, '结膜炎', '左氧氟沙星滴眼液 x 1支；玻璃酸钠滴眼液 x 1支', 45.00, '已缴费'),
(6, 4, 5, 4, '膝关节骨性关节炎', '硫酸氨基葡萄糖胶囊 x 1盒', 65.00, '待缴费'),
(7, 2, 2, 2, '急性阑尾炎先兆', '头孢克洛胶囊 x 1盒；甲硝唑片 x 1瓶', 55.50, '待缴费'),
(8, 1, 1, 1, '轻度脂肪肝', '多烯磷脂酰胆碱胶囊 x 2盒', 110.00, '已取药'),
(9, 5, 9, 5, '失眠', '枣仁安神胶囊 x 1盒', 42.00, '已取药'),
(10, 6, 4, 6, '视疲劳', '七叶洋地黄双苷滴眼液 x 1支', 38.00, '已取药'),
(11, 11, 11, 12, '湿疹', '糠酸莫米松乳膏 x 1支；氯雷他定片 x 1盒', 72.00, '已缴费'),
(12, 2, 2, 2, '录入错误处方', '错误测试数据', 1.00, '已作废');

-- DML操作：调整医生挂号费
UPDATE doctors
SET registration_fee = 85.00
WHERE doctor_id = 4;

-- DML操作：删除录入错误的处方，删除后处方表仍保留11条正式数据
DELETE FROM prescriptions
WHERE prescription_id = 12;

-- ----------------------------------------------------------
-- 5. 视图保护
-- ----------------------------------------------------------

-- 隐藏身份证号、手机号、住址等敏感字段
CREATE VIEW v_public_patients AS
SELECT patient_id, name, gender, dob, created_at
FROM patients;

-- 面向普通查询用户的挂号摘要视图
CREATE VIEW v_registration_summary AS
SELECT
    r.registration_id,
    p.name AS patient_name,
    d.department_name,
    doc.name AS doctor_name,
    r.visit_date,
    r.queue_number,
    r.fee,
    r.status
FROM registrations r
JOIN patients p ON r.patient_id = p.patient_id
JOIN departments d ON r.department_id = d.department_id
JOIN doctors doc ON r.doctor_id = doc.doctor_id;

-- ----------------------------------------------------------
-- 6. 存储过程、函数、触发器调用示例
-- ----------------------------------------------------------

-- 调用存储过程完成一次挂号，触发器会自动扣减科室剩余号源
SET @register_msg = '';
CALL sp_auto_register(12, 1, 11, DATE_ADD(CURDATE(), INTERVAL 3 DAY), @register_msg);
SELECT @register_msg AS procedure_result;

-- 调用函数统计医生当日有效挂号数量
SELECT
    doctor_id,
    name AS doctor_name,
    fn_get_doctor_reg_count(doctor_id, CURDATE()) AS today_registration_count
FROM doctors
ORDER BY today_registration_count DESC, doctor_id ASC;

-- 查看触发器扣减号源后的科室数据
SELECT department_id, department_name, remaining_quota
FROM departments
WHERE department_id = 1;

-- ----------------------------------------------------------
-- 7. 查询设计 DQL，共10条
-- ----------------------------------------------------------

-- Q1 基础查询：查询科室名称、位置和剩余号源，按剩余号源升序排列
SELECT department_name, location, remaining_quota
FROM departments
ORDER BY remaining_quota ASC;

-- Q2 基础查询：查询1990年以后出生的患者，按出生日期降序排列
SELECT name, gender, dob, created_at
FROM patients
WHERE dob >= '1990-01-01'
ORDER BY dob DESC;

-- Q3 等值连接：查询挂号记录对应的患者、医生和挂号状态
SELECT
    r.registration_id,
    p.name AS patient_name,
    doc.name AS doctor_name,
    r.visit_date,
    r.queue_number,
    r.status
FROM registrations r
JOIN patients p ON r.patient_id = p.patient_id
JOIN doctors doc ON r.doctor_id = doc.doctor_id
ORDER BY r.registration_id ASC;

-- Q4 多表连接：查询处方对应的患者、医生、科室和金额
SELECT
    pre.prescription_id,
    p.name AS patient_name,
    d.department_name,
    doc.name AS doctor_name,
    pre.diagnosis,
    pre.total_amount,
    pre.status
FROM prescriptions pre
JOIN patients p ON pre.patient_id = p.patient_id
JOIN doctors doc ON pre.doctor_id = doc.doctor_id
JOIN departments d ON doc.department_id = d.department_id
ORDER BY pre.total_amount DESC;

-- Q5 自连接：查询与赵明医生同科室的其他医生
SELECT
    d1.name AS base_doctor,
    d2.name AS same_department_doctor,
    d2.title,
    d2.registration_fee
FROM doctors d1
JOIN doctors d2 ON d1.department_id = d2.department_id
WHERE d1.name = '赵明'
  AND d2.doctor_id <> d1.doctor_id;

-- Q6 聚合分组：统计各科室有效挂号人数和挂号收入
SELECT
    d.department_name,
    COUNT(r.registration_id) AS registration_count,
    IFNULL(SUM(r.fee), 0) AS registration_income
FROM departments d
LEFT JOIN registrations r ON d.department_id = r.department_id AND r.status <> '已取消'
GROUP BY d.department_id, d.department_name
ORDER BY registration_count DESC;

-- Q7 聚合分组 HAVING：查询有效挂号数不少于2次的科室
SELECT
    d.department_name,
    COUNT(r.registration_id) AS valid_registration_count
FROM departments d
JOIN registrations r ON d.department_id = r.department_id
WHERE r.status <> '已取消'
GROUP BY d.department_id, d.department_name
HAVING COUNT(r.registration_id) >= 2
ORDER BY valid_registration_count DESC;

-- Q8 相关子查询：查询挂号费高于本医生所在科室平均挂号费的医生
SELECT
    d1.name AS doctor_name,
    d1.title,
    d1.registration_fee,
    dept.department_name
FROM doctors d1
JOIN departments dept ON d1.department_id = dept.department_id
WHERE d1.registration_fee > (
    SELECT AVG(d2.registration_fee)
    FROM doctors d2
    WHERE d2.department_id = d1.department_id
);

-- Q9 EXISTS子查询：查询至少开具过一张处方的患者
SELECT p.patient_id, p.name, p.gender, p.dob
FROM patients p
WHERE EXISTS (
    SELECT 1
    FROM prescriptions pre
    WHERE pre.patient_id = p.patient_id
)
ORDER BY p.patient_id ASC;

-- Q10 综合查询：多表连接、分组、HAVING、排序，统计各科室处方收入
SELECT
    d.department_name,
    COUNT(DISTINCT r.registration_id) AS registration_count,
    COUNT(pre.prescription_id) AS prescription_count,
    SUM(pre.total_amount) AS prescription_income
FROM departments d
JOIN doctors doc ON d.department_id = doc.department_id
JOIN registrations r ON doc.doctor_id = r.doctor_id
JOIN prescriptions pre ON r.registration_id = pre.registration_id
WHERE r.status IN ('已完成', '就诊中')
GROUP BY d.department_id, d.department_name
HAVING SUM(pre.total_amount) >= 100
ORDER BY prescription_income DESC;

-- ----------------------------------------------------------
-- 8. 完整性约束验证语句
-- 说明：以下语句用于截图数据库报错，需单独取消注释执行，不要放入总脚本自动运行。
-- ----------------------------------------------------------

-- 违反实体完整性：插入重复主键
-- INSERT INTO departments(department_id, department_name, description, location, remaining_quota)
-- VALUES(1, '重复科室', '测试重复主键', '测试位置', 10);

-- 违反用户定义完整性：剩余号源不能为负数
-- INSERT INTO departments(department_name, description, location, remaining_quota)
-- VALUES('测试科室', '测试CHECK约束', '测试位置', -1);

-- 违反用户定义完整性：身份证号长度必须为18位
-- INSERT INTO patients(name, gender, dob, phone, id_card, address)
-- VALUES('测试患者', '男', '2001-01-01', '13900000001', '123456', '测试地址');

-- 违反参照完整性：挂号使用不存在的患者ID
-- INSERT INTO registrations(patient_id, department_id, doctor_id, visit_date, fee, status)
-- VALUES(999, 1, 1, CURDATE(), 50.00, '待就诊');

-- 违反触发器业务规则：医生所属科室与挂号科室不一致
-- INSERT INTO registrations(patient_id, department_id, doctor_id, visit_date, fee, status)
-- VALUES(1, 2, 1, CURDATE(), 50.00, '待就诊');

-- ----------------------------------------------------------
-- 9. 数据库安全性：用户权限与授权回收
-- 说明：需要使用root或具有CREATE USER权限的账号执行。
-- ----------------------------------------------------------

DROP USER IF EXISTS 'admin_user'@'localhost';
DROP USER IF EXISTS 'doctor_user'@'localhost';
DROP USER IF EXISTS 'readonly_user'@'localhost';
DROP USER IF EXISTS 'app_user'@'localhost';

CREATE USER 'admin_user'@'localhost' IDENTIFIED BY 'Admin123!';
CREATE USER 'doctor_user'@'localhost' IDENTIFIED BY 'Doctor123!';
CREATE USER 'readonly_user'@'localhost' IDENTIFIED BY 'Read123!';
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'App123!';

-- 管理员：拥有当前数据库全部权限
GRANT ALL PRIVILEGES ON hospital_outpatient.* TO 'admin_user'@'localhost';

-- 医生用户：可以查看患者脱敏信息、查看挂号摘要，并维护处方
GRANT SELECT ON hospital_outpatient.v_public_patients TO 'doctor_user'@'localhost';
GRANT SELECT ON hospital_outpatient.v_registration_summary TO 'doctor_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON hospital_outpatient.prescriptions TO 'doctor_user'@'localhost';

-- 只读用户：只能访问脱敏视图，不能直接访问患者原表
GRANT SELECT ON hospital_outpatient.v_public_patients TO 'readonly_user'@'localhost';
GRANT SELECT ON hospital_outpatient.v_registration_summary TO 'readonly_user'@'localhost';

-- Web应用用户：仅授予系统运行所需权限，不使用root连接Web
GRANT SELECT ON hospital_outpatient.* TO 'app_user'@'localhost';
GRANT INSERT ON hospital_outpatient.registrations TO 'app_user'@'localhost';
GRANT INSERT ON hospital_outpatient.prescriptions TO 'app_user'@'localhost';
GRANT EXECUTE ON PROCEDURE hospital_outpatient.sp_auto_register TO 'app_user'@'localhost';

-- 权限回收示例：收回医生用户对处方表的UPDATE权限，用于截图验证REVOKE效果
REVOKE UPDATE ON hospital_outpatient.prescriptions FROM 'doctor_user'@'localhost';

FLUSH PRIVILEGES;

-- 视图保护验证查询
SELECT * FROM v_public_patients;
SELECT * FROM v_registration_summary;

-- ----------------------------------------------------------
-- 10. 给Web端使用的常用查询
-- ----------------------------------------------------------

-- Dashboard统计卡片
SELECT
    (SELECT COUNT(*) FROM departments) AS department_count,
    (SELECT COUNT(*) FROM doctors) AS doctor_count,
    (SELECT COUNT(*) FROM patients) AS patient_count,
    (SELECT COUNT(*) FROM registrations) AS registration_count,
    (SELECT IFNULL(SUM(total_amount), 0) FROM prescriptions WHERE status <> '已作废') AS prescription_amount;

-- 医生列表，包含科室名称
SELECT
    doc.doctor_id,
    doc.name,
    doc.gender,
    doc.title,
    d.department_name,
    doc.phone,
    doc.registration_fee
FROM doctors doc
JOIN departments d ON doc.department_id = d.department_id
ORDER BY doc.doctor_id ASC;

-- 挂号记录多表展示
SELECT * FROM v_registration_summary
ORDER BY visit_date DESC, registration_id DESC;
