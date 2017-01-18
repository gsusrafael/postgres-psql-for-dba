-- vim: ft=pgsql

-----------------------------------------
-- psql prompt settings for superuser  --
-- Author : Jesus Rafael Sanchez       --
-----------------------------------------

-- Mute psql
\set QUIET ON

-- Check if is superuser
select current_setting('is_superuser') is_superuser \gset

-- PROMPT1 and PROMPT2 Settings
\set PROMPT1 '%[%033[1;35;40m%]%M%[%033[0m%]:%[%033[0;35;40m%]%> %[%033[1;33;40m%]%n%[%033[0;33;40m%]@%[%033[1;31;40m%]%/%[%033[0;31;40m%]%R%#%[%033[0m%] '
\set PROMPT2 '%[%033[1;35;40m%]%R%[%033[0m%] %[%033[1;33;40m%]%n%[%033[0;33;40m%]@%[%033[1;31;40m%]%/%[%033[0;31;40m%]% %#%[%033[0m%] '

-- Unmute psql
\set QUIET OFF
