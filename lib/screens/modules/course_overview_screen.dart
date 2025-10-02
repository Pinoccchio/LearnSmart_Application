import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/course_models.dart';
import '../../models/user_progress_models.dart';
import '../../models/pre_assessment_models.dart';
import '../../services/supabase_service.dart';
import '../../services/user_progress_service.dart';
import '../../services/pre_assessment_service.dart';
import '../../providers/auth_provider.dart';
import 'module_details_screen.dart';
import '../pre_assessment/pre_assessment_intro_screen.dart';
import '../pre_assessment/pre_assessment_results_screen.dart';

class CourseOverviewScreen extends StatefulWidget {
  final Course course;
  final List<String>? weakModulesToHighlight;

  const CourseOverviewScreen({
    super.key,
    required this.course,
    this.weakModulesToHighlight,
  });

  @override
  State<CourseOverviewScreen> createState() => _CourseOverviewScreenState();
}

class _CourseOverviewScreenState extends State<CourseOverviewScreen> {
  Course? _courseWithDetails;
  CourseProgress? _courseProgress;
  bool _loading = true;
  String? _error;

  // Pre-assessment state
  final PreAssessmentService _preAssessmentService = PreAssessmentService();
  bool _preAssessmentCompleted = false;
  double? _preAssessmentScore;
  bool _preAssessmentPassed = false;
  PreAssessmentResult? _preAssessmentResult;
  PreAssessmentAttempt? _preAssessmentAttempt;

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

      // Load course details, user progress, and pre-assessment status in parallel
      final results = await Future.wait([
        SupabaseService.getCourseWithModulesAndMaterials(widget.course.id),
        UserProgressService.getCourseProgress(currentUser.id, widget.course.id),
        _preAssessmentService.isPreAssessmentCompleted(
          userId: currentUser.id,
          courseId: widget.course.id,
        ),
      ]);

      final courseDetails = results[0] as Course?;
      final courseProgress = results[1] as CourseProgress;
      final preAssessmentCompleted = results[2] as bool;

      // If pre-assessment is completed, get the result details
      if (preAssessmentCompleted) {
        final result = await _preAssessmentService.getResult(
          userId: currentUser.id,
          courseId: widget.course.id,
        );
        if (result != null) {
          // Also get the attempt for navigation (if attemptId exists)
          PreAssessmentAttempt? attempt;
          if (result.attemptId != null) {
            attempt = await _preAssessmentService.getAttempt(result.attemptId!);
          }

          setState(() {
            _preAssessmentScore = result.scorePercentage;
            _preAssessmentPassed = result.passed;
            _preAssessmentResult = result;
            _preAssessmentAttempt = attempt;
          });
        }
      }

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
          _preAssessmentCompleted = preAssessmentCompleted;
          _loading = false;
        });
      } else {
        setState(() {
          _courseWithDetails = courseDetails ?? widget.course;
          _courseProgress = courseProgress;
          _preAssessmentCompleted = preAssessmentCompleted;
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

                      // Pre-Assessment Banner
                      if (!_preAssessmentCompleted)
                        _buildPreAssessmentBanner(),
                      if (!_preAssessmentCompleted) const SizedBox(height: 24),

                      // Pre-Assessment Result (if completed)
                      if (_preAssessmentCompleted && _preAssessmentScore != null)
                        _buildPreAssessmentResult(),
                      if (_preAssessmentCompleted && _preAssessmentScore != null)
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
    final isWeak = _isWeakModule(module);
    final canAccess = !isLocked;

    // Determine colors based on module state
    Color borderColor;
    Color backgroundColor;
    if (isCompleted) {
      borderColor = Colors.green;
      backgroundColor = AppColors.white;
    } else if (isLocked) {
      borderColor = AppColors.grey300;
      backgroundColor = AppColors.grey100;
    } else if (isWeak) {
      borderColor = Colors.orange;
      backgroundColor = Colors.orange.withValues(alpha: 0.05);
    } else {
      borderColor = AppColors.grey200;
      backgroundColor = AppColors.white;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: canAccess ? () => _navigateToModule(module) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isWeak ? 2 : 1,
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
                    Row(
                      children: [
                        Text(
                          '${module.materials.length} materials',
                          style: TextStyle(
                            fontSize: 12,
                            color: isLocked ? AppColors.grey400 : AppColors.textSecondary,
                          ),
                        ),
                        if (isWeak && !isLocked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              'Review Recommended',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ],
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
    // Modules are locked if pre-assessment is not completed
    if (!_preAssessmentCompleted) return true;

    if (module.isLocked) return true;

    // First module is never locked (once pre-assessment is done)
    if (index == 0) return false;

    // Use the progress service to check if module is locked
    return _courseProgress?.isModuleLocked(module.id) ?? true;
  }

  bool _isWeakModule(Module module) {
    if (widget.weakModulesToHighlight == null) return false;
    return widget.weakModulesToHighlight!.any((weakModule) =>
      module.title.toLowerCase().contains(weakModule.toLowerCase()) ||
      weakModule.toLowerCase().contains(module.title.toLowerCase())
    );
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

  Widget _buildPreAssessmentBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.1),
            Colors.deepOrange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.clipboardCheck,
                  color: Colors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pre-Assessment Required',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Complete to unlock course modules',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Before starting this course, you need to complete a pre-assessment to evaluate your current knowledge and identify areas that need focus.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToPreAssessment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.playCircle, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Take Pre-Assessment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreAssessmentResult() {
    final scoreColor = _preAssessmentPassed ? Colors.green : Colors.orange;
    final statusIcon = _preAssessmentPassed ? LucideIcons.checkCircle : LucideIcons.alertCircle;
    final statusText = _preAssessmentPassed ? 'Passed' : 'Review Recommended';

    return InkWell(
      onTap: (_preAssessmentResult != null && _preAssessmentAttempt != null)
          ? () {
              // Navigate to detailed results screen
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PreAssessmentResultsScreen(
                    course: _courseWithDetails ?? widget.course,
                    result: _preAssessmentResult!,
                    attempt: _preAssessmentAttempt!,
                  ),
                ),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scoreColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scoreColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                statusIcon,
                color: scoreColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pre-Assessment: $statusText',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Score: ${_preAssessmentScore!.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      color: scoreColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!_preAssessmentPassed && _preAssessmentResult != null && _preAssessmentResult!.weakModules.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tap to review ${_preAssessmentResult!.weakModules.length} weak area${_preAssessmentResult!.weakModules.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight,
              color: scoreColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPreAssessment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PreAssessmentIntroScreen(
          course: _courseWithDetails ?? widget.course,
        ),
      ),
    ).then((_) {
      // Reload course details when returning from pre-assessment
      _loadCourseDetails();
    });
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