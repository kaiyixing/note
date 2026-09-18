-- ============================================================
-- MySQL 基础练习：员工表 emp
-- 配套讲解：GROUP BY / HAVING / ORDER BY / INSERT 引号规则
--
-- 执行方式（任选其一）：
--   方式一（推荐，避免中文乱码）：
--     mysql --default-character-set=utf8mb4 -u root -p < 本文件完整路径
--   方式二：进入 mysql 命令行后执行
--     source 本文件完整路径;
--
-- 提示：把下面各练习块逐段复制到 mysql 命令行里执行，
--       报错不可怕，看报错信息猜原因，就是最好的学习。
-- ============================================================

-- ------------------------------------------------------------
-- 第 0 步：建库 + 建表 + 造数据（先跑这一段）
-- ------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS practice DEFAULT CHARACTER SET utf8mb4;
USE practice;

DROP TABLE IF EXISTS emp;
CREATE TABLE emp (
  id        INT PRIMARY KEY AUTO_INCREMENT COMMENT '员工编号',
  name      VARCHAR(20)  NOT NULL COMMENT '姓名',
  dept      VARCHAR(20)  COMMENT '部门',
  job       VARCHAR(20)  COMMENT '职位',
  salary    DECIMAL(10,2) COMMENT '月薪',
  age       INT          COMMENT '年龄',
  hire_date DATE         COMMENT '入职日期'
);

INSERT INTO emp (name, dept, job, salary, age, hire_date) VALUES
('张三',   '技术部', '后端工程师', 15000.00, 28, '2021-03-15'),
('李四',   '技术部', '后端工程师', 18000.00, 32, '2019-07-01'),
('王五',   '技术部', '前端工程师', 12000.00, 26, '2022-01-10'),
('赵六',   '技术部', '架构师',     30000.00, 38, '2016-05-20'),
('钱七',   '销售部', '销售专员',    8000.00, 24, '2023-02-14'),
('孙八',   '销售部', '销售专员',    9500.00, 27, '2021-11-08'),
('周九',   '销售部', '销售经理',   20000.00, 35, '2015-08-30'),
('吴十',   '财务部', '会计',       10000.00, 30, '2020-04-01'),
('郑十一', '财务部', '会计',       11000.00, 33, '2019-12-12'),
('王十二', '财务部', '财务经理',   22000.00, 40, '2013-09-18'),
('冯十三', '人事部', 'HR',          9000.00, 29, '2022-06-06'),
('陈十四', '人事部', 'HR经理',     16000.00, 37, '2017-10-01'),
('褚十五', '技术部', '测试工程师', 11000.00, 25, '2023-09-01');

-- 先看下数据对不对：应该返回 13 行
SELECT * FROM emp;


-- ------------------------------------------------------------
-- 练习 1：最基础的查询（SELECT / WHERE）
-- ------------------------------------------------------------

SELECT name, salary FROM emp;
SELECT name, salary FROM emp WHERE salary > 10000;
SELECT name, dept FROM emp WHERE dept = '技术部';   -- 注意：字符串要加单引号
SELECT * FROM emp WHERE age BETWEEN 25 AND 35;
SELECT * FROM emp WHERE dept IN ('技术部', '财务部');


-- ------------------------------------------------------------
-- 练习 2：GROUP BY —— 分组 + 聚合函数
-- 口诀：相同的值合并成一组，配合 COUNT/SUM/AVG/MAX/MIN 用
-- ------------------------------------------------------------

-- 每个部门有多少人
SELECT dept, COUNT(*) FROM emp GROUP BY dept;

-- 每个部门工资总和
SELECT dept, SUM(salary) FROM emp GROUP BY dept;

-- 每个部门平均工资、最高、最低
SELECT dept, AVG(salary) AS avg_sal, MAX(salary) AS max_sal, MIN(salary) AS min_sal
FROM emp
GROUP BY dept;

-- 【思考题】下面这句会报错吗？为什么？（提示：想想 SELECT 里的普通列和 GROUP BY 的关系）
SELECT name, COUNT(*) FROM emp GROUP BY dept;


-- ------------------------------------------------------------
-- 练习 3：HAVING —— 分组后过滤「组」
-- 对比：WHERE 过滤「行」且不能用聚合函数；HAVING 过滤「组」可以用聚合函数
-- ------------------------------------------------------------

-- 人数超过 2 人的部门
SELECT dept, COUNT(*) AS cnt
FROM emp
GROUP BY dept
HAVING COUNT(*) > 2;

-- 平均工资大于 12000 的部门
SELECT dept, AVG(salary) AS avg_sal
FROM emp
GROUP BY dept
HAVING AVG(salary) > 12000;

-- 【会报错】WHERE 里写聚合函数：把下面这行的注释去掉再执行试试
-- SELECT dept FROM emp WHERE COUNT(*) > 2 GROUP BY dept;

-- WHERE 和 HAVING 一起用（完整看懂这一条，今天的内容就过关了）
-- 逻辑顺序：先过滤行(WHERE) → 再分组(GROUP BY) → 再过滤组(HAVING)
SELECT dept, COUNT(*) AS cnt
FROM emp
WHERE salary > 10000        -- ① 只留月薪过万的人
GROUP BY dept               -- ② 按部门分组
HAVING COUNT(*) >= 2;       -- ③ 留下人数至少 2 人的部门


-- ------------------------------------------------------------
-- 练习 4：ORDER BY —— 排序
-- ------------------------------------------------------------

SELECT name, salary FROM emp ORDER BY salary;        -- 默认升序 ASC
SELECT name, salary FROM emp ORDER BY salary DESC;   -- 降序
SELECT * FROM emp ORDER BY dept, salary DESC;        -- 先按部门，同部门内按工资降序

-- 按分组后的结果排序（把 练习2 的结果排个序）
SELECT dept, COUNT(*) AS cnt
FROM emp
GROUP BY dept
ORDER BY cnt DESC;


-- ------------------------------------------------------------
-- 练习 5：INSERT 单引号实验（本文件的核心实验区）
-- 规律一句话：字符串/日期必须加单引号，数字可以不写引号
-- ------------------------------------------------------------

-- ① 字符串加单引号 —— 正确写法
INSERT INTO emp (name, dept, salary) VALUES ('测试甲', '技术部', 5000);

-- ② 数字不加引号 —— 正确写法
INSERT INTO emp (name, dept, salary, age) VALUES ('测试乙', '销售部', 6000, 22);

-- ③ 【会报错】字符串不加引号 —— MySQL 会当成「列名」去解析
--    把下面这行的注释去掉再执行，看报错信息（Unknown column ...）
-- INSERT INTO emp (name) VALUES (测试丙);

-- ④ 数字加了引号 —— 能用，但会被隐式转成数字，不推荐这样写
INSERT INTO emp (name, dept, salary, age) VALUES ('测试丁', '财务部', '7000', '26');

-- ⑤ 日期必须加引号
INSERT INTO emp (name, dept, hire_date) VALUES ('测试戊', '人事部', '2026-09-18');

-- ⑥ 字符串里含有单引号 —— 用两个单引号转义
INSERT INTO emp (name) VALUES ('It''s a test');

-- ⑦ 【思考题】下面这句能成功吗？执行看看，注意 age 列的结果
INSERT INTO emp (name, age) VALUES ('测试己', '25');

-- 查看实验结果
SELECT id, name, dept, salary, age, hire_date FROM emp WHERE name LIKE '测试%' OR name LIKE 'It%';


-- ------------------------------------------------------------
-- 综合练习：一条语句串起今天全部知识点
-- 月薪大于 8000 的人里，找出人数超过 2 人的部门，
-- 按人数降序排列，只显示前 3 条
-- ------------------------------------------------------------

SELECT dept, COUNT(*) AS cnt, AVG(salary) AS avg_sal
FROM emp
WHERE salary > 8000          -- ① 先过滤行
GROUP BY dept                -- ② 分组
HAVING COUNT(*) > 2          -- ③ 过滤组
ORDER BY cnt DESC            -- ④ 排序
LIMIT 3;                     -- ⑤ 限量

-- 执行顺序回顾：FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT
