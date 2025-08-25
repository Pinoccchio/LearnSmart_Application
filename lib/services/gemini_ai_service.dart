import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/course_models.dart';
import '../models/active_recall_models.dart';
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
}