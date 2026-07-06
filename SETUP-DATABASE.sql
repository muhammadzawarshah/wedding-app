-- =============================================
-- WEDDING APP - DATABASE SETUP SCRIPT
-- pgAdmin mein yeh file open karein aur F5 dabayein
-- =============================================

-- Step 1: Wedding user banayein (agar pehle se hai toh error ignore karein)
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'wedding') THEN
      CREATE USER wedding WITH PASSWORD 'wedding';
      RAISE NOTICE 'User wedding banaya gaya.';
   ELSE
      ALTER USER wedding WITH PASSWORD 'wedding';
      RAISE NOTICE 'User wedding already hai, password update kiya.';
   END IF;
END
$$;

-- Step 2: Wedding database banayein (agar pehle se hai toh skip)
SELECT 'CREATE DATABASE wedding OWNER wedding'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'wedding')\gexec

-- Step 3: Permissions
GRANT ALL PRIVILEGES ON DATABASE wedding TO wedding;

-- Confirm
SELECT 'SUCCESS: Database setup complete! Ab API server chalayein.' AS status;
