-- Least-privilege application user: DML on the benchmark schema only.
CREATE USER 'tb_app'@'%' IDENTIFIED BY 'tb_app';
GRANT SELECT, INSERT, UPDATE, DELETE ON ticketbench.* TO 'tb_app'@'%';
