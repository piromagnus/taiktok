import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import '../models/paper.dart';
import '../services/prompt.dart';
import 'package:xml/xml.dart' as xml;

class PaperService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _geminiApiKey;
  final papersCollectionName = "papersv3";
  String _model = 'gemini-2.0-flash-lite';

  PaperService(this._geminiApiKey, {String model = 'gemini-2.0-flash-lite'}) {
    _model = model;
  }

  // Get only paper IDs and embeddings without full data for faster loading
  Future<Map<String, List<double>>> getAllPaperIdsWithEmbeddings() async {
    try {
      final Map<String, List<double>> result = {};

      final querySnapshot = await _firestore
          .collection(papersCollectionName)
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['embedding'] != null) {
          final List<dynamic> rawEmbedding = data['embedding'];
          final List<double> embedding = rawEmbedding.cast<double>();
          result[doc.id] = embedding;
        }
      }

      return result;
    } catch (e) {
      print('Error fetching paper IDs with embeddings: $e');
      return {};
    }
  }

  //updateModel
  void updateModel(String model) {
    _model = model;
  }

  // Get paper with only category information for filtering
  Future<Paper> getPaperCategory(String arxivId) async {
    try {
      final doc =
          await _firestore.collection(papersCollectionName).doc(arxivId).get();
      if (!doc.exists) {
        return Paper(
          title: '',
          authors: [],
          abstract: '',
          publishDate: '',
          arxivId: arxivId,
          category: '',
          arxivUrl: '',
        );
      }

      // Only extract minimal information needed for filtering
      final data = doc.data() as Map<String, dynamic>;
      return Paper(
        arxivId: arxivId,
        title: data['title'] ?? '',
        authors: [], // Not needed for filtering
        abstract: '', // Not needed for filtering
        publishDate: '',
        category: data['category'] ?? '',
        arxivUrl: '',
      );
    } catch (e) {
      print('Error getting paper category: $e');
      return Paper(
        title: '',
        authors: [],
        abstract: '',
        publishDate: '',
        arxivId: arxivId,
        category: '',
        arxivUrl: '',
      );
    }
  }

  // New method to get all papers with embeddings from Firestore
  Future<List<Paper>> getAllPapersWithEmbeddings({int limit = 1000}) async {
    try {
      final List<Paper> papers = [];

      final paperDocs = await _firestore
          .collection(papersCollectionName)
          .orderBy('createdAt', descending: true)
          // .limit(limit)
          .get();

      // check that is contains embedding and update if not
      for (var doc in paperDocs.docs) {
        final paper = Paper.fromMap(doc.data());
        if (paper.embedding.isEmpty) {
          paper.embedding = await generateEmbedding(paper.abstract);

          await savePaper(paper);
        }
        papers.add(paper);
      }

      return papers;
    } catch (e) {
      print('Error fetching papers with embeddings: $e');
      return [];
    }
  }

  Future<List<double>> generateEmbedding(String text) async {
    if (_geminiApiKey.isEmpty) return [];

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=$_geminiApiKey',
    );

    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'model': 'models/text-embedding-004',
      'content': {
        'parts': [
          {'text': text}
        ]
      }
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      // print(response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<double>.from(data['embedding']['values']);
      }
    } catch (e) {
      print('Error generating embedding: $e');
    }
    return [];
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    normA = sqrt(normA);
    normB = sqrt(normB);

    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (normA * normB);
  }

  // Comprehensive method to enrich paper metadata
  Future<Paper> enrichPaperMetadata(Paper paper) async {
    if (_geminiApiKey.isEmpty) {
      print('Gemini API key is empty');
      return paper;
    }

    try {
      // Handle embedding separately since it's a different type
      if (paper.embedding.isEmpty) {
        paper.embedding = await generateEmbedding(paper.abstract);
      }

      // Define metadata fields to check and update
      final fieldsToCheck = [
        if (paper.contributions.isEmpty) 'contributions',
        if (paper.tags.isEmpty) 'tags',
        if (paper.problemSolved.isEmpty) 'problem',
        if (paper.taskType.isEmpty) 'task_type',
      ];

      if (fieldsToCheck.isEmpty) return paper;

      // Get all needed responses in one batch
      final responses = await Future.wait(fieldsToCheck.map((field) =>
          _getGeminiAnalysis(
              formatPrompt(field, paper.abstract), _geminiApiKey)));
      // print(responses);
      // Map to store response index for each field
      final fieldIndices = Map.fromEntries(
          fieldsToCheck.asMap().entries.map((e) => MapEntry(e.value, e.key)));

      final contributions = responses[fieldIndices['contributions']!]
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final tags = responses[fieldIndices['tags']!]
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final problemSolved = responses[fieldIndices['problem']!];
      final taskType = responses[fieldIndices['task_type']!];

      print(contributions);
      print(tags);
      print(problemSolved);
      print(taskType);

      final updatedPaper = Paper(
        title: paper.title,
        authors: paper.authors,
        abstract: paper.abstract,
        publishDate: paper.publishDate,
        arxivId: paper.arxivId,
        arxivUrl: paper.arxivUrl,
        embedding: paper.embedding,
        category: paper.category,
        contributions: paper.contributions.isEmpty
            ? responses[fieldIndices['contributions']!]
                .split(';')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : paper.contributions,
        tags: paper.tags.isEmpty
            ? responses[fieldIndices['tags']!]
                .split(';')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : paper.tags,
        problemSolved: paper.problemSolved.isEmpty
            ? responses[fieldIndices['problem']!]
            : paper.problemSolved,
        taskType: paper.taskType.isEmpty
            ? responses[fieldIndices['task_type']!]
            : paper.taskType,
      );

      // print('Updated paper metadata: ${updatedPaper.toMap()}');

      await savePaper(updatedPaper);

      print('Paper metadata saved successfully.');
      return updatedPaper;
    } catch (e) {
      print('Error updating paper metadata: $e');
      return paper;
    }
  }

  Future<List<Paper>> fetchArxivPapers(
    String searchQuery,
    String category,
    int startIndex,
    int limit,
  ) async {
    final queryString = 'cat:$category+AND+all:$searchQuery';
    final url = Uri.parse(
      'http://export.arxiv.org/api/query?search_query=$queryString&start=$startIndex&max_results=$limit&sortBy=submittedDate&sortOrder=descending',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch papers from arXiv');
      }
      final xmlData = xml.XmlDocument.parse(response.body);
      final entries = xmlData.findAllElements('entry');
      return entries.map((entry) => Paper.fromArxiv(entry)).toList();
    } catch (e) {
      print('Error fetching from arXiv: $e');
      return [];
    }
  }

  // Future<List<MapEntry<Paper, double>>> getFirestorePapers(
  //   List<double> queryEmbedding,
  //   List<String> readPapers, {
  //   double threshold = 0.4,
  //   int limit = 100,
  // }) async {
  //   if (queryEmbedding.isEmpty) return [];

  //   final papers = await _firestore
  //       .collection(papersCollectionName)
  //       .orderBy('createdAt', descending: true)
  //       .limit(limit)
  //       .get();

  //   final List<MapEntry<Paper, double>> scoredPapers = [];

  //   for (var doc in papers.docs) {
  //     if (readPapers.contains(doc.id)) continue;

  //     Paper paper = Paper.fromMap(doc.data());
  //     await _checkAndUpdatePaperMetadata(paper);

  //     try {
  //       final similarity = cosineSimilarity(queryEmbedding, paper.embedding);
  //       if (similarity > threshold) {
  //         scoredPapers.add(MapEntry(paper, similarity));
  //       }
  //     } catch (e) {
  //       print('Error calculating similarity for paper ${paper.arxivId}: $e');
  //       continue;
  //     }
  //   }

  //   scoredPapers.sort((a, b) => b.value.compareTo(a.value));
  //   return scoredPapers;
  // }

  // Future<void> _checkAndUpdatePaperMetadata(Paper paper) async {
  //   if (!paper.embedding.isEmpty &&
  //       !paper.contributions.isEmpty &&
  //       !paper.tags.isEmpty &&
  //       !paper.problemSolved.isEmpty &&
  //       !paper.taskType.isEmpty) {
  //     return;
  //   }

  //   try {
  //     // Handle embedding separately since it's a different type
  //     paper.embedding = paper.embedding.isEmpty
  //         ? await generateEmbedding(paper.abstract)
  //         : paper.embedding;

  //     // Define metadata fields to check and update
  //     final fieldsToCheck = [
  //       if (paper.contributions.isEmpty) 'contributions',
  //       if (paper.tags.isEmpty) 'tags',
  //       if (paper.problemSolved.isEmpty) 'problem',
  //       if (paper.taskType.isEmpty) 'task_type',
  //     ];

  //     if (fieldsToCheck.isEmpty) return;

  //     // Get all needed responses in one batch
  //     final responses = await Future.wait(fieldsToCheck.map((field) =>
  //         _getGeminiAnalysis(
  //             formatPrompt(field, paper.abstract), _geminiApiKey)));

  //     // Map to store response index for each field
  //     final fieldIndices = Map.fromEntries(
  //         fieldsToCheck.asMap().entries.map((e) => MapEntry(e.value, e.key)));

  //     final updatedPaper = Paper(
  //       title: paper.title,
  //       authors: paper.authors,
  //       abstract: paper.abstract,
  //       publishDate: paper.publishDate,
  //       arxivId: paper.arxivId,
  //       arxivUrl: paper.arxivUrl,
  //       category: paper.category,
  //       embedding: paper.embedding,
  //       contributions: paper.contributions.isEmpty
  //           ? responses[fieldIndices['contributions']!]
  //               .split(';')
  //               .map((e) => e.trim())
  //               .where((e) => e.isNotEmpty)
  //               .toList()
  //           : paper.contributions,
  //       tags: paper.tags.isEmpty
  //           ? responses[fieldIndices['tags']!]
  //               .split(';')
  //               .map((e) => e.trim())
  //               .where((e) => e.isNotEmpty)
  //               .toList()
  //           : paper.tags,
  //       problemSolved: paper.problemSolved.isEmpty
  //           ? responses[fieldIndices['problem']!]
  //           : paper.problemSolved,
  //       taskType: paper.taskType.isEmpty
  //           ? responses[fieldIndices['task_type']!]
  //           : paper.taskType,
  //     );

  //     await savePaper(updatedPaper);
  //   } catch (e) {
  //     print('Error updating paper metadata: $e');
  //   }
  // }

  // Future<List<MapEntry<Paper, double>>> fetchMorePapers(
  //   String query,
  //   List<double> queryEmbedding,
  //   List<String> readPapers,
  //   String category,
  //   int startIndex,
  //   int limit, {
  //   double threshold = 0.4,
  // }) async {
  //   // First try to get papers from Firestore
  //   final firestorePapers = await getFirestorePapers(queryEmbedding, readPapers,
  //       threshold: threshold);

  //   // If we don't have enough papers, fetch from arXiv
  //   final neededPapers = limit - firestorePapers.length;
  //   if (neededPapers <= 0) return firestorePapers;
  //   final arxivPapers =
  //       await fetchArxivPapers(query, category, startIndex, neededPapers);

  //   final List<MapEntry<Paper, double>> newPapers = [];

  //   for (var paper in arxivPapers) {
  //     if (readPapers.contains(paper.arxivId)) continue;
  //     if (!await paperExists(paper.arxivId)) {
  //       paper.embedding = await generateEmbedding(paper.abstract);
  //       await _checkAndUpdatePaperMetadata(paper);

  //       final similarity = cosineSimilarity(queryEmbedding, paper.embedding);
  //       if (similarity > threshold) {
  //         newPapers.add(MapEntry(paper, similarity));
  //       }
  //     }
  //   }

  //   final allPapers = [...firestorePapers, ...newPapers];
  //   allPapers.sort((a, b) => b.value.compareTo(a.value));
  //   return allPapers.take(limit).toList();
  // }

  Future<void> savePaper(Paper paper) async {
    // Generate embedding if not already present
    if (paper.embedding.isEmpty) {
      paper.embedding = await generateEmbedding(paper.abstract);
    }

    print('Saving paper function ${paper.arxivId}');
    print(paper.contributions);
    print(paper.tags);
    // print(paper.toMap());
    await _firestore
        .collection(papersCollectionName)
        .doc(paper.arxivId)
        .set(paper.toMap());
  }

  Future<Paper> getPaper(String arxivId) async {
    final doc =
        await _firestore.collection(papersCollectionName).doc(arxivId).get();
    if (!doc.exists) {
      return Paper(
        title: '',
        authors: [],
        abstract: '',
        publishDate: '',
        arxivId: '',
        tags: [],
        arxivUrl: '',
      ); // Return a default Paper object if not found
    }
    final data = doc.data() as Map<String, dynamic>;
    return Paper.fromMap(data);
  }

  Future<void> updatePaperContributions(
      String arxivId, List<String> contributions) async {
    await _firestore.collection(papersCollectionName).doc(arxivId).update({
      'contributions': contributions,
    });
  }

  Future<void> updatePaperTags(String arxivId, List<String> tags) async {
    await _firestore.collection(papersCollectionName).doc(arxivId).update({
      'tags': tags,
    });
  }

  Future<void> updatePaperProblem(String arxivId, String problemSolved) async {
    await _firestore.collection(papersCollectionName).doc(arxivId).update({
      'problemSolved': problemSolved,
    });
  }

  Future<void> updatePaperTaskType(String arxivId, String taskType) async {
    await _firestore.collection(papersCollectionName).doc(arxivId).update({
      'taskType': taskType,
    });
  }

  Future<void> updatePaperCategory(String arxivId, String category) async {
    await _firestore.collection(papersCollectionName).doc(arxivId).update({
      'category': category,
    });
  }

  Future<List<MapEntry<Paper, double>>> getRankedPapers(
      List<double> queryEmbedding,
      {double threshold = 0.4,
      int limit = 1000}) async {
    // print(queryEmbedding);
    if (queryEmbedding.isEmpty) return [];

    final papers = await _firestore
        .collection(papersCollectionName)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    // print(papers);

    final List<MapEntry<Paper, double>> scoredPapers = [];

    for (var doc in papers.docs) {
      final paper = Paper.fromMap(doc.data());
      if (paper.embedding.isEmpty) {
        // Generate embedding if not already present
        paper.embedding = await generateEmbedding(paper.abstract);
        await savePaper(paper);
      }

      try {
        final similarity = cosineSimilarity(queryEmbedding, paper.embedding);
        if (similarity > threshold) {
          scoredPapers.add(MapEntry(paper, similarity));
        }
      } catch (e) {
        print('Error calculating similarity for paper ${paper.arxivId}: $e');
        continue;
      }
    }

    scoredPapers.sort((a, b) => b.value.compareTo(a.value));
    return scoredPapers.toList();
  }

  Future<bool> paperExists(String arxivId) async {
    final doc =
        await _firestore.collection(papersCollectionName).doc(arxivId).get();
    return doc.exists;
  }

  Future<List<MapEntry<Paper, double>>> fetchPapers(
    String query,
    List<double> queryEmbedding,
    String apiKey,
    String model,
    double threshold,
    String category,
    int startIndex,
    int limit,
  ) async {
    // First, try to find similar papers in the database
    // final List<MapEntry<Paper, double>> similarPapers = [];
    final similarPapers =
        await getRankedPapers(queryEmbedding, threshold: threshold, limit: 100);
    print('Found ${similarPapers.length} similar papers in the database');
    // If we don't have enough papers, fetch from arXiv

    if (similarPapers.length < limit) {
      final neededPapers = limit - similarPapers.length;
      final arxivPapers =
          await _fetchFromArxiv(query, category, startIndex, neededPapers);

      for (var paper in arxivPapers) {
        if (!await paperExists(paper.arxivId)) {
          // Generate Gemini analysis and embedding
          await _analyzeAndEnrichPaper(paper, apiKey);

          if (paper.embedding.isNotEmpty) {
            final similarity =
                cosineSimilarity(queryEmbedding, paper.embedding);
            similarPapers.add(MapEntry(paper, similarity));
          } else {
            // generate embedding
            paper.embedding = await generateEmbedding(paper.abstract);
            await savePaper(paper);
            final similarity =
                cosineSimilarity(queryEmbedding, paper.embedding);
            similarPapers.add(MapEntry(paper, similarity));
          }
        }
      }
    }

    // Sort by similarity and return top results
    similarPapers.sort((a, b) => b.value.compareTo(a.value));
    return similarPapers.take(limit).toList();
  }

  Future<List<Paper>> _fetchFromArxiv(
      String searchQuery, String category, int startIndex, int limit) async {
    final queryString =
        'cat:$category+AND+all:$searchQuery'; // Fixed variable naming
    final url = Uri.parse(
      'http://export.arxiv.org/api/query?search_query=$queryString&start=$startIndex&max_results=$limit&sortBy=submittedDate&sortOrder=descending',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch papers from arXiv');
      }
      //use Paper.fromArxiv()
      final xmlData = xml.XmlDocument.parse(response.body);
      final entries = xmlData.findAllElements('entry');
      return entries.map((entry) => Paper.fromArxiv(entry)).toList();
    } catch (e) {
      print('Error fetching from arXiv: $e');
      return [];
    }
  }

  Future<void> _analyzeAndEnrichPaper(Paper paper, String apiKey) async {
    if (apiKey.isEmpty) return;

    try {
      final responses = await Future.wait([
        _getGeminiAnalysis(
            formatPrompt('contributions', paper.abstract), apiKey),
        _getGeminiAnalysis(formatPrompt('tags', paper.abstract), apiKey),
        _getGeminiAnalysis(formatPrompt('problem', paper.abstract), apiKey),
        _getGeminiAnalysis(formatPrompt('task_type', paper.abstract), apiKey),
      ]);

      // Create a new Paper instance with updated values since fields are final
      final updatedPaper = Paper(
        title: paper.title,
        authors: paper.authors,
        abstract: paper.abstract,
        publishDate: paper.publishDate,
        arxivId: paper.arxivId,
        arxivUrl: paper.arxivUrl,
        category: paper.category,
        tags: responses[1]
            .split(';')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        contributions: responses[0]
            .split(';')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        problemSolved: responses[2],
        taskType: responses[3],
        embedding: await generateEmbedding(paper.abstract),
      );

      // Save the updated paper
      await savePaper(updatedPaper);
    } catch (e) {
      print('Error analyzing paper with Gemini: $e');
    }
  }

  Future<String> _getGeminiAnalysis(String prompt, String apiKey) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_geminiApiKey',
    );

    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': GeminiConfig.config,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      // print(response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // print(data);
        return data['candidates'][0]['content']['parts'][0]['text'] ?? '';
      } else {
        print('Error: Received status code ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting Gemini analysis: $e');
    }
    return '';
  }
}
