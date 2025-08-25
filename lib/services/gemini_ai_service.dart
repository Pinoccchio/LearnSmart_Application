import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/course_models.dart';
import '../models/active_recall_models.dart';
import '../models/feynman_models.dart';
import '../models/study_analytics_models.dart';
import 'pdf_extraction_service.dart';

class GeminiAIService {
  static const String _apiKey = 'AIzaSyDyFbfNS8XwzcBtnpYY-5lovrTKH5-NXLM';
  late final GenerativeModel _model;
  late final PdfExtractionService _pdfExtractor;
  
  GeminiAIService() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
    );
    _pdfExtractor = PdfExtractionService();
  }

  Future<List<ActiveRecallFlashcard>> generateFlashcardsFromMaterials(
    List<CourseMaterial> materials,
    String moduleTitle,
  ) async {
    try {
      print('🧠 [GEMINI AI] Starting flashcard generation for ${materials.length} materials');
      
      List<ActiveRecallFlashcard> allFlashcards = [];
      
      for (int i = 0; i < materials.length; i++) {
        final material = materials[i];
        print('📄 [GEMINI AI] Processing material ${i + 1}/${materials.length}: ${material.title}');
        
        try {
          final flashcards = await _generateFlashcardsFromMaterial(material, moduleTitle);
          allFlashcards.addAll(flashcards);
          print('✅ [GEMINI AI] Generated ${flashcards.length} flashcards from ${material.title}');
        } catch (e) {
          print('⚠️ [GEMINI AI] Failed to process ${material.title}: $e');
          // Continue with other materials even if one fails
        }
      }
      
      print('🎯 [GEMINI AI] Total flashcards generated: ${allFlashcards.length}');
      return allFlashcards;
      
    } catch (e) {
      print('❌ [GEMINI AI ERROR] $e');
      rethrow;
    }
  }

  Future<List<ActiveRecallFlashcard>> _generateFlashcardsFromMaterial(
    CourseMaterial material,
    String moduleTitle,
  ) async {
    // For now, we'll generate flashcards based on material metadata
    // In a full implementation, you'd extract content from PDFs/documents
    final content = await _extractContentFromMaterial(material);
    
    final prompt = '''
You are an expert educator creating Active Recall flashcards for a module titled "$moduleTitle".

Based on this learning material:
Title: ${material.title}
Description: ${material.description ?? 'No description provided'}
File Type: ${material.fileType}
Content Context: $content

Generate exactly 5 high-quality flashcards that test key concepts. Each flashcard should promote active recall and memory retrieval.

Return your response as a valid JSON array with this exact structure:
[
  {
    "type": "fill_in_blank",
    "question": "Complete this statement: _____ is the fundamental concept that...",
    "answer": "Object-oriented programming",
    "hints": ["Think about programming paradigms", "Related to classes and objects"],
    "difficulty": "medium",
    "explanation": "Brief explanation of why this answer is correct"
  },
  {
    "type": "definition_recall",
    "question": "What is the definition of [key term]?",
    "answer": "Clear, concise definition",
    "hints": ["Think about the core characteristics", "Consider its purpose"],
    "difficulty": "easy",
    "explanation": "Why this definition is important"
  },
  {
    "type": "concept_application",
    "question": "How would you apply [concept] in a real-world scenario?",
    "answer": "Practical application example",
    "hints": ["Think about practical uses", "Consider industry examples"],
    "difficulty": "hard",
    "explanation": "Why this application works"
  }
]

Important rules:
- Use only these types: "fill_in_blank", "definition_recall", "concept_application"
- Use only these difficulty levels: "easy", "medium", "hard"
- Keep questions clear and specific
- Provide 2-3 helpful hints per flashcard
- Make answers concise but complete
- Return ONLY the JSON array, no other text
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;
      
      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from Gemini AI');
      }

      print('🤖 [GEMINI AI] Raw response: ${responseText.substring(0, responseText.length.clamp(0, 200))}...');

      // Clean up the response to extract JSON
      String jsonText = responseText.trim();
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      }
      if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      jsonText = jsonText.trim();

      final List<dynamic> flashcardsJson = jsonDecode(jsonText);
      
      return flashcardsJson.asMap().entries.map((entry) {
        final index = entry.key;
        final json = entry.value as Map<String, dynamic>;
        return ActiveRecallFlashcard.fromAI(
          json,
          material.id,
          material.moduleId,
          index: index,
        );
      }).toList();

    } catch (e) {
      print('❌ [GEMINI AI] Error generating flashcards: $e');
      
      // Return fallback flashcards if AI fails
      return _getFallbackFlashcards(material);
    }
  }

  Future<String> _extractContentFromMaterial(CourseMaterial material) async {
    String contentContext = '';
    
    switch (material.fileType.toLowerCase()) {
      case 'pdf':
        // Try direct PDF upload to Gemini 2.0 Flash first (processes ALL pages)
        if (_pdfExtractor.isPdfUrl(material.fileUrl)) {
          try {
            print('🚀 [CONTENT EXTRACTION] Trying Gemini 2.0 Flash direct PDF upload: ${material.title}');
            final fullPdfContent = await _processFullPdfWithGemini(material.fileUrl, material.title);
            
            contentContext = '''PDF Document: "${material.title}"

Complete Document Analysis (ALL pages processed by Gemini 2.0 Flash):
$fullPdfContent

Summary: This PDF contains comprehensive educational material. All pages have been analyzed for complete coverage.''';
              
            print('✅ [CONTENT EXTRACTION] Successfully processed full PDF via Gemini upload (${fullPdfContent.length} chars)');
            
          } catch (e) {
            print('⚠️ [CONTENT EXTRACTION] Gemini direct upload failed, falling back to Syncfusion: $e');
            
            // Fallback to original Syncfusion extraction (limited to ~41 pages)
            try {
              final pdfContent = await _pdfExtractor.extractTextFromPdfUrl(material.fileUrl);
              
              if (pdfContent.isNotEmpty && pdfContent != 'No readable text content found in this PDF document.') {
                final preview = _pdfExtractor.getSampleContent(pdfContent, sampleLength: 150);
                contentContext = '''PDF Document: "${material.title}"

Key Content (Syncfusion extraction - limited pages):
$pdfContent

Summary: This PDF contains educational material covering concepts related to ${material.title}. Note: Content may be incomplete due to extraction limitations.''';
                
                print('✅ [CONTENT EXTRACTION] Fallback: Syncfusion extracted PDF content (${pdfContent.length} chars)');
                print('📖 [CONTENT PREVIEW] ${preview}');
              } else {
                contentContext = 'PDF document "${material.title}" - content extraction was attempted but no readable text was found. This may be an image-based or encrypted PDF.';
                print('⚠️ [CONTENT EXTRACTION] No text found in PDF: ${material.title}');
              }
            } catch (syncfusionError) {
              print('❌ [CONTENT EXTRACTION] Both methods failed for ${material.title}: $syncfusionError');
              contentContext = 'PDF document "${material.title}" containing detailed information about the topic. (All extraction methods failed, using metadata only)';
            }
          }
        } else {
          contentContext = 'PDF document "${material.title}" containing detailed information about the topic.';
        }
        break;
        
      case 'mp4':
      case 'avi':
      case 'mov':
        contentContext = 'Video content "${material.title}" explaining key concepts through visual demonstration and narration.';
        break;
        
      case 'ppt':
      case 'pptx':
        contentContext = 'Presentation slides "${material.title}" covering structured information with visual aids and bullet points.';
        break;
        
      case 'doc':
      case 'docx':
        contentContext = 'Document "${material.title}" with comprehensive written information and detailed explanations.';
        break;
        
      default:
        contentContext = 'Educational material "${material.title}" covering important concepts and information.';
    }
    
    // Add description if available
    if (material.description?.isNotEmpty == true) {
      contentContext += '\n\nMaterial Description: ${material.description}';
    }
    
    return contentContext;
  }

  /// Process full PDF directly with Gemini 2.0 Flash via file upload
  Future<String> _processFullPdfWithGemini(String pdfUrl, String materialTitle) async {
    try {
      print('🚀 [GEMINI PDF UPLOAD] Starting direct PDF processing: $materialTitle');
      
      // Download PDF bytes directly
      final pdfBytes = await _downloadPdfBytes(pdfUrl);
      
      if (pdfBytes == null) {
        throw Exception('Failed to download PDF file for direct processing');
      }
      
      print('📁 [GEMINI PDF UPLOAD] Downloaded ${pdfBytes.length} bytes, uploading to Gemini 2.0 Flash...');
      
      // Create comprehensive prompt for flashcard generation
      final prompt = '''
Analyze this complete PDF document titled "$materialTitle" and extract ALL educational content for comprehensive flashcard generation.

Please provide a detailed content summary that captures:
1. All major concepts, theories, and principles
2. Key definitions and terminology  
3. Important formulas, processes, or methodologies
4. Critical examples and case studies
5. Essential facts and data points
6. Learning objectives and takeaways

Focus on educational content that would be valuable for active recall and spaced repetition learning. Include content from ALL pages of the document, not just the beginning.

Provide the response as a comprehensive text summary covering the entire document.
''';

      // Send PDF directly to Gemini 2.0 Flash
      final response = await _model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('application/pdf', pdfBytes),
        ])
      ]);
      
      final fullContent = response.text;
      
      if (fullContent == null || fullContent.trim().isEmpty) {
        throw Exception('Gemini returned empty response for PDF processing');
      }
      
      print('✅ [GEMINI PDF UPLOAD] Successfully processed full PDF (${fullContent.length} chars)');
      print('📊 [GEMINI PDF UPLOAD] Content preview: ${fullContent.substring(0, 200)}...');
      
      return fullContent;
      
    } catch (e) {
      print('❌ [GEMINI PDF UPLOAD] Direct PDF processing failed: $e');
      rethrow;
    }
  }

  /// Download PDF file as bytes for direct Gemini upload
  Future<Uint8List?> _downloadPdfBytes(String url) async {
    try {
      print('📥 [PDF DOWNLOAD] Downloading PDF from: ${url.substring(0, 50)}...');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'LearnSmart-App/1.0',
          'Accept': 'application/pdf',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        print('✅ [PDF DOWNLOAD] Downloaded ${response.bodyBytes.length} bytes for Gemini upload');
        return response.bodyBytes;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('❌ [PDF DOWNLOAD] Download failed: $e');
      return null;
    }
  }

  List<ActiveRecallFlashcard> _getFallbackFlashcards(CourseMaterial material) {
    // Fallback flashcards if AI generation fails
    return [
      ActiveRecallFlashcard(
        id: '${material.id}_fallback_1',
        materialId: material.id,
        moduleId: material.moduleId,
        type: FlashcardType.definitionRecall,
        question: 'What is the main topic covered in "${material.title}"?',
        answer: 'The main topic relates to the learning objectives of this module.',
        hints: ['Think about the material title', 'Consider the module context'],
        difficulty: FlashcardDifficulty.easy,
        explanation: 'This tests basic comprehension of the material topic.',
        createdAt: DateTime.now(),
      ),
      ActiveRecallFlashcard(
        id: '${material.id}_fallback_2',
        materialId: material.id,
        moduleId: material.moduleId,
        type: FlashcardType.fillInBlank,
        question: 'Complete this: "${material.title}" is important because _____.',
        answer: 'it provides essential knowledge for understanding the module concepts.',
        hints: ['Think about learning objectives', 'Consider practical applications'],
        difficulty: FlashcardDifficulty.medium,
        explanation: 'This tests understanding of the material\'s relevance.',
        createdAt: DateTime.now(),
      ),
    ];
  }

  /// Generate comprehensive descriptive and prescriptive analytics
  Future<Map<String, dynamic>> generateStudyAnalyticsInsights(Map<String, dynamic> analyticsData) async {
    try {
      print('🤖 [GEMINI AI] Generating descriptive and prescriptive analytics...');
      
      final prompt = '''
You are an expert educational data scientist and learning psychologist. Analyze the following comprehensive study session data and provide proper DESCRIPTIVE ANALYTICS (what happened) and PRESCRIPTIVE ANALYTICS (what to do next).

STUDY SESSION DATA:
Course: ${analyticsData['course']}
Module: ${analyticsData['module']}

PERFORMANCE METRICS:
- Pre-Study Accuracy: ${analyticsData['performance']['pre_study_accuracy']}%
- Post-Study Accuracy: ${analyticsData['performance']['post_study_accuracy']}%
- Improvement: ${analyticsData['performance']['improvement']}%
- Average Response Time: ${analyticsData['performance']['avg_response_time']} seconds
- Overall Performance Level: ${analyticsData['performance']['overall_level']}

LEARNING PATTERNS:
- Pattern Type: ${analyticsData['learning_patterns']['pattern_type']}
- Learning Velocity: ${analyticsData['learning_patterns']['learning_velocity']}
- Strong Concepts: ${analyticsData['learning_patterns']['strong_concepts']}
- Weak Concepts: ${analyticsData['learning_patterns']['weak_concepts']}

BEHAVIOR ANALYSIS:
- Study Duration: ${analyticsData['behavior']['total_study_minutes']} minutes
- Persistence Score: ${analyticsData['behavior']['persistence_score']}
- Engagement Level: ${analyticsData['behavior']['engagement_level']}
- Common Error Types: ${analyticsData['behavior']['common_errors']}

COGNITIVE ANALYSIS:
- Cognitive Load: ${analyticsData['cognitive']['cognitive_load']}
- Processing Speed: ${analyticsData['cognitive']['processing_speed']}
- Attention Span: ${analyticsData['cognitive']['attention_span']}
- Cognitive Strengths: ${analyticsData['cognitive']['strengths']}
- Cognitive Weaknesses: ${analyticsData['cognitive']['weaknesses']}

Generate the following in JSON format:

{
  "insights": [
    {
      "id": "descriptive_insight_id",
      "category": "performance|behavior|cognitive|learning_patterns",
      "title": "Descriptive Insight Title",
      "insight": "DESCRIPTIVE ANALYTICS: Detailed analysis of what actually happened in the learning session. Focus on patterns, trends, correlations, and statistical observations about the student's learning behavior and performance.",
      "significance": 0.0-1.0,
      "supporting_data": ["quantitative evidence", "behavioral patterns identified", "performance metrics"]
    }
  ],
  "recommendations": [
    {
      "id": "prescriptive_action_id",
      "type": "studyStrategy|timeManagement|conceptMastery|practiceMethod|cognitiveOptimization|behaviorModification",
      "title": "Prescriptive Action Title",
      "description": "PRESCRIPTIVE ANALYTICS: Specific evidence-based strategy to optimize learning outcomes",
      "actionable_advice": "Detailed step-by-step actions the student should take, based on data analysis. Include timing, methods, and measurable goals.",
      "priority": 1-5,
      "confidence_score": 0.0-1.0,
      "reasons": ["data-driven justification", "expected outcome", "success probability"]
    }
  ],
  "study_plan": {
    "id": "technique_recommendation_${DateTime.now().millisecondsSinceEpoch}",
    "activities": [
      {
        "type": "active_recall|pomodoro_technique|feynman_technique|retrieval_practice",
        "description": "Recommended study technique based on performance analysis and learning patterns",
        "duration_minutes": 25-45,
        "priority": 1-3,
        "materials": ["specific concepts to focus on based on weak areas identified"]
      }
    ],
    "estimated_duration_minutes": 25-90,
    "focus_areas": {
      "primary_technique": "recommended study technique based on performance data",
      "secondary_technique": "alternative study technique if needed"
    },
    "objectives": ["technique-specific learning goal", "performance improvement target"]
  }
}

ANALYTICS REQUIREMENTS:

DESCRIPTIVE ANALYTICS (Insights):
1. Analyze WHAT HAPPENED during the learning session
2. Identify patterns, correlations, and trends in the data
3. Provide statistical observations about performance, behavior, and cognition
4. Focus on data interpretation and pattern recognition
5. Answer: "What can we learn from this session data?"

PRESCRIPTIVE ANALYTICS (Recommendations):  
1. Determine WHAT ACTION TO TAKE based on the descriptive analysis
2. Provide specific, data-driven strategies for optimization
3. Include step-by-step actionable plans with measurable outcomes
4. Prioritize actions by expected impact and feasibility
5. Answer: "What should the student do to improve based on this data?"

STUDY TECHNIQUE RECOMMENDATIONS (Prescriptive Implementation):
1. Recommend specific study techniques from our available options: Active Recall, Pomodoro Technique, Feynman Technique, Retrieval Practice
2. Base recommendations on student's performance patterns, learning velocity, and cognitive analysis
3. Match technique characteristics to student's strengths and weaknesses
4. Prioritize techniques that will maximize learning efficiency for this student's profile
5. Consider: Quick learners → Active Recall or Retrieval Practice; Attention issues → Pomodoro Technique; Conceptual struggles → Feynman Technique

Return ONLY the JSON response, no other text.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;
      
      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from Gemini AI for analytics insights');
      }

      print('🤖 [GEMINI AI] Analytics response received: ${responseText.substring(0, responseText.length.clamp(0, 300))}...');

      // Clean up the response to extract JSON
      String jsonText = responseText.trim();
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      }
      if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      jsonText = jsonText.trim();

      final Map<String, dynamic> aiResponse = jsonDecode(jsonText);
      
      // Convert AI response to our model objects
      return _processAIAnalyticsResponse(aiResponse);
      
    } catch (e) {
      print('❌ [GEMINI AI] Error generating analytics insights: $e');
      throw Exception('Failed to generate AI insights: $e');
    }
  }

  /// Process AI response and convert to model objects
  Map<String, dynamic> _processAIAnalyticsResponse(Map<String, dynamic> aiResponse) {
    try {
      // Convert insights
      final insights = (aiResponse['insights'] as List).map((insightJson) {
        return AnalyticsInsight(
          id: insightJson['id'] ?? 'insight_${DateTime.now().millisecondsSinceEpoch}',
          category: InsightCategory.values.firstWhere(
            (cat) => cat.name == insightJson['category'],
            orElse: () => InsightCategory.performance,
          ),
          title: insightJson['title'] ?? 'Learning Insight',
          insight: insightJson['insight'] ?? 'Insight not available',
          significance: (insightJson['significance'] as num?)?.toDouble() ?? 0.5,
          supportingData: List<String>.from(insightJson['supporting_data'] ?? []),
          visualizationData: insightJson['visualization_data'] ?? {},
        );
      }).toList();

      // Convert recommendations
      final recommendations = (aiResponse['recommendations'] as List).map((recJson) {
        return PersonalizedRecommendation(
          id: recJson['id'] ?? 'rec_${DateTime.now().millisecondsSinceEpoch}',
          type: RecommendationType.values.firstWhere(
            (type) => type.name == recJson['type'],
            orElse: () => RecommendationType.studyTechnique,
          ),
          title: recJson['title'] ?? 'Study Recommendation',
          description: recJson['description'] ?? 'Recommendation not available',
          actionableAdvice: recJson['actionable_advice'] ?? 'Continue with current approach',
          priority: recJson['priority'] ?? 3,
          confidenceScore: (recJson['confidence_score'] as num?)?.toDouble() ?? 0.7,
          reasons: List<String>.from(recJson['reasons'] ?? []),
          parameters: recJson['parameters'] ?? {},
        );
      }).toList();

      // Convert study plan
      final studyPlanJson = aiResponse['study_plan'] as Map<String, dynamic>? ?? {};
      final activities = (studyPlanJson['activities'] as List? ?? []).map((activityJson) {
        return StudyActivity(
          type: activityJson['type'] ?? 'review',
          description: activityJson['description'] ?? 'Study activity',
          duration: Duration(minutes: activityJson['duration_minutes'] ?? 30),
          priority: activityJson['priority'] ?? 2,
          materials: List<String>.from(activityJson['materials'] ?? []),
        );
      }).toList();

      final studyPlan = StudyPlan(
        id: studyPlanJson['id'] ?? 'plan_${DateTime.now().millisecondsSinceEpoch}',
        activities: activities,
        estimatedDuration: Duration(minutes: studyPlanJson['estimated_duration_minutes'] ?? 60),
        focusAreas: Map<String, String>.from(studyPlanJson['focus_areas'] ?? {}),
        objectives: List<String>.from(studyPlanJson['objectives'] ?? []),
      );

      print('✅ [GEMINI AI] Successfully processed AI analytics response');
      print('📊 [AI RESULTS] Generated ${insights.length} insights, ${recommendations.length} recommendations');
      
      return {
        'insights': insights,
        'recommendations': recommendations,
        'studyPlan': studyPlan,
      };
      
    } catch (e) {
      print('❌ [GEMINI AI] Error processing AI analytics response: $e');
      rethrow;
    }
  }

  /// Generate comprehensive analytics insights for Pomodoro Technique sessions
  Future<Map<String, dynamic>> generatePomodoroAnalyticsInsights(Map<String, dynamic> analyticsData) async {
    try {
      print('🍅 [GEMINI AI] Generating Pomodoro-specific analytics insights...');
      
      final prompt = '''
You are an expert educational data scientist specializing in productivity and focus optimization through the Pomodoro Technique. Analyze the following Pomodoro study session data and provide DESCRIPTIVE ANALYTICS (what happened) and PRESCRIPTIVE ANALYTICS (what to do next).

POMODORO SESSION DATA:
Course: ${analyticsData['course']}
Module: ${analyticsData['module']}
Study Technique: Pomodoro Technique

SESSION OVERVIEW:
- Total Cycles: ${analyticsData['session_data']['total_cycles']}
- Completed Cycles: ${analyticsData['session_data']['completed_cycles']}
- Total Duration: ${analyticsData['session_data']['total_duration_minutes']} minutes
- Work Cycles: ${analyticsData['session_data']['work_cycles']}
- Break Cycles: ${analyticsData['session_data']['break_cycles']}
- Notes Taken: ${analyticsData['session_data']['notes_taken']}

FOCUS ANALYSIS:
- Average Focus Score: ${analyticsData['focus_analysis']['average_focus_score']}/10
- Focus Progression: ${analyticsData['focus_analysis']['focus_progression']}
- Pattern Type: ${analyticsData['focus_analysis']['pattern_type']}

PERFORMANCE METRICS:
- Productivity Score: ${analyticsData['performance']['productivity_score']}%
- Completion Rate: ${analyticsData['performance']['completion_rate']}%
- Improvement: ${analyticsData['performance']['improvement']}

BEHAVIOR PATTERNS:
- Persistence Score: ${analyticsData['behavior']['persistence_score']}
- Engagement Level: ${analyticsData['behavior']['engagement_level']}
- Break Adherence: ${analyticsData['behavior']['break_adherence']}
- Common Challenges: ${analyticsData['behavior']['common_challenges']}

COGNITIVE FACTORS:
- Cognitive Load: ${analyticsData['cognitive']['cognitive_load']}
- Processing Efficiency: ${analyticsData['cognitive']['processing_efficiency']}
- Attention Span: ${analyticsData['cognitive']['attention_span']}
- Strengths: ${analyticsData['cognitive']['strengths']}
- Weaknesses: ${analyticsData['cognitive']['weaknesses']}

NOTE-TAKING ANALYSIS:
- Study Notes: ${analyticsData['notes_analysis']['study_notes']}
- Reflections: ${analyticsData['notes_analysis']['reflections']}

HISTORICAL CONTEXT (Previous Module Sessions):
- Total Sessions in Module: ${analyticsData['historical_context']['total_module_sessions']}
- Total Cycles Completed: ${analyticsData['historical_context']['total_module_cycles']}
- Historical Average Focus: ${analyticsData['historical_context']['historical_avg_focus']}/10
- Historical Completion Rate: ${analyticsData['historical_context']['historical_completion_rate']}%
- Optimal Cycle Length: ${analyticsData['historical_context']['optimal_cycle_length']} minutes
- Focus Trend: ${analyticsData['historical_context']['focus_trend']}
- Best Study Time: ${analyticsData['historical_context']['best_time_of_day']}
- Recent Focus Scores: ${analyticsData['historical_context']['focus_score_trends']}
- Average Cycles per Session: ${analyticsData['historical_context']['avg_cycles_per_session']}

Generate the following in JSON format:

{
  "insights": [
    {
      "id": "pomodoro_descriptive_insight_id",
      "category": "performance|behavior|cognitive|focus_patterns",
      "title": "Pomodoro Session Insight Title",
      "insight": "DESCRIPTIVE ANALYTICS: Analysis of focus patterns, cycle completion, productivity trends, and Pomodoro technique effectiveness. Focus on what the data reveals about the student's ability to maintain focused work periods, take effective breaks, and sustain attention throughout the session.",
      "significance": 0.0-1.0,
      "supporting_data": ["focus score data", "cycle completion patterns", "productivity metrics"]
    }
  ],
  "recommendations": [
    {
      "id": "pomodoro_prescriptive_action_id",
      "type": "pomodoroOptimization|focusImprovement|cycleManagement|breakStrategy|timeBlocking|distractionControl",
      "title": "Pomodoro Technique Optimization",
      "description": "PRESCRIPTIVE ANALYTICS: Evidence-based recommendations to improve Pomodoro technique effectiveness",
      "actionable_advice": "Specific adjustments to Pomodoro cycle length, break duration, distraction management, or focus enhancement strategies. Include timing recommendations, environmental modifications, and technique adaptations.",
      "priority": 1-5,
      "confidence_score": 0.0-1.0,
      "reasons": ["focus pattern analysis", "productivity data", "attention span observations"]
    }
  ],
  "study_plan": {
    "id": "pomodoro_plan_${DateTime.now().millisecondsSinceEpoch}",
    "activities": [
      {
        "type": "pomodoro_technique",
        "description": "Optimized Pomodoro session based on performance analysis",
        "duration_minutes": 25-50,
        "priority": 1,
        "materials": ["specific concepts to focus on", "distraction management tools"]
      }
    ],
    "estimated_duration_minutes": 25-90,
    "focus_areas": {
      "cycle_optimization": "recommended cycle length adjustments",
      "break_strategy": "break management improvements",
      "focus_enhancement": "attention improvement techniques"
    },
    "objectives": ["improve focus consistency", "increase cycle completion rate", "enhance productivity"]
  }
}

POMODORO-SPECIFIC ANALYTICS REQUIREMENTS:

DESCRIPTIVE ANALYTICS (Focus on Pomodoro Elements):
1. Analyze focus score progression throughout work cycles
2. Examine cycle completion patterns and break adherence
3. Identify productivity trends and attention patterns
4. Evaluate note-taking engagement during work periods (study notes and reflections)
5. Assess overall Pomodoro technique effectiveness for focused learning

PRESCRIPTIVE ANALYTICS (Pomodoro Optimizations with Historical Context):
1. Recommend optimal cycle lengths based on current session + historical focus patterns
2. Suggest break strategies considering attention span trends over time
3. Compare current performance to historical averages and suggest improvements
4. Provide cycle scheduling recommendations based on best performing times
5. Suggest focus enhancement techniques considering long-term progress trends
6. Recommend technique changes if productivity is declining compared to history
7. Optimize session length based on historical cycle completion patterns

FOCUS PATTERN ANALYSIS:
- High focus (7-10): Recommend maintaining or extending cycles
- Medium focus (4-6): Suggest moderate adjustments and distraction reduction
- Low focus (1-3): Recommend shorter cycles and environment optimization

PRODUCTIVITY OPTIMIZATION:
- High completion rate (>80%): Consider cycle extension or advanced techniques
- Medium completion rate (50-80%): Focus on consistency and minor adjustments
- Low completion rate (<50%): Recommend cycle shortening and motivation strategies

Return ONLY the JSON response, no other text.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;
      
      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from Gemini AI for Pomodoro analytics insights');
      }

      print('🍅 [GEMINI AI] Pomodoro analytics response received: ${responseText.substring(0, responseText.length.clamp(0, 300))}...');

      // Clean up the response to extract JSON
      String jsonText = responseText.trim();
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      }
      if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      jsonText = jsonText.trim();

      final Map<String, dynamic> aiResponse = jsonDecode(jsonText);
      
      // Convert AI response to our model objects
      return _processAIAnalyticsResponse(aiResponse);
      
    } catch (e) {
      print('❌ [GEMINI AI] Error generating Pomodoro analytics insights: $e');
      throw Exception('Failed to generate Pomodoro AI insights: $e');
    }
  }

  /// Generate study insights for a specific learning pattern
  Future<List<String>> generateLearningPatternAdvice(String patternType, Map<String, dynamic> contextData) async {
    try {
      final prompt = '''
As an educational expert, provide 3-5 specific, actionable study tips for a student with a "$patternType" learning pattern.

Context: ${jsonEncode(contextData)}

Focus on:
1. Techniques that work well for this learning pattern
2. Common pitfalls to avoid
3. Optimal study scheduling
4. Motivation and engagement strategies

Return a JSON array of strings with specific advice:
["tip 1", "tip 2", "tip 3", "tip 4", "tip 5"]
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;
      
      if (responseText == null || responseText.isEmpty) {
        return ['Continue with your current approach', 'Focus on consistent practice'];
      }

      // Clean and parse JSON
      String jsonText = responseText.trim();
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      }
      if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      jsonText = jsonText.trim();

      final List<dynamic> tips = jsonDecode(jsonText);
      return tips.cast<String>();
      
    } catch (e) {
      print('❌ [GEMINI AI] Error generating pattern advice: $e');
      return [
        'Continue practicing regularly',
        'Focus on your strong areas while improving weak ones',
        'Take breaks to maintain focus',
      ];
    }
  }

  /// Analyze a Feynman technique explanation using AI
  Future<Map<String, dynamic>> analyzeFeynmanExplanation(Map<String, dynamic> analysisData) async {
    try {
      print('🤖 [FEYNMAN AI] Analyzing explanation for topic: ${analysisData['topic']}');
      
      final prompt = '''
      Analyze this Feynman Technique explanation and provide detailed feedback:

      Topic: ${analysisData['topic']}
      Explanation Text: ${analysisData['explanation_text']}
      Attempt Number: ${analysisData['attempt_number']}
      Word Count: ${analysisData['word_count']}

      Please provide a comprehensive analysis in JSON format with the following structure:
      {
        "scores": {
          "clarity": 8.5,
          "completeness": 7.2,
          "conceptual_accuracy": 9.1,
          "overall": 8.3
        },
        "identified_gaps": ["concept1", "concept2"],
        "strengths": ["strength1", "strength2"],
        "improvement_areas": ["area1", "area2"],
        "feedback": [
          {
            "type": "clarity",
            "text": "The explanation is generally clear but could use more examples",
            "severity": "medium",
            "suggestion": "Add 1-2 concrete examples to illustrate the concept",
            "related_concepts": ["examples", "analogies"],
            "priority": 3
          }
        ],
        "study_suggestions": [
          {
            "type": "material_review",
            "title": "Review Core Concepts",
            "description": "Focus on understanding fundamental principles",
            "priority": 1,
            "duration_minutes": 20,
            "related_concepts": ["concept1", "concept2"],
            "suggested_materials": []
          }
        ]
      }

      Scoring Guidelines:
      - 10: Excellent, teaching-quality explanation
      - 8-9: Very good, minor improvements needed
      - 6-7: Good, some gaps or unclear areas
      - 4-5: Adequate, significant improvements needed
      - 1-3: Poor, major understanding gaps

      Focus on evaluating:
      1. Clarity: Is the explanation easy to understand?
      2. Completeness: Does it cover all important aspects?
      3. Conceptual Accuracy: Are the concepts explained correctly?
      4. Teaching Quality: Could someone else learn from this explanation?

      Provide constructive, specific feedback that helps improve understanding.
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';
      
      // Parse JSON response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(responseText);
      if (jsonMatch != null) {
        final jsonString = jsonMatch.group(0)!;
        final analysis = json.decode(jsonString) as Map<String, dynamic>;
        
        print('✅ [FEYNMAN AI] Analysis completed with overall score: ${analysis['scores']?['overall'] ?? 'N/A'}');
        return analysis;
      } else {
        throw Exception('Could not parse AI response as JSON');
      }
      
    } catch (e) {
      print('❌ [FEYNMAN AI] Error analyzing explanation: $e');
      
      // Return fallback analysis
      return {
        'scores': {
          'clarity': 5.0,
          'completeness': 5.0,
          'conceptual_accuracy': 5.0,
          'overall': 5.0,
        },
        'identified_gaps': ['AI analysis failed'],
        'strengths': ['Completed explanation attempt'],
        'improvement_areas': ['Retry AI analysis'],
        'feedback': [
          {
            'type': 'overall',
            'text': 'AI analysis failed, but your effort in explaining is valuable',
            'severity': 'low',
            'suggestion': 'Continue practicing explanations',
            'related_concepts': [],
            'priority': 1,
          }
        ],
        'study_suggestions': [
          {
            'type': 'material_review',
            'title': 'Continue Learning',
            'description': 'Keep practicing the Feynman technique',
            'priority': 1,
            'duration_minutes': 15,
            'related_concepts': [],
            'suggested_materials': [],
          }
        ],
      };
    }
  }

  /// Generate comprehensive analytics insights for Feynman sessions
  Future<Map<String, dynamic>> generateFeynmanAnalyticsInsights(Map<String, dynamic> analyticsData) async {
    try {
      print('🧠 [FEYNMAN ANALYTICS AI] Generating insights for session analytics...');
      
      final sessionData = analyticsData['session_data'] ?? {};
      final explanationAnalysis = analyticsData['explanation_analysis'] ?? {};
      final performance = analyticsData['performance'] ?? {};
      final behavior = analyticsData['behavior'] ?? {};
      final cognitive = analyticsData['cognitive'] ?? {};
      final feedbackAnalysis = analyticsData['feedback_analysis'] ?? {};
      final historicalContext = analyticsData['historical_context'] ?? {};

      final prompt = '''
      Analyze this comprehensive Feynman Technique study session data and generate personalized insights and recommendations:

      COURSE & MODULE:
      Course: ${analyticsData['course']?.toString() ?? 'Unknown'}
      Module: ${analyticsData['module']?.toString() ?? 'Unknown'}

      SESSION DATA:
      Topic: ${sessionData['topic']?.toString() ?? 'Unknown'}
      Total Explanations: ${sessionData['total_explanations']?.toString() ?? '0'}
      Session Duration: ${sessionData['session_duration_minutes']?.toString() ?? '0'} minutes
      Explanation Types: ${sessionData['explanation_types']?.toString() ?? '[]'}

      EXPLANATION ANALYSIS:
      Average Overall Score: ${explanationAnalysis['average_overall_score']?.toStringAsFixed(1) ?? 'N/A'}/10
      Average Clarity Score: ${explanationAnalysis['average_clarity_score']?.toStringAsFixed(1) ?? 'N/A'}/10
      Average Completeness Score: ${explanationAnalysis['average_completeness_score']?.toStringAsFixed(1) ?? 'N/A'}/10
      Improvement Trend: ${explanationAnalysis['improvement_trend']?.toStringAsFixed(2) ?? 'N/A'}
      Average Word Count: ${explanationAnalysis['average_word_count']?.round() ?? 0}

      PERFORMANCE METRICS:
      Overall Improvement: ${performance['overall_improvement']?.toStringAsFixed(1) ?? 'N/A'}%
      Pattern Type: ${performance['pattern_type']?.toString() ?? 'Unknown'}
      Strong Concepts: ${performance['strong_concepts']?.toString() ?? '[]'}
      Weak Concepts: ${performance['weak_concepts']?.toString() ?? '[]'}

      BEHAVIOR ANALYSIS:
      Persistence Score: ${behavior['persistence_score']?.toStringAsFixed(0) ?? 'N/A'}%
      Engagement Level: ${behavior['engagement_level']?.toStringAsFixed(0) ?? 'N/A'}%
      Study Time: ${behavior['total_study_minutes']?.toString() ?? '0'} minutes
      Common Challenges: ${behavior['common_challenges']?.toString() ?? '[]'}

      COGNITIVE ANALYSIS:
      Cognitive Load: ${cognitive['cognitive_load']?.toStringAsFixed(0) ?? 'N/A'}%
      Processing Speed: ${cognitive['processing_speed']?.toStringAsFixed(0) ?? 'N/A'}%
      Attention Span: ${cognitive['attention_span']?.toStringAsFixed(0) ?? 'N/A'}%
      Strengths: ${cognitive['strengths']?.toString() ?? '[]'}
      Weaknesses: ${cognitive['weaknesses']?.toString() ?? '[]'}

      FEEDBACK ANALYSIS:
      Total Feedback Items: ${feedbackAnalysis['total_feedback']?.toString() ?? '0'}
      Critical Issues: ${feedbackAnalysis['critical_issues']?.toString() ?? '0'}
      High Priority Items: ${feedbackAnalysis['high_priority_items']?.toString() ?? '0'}
      Feedback Categories: ${feedbackAnalysis['feedback_categories']?.toString() ?? '[]'}

      HISTORICAL CONTEXT:
      Total Module Sessions: ${historicalContext['total_module_sessions']?.toString() ?? '0'}
      Total Module Explanations: ${historicalContext['total_module_explanations']?.toString() ?? '0'}
      Historical Average Score: ${historicalContext['historical_avg_score']?.toStringAsFixed(1) ?? 'N/A'}/10
      Improvement Trend: ${historicalContext['improvement_trend']?.toString() ?? 'stable'}
      Strong Concepts (History): ${historicalContext['strong_concepts_history']?.toString() ?? '[]'}
      Struggling Concepts (History): ${historicalContext['struggling_concepts_history']?.toString() ?? '[]'}
      Best Topic: ${historicalContext['best_topic']?.toString() ?? 'Unknown'}
      Sessions by Topic: ${historicalContext['sessions_by_topic']?.toString() ?? '{}'}

      Based on this comprehensive analysis, provide insights and recommendations in JSON format:
      {
        "recommendations": [
          {
            "id": "feynman_rec_1",
            "type": "studyMethods",
            "title": "Improve Explanation Quality",
            "description": "Focus on enhancing your teaching-style explanations",
            "actionableAdvice": "Specific advice based on the analysis",
            "priority": 1,
            "confidenceScore": 0.9,
            "reasons": ["Performance data analysis", "Learning pattern recognition"]
          }
        ],
        "insights": [
          {
            "id": "feynman_insight_1",
            "category": "performance",
            "title": "Explanation Effectiveness",
            "insight": "Detailed insight based on the analysis",
            "significance": 0.8,
            "supportingData": ["Data point 1", "Data point 2"]
          }
        ],
        "studyPlan": {
          "id": "feynman_plan",
          "activities": [
            {
              "type": "concept_refinement",
              "description": "Specific activity based on analysis",
              "duration": {"minutes": 25},
              "priority": 1,
              "materials": ["material1", "material2"]
            }
          ],
          "estimatedDuration": {"minutes": 45},
          "focusAreas": {
            "explanation_clarity": "Improve",
            "concept_depth": "Maintain",
            "teaching_quality": "Enhance"
          },
          "objectives": ["Objective 1", "Objective 2"]
        }
      }

      IMPORTANT GUIDELINES:
      1. Be specific and actionable in recommendations
      2. Reference actual data points in insights
      3. Consider both current session and historical context
      4. Focus on the unique aspects of Feynman technique (teaching-to-learn)
      5. Provide constructive feedback that builds confidence
      6. Suggest concrete next steps for improvement
      7. Balance strengths recognition with areas for growth
      8. Consider the progression and learning velocity
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';
      
      // Parse JSON response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(responseText);
      if (jsonMatch != null) {
        final jsonString = jsonMatch.group(0)!;
        final insights = json.decode(jsonString) as Map<String, dynamic>;
        
        // Validate and clean AI-generated data before parsing
        final cleanedInsights = _validateAndCleanAnalyticsResponse(insights);

        // Convert the parsed data to proper model objects
        final recommendations = (cleanedInsights['recommendations'] as List? ?? [])
            .map((rec) => PersonalizedRecommendation.fromJson(rec))
            .toList();
            
        final analyticsInsights = (cleanedInsights['insights'] as List? ?? [])
            .map((insight) => AnalyticsInsight.fromJson(insight))
            .toList();
            
        final studyPlanData = cleanedInsights['studyPlan'] as Map<String, dynamic>? ?? {};
        final studyPlan = StudyPlan.fromJson(studyPlanData);
        
        print('✅ [FEYNMAN ANALYTICS AI] Generated ${recommendations.length} recommendations and ${analyticsInsights.length} insights');
        
        return {
          'recommendations': recommendations,
          'insights': analyticsInsights,
          'studyPlan': studyPlan,
        };
      } else {
        throw Exception('Could not parse AI response as JSON');
      }
      
    } catch (e) {
      print('❌ [FEYNMAN ANALYTICS AI] Error generating insights: $e');
      
      // Return fallback insights
      return _generateFallbackFeynmanInsights(analyticsData);
    }
  }

  /// Generate fallback insights when AI fails
  Map<String, dynamic> _generateFallbackFeynmanInsights(Map<String, dynamic> analyticsData) {
    final explanationAnalysis = analyticsData['explanation_analysis'] ?? {};
    final avgScore = explanationAnalysis['average_overall_score'] ?? 0.0;
    final sessionData = analyticsData['session_data'] ?? {};
    
    final recommendations = [
      PersonalizedRecommendation(
        id: 'fallback_feynman_rec_1',
        type: RecommendationType.studyMethods,
        title: 'Continue Feynman Practice',
        description: 'Based on your explanation attempts, continue developing your teaching approach.',
        actionableAdvice: avgScore >= 7.0 
            ? 'Excellent explanations! Challenge yourself with more complex topics.'
            : avgScore >= 5.0 
                ? 'Good progress! Focus on adding examples and simplifying complex ideas.'
                : 'Practice breaking down concepts into smaller, teachable parts.',
        priority: 1,
        confidenceScore: 0.8,
        reasons: ['Explanation quality assessment', 'Learning behavior analysis'],
      ),
      PersonalizedRecommendation(
        id: 'fallback_feynman_rec_2',
        type: RecommendationType.studyTiming,
        title: 'Optimize Explanation Sessions',
        description: 'Improve your Feynman technique timing and approach.',
        actionableAdvice: 'Spend 15-20 minutes per explanation attempt and review feedback carefully.',
        priority: 2,
        confidenceScore: 0.7,
        reasons: ['Session duration analysis', 'Feedback patterns'],
      ),
    ];

    final insights = [
      AnalyticsInsight(
        id: 'fallback_feynman_insight_1',
        category: InsightCategory.performance,
        title: 'Explanation Quality Assessment',
        insight: 'Your explanation attempts show ${avgScore >= 6.0 ? 'good' : 'developing'} understanding of the topic.',
        significance: 0.9,
        supportingData: [
          'Average explanation score: ${avgScore.toStringAsFixed(1)}/10',
          'Total attempts: ${sessionData['total_explanations'] ?? 0}',
          'Session duration: ${sessionData['session_duration_minutes'] ?? 0} minutes',
        ],
      ),
      AnalyticsInsight(
        id: 'fallback_feynman_insight_2',
        category: InsightCategory.behavior,
        title: 'Learning Approach',
        insight: 'You engaged with the Feynman technique by attempting to teach the concept.',
        significance: 0.7,
        supportingData: [
          'Teaching-to-learn approach demonstrated',
          'Active explanation attempts completed',
        ],
      ),
    ];

    final studyPlan = StudyPlan(
      id: 'fallback_feynman_plan',
      activities: [
        StudyActivity(
          type: 'concept_review',
          description: avgScore < 6.0 
              ? 'Review fundamental concepts and practice simple explanations'
              : 'Expand explanations with examples and real-world applications',
          duration: const Duration(minutes: 25),
          priority: 1,
          materials: ['Study materials', 'Core concepts'],
        ),
        StudyActivity(
          type: 'explanation_practice',
          description: 'Practice explaining the topic using different approaches',
          duration: const Duration(minutes: 20),
          priority: 2,
          materials: [sessionData['topic'] ?? 'Current topic'],
        ),
      ],
      estimatedDuration: const Duration(minutes: 45),
      focusAreas: {
        'explanation_quality': avgScore < 6.0 ? 'Improve' : 'Maintain',
        'concept_understanding': 'Continue developing',
        'teaching_approach': 'Refine',
      },
      objectives: [
        if (avgScore < 6.0) 'Strengthen conceptual understanding',
        'Improve explanation clarity',
        'Develop teaching-style communication',
        'Practice iterative explanation refinement',
      ],
    );

    return {
      'recommendations': recommendations,
      'insights': insights,
      'studyPlan': studyPlan,
    };
  }

  Future<bool> testConnection() async {
    try {
      final response = await _model.generateContent([
        Content.text('Respond with "Connection successful" if you can read this message.')
      ]);
      
      final responseText = response.text?.toLowerCase() ?? '';
      return responseText.contains('connection successful');
    } catch (e) {
      print('❌ [GEMINI AI] Connection test failed: $e');
      return false;
    }
  }

  /// Validates and cleans AI-generated analytics response to prevent enum errors
  Map<String, dynamic> _validateAndCleanAnalyticsResponse(Map<String, dynamic> response) {
    final cleaned = Map<String, dynamic>.from(response);
    
    // Valid enum values for validation
    final validInsightCategories = ['performance', 'behavior', 'cognitive', 'temporal', 'material', 'contentFocus', 'contentMastery', 'depth'];
    final validRecommendationTypes = ['studyTiming', 'materialFocus', 'studyTechnique', 'practiceFrequency', 'difficultyAdjustment', 'conceptReinforcement', 'studyMethods', 'pomodoroOptimization', 'focusImprovement', 'cycleManagement', 'breakStrategy', 'timeBlocking', 'distractionControl'];
    final validFeedbackTypes = ['clarity', 'completeness', 'accuracy', 'simplification', 'examples', 'overall', 'depth'];
    final validSuggestionTypes = ['material_review', 'concept_practice', 'active_recall', 'retrieval_practice', 'additional_reading', 'video_content', 'examples_practice', 'concept_application'];
    
    // Mapping for invalid enum values to valid ones
    final insightCategoryMapping = {
      'efficiency': 'performance',
      'strengths': 'performance', 
      'learningPatterns': 'behavior',
    };
    
    final recommendationTypeMapping = {
      'contentFocus': 'materialFocus',
      'studyTechniques': 'studyTechnique',
      'knowledgeConsolidation': 'conceptReinforcement',
      'timeManagement': 'studyTiming',
    };
    
    final suggestionTypeMapping = {
      'term_definition': 'concept_practice',
    };
    
    // Clean insights
    if (cleaned['insights'] is List) {
      final insights = cleaned['insights'] as List;
      for (var insight in insights) {
        if (insight is Map<String, dynamic>) {
          // Validate and fix category
          if (insight.containsKey('category')) {
            final category = insight['category']?.toString();
            if (category != null) {
              if (!validInsightCategories.contains(category)) {
                // Try to map to a valid category first
                final mappedCategory = insightCategoryMapping[category] ?? 'performance';
                print('! [FEYNMAN] Unknown insight category: $category, mapping to $mappedCategory');
                insight['category'] = mappedCategory;
              }
            }
          }
        }
      }
    }
    
    // Clean recommendations
    if (cleaned['recommendations'] is List) {
      final recommendations = cleaned['recommendations'] as List;
      for (var rec in recommendations) {
        if (rec is Map<String, dynamic>) {
          // Validate and fix type
          if (rec.containsKey('type')) {
            final type = rec['type']?.toString();
            if (type != null) {
              if (!validRecommendationTypes.contains(type)) {
                // Try to map to a valid type first
                final mappedType = recommendationTypeMapping[type] ?? 'studyMethods';
                print('! [FEYNMAN] Unknown recommendation type: $type, mapping to $mappedType');
                rec['type'] = mappedType;
              }
            }
          }
        }
      }
    }
    
    // Clean study plan suggestions if present
    if (cleaned['studyPlan'] is Map<String, dynamic>) {
      final studyPlan = cleaned['studyPlan'] as Map<String, dynamic>;
      if (studyPlan['activities'] is List) {
        final activities = studyPlan['activities'] as List;
        for (var activity in activities) {
          if (activity is Map<String, dynamic> && activity.containsKey('type')) {
            final type = activity['type']?.toString();
            if (type != null) {
              if (!validSuggestionTypes.contains(type)) {
                // Try to map to a valid type first
                final mappedType = suggestionTypeMapping[type] ?? 'material_review';
                print('! [FEYNMAN] Unknown suggestion type: $type, mapping to $mappedType');
                activity['type'] = mappedType;
              }
            }
          }
        }
      }
    }
    
    return cleaned;
  }
}