import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/feynman_models.dart';

class ExplanationFeedbackWidget extends StatelessWidget {
  final FeynmanExplanation explanation;
  final List<FeynmanFeedback> feedback;
  final bool showDetailed;

  const ExplanationFeedbackWidget({
    super.key,
    required this.explanation,
    required this.feedback,
    this.showDetailed = true,
  });

  @override
  Widget build(BuildContext context) {
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getScoreColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  explanation.isProcessing 
                      ? LucideIcons.loader2
                      : explanation.isProcessed && explanation.hasScores
                          ? LucideIcons.checkCircle
                          : LucideIcons.alertCircle,
                  color: _getScoreColor(),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explanation Analysis',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getScoreColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (explanation.isProcessed && explanation.overallScore != null)
                _buildOverallScoreBadge(),
            ],
          ),
          
          if (explanation.isProcessing) ...[
            const SizedBox(height: 20),
            _buildProcessingState(),
          ] else if (!explanation.isProcessed) ...[
            const SizedBox(height: 20),
            _buildPendingState(),
          ] else if (explanation.hasScores) ...[
            const SizedBox(height: 20),
            _buildScoreBreakdown(),
            
            if (explanation.strengths.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildStrengthsSection(),
            ],
            
            if (explanation.identifiedGaps.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildGapsSection(),
            ],
            
            if (feedback.isNotEmpty && showDetailed) ...[
              const SizedBox(height: 16),
              _buildFeedbackSection(),
            ],
            
            if (explanation.improvementAreas.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildImprovementSection(),
            ],
          ] else ...[
            const SizedBox(height: 20),
            _buildErrorState(),
          ],
        ],
      ),
    );
  }

  Widget _buildOverallScoreBadge() {
    final score = explanation.overallScore!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getScoreColor(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.star,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '${score.toStringAsFixed(1)}/10',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI is analyzing your explanation. This usually takes 10-30 seconds...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.clock,
            color: Colors.orange.shade600,
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your explanation is queued for AI analysis. Please wait...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.alertTriangle,
            color: Colors.red.shade600,
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI analysis failed, but your explanation effort is still valuable for learning.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Score Breakdown',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        
        if (explanation.clarityScore != null)
          _buildScoreBar('Clarity', explanation.clarityScore!, LucideIcons.eye),
        
        if (explanation.completenessScore != null)
          _buildScoreBar('Completeness', explanation.completenessScore!, LucideIcons.checkCircle),
        
        if (explanation.conceptualAccuracyScore != null)
          _buildScoreBar('Accuracy', explanation.conceptualAccuracyScore!, LucideIcons.target),
        
        if (explanation.overallScore != null)
          _buildScoreBar('Overall', explanation.overallScore!, LucideIcons.award, isOverall: true),
      ],
    );
  }

  Widget _buildScoreBar(String label, double score, IconData icon, {bool isOverall = false}) {
    final percentage = (score / 10.0).clamp(0.0, 1.0);
    final color = _getScoreColorForValue(score);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isOverall ? 14 : 12,
                      fontWeight: isOverall ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${score.toStringAsFixed(1)}/10',
                style: TextStyle(
                  fontSize: isOverall ? 14 : 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: isOverall ? 6 : 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.thumbsUp,
              color: Colors.green.shade600,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              'Strengths',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: explanation.strengths.map((strength) => _buildTag(
            strength,
            Colors.green,
            LucideIcons.check,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildGapsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.target,
              color: Colors.orange.shade600,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              'Areas to Address',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: explanation.identifiedGaps.map((gap) => _buildTag(
            gap,
            Colors.orange,
            LucideIcons.alertCircle,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildImprovementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.trendingUp,
              color: Colors.blue.shade600,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              'Improvement Areas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: explanation.improvementAreas.map((area) => _buildTag(
            area,
            Colors.blue,
            LucideIcons.arrowUp,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildFeedbackSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.messageCircle,
              color: Colors.purple.shade600,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              'Detailed Feedback',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: feedback.map((item) => _buildFeedbackItem(item)).toList(),
        ),
      ],
    );
  }

  Widget _buildFeedbackItem(FeynmanFeedback feedbackItem) {
    final severityColor = _getSeverityColor(feedbackItem.severity);
    final isLongText = feedbackItem.feedbackText.length > 200;
    
    return StatefulBuilder(
      builder: (context, setState) {
        bool isExpanded = !isLongText; // Auto-expand short text
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: severityColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: severityColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      feedbackItem.feedbackType.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: severityColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: List.generate(
                      feedbackItem.priority,
                      (index) => Icon(
                        LucideIcons.star,
                        size: 10,
                        color: severityColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Main feedback text with expand/collapse for long content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpanded || !isLongText
                        ? feedbackItem.feedbackText
                        : '${feedbackItem.feedbackText.substring(0, 200)}...',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                  
                  // Show expand/collapse button for long text
                  if (isLongText) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => isExpanded = !isExpanded),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                            size: 14,
                            color: severityColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isExpanded ? 'Show less' : 'Read more',
                            style: TextStyle(
                              fontSize: 12,
                              color: severityColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              
              if (feedbackItem.suggestedImprovement != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.lightbulb,
                        size: 14,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          feedbackItem.suggestedImprovement!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontStyle: FontStyle.italic,
                            height: 1.3,
                          ),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTag(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
                height: 1.2,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor() {
    if (!explanation.isProcessed || explanation.overallScore == null) {
      return explanation.isProcessing ? Colors.blue : Colors.grey;
    }
    return _getScoreColorForValue(explanation.overallScore!);
  }

  Color _getScoreColorForValue(double score) {
    if (score >= 8.0) return Colors.green;
    if (score >= 6.0) return Colors.blue;
    if (score >= 4.0) return Colors.orange;
    return Colors.red;
  }

  Color _getSeverityColor(FeedbackSeverity severity) {
    switch (severity) {
      case FeedbackSeverity.low:
        return Colors.green;
      case FeedbackSeverity.medium:
        return Colors.blue;
      case FeedbackSeverity.high:
        return Colors.orange;
      case FeedbackSeverity.critical:
        return Colors.red;
    }
  }

  String _getStatusText() {
    if (explanation.isProcessing) {
      return 'Analyzing...';
    } else if (!explanation.isProcessed) {
      return 'Pending analysis';
    } else if (explanation.hasScores) {
      final score = explanation.overallScore!;
      if (score >= 8.0) return 'Excellent explanation!';
      if (score >= 6.0) return 'Good explanation';
      if (score >= 4.0) return 'Needs improvement';
      return 'Try again with more detail';
    } else {
      return 'Analysis failed';
    }
  }
}