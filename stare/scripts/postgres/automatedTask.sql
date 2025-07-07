-- Create a function to automatically refresh materialized views
CREATE OR REPLACE FUNCTION refresh_remarks_statistics()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW remarks.mv_remarks_statistics;
    RAISE NOTICE 'Remarks statistics refreshed at %', CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- You can set up a cron job or use pg_cron extension to run this periodically
-- Example: SELECT cron.schedule('refresh-remarks-stats', '0 1 * * *', 'SELECT refresh_remarks_statistics();');