-- 影响范围：为接口成功率告警补充任务成功率统计提供按完成时间窗口过滤的索引。
-- 回滚思路：DROP INDEX idx_tasks_request_finished_at ON tasks;
-- 执行前置：建议低峰期执行；代码发布前先完成该迁移。

SET @index_exists := (
  SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'tasks'
    AND INDEX_NAME = 'idx_tasks_request_finished_at'
);

SET @ddl := IF(
  @index_exists = 0,
  'CREATE INDEX idx_tasks_request_finished_at ON tasks (request_finished_at)',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
