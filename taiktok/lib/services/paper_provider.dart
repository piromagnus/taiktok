import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../models/paper.dart';
import 'prompt.dart';
import '../utils.dart';

String initialQuery = 'mamba';
double initialThreshold = 0.5;
String initialCategory = 'cs.CV';
List<String> listModels = [
  'gemini-2.0-flash-lite',
  'gemini-2.0-flash-exp',
  'gemini-2.0-pro-exp-02-05',
];

class PaperProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _geminiApiKey;
  final String papersCollectionName = "papersv3";

  // Store paper IDs with their similarity scores
  final Map<String, double> _paperSimilarityMap = {};

  // Cache paper objects that have been fully loaded
  final Map<String, Paper> _paperCache = {};

  // Papers currently being displayed
  List<MapEntry<Paper, double>> _cachedPapers = [];

  bool _isLoading = false;
  String _error = '';

  String _customQuery = initialQuery;
  List<double> _queryEmbedding = [];
  double _threshold = initialThreshold;
  String _category = initialCategory;
  int _startIndex = 0;
  static const int _papersPerPage = 5;
  bool _hasMorePapers = true;
  String _model = 'gemini-2.0-flash-lite';
  // AppUser? _currentUser;

  // Getters
  bool get isLoading => _isLoading;
  String get error => _error;
  List<MapEntry<Paper, double>> get papers => _cachedPapers;
  bool get hasMorePapers => _hasMorePapers;
  String get model => _model;
  String get category => _category;
  double get threshold => _threshold;
  String get query => _customQuery;
  String get apiKey => _geminiApiKey;

  PaperProvider(this._geminiApiKey, {String model = 'gemini-2.0-flash-lite'}) {
    _model = model;
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPreferences();
    await _generateQueryEmbedding();
    await _loadAllPaperIds();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _customQuery = prefs.getString('customQuery') ?? initialQuery;
    _threshold = prefs.getDouble('threshold') ?? initialThreshold;
    _category = prefs.getString('category') ?? initialCategory;
    _model = prefs.getString('model') ?? 'gemini-2.0-flash-lite-preview-02-05';
  }

  // Get only paper IDs and embeddings without full data for faster loading
  Future<Map<String, List<double>>> getAllPaperIdsWithEmbeddings() async {
    try {
      final Map<String, List<double>> result = {};
      List<double> embedding;
      final querySnapshot = await _firestore
          .collection(papersCollectionName)
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['embedding'] != null) {
          final List<dynamic> rawEmbedding = data['embedding'];
          embedding = rawEmbedding.cast<double>();
        } else {
          // get the embedding
          embedding = await generateEmbedding(data['abstract']);

          await _firestore
              .collection(papersCollectionName)
              .doc(doc.id)
              .update({'embedding': embedding});
        }

        result[doc.id] = embedding;
      }
      return result;
    } catch (e) {
      print('Error fetching paper IDs with embeddings: $e');
      return {};
    }
  }

  Future<void> _generateQueryEmbedding() async {
    _queryEmbedding = await generateEmbedding(_customQuery);
  }

  // Step 1: Load only paper IDs and embeddings for faster initial loading
  Future<void> _loadAllPaperIds() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Get all paper IDs and embeddings from Firebase
      final allPaperIdsAndEmbeddings = await getAllPaperIdsWithEmbeddings();

      // Compute similarity for each paper
      _paperSimilarityMap.clear();
      for (final entry in allPaperIdsAndEmbeddings.entries) {
        final similarity = cosineSimilarity(_queryEmbedding, entry.value);
        _paperSimilarityMap[entry.key] = similarity;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _recomputeSimilarities() async {
    final allPaperIdsAndEmbeddings = await getAllPaperIdsWithEmbeddings();

    _paperSimilarityMap.clear();
    for (final entry in allPaperIdsAndEmbeddings.entries) {
      final similarity = cosineSimilarity(_queryEmbedding, entry.value);

      _paperSimilarityMap[entry.key] = similarity;
    }
  }

  // Step 2 & 3: Fetch papers with filtering and get full data only when needed
  Future<void> fetchPapers(List<String> readPapers) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Step 2: Filter out papers that the user has already read
      final filteredMap = Map<String, double>.from(_paperSimilarityMap);
      if (readPapers.isNotEmpty) {
        for (final paperId in readPapers) {
          filteredMap.remove(paperId);
        }
      }
      // Filter by category
      final sortedEntries = await _filterByCategory(filteredMap);

      //Filter with _threshold
      sortedEntries.removeWhere((entry) => entry.value < _threshold);

      // Sort by similarity
      sortedEntries.sort((a, b) => b.value.compareTo(a.value));

      print(
          'Filtered ${sortedEntries.length} papers by category and threshold');

      // Paginate results
      final paginatedEntries = sortedEntries.take(_papersPerPage).toList();
      print('Fetched ${paginatedEntries.length} papers from cache');

      // If we don't have enough papers from the cached map, fetch more from ArXiv
      if (paginatedEntries.length < _papersPerPage) {
        print('Fetching more papers from ArXiv...');
        final foundPapers = await _fetchMoreFromArxiv(paginatedEntries);
        paginatedEntries.addAll(foundPapers);
      }

      // Step 3: Load full paper data for display
      final paperResults = <MapEntry<Paper, double>>[];
      for (final entry in paginatedEntries) {
        Paper paper;

        // Check if paper is already in cache
        if (_paperCache.containsKey(entry.key)) {
          paper = _paperCache[entry.key]!;
        } else {
          // Get full paper data and ensure it has all metadata
          paper = await getPaper(entry.key);
          await _ensurePaperMetadata(paper);
          _paperCache[entry.key] = paper;
        }

        paperResults.add(MapEntry(paper, entry.value));
      }

      // Update the cached papers
      if (_startIndex == 0) {
        _cachedPapers = paperResults;
      } else {
        _cachedPapers.addAll(paperResults);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper method to ensure a paper has all required metadata
  Future<Paper> _ensurePaperMetadata(Paper paper) async {
    bool needsUpdate = paper.embedding.isEmpty ||
        paper.contributions.isEmpty ||
        paper.tags.isEmpty ||
        paper.problemSolved.isEmpty ||
        paper.taskType.isEmpty;
    print('Needs update: $needsUpdate');

    Paper updatePaper = paper;
    if (needsUpdate) {
      updatePaper = await enrichPaperMetadata(paper);
      _paperCache[paper.arxivId] = updatePaper;
      notifyListeners();
    }
    return updatePaper;
  }

  // Helper method to filter papers by category and sort by similarity
  Future<List<MapEntry<String, double>>> _filterByCategory(
      Map<String, double> paperMap) async {
    final result = <MapEntry<String, double>>[];

    for (final entry in paperMap.entries) {
      // Use cached paper if available, otherwise fetch minimal data to check category
      Paper? paper = _paperCache[entry.key];
      String category;
      if (paper == null) {
        category = await getPaperCategory(entry.key);
      } else {
        category = paper.category;
      }

      // Include paper if it matches the selected category
      if (category == _category) {
        result.add(entry);
      }
    }
    return result;
  }

  // Helper method to fetch more papers from ArXiv if needed
  Future<List<MapEntry<String, double>>> _fetchMoreFromArxiv(
      List<MapEntry<String, double>> currentEntries) async {
    final arxivStartIndex = _startIndex + currentEntries.length;
    final neededCount = _papersPerPage - currentEntries.length;

    // Request more papers than needed to have a better chance of finding relevant ones
    final extraFactor = 3; // Request 3x more papers than needed
    final requestCount = neededCount * extraFactor;

    // Create a temporary map to store papers and their similarity scores
    final Map<String, MapEntry<Paper, double>> tempPaperMap = {};

    final arxivPapers = await fetchArxivPapers(
        _customQuery, _category, arxivStartIndex, requestCount);
    print('Fetched ${arxivPapers.length} papers from ArXiv');

    // Process papers in batches to avoid overwhelming the API
    for (final paper in arxivPapers) {
      // Skip if already in our similarity map
      if (_paperSimilarityMap.containsKey(paper.arxivId)) {
        print(
            'Skipping ${paper.arxivId} as it is already in the similarity map');
        continue;
      }

      // Generate embedding and check similarity
      paper.embedding = await generateEmbedding(paper.abstract);
      final similarity = cosineSimilarity(_queryEmbedding, paper.embedding);

      // Store all papers above threshold in temporary map
      if (similarity >= _threshold) {
        tempPaperMap[paper.arxivId] = MapEntry(paper, similarity);
      }
    }
    print('Found ${tempPaperMap.length} new papers above threshold');

    // Sort papers by similarity and take only the needed count
    final sortedPapers = tempPaperMap.values.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final selectedPapers = sortedPapers.take(neededCount).toList();

    // Process the selected papers
    for (final entry in selectedPapers) {
      final paper = entry.key;
      final similarity = entry.value;

      // Ensure paper has all metadata before saving
      await _ensurePaperMetadata(paper);
      // await savePaper(paper);

      _paperSimilarityMap[paper.arxivId] = similarity;
      _paperCache[paper.arxivId] = paper;

      // Add to current entries
      currentEntries.add(MapEntry(paper.arxivId, similarity));
    }

    // Sort the entries by similarity
    currentEntries.sort((a, b) => b.value.compareTo(a.value));

    print('Updated current entries with ${currentEntries.length} papers.');
    return currentEntries;
  }

  // Fetch more papers when user scrolls
  Future<void> fetchMorePapers(List<String> readPapers) async {
    if (_isLoading) return;

    _startIndex += _papersPerPage;
    await fetchPapers(readPapers);
  }

  // Step 4: Remove read papers from the map
  void removeReadPaper(String paperId) {
    _paperSimilarityMap.remove(paperId);
    _paperCache.remove(paperId);
    _cachedPapers.removeWhere((entry) => entry.key.arxivId == paperId);
    notifyListeners();
  }

  Future<void> refreshPapers(List<String> readPapers) async {
    _startIndex = 0;

    _cachedPapers = [];
    _paperCache.clear();
    await _loadAllPaperIds();
    await fetchPapers(readPapers);
  }

  // Methods migrated from PaperService

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
      final responses = await Future.wait(fieldsToCheck.map(
          (field) => _getGeminiAnalysis(formatPrompt(field, paper.abstract))));

      // Map to store response index for each field
      final fieldIndices = Map.fromEntries(
          fieldsToCheck.asMap().entries.map((e) => MapEntry(e.value, e.key)));

      final updatedPaper = Paper(
        title: paper.title,
        authors: paper.authors,
        abstract: paper.abstract,
        publishDate: paper.publishDate,
        arxivId: paper.arxivId,
        arxivUrl: paper.arxivUrl,
        embedding: paper.embedding,
        category: paper.category,
        contributions: paper.contributions.isEmpty &&
                fieldIndices.containsKey('contributions')
            ? responses[fieldIndices['contributions']!]
                .split(';')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : paper.contributions,
        tags: paper.tags.isEmpty && fieldIndices.containsKey('tags')
            ? responses[fieldIndices['tags']!]
                .split(';')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : paper.tags,
        problemSolved:
            paper.problemSolved.isEmpty && fieldIndices.containsKey('problem')
                ? responses[fieldIndices['problem']!]
                : paper.problemSolved,
        taskType:
            paper.taskType.isEmpty && fieldIndices.containsKey('task_type')
                ? responses[fieldIndices['task_type']!]
                : paper.taskType,
      );

      await savePaper(updatedPaper);
      print('Paper metadata saved successfully.');
      return updatedPaper;
    } catch (e) {
      print('Error updating paper metadata: $e');
      return paper;
    }
  }

  // Interaction with Paper collection in Firestore

  Future<void> savePaper(Paper paper) async {
    // Generate embedding if not already present
    if (paper.embedding.isEmpty) {
      paper.embedding = await generateEmbedding(paper.abstract);
    }
    print('Saving paper ${paper.arxivId}');
    await _firestore
        .collection(papersCollectionName)
        .doc(paper.arxivId)
        .set(paper.toMap());
  }

  Future<Paper> getPaper(String arxivId) async {
    final doc =
        await _firestore.collection(papersCollectionName).doc(arxivId).get();

    if (!doc.exists) {
      throw Exception('Paper not found'); //TODO handle this better
    }
    final data = doc.data() as Map<String, dynamic>;
    return Paper.fromMap(data);
  }

  Future<String> getPaperCategory(String arxivId) async {
    try {
      final doc =
          await _firestore.collection(papersCollectionName).doc(arxivId).get();

      if (!doc.exists) {
        throw Exception('Paper not found'); //TODO handle this better
      }

      // Only extract minimal information needed for filtering
      final data = doc.data() as Map<String, dynamic>;
      return data['category'] ?? '';
    } catch (e) {
      print('Error getting paper category: $e');
      return '';
    }
  }

  Future<bool> paperExists(String arxivId) async {
    final doc =
        await _firestore.collection(papersCollectionName).doc(arxivId).get();
    return doc.exists;
  }

  // ArXiv API methods
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

  // Gemini API methods

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
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<double>.from(data['embedding']['values']);
      }
    } catch (e) {
      print('Error generating embedding: $e');
    }

    return [];
  }

  Future<String> _getGeminiAnalysis(String prompt) async {
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
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] ?? '';
      } else {
        print('Error: Received status code ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting Gemini analysis: $e');
    }

    return '';
  }

  // Methods for updating settings

  Future<void> updateQuery(String query) async {
    _customQuery = query;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customQuery', query);

    // Recompute the query embedding and similarities
    await _generateQueryEmbedding();
    await _recomputeSimilarities();
  }

  Future<void> updateThreshold(double threshold) async {
    _threshold = threshold;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('threshold', threshold);
  }

  Future<void> updateCategory(String category) async {
    _category = category;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('category', category);
  }

  Future<void> updateModel(String model) async {
    _model = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('model', model);
    notifyListeners();
  }

  Future<void> updateApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('geminiApiKey', apiKey);
  }
}
