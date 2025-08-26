import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/user_progress_models.dart';
import '../../services/supabase_service.dart';
import '../../services/user_progress_service.dart';
import '../../providers/auth_provider.dart';
import 'module_details_screen.dart';

class CourseOverviewScreen extends StatefulWidget {
  final Course course;

  const CourseOverviewScreen({
    super.key,
    required this.course,
  });

  @override
  State<CourseOverviewScreen> createState() => _CourseOverviewScreenState();
}

class _CourseOverviewScreenState extends State<CourseOverviewScreen> {
  Course? _courseWithDetails;
  CourseProgress? _courseProgress;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourseDetails();
  }

  Future<void> _loadCourseDetails() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      
      if (currentUser == null) {
        setState(() {
          _error = 'User not authenticated';
          _loading = false;
        });
        return;
      }

      print('📚 [COURSE OVERVIEW] Loading course details for: ${widget.course.id}');
      
      // Load course details and user progress in parallel
      final results = await Future.wait([
        SupabaseService.getCourseWithModulesAndMaterials(widget.course.id),
        UserProgressService.getCourseProgress(currentUser.id, widget.course.id),
      ]);

      final courseDetails = results[0] as Course?;
      final courseProgress = results[1] as CourseProgress;

      // If no progress records exist, initialize them
      if (courseProgress.moduleProgresses.isEmpty && courseDetails != null) {
        print('🔄 [INITIALIZATION] No progress found, initializing...');
        await UserProgressService.initializeUserModuleProgress(currentUser.id, courseDetails);
        
        // Reload progress after initialization
        final initializedProgress = await UserProgressService.getCourseProgress(
          currentUser.id, 
          widget.course.id,
        );
        
        setState(() {
          _courseWithDetails = courseDetails;
          _courseProgress = initializedProgress;
          _loading = false;
        });
      } else {
        setState(() {
          _courseWithDetails = courseDetails ?? widget.course;
          _courseProgress = courseProgress;
          _loading = false;
        });
      }

      print('✅ [COURSE OVERVIEW] Course loaded with ${courseProgress.totalModules} modules, ${courseProgress.completedModules} completed');

    } catch (e) {
      print('❌ [COURSE OVERVIEW] Error loading course details: $e');
      setState(() {
        _courseWithDetails = widget.course;
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = _courseWithDetails ?? widget.course;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Overview'),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Course Header
                      _buildCourseHeader(course),
                      const SizedBox(height: 24),
                      
                      // Progress Section
                      _buildProgressSection(course),
                      const SizedBox(height: 24),
                      
                      // Modules Section
                      _buildModulesSection(course),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCourseHeader(Course course) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  LucideIcons.bookOpen,
                  color: Colors.blue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (course.instructorName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'by ${course.instructorName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            course.description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(Course course) {
    final completedModules = _courseProgress?.completedModules ?? 0;
    final totalModules = _courseProgress?.totalModules ?? course.modules.length;
    final progressPercentage = _courseProgress != null ? (_courseProgress!.overallProgress / 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Course Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${(progressPercentage * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercentage,
              backgroundColor: AppColors.grey200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$completedModules of $totalModules modules completed',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulesSection(Course course) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Course Modules',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: course.modules.length,
          itemBuilder: (context, index) {
            final module = course.modules[index];
            return _buildModuleCard(module, index);
          },
        ),
      ],
    );
  }

  Widget _buildModuleCard(Module module, int index) {
    final isCompleted = _isModuleCompleted(module);
    final isLocked = _isModuleLocked(module, index);
    final canAccess = !isLocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: canAccess ? () => _navigateToModule(module) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLocked 
                ? AppColors.grey100 
                : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted 
                  ? Colors.green 
                  : isLocked 
                      ? AppColors.grey300 
                      : AppColors.grey200,
              width: 1,
            ),
            boxShadow: canAccess ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted 
                      ? Colors.green 
                      : isLocked 
                          ? AppColors.grey300 
                          : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isCompleted 
                      ? LucideIcons.check 
                      : isLocked 
                          ? LucideIcons.lock 
                          : LucideIcons.playCircle,
                  color: isCompleted 
                      ? AppColors.white 
                      : isLocked 
                          ? AppColors.grey500 
                          : Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Module ${index + 1}: ${module.title}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isLocked ? AppColors.grey500 : AppColors.textPrimary,
                      ),
                    ),
                    if (module.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        module.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: isLocked ? AppColors.grey400 : AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${module.materials.length} materials',
                      style: TextStyle(
                        fontSize: 12,
                        color: isLocked ? AppColors.grey400 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (canAccess) ...[
                const SizedBox(width: 8),
                const Icon(
                  LucideIcons.chevronRight,
                  color: AppColors.grey400,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isModuleCompleted(Module module) {
    return _courseProgress?.isModuleCompleted(module.id) ?? false;
  }

  bool _isModuleLocked(Module module, int index) {
    if (module.isLocked) return true;
    
    // First module is never locked
    if (index == 0) return false;
    
    // Use the progress service to check if module is locked
    return _courseProgress?.isModuleLocked(module.id) ?? true;
  }

  void _navigateToModule(Module module) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ModuleDetailsScreen(
          course: _courseWithDetails ?? widget.course,
          module: module,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.alertCircle,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Course',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unknown error occurred',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadCourseDetails();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}