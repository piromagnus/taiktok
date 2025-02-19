import 'package:xml/xml.dart' as xml;
import 'package:intl/intl.dart';

class Paper {
  final String title;
  final List<String> authors;
  final String abstract;
  final String publishDate;
  final String arxivId;
  final List<String> tags;
  final String arxivUrl;
  final String? githubUrl;
  List<String> contributions;

  Paper({
    required this.title,
    required this.authors,
    required this.abstract,
    required this.publishDate,
    required this.arxivId,
    required this.tags,
    required this.arxivUrl,
    this.githubUrl,
    this.contributions = const <String>[],
  });

  static String? extractGithubUrl(String text) {
    final githubRegex = RegExp(
      r'https?:\/\/(?:www\.)?github\.(?:com|io)\/[^\s\)]+',
      caseSensitive: false,
    );
    final match = githubRegex.firstMatch(text);
    if (match != null) {
      final group0 = match.group(0);
      if (group0 != null && group0.endsWith('.')) {
        return group0.substring(0, group0.length - 1);
      }
      return group0;
    }
    return null;
  }

  factory Paper.fromArxiv(xml.XmlElement entry) {
    final title = entry.findElements('title').first.innerText.trim();
    final authors = entry
        .findElements('author')
        .map((author) => author.findElements('name').first.innerText.trim())
        .toList();
    final abstract = entry
        .findElements('summary')
        .first
        .innerText
        .trim()
        .replaceAll('\n', ' ');
    final publishDate = entry.findElements('published').first.innerText.trim();
    final arxivId = entry
        .findElements('id')
        .first
        .innerText
        .trim()
        .split('/')
        .last
        .replaceAll('v', '');
    final arxivUrl = 'https://arxiv.org/abs/${arxivId.substring(0, 10)}';
    final githubUrl = extractGithubUrl(abstract);

    return Paper(
      title: title,
      authors: authors,
      abstract: abstract,
      publishDate: DateFormat('yyyy-MM-dd').format(DateTime.parse(publishDate)),
      arxivId: arxivId,
      tags: ['AI'],
      arxivUrl: arxivUrl,
      githubUrl: githubUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'authors': authors,
      'abstract': abstract,
      'publishDate': publishDate,
      'arxivId': arxivId,
      'tags': tags,
      'arxivUrl': arxivUrl,
      'githubUrl': githubUrl,
      'contributions': contributions,
    };
  }

  factory Paper.fromMap(Map<String, dynamic> map) {
    return Paper(
      title: map['title'],
      authors: List<String>.from(map['authors']),
      abstract: map['abstract'],
      publishDate: map['publishDate'],
      arxivId: map['arxivId'],
      tags: List<String>.from(map['tags']),
      arxivUrl: map['arxivUrl'],
      githubUrl: map['githubUrl'],
      contributions: List<String>.from(map['contributions']),
    );
  }
}
