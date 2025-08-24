-- =====================================================
-- INSTRUCTOR COURSE MATERIALS STORAGE POLICIES
-- =====================================================
-- 
-- These policies control access to the 'course-materials' storage bucket
-- for the LearnSmart instructor course management system.
--
-- SETUP INSTRUCTIONS:
-- 1. Create storage bucket named 'course-materials' (NOT public)
-- 2. Apply these policies under Storage > Policies > "Other policies under storage.objects"
-- 3. Each policy should target all roles (leave Target roles empty)
-- 
-- BUCKET CONFIGURATION:
-- - Bucket Name: course-materials
-- - Public: No (unchecked)
-- - File Types: PDF, DOC, DOCX, TXT
-- - Max Size: 50MB per file
-- - Path Structure: modules/{moduleId}/{uniqueFileName}
-- =====================================================

-- POLICY 1: Allow instructors to upload course materials
-- =====================================================
-- Policy name: Instructors can upload course materials
-- Allowed operation: INSERT
-- Target roles: (leave empty - defaults to all roles)
-- Policy definition:
CREATE POLICY "Instructors can upload course materials" ON storage.objects
FOR INSERT WITH CHECK (
    bucket_id = 'course-materials' AND (
        SELECT role FROM auth.users WHERE id = auth.uid()
    ) = 'instructor'
);

-- POLICY 2: Allow instructors to read/download course materials
-- =====================================================
-- Policy name: Instructors can read course materials  
-- Allowed operation: SELECT
-- Target roles: (leave empty - defaults to all roles)
-- Policy definition:
CREATE POLICY "Instructors can read course materials" ON storage.objects
FOR SELECT USING (
    bucket_id = 'course-materials' AND (
        SELECT role FROM auth.users WHERE id = auth.uid()
    ) = 'instructor'
);

-- POLICY 3: Allow instructors to delete course materials
-- =====================================================
-- Policy name: Instructors can delete course materials
-- Allowed operation: DELETE  
-- Target roles: (leave empty - defaults to all roles)
-- Policy definition:
CREATE POLICY "Instructors can delete course materials" ON storage.objects
FOR DELETE USING (
    bucket_id = 'course-materials' AND (
        SELECT role FROM auth.users WHERE id = auth.uid()
    ) = 'instructor'
);

-- POLICY 4: Allow instructors to update course materials (Optional)
-- =====================================================
-- Policy name: Instructors can update course materials
-- Allowed operation: UPDATE
-- Target roles: (leave empty - defaults to all roles)  
-- Policy definition:
CREATE POLICY "Instructors can update course materials" ON storage.objects
FOR UPDATE USING (
    bucket_id = 'course-materials' AND (
        SELECT role FROM auth.users WHERE id = auth.uid()
    ) = 'instructor'
) WITH CHECK (
    bucket_id = 'course-materials' AND (
        SELECT role FROM auth.users WHERE id = auth.uid()
    ) = 'instructor'
);

-- =====================================================
-- FUTURE: STUDENT ACCESS POLICIES (Optional)
-- =====================================================
-- Uncomment and modify these if you want students to download materials

/*
-- Allow students to read course materials for enrolled courses
CREATE POLICY "Students can read enrolled course materials" ON storage.objects
FOR SELECT USING (
    bucket_id = 'course-materials' AND (
        SELECT role FROM auth.users WHERE id = auth.uid()
    ) = 'student' AND
    -- Add enrollment check logic here
    EXISTS (
        SELECT 1 FROM enrollments e
        JOIN modules m ON m.course_id = e.course_id
        WHERE e.user_id = auth.uid()
        AND m.id = (name::text[])[2]::uuid  -- Extract module_id from path
    )
);
*/

-- =====================================================
-- ADMIN ACCESS POLICIES (Optional)
-- =====================================================
-- Uncomment if you want admins to have full access

/*
-- Allow admins full access to course materials
CREATE POLICY "Admins can manage all course materials" ON storage.objects
FOR ALL USING (
    bucket_id = 'course-materials' AND (
        SELECT role FROM auth.users WHERE id = auth.uid()
    ) = 'admin'
) WITH CHECK (
    bucket_id = 'course-materials' AND (
        SELECT role FROM auth.users WHERE id = auth.uid()
    ) = 'admin'
);
*/

-- =====================================================
-- POLICY VERIFICATION QUERIES
-- =====================================================
-- Use these to verify your policies are working correctly

-- Check if current user is an instructor
-- SELECT role FROM auth.users WHERE id = auth.uid();

-- List all storage policies for course-materials bucket
-- SELECT * FROM pg_policies WHERE tablename = 'objects' AND policyname LIKE '%course materials%';

-- Test file upload permissions (run as instructor)
-- SELECT bucket_id, name, created_at FROM storage.objects WHERE bucket_id = 'course-materials' LIMIT 5;

-- =====================================================
-- TROUBLESHOOTING
-- =====================================================
-- 
-- Common Issues:
-- 1. "Permission denied" - Check user role in auth.users table
-- 2. "Bucket not found" - Ensure bucket 'course-materials' exists
-- 3. "Policy not applied" - Make sure policies are created under storage.objects, not storage.buckets
-- 4. "File too large" - Check bucket file size limits (set to 50MB)
-- 
-- File Path Structure:
-- - modules/{moduleId}/{uniqueFileName}
-- - Example: modules/123e4567-e89b-12d3-a456-426614174000/Criminal_Law_Basics_1234567890_abc123.pdf
-- 
-- Supported File Types:
-- - application/pdf (.pdf)
-- - application/msword (.doc)  
-- - application/vnd.openxmlformats-officedocument.wordprocessingml.document (.docx)
-- - text/plain (.txt)
-- =====================================================