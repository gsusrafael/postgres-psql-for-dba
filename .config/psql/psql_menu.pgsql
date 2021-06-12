-- vim: ft=pgsql

-----------------------------------------
-- psql tools menu                     --
-- Author : Jesus Rafael Sanchez       --
-----------------------------------------

\echo '\nCurrent Host Server Date Time : '`date` '\n'

\echo 'Administrative queries:\n'
\echo '\t:settings   \t\t\t-- Server Settings'
\echo '\t:conninfo   \t\t\t-- Server connections'
\echo '\t:activity   \t\t\t-- Server activity'
\echo '\t:waits   \t\t\t-- Waiting queires'
\echo '\t:slowq   \t\t\t-- Slow queires'
\echo '\t:dbsize   \t\t\t-- Database Size'
\echo '\t:tablesize   \t\t\t-- Tables Size'
\echo '\t:uselesscol   \t\t\t-- Useless columns'
\echo '\t:uptime   \t\t\t-- Server uptime'
\echo '\t:lock_info   \t\t\t-- Lock info'
\echo '\t:locks  \t\t\t-- Display queries with active locks'
\echo '\t:long_running_queries \t\t-- Show all queries taking longer than five minutes ordered by duration'
\echo '\t:ps   \t\t\t\t-- View active queries with execution time'
\echo '\t:seq_scans  \t\t\t-- Show the count of seq_scans by table descending by order'
\echo '\t:tablesize   \t\t\t-- Tables Size'
\echo '\t:total_index_size   \t\t-- Show the total size of the indexes in MB'
\echo '\t:unused_indexes   \t\t-- Show unused and almost unused indexes, ordered by their size relative'
\echo '\t:pg_bloat   \t\t\t-- Show the information about database bloating'
\echo '\t:pg_blocking   \t\t\t-- Show the information locking queries'
\echo '\t:pg_cache_hit  \t\t\t-- Show the information about query cache'
\echo '\t:pg_index_size   \t\t-- Show the information about all indexes sizes on database'
\echo '\t:pg_index_usage   \t\t-- Show the information about index usage on database'
\echo '\t:pg_locks   \t\t\t-- Show detailed info about locks'
\echo '\t:pg_vacuum_stats   \t\t-- Vacuum statistics report'
\echo '\t:pg_near_tx_wrap   \t\t-- Show which tables are closest to transaction id wraparound'
\echo '\t:cache_hit_explain   \t\t-- Show page cache hits (and misses) in query explain plan (ends with semi-colon [;])'
\echo '\t:db_cache_hit   \t\t-- Calculate the database cache hit ratio'
\echo '\t:table_candidates_to_ssd \t-- Show tables which should be moved to SSD (low writes, high reads)'
\echo '\t:cache_stat  \t\t\t-- Show shared_buffers and os pagecache stat for current database (needs pgfincore and pg_buffercache)'
\echo '\t:seq_scan_tables  \t\t-- Shows the top 20 tables with sequential scan on tuple read'


\echo '\t:menu  \t\t\t\t-- Help Menu'
\echo '\t\\h  \t\t\t\t-- Help with SQL commands'
\echo '\t\\?  \t\t\t\t-- Help with psql commands\n'

\echo 'Development queries:\n'
\echo '\t:show_slow_queries \t\t-- Show slow queries (requires pg_stat_statements)'
\echo '\t:prompt_reload  \t\t-- Reloads prompt configuration on user change'
\echo '\t:sp   \t\t\t\t-- Current Search Path'
\echo '\t:clear   \t\t\t-- Clear screen'
\echo '\t:ll   \t\t\t\t-- List\n'


