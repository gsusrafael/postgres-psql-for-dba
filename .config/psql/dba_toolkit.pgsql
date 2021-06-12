-- vim: ft=pgsql

-----------------------------------------
-- dba toolkit file to set psql tools  --
-- Author : Jesus Rafael Sanchez       --
-----------------------------------------

-- Check if is superuser
select current_setting('is_superuser') is_superuser \gset

-- Server Settings
SELECT $$
 SELECT name, 
        setting,
        unit,
        context 
   FROM pg_settings;
$$ settings \gset

-- Slow queries
SELECT $$
 SELECT (total_time / 1000 / 60) as total_minutes, 
        (total_time/calls) as average_time, 
        query 
   FROM pg_stat_statements 
  ORDER BY 1 DESC 
  LIMIT 100;
$$ slowq \gset

-- Locks in the server
SELECT $$
 SELECT bl.pid AS blocked_pid, 
        a.usename AS blocked_user, 
        kl.pid AS blocking_pid, 
        ka.usename AS blocking_user, 
        a.query AS blocked_statement 
   FROM pg_catalog.pg_locks bl 
        JOIN pg_catalog.pg_stat_activity a 
          ON bl.pid = a.pid
        JOIN pg_catalog.pg_locks kl 
        JOIN pg_catalog.pg_stat_activity ka 
          ON kl.pid = ka.pid 
          ON bl.transactionid = kl.transactionid 
         AND bl.pid != kl.pid 
  WHERE NOT bl.granted;
$$ locks \gset

-- Lock info (provided by pg_stat_activity plugin)
SELECT $$
 SELECT pg_stat_activity.pid, 
        pg_class.relname, 
        pg_locks.transactionid, 
        pg_locks.granted, 
        substr(pg_stat_activity.query,1,30) as query_snippet, 
        age(now(), pg_stat_activity.query_start) as "age" 
   FROM pg_stat_activity,pg_locks 
        LEFT OUTER JOIN pg_class 
          ON pg_locks.relation = pg_class.oid
  WHERE pg_stat_activity.query <> '<insufficient privilege>' 
    AND pg_locks.pid=pg_stat_activity.pid 
    AND pg_locks.mode = 'ExclusiveLock' 
  ORDER BY query_start;
$$ lock_info \gset

-- Connection info
SELECT $$
 SELECT usename, 
        count(*) 
   FROM pg_stat_activity 
  GROUP by usename;
$$ conninfo \gset

-- Server activity
SELECT $$
 SELECT datname, 
        pid, 
        usename, 
        application_name,
        client_addr, 
        client_hostname, 
        client_port, 
        query, 
        state 
   FROM pg_stat_activity;
$$ activity \gset

-- Server waiting queries
SELECT $$
 SELECT pg_stat_activity.pid, 
        pg_stat_activity.query, 
        pg_stat_activity.waiting, 
        now() - pg_stat_activity.query_start AS "total time",
        pg_stat_activity.backend_start 
   FROM pg_stat_activity 
  WHERE pg_stat_activity.query !~ '%IDLE%'::text 
    AND pg_stat_activity.waiting = true;
$$ waits \gset

-- Database size
SELECT $$
 SELECT datname, 
        pg_size_pretty(pg_database_size(datname)) db_size 
   FROM pg_database 
  ORDER BY db_size;
$$ dbsize \gset

-- Table size
SELECT $$
 SELECT nspname || '.' || relname AS "relation",
        pg_size_pretty(pg_relation_size(C.oid)) AS "size" 
   FROM pg_class C 
        LEFT JOIN pg_namespace N 
          ON (N.oid = C.relnamespace) 
  WHERE nspname NOT IN ('pg_catalog', 'information_schema') 
  ORDER BY pg_relation_size(C.oid) DESC 
  LIMIT 40;
$$ tablesize \gset

-- Useless columns 
SELECT $$
 SELECT nspname, 
        relname, 
        attname, 
        typname, 
        (stanullfrac * 100)::int AS null_percent, 
        CASE 
            WHEN stadistinct >= 0 THEN 
                stadistinct 
            ELSE 
                abs(stadistinct)*reltuples 
        END AS "distinct", 
        CASE 1 
            WHEN stakind1 THEN 
                stavalues1 
            WHEN stakind2 THEN 
                stavalues2 
        END AS "values" 
   FROM pg_class c 
        JOIN pg_namespace ns 
          ON ns.oid = relnamespace
        JOIN pg_attribute 
          ON c.oid = attrelid
        JOIN pg_type t 
          ON t.oid = atttypid
        JOIN pg_statistic 
          ON c.oid=starelid 
         AND staattnum=attnum 
  WHERE nspname NOT LIKE E'pg\\_%' 
    AND nspname != 'information_schema' 
    AND relkind='r' 
    AND NOT attisdropped 
    AND attstattarget != 0 
    AND reltuples >= 100 
    AND stadistinct BETWEEN 0 AND 1 
  ORDER BY nspname, relname, attname;
$$ uselesscol \gset

-- Uptime
SELECT $$
 SELECT now() - pg_postmaster_start_time() AS uptime;
$$ uptime \gset

-- Long Running Queries
SELECT $$
 SELECT pid, 
        now() - pg_stat_activity.query_start AS duration, 
        query AS query 
   FROM pg_stat_activity 
  WHERE pg_stat_activity.query <> ''::text 
    AND now() - pg_stat_activity.query_start > interval '5 minutes' 
  ORDER BY now() - pg_stat_activity.query_start DESC;
$$ long_running_queries \gset

-- Process Summary (ps)
SELECT $$
 SELECT pid, 
        application_name AS source, 
        age(now(),query_start) AS running_for, 
        wait_event_type, wait_event, 
        query AS query 
   FROM pg_stat_activity 
  WHERE query <> '<insufficient privilege>' 
    AND state <> 'idle' 
    AND pid <> pg_backend_pid() 
  ORDER BY 3 DESC;
$$ ps \gset

-- Sequential Scans per table/relation
SELECT $$
 SELECT relname AS name, 
        seq_scan as count 
   FROM pg_stat_user_tables 
  ORDER BY seq_scan DESC;
$$ seq_scans \gset

-- Total index size in database
SELECT $$
 SELECT pg_size_pretty(sum(relpages*1024)) AS size 
   FROM pg_class 
  WHERE reltype=0;
$$ total_index_size \gset

-- List unused indexes
SELECT $$
 SELECT schemaname || '.' || relname AS "table",
        indexrelname AS index,
        pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size,
        idx_scan AS index_scans 
   FROM pg_stat_user_indexes ui 
        JOIN pg_index i 
          ON ui.indexrelid = i.indexrelid 
  WHERE NOT indisunique 
    AND idx_scan < 50 
    AND pg_relation_size(relid) > 5 * 8192 
  ORDER BY pg_relation_size(i.indexrelid) / nullif(idx_scan, 0) DESC 
  NULLS FIRST, pg_relation_size(i.indexrelid) DESC;
$$ unused_indexes \gset

-- PostgreSQL Data Bloat
SELECT $$
 -- new table bloat query
 -- still needs work; is often off by +/- 20%
 WITH constants AS (
     -- define some constants for sizes of things
     -- for reference down the query and easy maintenance
     SELECT current_setting('block_size')::numeric AS bs, 23 AS hdr, 8 AS ma
 ),
 no_stats AS (
     -- screen out table who have attributes
     -- which dont have stats, such as JSON
     SELECT table_schema, table_name, 
         n_live_tup::numeric as est_rows,
         pg_table_size(relid)::numeric as table_size
     FROM information_schema.columns
         JOIN pg_stat_user_tables as psut
            ON table_schema = psut.schemaname
            AND table_name = psut.relname
         LEFT OUTER JOIN pg_stats
         ON table_schema = pg_stats.schemaname
             AND table_name = pg_stats.tablename
             AND column_name = attname 
     WHERE attname IS NULL
         AND table_schema NOT IN ('pg_catalog', 'information_schema')
     GROUP BY table_schema, table_name, relid, n_live_tup
 ),
 null_headers AS (
     -- calculate null header sizes
     -- omitting tables which dont have complete stats
     -- and attributes which aren't visible
     SELECT
         hdr+1+(sum(case when null_frac <> 0 THEN 1 else 0 END)/8) as nullhdr,
         SUM((1-null_frac)*avg_width) as datawidth,
         MAX(null_frac) as maxfracsum,
         schemaname,
         tablename,
         hdr, ma, bs
     FROM pg_stats CROSS JOIN constants
         LEFT OUTER JOIN no_stats
             ON schemaname = no_stats.table_schema
             AND tablename = no_stats.table_name
     WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
         AND no_stats.table_name IS NULL
         AND EXISTS ( SELECT 1
             FROM information_schema.columns
                 WHERE schemaname = columns.table_schema
                     AND tablename = columns.table_name )
     GROUP BY schemaname, tablename, hdr, ma, bs
 ),
 data_headers AS (
     -- estimate header and row size
     SELECT
         ma, bs, hdr, schemaname, tablename,
         (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,
         (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
     FROM null_headers
 ),
 table_estimates AS (
     -- make estimates of how large the table should be
     -- based on row and page size
     SELECT schemaname, tablename, bs,
         reltuples::numeric as est_rows, relpages * bs as table_bytes,
     CEIL((reltuples*
             (datahdr + nullhdr2 + 4 + ma -
                 (CASE WHEN datahdr%ma=0
                     THEN ma ELSE datahdr%ma END)
                 )/(bs-20))) * bs AS expected_bytes,
         reltoastrelid
     FROM data_headers
         JOIN pg_class ON tablename = relname
         JOIN pg_namespace ON relnamespace = pg_namespace.oid
             AND schemaname = nspname
     WHERE pg_class.relkind = 'r'
 ),
 estimates_with_toast AS (
     -- add in estimated TOAST table sizes
     -- estimate based on 4 toast tuples per page because we dont have 
     -- anything better.  also append the no_data tables
     SELECT schemaname, tablename, 
         TRUE as can_estimate,
         est_rows,
         table_bytes + ( coalesce(toast.relpages, 0) * bs ) as table_bytes,
         expected_bytes + ( ceil( coalesce(toast.reltuples, 0) / 4 ) * bs ) as expected_bytes
     FROM table_estimates LEFT OUTER JOIN pg_class as toast
         ON table_estimates.reltoastrelid = toast.oid
             AND toast.relkind = 't'
 ),
 table_estimates_plus AS (
 -- add some extra metadata to the table data
 -- and calculations to be reused
 -- including whether we cant estimate it
 -- or whether we think it might be compressed
     SELECT current_database() as databasename,
             schemaname, tablename, can_estimate, 
             est_rows,
             CASE WHEN table_bytes > 0
                 THEN table_bytes::NUMERIC
                 ELSE NULL::NUMERIC END
                 AS table_bytes,
             CASE WHEN expected_bytes > 0 
                 THEN expected_bytes::NUMERIC
                 ELSE NULL::NUMERIC END
                     AS expected_bytes,
             CASE WHEN expected_bytes > 0 AND table_bytes > 0
                 AND expected_bytes <= table_bytes
                 THEN (table_bytes - expected_bytes)::NUMERIC
                 ELSE 0::NUMERIC END AS bloat_bytes
     FROM estimates_with_toast
     UNION ALL
     SELECT current_database() as databasename, 
         table_schema, table_name, FALSE, 
         est_rows, table_size,
         NULL::NUMERIC, NULL::NUMERIC
     FROM no_stats
 ),
 bloat_data AS (
     -- do final math calculations and formatting
     select current_database() as databasename,
         schemaname, tablename, can_estimate, 
         table_bytes, round(table_bytes/(1024^2)::NUMERIC,3) as table_mb,
         expected_bytes, round(expected_bytes/(1024^2)::NUMERIC,3) as expected_mb,
         round(bloat_bytes*100/table_bytes) as pct_bloat,
         round(bloat_bytes/(1024::NUMERIC^2),2) as mb_bloat,
         table_bytes, expected_bytes, est_rows
     FROM table_estimates_plus
 )
 -- filter output for bloated tables
 SELECT databasename, schemaname, tablename,
     can_estimate,
     est_rows,
     pct_bloat, mb_bloat,
     table_mb
 FROM bloat_data
 -- this where clause defines which tables actually appear
 -- in the bloat chart
 -- example below filters for tables which are either 50%
 -- bloated and more than 20mb in size, or more than 25%
 -- bloated and more than 4GB in size
 WHERE ( pct_bloat >= 50 AND mb_bloat >= 10 )
     OR ( pct_bloat >= 25 AND mb_bloat >= 1000 )
 ORDER BY pct_bloat DESC;
$$ pg_bloat \gset

-- PostgreSQL Blocking Queries 
SELECT $$
 SELECT	bl.pid AS blocked_pid,
        a.query AS blocking_statement,
        now ( ) - ka.query_start AS blocking_duration,
        kl.pid AS blocking_pid,
        a.query AS blocked_statement,
        now ( ) - a.query_start AS blocked_duration
   FROM pg_catalog.pg_locks bl
   JOIN pg_catalog.pg_stat_activity a ON bl.pid = a.pid
   JOIN pg_catalog.pg_locks kl
   JOIN pg_catalog.pg_stat_activity ka 
        ON kl.pid = ka.pid 
        ON bl.transactionid = kl.transactionid
    AND bl.pid != kl.pid
  WHERE NOT bl.granted;
$$ pg_blocking \gset

-- PostgreSQL cache hit
SELECT $$
 SELECT 'index hit rate' AS name,
        sum(idx_blks_hit) / sum(idx_blks_hit + idx_blks_read) AS ratio
   FROM pg_statio_user_indexes
  UNION
    ALL
 SELECT 'cache hit rate' AS name,
        sum (heap_blks_hit) / (sum(heap_blks_hit) + sum (heap_blks_read)) AS ratio
   FROM pg_statio_user_tables;
$$ pg_cache_hit \gset

-- PostgreSQL Index Size
SELECT $$
 SELECT relname AS name,
        pg_size_pretty (sum (relpages::BIGINT * 8192)::BIGINT) AS SIZE
   FROM pg_class
  WHERE reltype = 0
  GROUP BY relname
  ORDER BY sum(relpages) DESC;
$$ pg_index_size \gset

-- PostgreSQL Index Usage List
SELECT $$
 SELECT relname,
        CASE idx_scan
          WHEN 0 THEN 
			'Insufficient data'
          ELSE 
		    (100 * idx_scan / (seq_scan + idx_scan ) ) ::text
    	END percent_of_times_index_used,
    	n_live_tup rows_in_table
   FROM pg_stat_user_tables
  ORDER BY n_live_tup DESC;
$$ pg_index_usage \gset

-- PostgreSQL Locks
SELECT $$
 SELECT 
     pg_stat_activity.pid,
     pg_class.relname,
     pg_locks.transactionid,
     pg_locks.granted,
     substr (
         pg_stat_activity.query,
         1,
         30 ) AS query_snippet,
     age (
         now ( ),
         pg_stat_activity.query_start ) AS "age"
 FROM
     pg_stat_activity,
     pg_locks
     LEFT OUTER JOIN pg_class ON (
         pg_locks.relation = pg_class.oid )
 WHERE
     pg_stat_activity.query <> ''
     AND pg_locks.pid = pg_stat_activity.pid
     AND pg_locks.mode = 'ExclusiveLock'
 ORDER BY
     query_start;
$$ pg_locks \gset

-- Vacuum stats
SELECT $$
 WITH table_opts AS
  (SELECT pg_class.oid,
          relname,
          nspname,
          array_to_string(reloptions, '') AS relopts
    FROM pg_class
   INNER JOIN pg_namespace ns ON relnamespace = ns.oid),
     vacuum_settings AS
   (SELECT oid,
           relname,
           nspname,
           CASE
               WHEN relopts LIKE '%autovacuum_vacuum_threshold%' THEN regexp_replace(relopts, '.*autovacuum_vacuum_threshold=([0-9.]+).*', E'\\\\\\1')::integer
               ELSE current_setting('autovacuum_vacuum_threshold')::integer
           END AS autovacuum_vacuum_threshold,
           CASE
               WHEN relopts LIKE '%autovacuum_vacuum_scale_factor%' THEN regexp_replace(relopts, '.*autovacuum_vacuum_scale_factor=([0-9.]+).*', E'\\\\\\1')::real
               ELSE current_setting('autovacuum_vacuum_scale_factor')::real
           END AS autovacuum_vacuum_scale_factor
    FROM table_opts)
  SELECT vacuum_settings.nspname AS SCHEMA,
         vacuum_settings.relname AS TABLE,
         to_char(psut.last_vacuum, 'YYYY-MM-DD HH24:MI') AS last_vacuum,
         to_char(psut.last_autovacuum, 'YYYY-MM-DD HH24:MI') AS last_autovacuum,
         to_char(pg_class.reltuples, '9G999G999G999') AS rowcount,
         to_char(psut.n_dead_tup, '9G999G999G999') AS dead_rowcount,
         to_char(autovacuum_vacuum_threshold + (autovacuum_vacuum_scale_factor::numeric * pg_class.reltuples), '9G999G999G999') AS autovacuum_threshold,
         CASE
             WHEN autovacuum_vacuum_threshold + (autovacuum_vacuum_scale_factor::numeric * pg_class.reltuples) < psut.n_dead_tup THEN 'yes'
         END AS expect_autovacuum
  FROM pg_stat_user_tables psut
  INNER JOIN pg_class ON psut.relid = pg_class.oid
  INNER JOIN vacuum_settings ON pg_class.oid = vacuum_settings.oid
  ORDER BY 1,
           2;
$$ pg_vacuum_stats \gset

-- PostgreSQL Slow Queries
SELECT $$
 SELECT (
        total_time / 1000 / 60 ) AS total_minutes,
    (
        total_time / calls ) AS average_time,
    query
   FROM pg_stat_statements
  ORDER BY
      1 DESC
  LIMIT 100;
$$ show_slow_queries \gset

-- Show which tables are closest to transaction id wraparound
SELECT $$
 SELECT scma.nspname AS scma,
          tbl.relname AS tbl,
          ((SELECT setting 
			  FROM pg_settings 
			 WHERE name = 'autovacuum_freeze_max_age')::bigint - age(tbl.relfrozenxid)) as tx_until_forced_autovacuum
   FROM pg_class AS tbl
   LEFT JOIN pg_namespace scma 
          ON scma.oid = tbl.relnamespace
  WHERE scma.nspname NOT IN ('pg_catalog', 'information_schema')
    AND scma.nspname not like 'pg_temp_%'
    AND tbl.relkind = 'r'
    AND ((SELECT setting 
            FROM pg_settings 
           WHERE name = 'autovacuum_freeze_max_age')::bigint - age(tbl.relfrozenxid)) < 500000000
  ORDER BY tx_until_forced_autovacuum ASC;
$$ pg_near_tx_wrap \gset

-- Show page cache hits (and misses) in query explain plan
SELECT $$
 EXPLAIN (ANALYZE on, BUFFERS on) SELECT * FROM
$$ cache_hit_explain \gset

-- Calculate the database cache hit ratio
SELECT $$
 SELECT sum(blks_hit) * 100 / sum(blks_hit + blks_read) AS hit_ratio 
   FROM pg_stat_database;
$$ db_cache_hit \gset

-- Shows the background and backend writer stats
SELECT $$
  SELECT 
        now()-pg_postmaster_start_time()    "Uptime", now()-stats_reset     "Since stats reset",
        round(100.0*checkpoints_req/total_checkpoints,1)                    "Forced checkpoint ratio (%)",
        round(np.min_since_reset/total_checkpoints,2)                       "Minutes between checkpoints",
        round(checkpoint_write_time::numeric/(total_checkpoints*1000),2)    "Average write time per checkpoint (s)",
        round(checkpoint_sync_time::numeric/(total_checkpoints*1000),2)     "Average sync time per checkpoint (s)",
        round(total_buffers/np.mp,1)                                        "Total MB written",
        round(buffers_checkpoint/(np.mp*total_checkpoints),2)               "MB per checkpoint",
        round(buffers_checkpoint/(np.mp*np.min_since_reset*60),2)           "Checkpoint MBps",
        round(buffers_clean/(np.mp*np.min_since_reset*60),2)                "Bgwriter MBps",
        round(buffers_backend/(np.mp*np.min_since_reset*60),2)              "Backend MBps",
        round(total_buffers/(np.mp*np.min_since_reset*60),2)                "Total MBps",
        round(1.0*buffers_alloc/total_buffers,3)                            "New buffer allocation ratio",        
        round(100.0*buffers_checkpoint/total_buffers,1)                     "Clean by checkpoints (%)",
        round(100.0*buffers_clean/total_buffers,1)                          "Clean by bgwriter (%)",
        round(100.0*buffers_backend/total_buffers,1)                        "Clean by backends (%)",
        round(100.0*maxwritten_clean/(np.min_since_reset*60000/np.bgwr_delay),2)            "Bgwriter halt-only length (buffers)",
        coalesce(round(100.0*maxwritten_clean/(nullif(buffers_clean,0)/np.bgwr_maxp),2),0)  "Bgwriter halt ratio (%)",
        '--------------------------------------'         "--------------------------------------",
        bgstats.*
  FROM (
    SELECT bg.*,
        checkpoints_timed + checkpoints_req total_checkpoints,
        buffers_checkpoint + buffers_clean + buffers_backend total_buffers,
        pg_postmaster_start_time() startup,
        current_setting('checkpoint_timeout') checkpoint_timeout,
        current_setting('max_wal_size') max_wal_size,
        current_setting('checkpoint_completion_target') checkpoint_completion_target,
        current_setting('bgwriter_delay') bgwriter_delay,
        current_setting('bgwriter_lru_maxpages') bgwriter_lru_maxpages,
        current_setting('bgwriter_lru_multiplier') bgwriter_lru_multiplier
    FROM pg_stat_bgwriter bg
        ) bgstats,
        (
    SELECT
        round(extract('epoch' from now() - stats_reset)/60)::numeric min_since_reset,
        (1024 * 1024 / block.setting::numeric) mp,
        delay.setting::numeric bgwr_delay,
        lru.setting::numeric bgwr_maxp
    FROM pg_stat_bgwriter bg
    JOIN pg_settings lru   ON lru.name = 'bgwriter_lru_maxpages'
    JOIN pg_settings delay ON delay.name = 'bgwriter_delay'
    JOIN pg_settings block ON block.name = 'block_size'
        ) np;   -- don't print that
$$ bgwriter_stats \gset


-- Shows the tables canditates to be moved to an SSD storage
SELECT $$
  SELECT * 
    FROM (
        WITH totals_counts AS (
          SELECT
             sum(pg_stat_get_blocks_fetched(c.oid)-pg_stat_get_blocks_hit(c.oid)+pg_stat_get_blocks_fetched(c.reltoastrelid)-pg_stat_get_blocks_hit(c.reltoastrelid)) as disk,
             sum(pg_stat_get_tuples_inserted(c.oid)+pg_stat_get_tuples_inserted(c.reltoastrelid)+2*(pg_stat_get_tuples_updated(c.oid)+pg_stat_get_tuples_updated(c.reltoastrelid))+pg_stat_get_tuples_deleted(c.oid)+pg_stat_get_tuples_deleted(c.reltoastrelid)) as write
            FROM pg_class c
           WHERE c.relkind='r'
        )
        SELECT (n.nspname||'.'||c.relname)::varchar(30),
               t.spcname AS tblsp,
               pg_size_pretty(
                pg_relation_size(c.oid) + ( 
                    CASE 
                        WHEN c.reltoastrelid = 0 
                            THEN 0 
                        ELSE 
                            pg_total_relation_size(c.reltoastrelid) 
                    END)
                ) AS size,
               ( pg_stat_get_blocks_fetched(c.oid) - 
                 pg_stat_get_blocks_hit(c.oid) + 
                 pg_stat_get_blocks_fetched(c.reltoastrelid) - 
                 pg_stat_get_blocks_hit(c.reltoastrelid) ) / 
               GREATEST(
                1, 
                ( pg_stat_get_tuples_inserted(c.oid) + 
                  pg_stat_get_tuples_inserted(c.reltoastrelid) + 2 * 
                  ( pg_stat_get_tuples_updated(c.oid) + 
                    pg_stat_get_tuples_updated(c.reltoastrelid) ) + 
                  pg_stat_get_tuples_deleted(c.oid) + 
                  pg_stat_get_tuples_deleted(c.reltoastrelid) ) 
               ) AS ratio,
               ( pg_stat_get_blocks_fetched(c.oid) - 
                 pg_stat_get_blocks_hit(c.oid) + 
                 pg_stat_get_blocks_fetched(c.reltoastrelid) - 
                 pg_stat_get_blocks_hit(c.reltoastrelid) ) AS disk,
               ( ( 100 * 
                   ( pg_stat_get_blocks_fetched(c.oid) - 
                     pg_stat_get_blocks_hit(c.oid) + 
                     pg_stat_get_blocks_fetched(c.reltoastrelid) - 
                     pg_stat_get_blocks_hit(c.reltoastrelid)) ) /
                   ( SELECT disk FROM totals_counts )
               )::numeric(5,2) AS "disk %",
               ( ( SELECT 
                      SUM(pg_stat_get_tuples_fetched(i.indexrelid))::bigint 
                     FROM pg_index i 
                    WHERE i.indrelid = c.oid ) + 
                 pg_stat_get_tuples_fetched(c.oid) ) / 
               GREATEST(
                1, 
                ( pg_stat_get_blocks_fetched(c.oid) - 
                  pg_stat_get_blocks_hit(c.oid) + 
                  pg_stat_get_blocks_fetched(c.reltoastrelid) -
                  pg_stat_get_blocks_hit(c.reltoastrelid) )
               ) AS rt_d_rat,
               ( ( SELECT SUM(pg_stat_get_tuples_fetched(i.indexrelid))::bigint 
                     FROM pg_index i 
                    WHERE i.indrelid=c.oid ) + 
                 pg_stat_get_tuples_fetched(c.oid)
               ) AS r_tuples,
               ( pg_stat_get_tuples_inserted(c.oid) + 
                 pg_stat_get_tuples_inserted(c.reltoastrelid) +
                 2 * 
                ( pg_stat_get_tuples_updated(c.oid) + 
                  pg_stat_get_tuples_updated(c.reltoastrelid) ) +
                pg_stat_get_tuples_deleted(c.oid) + 
                pg_stat_get_tuples_deleted(c.reltoastrelid)
               ) AS "write",
               ( ( 100 * 
                   ( pg_stat_get_tuples_inserted(c.oid) + 
                     pg_stat_get_tuples_inserted(c.reltoastrelid) +
                     2 * 
                     ( pg_stat_get_tuples_updated(c.oid) + 
                       pg_stat_get_tuples_updated(c.reltoastrelid) ) +
                     pg_stat_get_tuples_deleted(c.oid) + 
                     pg_stat_get_tuples_deleted(c.reltoastrelid)
                   )
                 ) / ( SELECT write FROM totals_counts))::numeric(5,2) AS "write %",
               pg_stat_get_tuples_inserted(c.oid) + pg_stat_get_tuples_inserted(c.reltoastrelid) AS n_tup_ins,
               pg_stat_get_tuples_updated(c.oid) + pg_stat_get_tuples_updated(c.reltoastrelid) AS n_tup_upd,
               pg_stat_get_tuples_deleted(c.oid) + pg_stat_get_tuples_deleted(c.reltoastrelid) AS n_tup_del
          FROM pg_class c
          LEFT JOIN pg_namespace n 
            ON n.oid = c.relnamespace
          LEFT JOIN pg_tablespace t 
            ON t.oid=c.reltablespace
         WHERE c.relkind='r'
           AND n.nspname IS DISTINCT FROM 'pg_catalog'
           AND t.spcname IS DISTINCT FROM 'ssd'
    ) AS t1 
  WHERE ratio > 10
    AND disk > 1000
  ORDER BY disk DESC NULLS LAST LIMIT 100;
$$ table_candidates_to_ssd \gset


-- Show shared_buffers and os pagecache stat for current database
-- Require pg_buffercache and pgfincore
SELECT $$
  WITH qq AS (
    SELECT c.oid,
           count(b.bufferid) * 8192 AS size,
           (SELECT sum(pages_mem) * 4096 
              FROM pgfincore(c.oid::regclass) ) AS size_in_pagecache
      FROM pg_buffercache b
     INNER JOIN pg_class c 
        ON b.relfilenode = pg_relation_filenode(c.oid)
       AND b.reldatabase 
        IN (0, 
            ( SELECT oid 
                FROM pg_database 
               WHERE datname = current_database()
            ))
     GROUP BY 1)
  SELECT
         pg_size_pretty(sum(qq.size)) AS shared_buffers_size,
         pg_size_pretty(sum(qq.size_in_pagecache)) AS size_in_pagecache,
         pg_size_pretty(pg_database_size(current_database())) as database_size
    FROM qq;
$$ cache_stat \gset


-- Shows the top 20 tables with sequential scan on tuple read
SELECT $$
  SELECT schemaname||'.'||relname "relation name",
         n_live_tup as "number of live tuples",
         seq_scan as "sequential scan",
         seq_tup_read as "sequential tuple read",
         (coalesce(n_tup_ins,0)+coalesce(n_tup_upd,0)+coalesce(n_tup_del,0)) as "write activity",
         (SELECT count(*) FROM pg_index WHERE pg_index.indrelid=pg_stat_all_tables.relid) AS "index count",
         idx_scan as "index scan",
         idx_tup_fetch as "indexed tuple fetch"
    FROM pg_stat_all_tables
   WHERE seq_scan > 0
     AND seq_tup_read > 100000
     AND schemaname <> 'pg_catalog'
   ORDER BY seq_tup_read DESC
   LIMIT 20;
$$ seq_scan_tables \gset


