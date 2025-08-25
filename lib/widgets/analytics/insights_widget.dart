import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/study_analytics_models.dart';

class InsightsWidget extends StatelessWidget {
  final List<AnalyticsInsight> insights;
  final bool showAll;

  const InsightsWidget({
    super.key,
    required this.insights,
    this.showAll = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayInsights = showAll ? insights : insights.take(3).toList();
    
    return Container(
      padding: const EdgeInsets.all(16),
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.lightbulb,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Learning Insights',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (insights.length > 3 && !showAll)
                TextButton(
                  onPressed: () => _showAllInsights(context),
                  child: const Text('View All'),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (insights.isEmpty)
            _buildEmptyState()
          else
            ...displayInsights.map((insight) => _buildInsightCard(insight)),
        ],
      ),
    );
  }

  Widget _buildInsightCard(AnalyticsInsight insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getCategoryColor(insight.category).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getCategoryColor(insight.category).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with category and significance
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCategoryColor(insight.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getCategoryIcon(insight.category),
                      size: 12,
                      color: _getCategoryColor(insight.category),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatCategoryName(insight.category),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _getCategoryColor(insight.category),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Significance indicator
              _buildSignificanceIndicator(insight.significance),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Title
          Text(
            insight.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
          
          const SizedBox(height: 8),
          
          // Insight content
          Text(
            insight.insight,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 6,
          ),
          
          // Supporting data
          if (insight.supportingData.isNotEmpty) ...[
            const SizedBox(height: 12),
            
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: insight.supportingData.take(3).map((data) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignificanceIndicator(double significance) {
    final level = significance >= 0.8 
        ? 'High' 
        : significance >= 0.5 
            ? 'Medium' 
            : 'Low';
    
    final color = significance >= 0.8 
        ? Colors.red 
        : significance >= 0.5 
            ? Colors.orange 
            : Colors.green;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            level,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            LucideIcons.brain,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          const Text(
            'Generating Insights...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI is analyzing your study patterns to provide personalized insights.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(InsightCategory category) {
    switch (category) {
      case InsightCategory.performance:
        return Colors.blue;
      case InsightCategory.behavior:
        return Colors.green;
      case InsightCategory.cognitive:
        return Colors.purple;
      case InsightCategory.temporal:
        return Colors.orange;
      case InsightCategory.material:
        return Colors.teal;
    }
  }

  IconData _getCategoryIcon(InsightCategory category) {
    switch (category) {
      case InsightCategory.performance:
        return LucideIcons.trendingUp;
      case InsightCategory.behavior:
        return LucideIcons.user;
      case InsightCategory.cognitive:
        return LucideIcons.brain;
      case InsightCategory.temporal:
        return LucideIcons.clock;
      case InsightCategory.material:
        return LucideIcons.bookOpen;
    }
  }

  String _formatCategoryName(InsightCategory category) {
    switch (category) {
      case InsightCategory.performance:
        return 'Performance';
      case InsightCategory.behavior:
        return 'Behavior';
      case InsightCategory.cognitive:
        return 'Cognitive';
      case InsightCategory.temporal:
        return 'Timing';
      case InsightCategory.material:
        return 'Material';
    }
  }

  void _showAllInsights(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grey300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.lightbulb,
                        color: Colors.purple,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'All Learning Insights',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: insights.map((insight) => _buildInsightCard(insight)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}