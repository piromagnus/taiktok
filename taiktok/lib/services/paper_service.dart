import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
// import 'package:vector_math/vector_math.dart';
import 'dart:math';
import '../models/paper.dart';

class PaperService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _geminiApiKey;

  PaperService(this._geminiApiKey);

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

  Future<void> savePaper(Paper paper) async {
    final embedding = await generateEmbedding(paper.abstract);

    await _firestore.collection('papers').doc(paper.arxivId).set({
      'title': paper.title,
      'authors': paper.authors,
      'abstract': paper.abstract,
      'publishDate': paper.publishDate,
      'arxivId': paper.arxivId,
      'tags': paper.tags,
      'arxivUrl': paper.arxivUrl,
      'githubUrl': paper.githubUrl,
      'contributions': paper.contributions,
      'embedding': embedding,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Paper> getPaper(String arxivId) async {
    final doc = await _firestore.collection('papers').doc(arxivId).get();
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
    return Paper(
      title: data['title'],
      authors: List<String>.from(data['authors']),
      abstract: data['abstract'],
      publishDate: data['publishDate'],
      arxivId: data['arxivId'],
      tags: List<String>.from(data['tags']),
      arxivUrl: data['arxivUrl'],
      githubUrl: data['githubUrl'],
      contributions: List<String>.from(data['contributions']),
    );
  }

  Future<void> updatePaperContributions(
      String arxivId, List<String> contributions) async {
    await _firestore.collection('papers').doc(arxivId).update({
      'contributions': contributions,
    });
  }

  Future<void> updatePaperTags(String arxivId, List<String> tags) async {
    await _firestore.collection('papers').doc(arxivId).update({
      'tags': tags,
    });
  }

  Future<List<Paper>> searchSimilarPapers(String query,
      {double threshold = 0.4, int limit = 5}) async {
    final queryEmbedding = await generateEmbedding(query);
    if (queryEmbedding.isEmpty) return [];

    final papers = await _firestore
        .collection('papers')
        .orderBy('createdAt', descending: true)
        .limit(100) // Get recent papers to compare
        .get();

    final List<MapEntry<Paper, double>> scoredPapers = [];

    for (var doc in papers.docs) {
      final data = doc.data();
      final embedding = List<double>.from(data['embedding']);
      final similarity = cosineSimilarity(queryEmbedding, embedding);
      print(similarity);
      if (similarity > threshold) {
        // Threshold for similarity
        scoredPapers.add(
          MapEntry(
            Paper(
              title: data['title'],
              authors: List<String>.from(data['authors']),
              abstract: data['abstract'],
              publishDate: data['publishDate'],
              arxivId: data['arxivId'],
              tags: List<String>.from(data['tags']),
              arxivUrl: data['arxivUrl'],
              githubUrl: data['githubUrl'],
              contributions: List<String>.from(data['contributions']),
            ),
            similarity,
          ),
        );
      }
    }

    // Sort by similarity score
    scoredPapers.sort((a, b) => b.value.compareTo(a.value));

    // Return the top papers
    return scoredPapers.take(limit).map((e) => e.key).toList();
  }

  Future<bool> paperExists(String arxivId) async {
    final doc = await _firestore.collection('papers').doc(arxivId).get();
    return doc.exists;
  }
}
