import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../models/course.dart';
import '../../widgets/stat_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with greeting
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${authProvider.currentUser?.name ?? "UserName"}!',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ready to continue learning?',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.bgPrimary, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/logo/logo.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Today's Study Plan
              Consumer<AppProvider>(
                builder: (context, appProvider, child) {
                  return _buildTodaysStudyPlan(context, appProvider);
                },
              ),
              const SizedBox(height: 24),

              // Quick Stats
              const Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Consumer<AppProvider>(
                builder: (context, appProvider, child) {
                  final stats = appProvider.studyStats;
                  return Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'Consistency',
                          value: '${stats.consistency}%',
                          subtitle: 'this week',
                          icon: LucideIcons.calendar,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Total Time',
                          value: stats.totalTime,
                          subtitle: 'of study',
                          icon: LucideIcons.clock,
                          color: AppColors.bgPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Top Technique',
                          value: stats.topTechnique,
                          subtitle: 'most used',
                          icon: LucideIcons.brain,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Learning Path
              const Text(
                'Learning Path',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Continue from where left off',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Consumer<AppProvider>(
                builder: (context, appProvider, child) {
                  return _buildLearningPath(context, appProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build Today's Study Plan section with real data
  Widget _buildTodaysStudyPlan(BuildContext context, AppProvider appProvider) {
    // Handle loading state
    if (appProvider.homeScreenLoading) {
      return Container(
        width: double.infinity,
        height: 140,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.white),
        ),
      );
    }

    // Handle error state
    if (appProvider.homeScreenHasError) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Study Plan",
              style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unable to load study recommendations',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => appProvider.refreshHomeScreenData(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.bgPrimary,
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      );
    }

    // Get study plan recommendations
    final recommendations = appProvider.todaysStudyPlan;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Study Plan",
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Show recommendations or default message
          if (recommendations.isEmpty) ...[
            const Text(
              'No specific study recommendations today',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Continue with your current learning path',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 14,
              ),
            ),
          ] else ...[
            ...recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${rec['title']} - ${rec['description']}',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                ),
              ),
            )),
          ],
          
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to modules
                context.read<AppProvider>().setCurrentIndex(1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.bgPrimary,
              ),
              child: const Text('Start Studying'),
            ),
          ),
        ],
      ),
    );
  }

  /// Build Learning Path section with real data
  Widget _buildLearningPath(BuildContext context, AppProvider appProvider) {
    // Handle loading state
    if (appProvider.homeScreenLoading) {
      return Container(
        width: double.infinity,
        height: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.bgPrimary),
        ),
      );
    }

    // Handle error state
    if (appProvider.homeScreenHasError) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'Unable to load learning path',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => appProvider.refreshHomeScreenData(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Get current learning path
    final learningPath = appProvider.currentLearningPath;
    
    // Handle empty state (no enrolled courses)
    if (learningPath == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(
              Icons.school_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 8),
            Text(
              'No courses enrolled yet',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Enroll in courses to start your learning journey',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final progress = (learningPath['progress'] as num?)?.toDouble() ?? 0.0;
    final title = learningPath['title'] as String? ?? 'Unknown Course';
    final completedModules = (learningPath['completedModules'] as int?) ?? 0;
    final totalModules = (learningPath['totalModules'] as int?) ?? 0;

    // Create a Course object for color generation
    final course = Course.fromDatabaseData(learningPath);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: course.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.bookOpen,
                  color: course.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalModules > 0 
                          ? '$completedModules/$totalModules modules • ${(progress * 100).toInt()}% completed'
                          : '${(progress * 100).toInt()}% completed',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.grey200,
              valueColor: AlwaysStoppedAnimation<Color>(course.color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}