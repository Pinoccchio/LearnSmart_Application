-- =============================================================================
-- MODULES TABLE MIGRATION: Add created_by Column
-- =============================================================================
-- 
-- This migration adds the missing 'created_by' column to the existing modules table
-- Run this in Supabase SQL Editor to fix the "created_by column not found" error
--
-- BEFORE RUNNING: Ensure you have users in the 'users' table
-- AFTER RUNNING: Module creation API will work correctly
-- =============================================================================

-- Add created_by column to modules table
-- This column will track which user (instructor) created each module
ALTER TABLE public.modules 
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);

-- Create index for better performance when querying by creator
CREATE INDEX IF NOT EXISTS idx_modules_created_by ON public.modules(created_by);

-- =============================================================================
-- OPTIONAL: Update existing modules with a default creator
-- =============================================================================
-- Uncomment the following lines if you want to assign existing modules to a user
-- This will set all existing modules to be "created by" the first admin user

/*
-- Find the first admin user and assign all existing modules to them
UPDATE public.modules 
SET created_by = (
    SELECT id 
    FROM public.users 
    WHERE role = 'admin' 
    ORDER BY created_at ASC 
    LIMIT 1
) 
WHERE created_by IS NULL;
*/

-- Alternative: Assign to first instructor user
/*
UPDATE public.modules 
SET created_by = (
    SELECT id 
    FROM public.users 
    WHERE role = 'instructor' 
    ORDER BY created_at ASC 
    LIMIT 1
) 
WHERE created_by IS NULL;
*/

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================
-- Run these to verify the migration worked correctly

-- Check that the column was added successfully
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'modules' AND column_name = 'created_by';

-- Check current modules table structure
-- \d public.modules;

-- Count modules with and without created_by values
-- SELECT 
--   COUNT(*) as total_modules,
--   COUNT(created_by) as modules_with_creator,
--   COUNT(*) - COUNT(created_by) as modules_without_creator
-- FROM public.modules;

-- =============================================================================
-- ROLLBACK (if needed)
-- =============================================================================
-- Uncomment this line if you need to undo the migration
-- ALTER TABLE public.modules DROP COLUMN IF EXISTS created_by;

-- =============================================================================
-- NOTES
-- =============================================================================
-- 
-- 1. This migration is safe to run multiple times (uses IF NOT EXISTS)
-- 2. The created_by column is nullable to accommodate existing modules
-- 3. New modules created via API will automatically have created_by populated
-- 4. You can optionally assign existing modules to a default creator
-- 5. The foreign key constraint ensures data integrity
-- 
-- After running this migration, test module creation:
-- 1. Go to instructor dashboard
-- 2. Try creating a new module
-- 3. Should work without "created_by column not found" error
-- =============================================================================