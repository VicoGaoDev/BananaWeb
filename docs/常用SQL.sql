# Web实时任务情况
select u.username,t.model,t.status,t.size,TIMESTAMPDIFF(SECOND, t.created_at, t.request_finished_at) as run_time,
        TIMESTAMPDIFF(SECOND, t.request_started_at, t.request_finished_at) as request_time,
        t.created_at,t.error_message 
    from tasks t
    join users u on t.user_id = u.id
    where t.source = 'web'
    order by t.created_at desc limit 30;
    
    
# API实时任务情况
select u.username,t.model,t.source,t.status,TIMESTAMPDIFF(SECOND, t.created_at, t.request_finished_at) as run_time,
        TIMESTAMPDIFF(SECOND, t.request_started_at, t.request_finished_at) as request_time,
        t.created_at,t.error_message 
    from tasks t
    join users u on t.user_id = u.id
    where t.source = 'api'
    order by t.created_at desc limit 50;
    
    
# 最近7天，每天任务数量和消耗积分
SELECT
  DATE(t.created_at) AS stat_date,
  COUNT(*) AS total_task_count,
  COALESCE(
    SUM(
      CASE
        WHEN refund.task_id IS NOT NULL THEN 0
        ELSE t.credit_cost
      END
    ),
    0
  ) AS credits_consumed,
  SUM(CASE WHEN t.status = 'success' THEN 1 ELSE 0 END) AS success_task_count,
  SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END) AS failed_task_count
FROM tasks t
JOIN users u ON u.id = t.user_id
LEFT JOIN (
  SELECT DISTINCT task_id
  FROM credit_logs
  WHERE task_id IS NOT NULL
    AND type = 'allocate'
    AND description IN ('任务入队失败，返还积分', '任务失败，返还积分')
) refund ON refund.task_id = t.id
WHERE u.is_whitelisted = 0
  AND u.role NOT IN ('admin', 'superadmin')
  AND t.created_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY DATE(t.created_at)
ORDER BY stat_date DESC;

# 查看当天积分兑换码，按积分值分别使用了多少个，以及收入
WITH daily_redeem AS (
  SELECT
    DATE(used_at) AS use_date,
    credit_amount,
    COUNT(*) AS used_count,
    CASE credit_amount
      WHEN 30 THEN 1.45
      WHEN 50 THEN 3.50
      WHEN 70 THEN 2.00
      WHEN 300 THEN 18.50
      WHEN 500 THEN 34.00
      WHEN 1000 THEN 65.00
      WHEN 2000 THEN 120.00
      WHEN 6000 THEN 300.00
      ELSE 0
    END AS unit_price
  FROM credit_redeem_keys
  WHERE used_at >= '2026-06-01 00:00:00'
    AND used_at < '2026-06-02 00:00:00'
  GROUP BY DATE(used_at), credit_amount
)
SELECT
  use_date,
  credit_amount,
  used_count,
  unit_price,
  ROUND(used_count * unit_price, 2) AS daily_income,
  ROUND(SUM(used_count * unit_price) OVER (), 2) AS target_date_total_income
FROM daily_redeem
ORDER BY credit_amount ASC;


# 计算每天的积分兑换对应营业额
SELECT
  DATE(CONVERT_TZ(used_at, '+00:00', '+08:00')) AS beijing_date,
  ROUND(
    SUM(
      CASE credit_amount
        WHEN 30 THEN 2.00
        WHEN 50 THEN 3.50
        WHEN 70 THEN 2.00
        WHEN 300 THEN 18.50
        WHEN 500 THEN 34.00
        WHEN 1000 THEN 65.00
        WHEN 2000 THEN 120.00
        WHEN 6000 THEN 300.00
        ELSE 0
      END
    ),
    2
  ) AS daily_income
FROM credit_redeem_keys
WHERE used_at >= CONVERT_TZ(CURDATE() - INTERVAL 29 DAY, '+00:00', '+00:00')
  AND used_at < CONVERT_TZ(CURDATE() + INTERVAL 1 DAY, '+00:00', '+00:00')
GROUP BY DATE(CONVERT_TZ(used_at, '+00:00', '+08:00'))
ORDER BY beijing_date DESC;


# 每个模型的使用数量
SELECT
  DATE(t.created_at) AS stat_date,
  COALESCE(NULLIF(t.model, ''), '未设置') AS model,
  COUNT(*) AS success_charged_task_count,
  COALESCE(SUM(t.credit_cost), 0) AS credits_consumed
FROM tasks t
JOIN users u ON u.id = t.user_id
WHERE u.is_whitelisted = 0
  AND t.status = 'success'
  AND t.credit_cost > 0
  AND u.role NOT IN ('admin', 'superadmin')
  AND t.created_at >= DATE_SUB(CURDATE(), INTERVAL 1 DAY)
GROUP BY DATE(t.created_at), COALESCE(NULLIF(t.model, ''), '未设置')
ORDER BY stat_date DESC, success_charged_task_count DESC;


select u.username,k.api_key from user_api_key as k
    left join users as u on k.user_id = u.id;
select * from users WHERE id = 259;
select * from users order by created_at desc limit 50;


# 复购的用户
SELECT
  u.id AS user_id,
  u.username,
  u.email,
  COUNT(*) AS redeem_count,
  SUM(rk.credit_amount) AS total_redeem_credits,
  MIN(rk.used_at) AS first_redeem_at,
  MAX(rk.used_at) AS last_redeem_at
FROM credit_redeem_keys rk
JOIN users u ON u.id = rk.used_by_user_id
WHERE rk.used_at IS NOT NULL
  AND rk.credit_amount > 200
  AND u.is_whitelisted = 0
  AND u.role NOT IN ('admin', 'superadmin')
GROUP BY u.id, u.username, u.email
HAVING COUNT(*) >= 2
ORDER BY redeem_count DESC, total_redeem_credits DESC;

