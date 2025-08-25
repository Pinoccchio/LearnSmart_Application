import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../services/supabase_service.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCourseDetails();
  }

  Future<void> _loadCourseDetails() async {
    try {
      final courseDetails = await SupabaseService.getCourseWithModulesAndMaterials(widget.course.id);
      setState(() {
        _courseWithDetails = courseDetails ?? widget.course;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _courseWithDetails = widget.course;
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
    final completedModules = course.modules.where((m) => _isModuleCompleted(m)).length;
    final totalModules = course.modules.length;
    final progressPercentage = totalModules > 0 ? (completedModules / totalModules) : 0.0;

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
    // TODO: Implement actual completion logic based on user progress
    return false;
  }

  bool _isModuleLocked(Module module, int index) {
    if (module.isLocked) return true;
    
    // First module is never locked
    if (index == 0) return false;
    
    // Check if prerequisite modules are completed
    if (module.prerequisiteModuleId != null) {
      // TODO: Check if prerequisite module is completed
      return false;
    }
    
    return false;
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
}