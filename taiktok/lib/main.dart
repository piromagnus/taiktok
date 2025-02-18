import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
// import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options_claude.dart';
import 'services/paper_service.dart';
import 'package:taiktok/models/paper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
      name: '[MyApp]',
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taiktok',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blueGrey,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      home: const MyHomePage(title: 'Taiktok'),
    );
  }
}

// class Paper {
//   final String title;
//   final List<String> authors;
//   final String abstract;
//   final String publishDate;
//   final String arxivId;
//   final List<String> tags;
//   final String arxivUrl;
//   final String? githubUrl;
//   List<String> contributions;

//   Paper({
//     required this.title,
//     required this.authors,
//     required this.abstract,
//     required this.publishDate,
//     required this.arxivId,
//     required this.tags,
//     required this.arxivUrl,
//     this.githubUrl,
//     this.contributions = const <String>[],
//   });

//   static String? extractGithubUrl(String text) {
//     final githubRegex = RegExp(
//       r'https?:\/\/(?:www\.)?github\.(?:com|io)\/[^\s\)]+',
//       caseSensitive: false,
//     );
//     final match = githubRegex.firstMatch(text);
//     if (match != null) {
//       final group0 = match.group(0);
//       if (group0 != null && group0.endsWith('.')) {
//         return group0.substring(0, group0.length - 1);
//       }
//       return group0;
//     }
//     return null;
//   }

//   factory Paper.fromArxiv(xml.XmlElement entry) {
//     final title = entry.findElements('title').first.innerText.trim();
//     final authors = entry
//         .findElements('author')
//         .map((author) => author.findElements('name').first.innerText.trim())
//         .toList();
//     final abstract = entry
//         .findElements('summary')
//         .first
//         .innerText
//         .trim()
//         .replaceAll('\n', ' ');
//     final publishDate = entry.findElements('published').first.innerText.trim();
//     final arxivId = entry
//         .findElements('id')
//         .first
//         .innerText
//         .trim()
//         .split('/')
//         .last
//         .replaceAll('v', '');
//     // keep the 10 first char in the id
//     final arxivUrl = 'https://arxiv.org/abs/${arxivId.substring(0, 10)}';
//     final githubUrl = extractGithubUrl(abstract);

//     return Paper(
//       title: title,
//       authors: authors,
//       abstract: abstract,
//       publishDate: DateFormat('yyyy-MM-dd').format(DateTime.parse(publishDate)),
//       arxivId: arxivId,
//       tags: ['AI'],
//       arxivUrl: arxivUrl,
//       githubUrl: githubUrl,
//     );
//   }
// }

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final PageController _pageController = PageController();
  List<Paper> _papers = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  String _error = '';
  int _startIndex = 0;
  static const int _papersPerPage = 5;
  bool _hasMorePapers = true;
  String _customQuery = 'mamba';
  String _geminiApiKey = '';
  late PaperService _paperService;
  String _model =
      'gemini-2.0-flash-lite-preview-02-05'; //'gemini-2.0-flash-exp'; // gemini-2.0-flash-lite-preview-02-05
  double _similarityThreshold = 0.4;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customQuery = (prefs.getString('customQuery') ?? 'mamba');
      _geminiApiKey = prefs.getString('geminiApiKey') ?? '';
      _similarityThreshold = prefs.getDouble('similarityThreshold') ?? 0.4;
      _model =
          prefs.getString('model') ?? 'gemini-2.0-flash-lite-preview-02-05';
    });
    _paperService = PaperService(_geminiApiKey);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadData();
      _pageController.addListener(_onScroll);
    });
  }

  Future<void> _loadData() async {
    await _fetchPapers();
  }

  Future<void> _fetchPapers() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // First, try to find similar papers in Firebase
      final similarPapers = await _paperService
          .searchSimilarPapers(_customQuery, threshold: _similarityThreshold);

      if (similarPapers.isNotEmpty) {
        setState(() {
          _papers = similarPapers;
          _isLoading = false;
        });
        return;
      }

      // If no similar papers found, fetch from arXiv
      await _fetchArxivPapers();
    } catch (e) {
      setState(() {
        _error = 'Error loading papers: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMorePapers() async {
    if (!_isFetchingMore && !_isLoading && _hasMorePapers) {
      _startIndex += _papersPerPage;
      await _fetchArxivPapers(isLoadingMore: true);
    }
  }

  Future<void> _fetchArxivPapers({bool isLoadingMore = false}) async {
    setState(() {
      if (isLoadingMore) {
        _isFetchingMore = true;
      } else {
        _isLoading = true;
      }
      _error = '';
    });

    try {
      const baseQuery = 'cat:cs.CV';
      final formattedQuery = '+AND+all:$_customQuery';
      final url = Uri.parse(
        'https://arxiv.org/api/query?search_query=$baseQuery$formattedQuery&sortBy=lastUpdatedDate&sortOrder=descending&start=$_startIndex&max_results=$_papersPerPage',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final entries = document.findAllElements('entry');
        final newPapers =
            entries.map((entry) => Paper.fromArxiv(entry)).toList();

        if (newPapers.length < _papersPerPage) {
          _hasMorePapers = false;
        }

        setState(() {
          if (isLoadingMore) {
            _isFetchingMore = false;
          } else {
            _isLoading = false;
          }
        });

        List<Paper> updatedPapers = [];
        for (final paper in newPapers) {
          // Check if paper already exists in Firebase
          if (!await _paperService.paperExists(paper.arxivId)) {
            final contributions = await _getGeminiContributions(paper.abstract);
            final tags = await _getGeminiTags(paper.abstract);

            print('Contributions: $contributions, Tags: $tags');
            final updatedPaper = Paper(
              title: paper.title,
              authors: paper.authors,
              abstract: paper.abstract,
              publishDate: paper.publishDate,
              arxivId: paper.arxivId,
              tags: tags,
              arxivUrl: paper.arxivUrl,
              githubUrl: paper.githubUrl,
              contributions: contributions,
            );

            // Save to Firebase
            await _paperService.savePaper(updatedPaper);
            updatedPapers.add(updatedPaper);
          } else {
            final existingPaper = await _paperService.getPaper(paper.arxivId);
            if (existingPaper.contributions.isEmpty) {
              final contributions =
                  await _getGeminiContributions(paper.abstract);
              await _paperService.updatePaperContributions(
                  paper.arxivId, contributions);
            }
            if (existingPaper.tags == ['AI']) {
              final tags = await _getGeminiTags(paper.abstract);
              await _paperService.updatePaperTags(paper.arxivId, tags);
            }
            updatedPapers.add(existingPaper);
          }
        }

        setState(() {
          if (isLoadingMore) {
            _papers.addAll(updatedPapers);
          } else {
            _papers = updatedPapers;
          }
        });
      } else {
        throw Exception('Failed to load papers: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading papers: $e';
        if (isLoadingMore) {
          _isFetchingMore = false;
        } else {
          _isLoading = false;
        }
      });
    }
  }

  void _onScroll() {
    if (_pageController.position.pixels ==
        _pageController.position.maxScrollExtent) {
      _fetchMorePapers();
    }
  }

  Future<void> _saveGeminiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('geminiApiKey', key);
    setState(() {
      _geminiApiKey = key;
    });
  }

  Future<void> _saveCustomQuery(String query) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customQuery', query);
    setState(() {
      _customQuery = query;
    });
  }

  Future<void> _saveModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('model', model);
    setState(() {
      _model = model;
    });
  }

  Future<List<String>> _getGeminiContributions(String abstract) async {
    if (_geminiApiKey.isEmpty) {
      return [];
    }
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_geminiApiKey',
    );
    final headers = {'Content-Type': 'application/json'};
    final prompt =
        '<format>{contribution 1};{contribution 2};{contribution 3}<\format>\n You will answer ONLY the contributions. You will just output the text without any special characters at the beginning or end. Summarize the following research paper abstract into exactly 3 main contributions:\n\n$abstract';
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'];
        // print(candidates);
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          if (content != null) {
            final parts = content['parts'];
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text']
                  .replaceAll('<format>', '')
                  .replaceAll('</format>', '')
                  .replaceAll('{', '')
                  .replaceAll('}', '');
              return text.split(';').take(3).toList();
            }
          }
        }
        print(data);
      } else {
        print('Error getting Gemini contributions: ${response.statusCode}');
      }

      return [];
    } catch (e) {
      print('Error getting Gemini contributions: $e');
      return [];
    }
  }

  Future<List<String>> _getGeminiTags(String abstract) async {
    if (_geminiApiKey.isEmpty) {
      return ['AI'];
    }
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_geminiApiKey',
    );
    final headers = {'Content-Type': 'application/json'};
    final prompt =
        'You are a specialist of Machine Learning and computer science in general. Generate 3 relevant technical tags for this research paper abstract. Return ONLY the tags separated by commas, without any additional text or formatting: $abstract';
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'];
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          if (content != null) {
            final parts = content['parts'];
            if (parts != null && parts.isNotEmpty) {
              String text = parts[0]['text'].trim();
              // print(text);
              return text
                  .split(',')
                  .map((tag) => tag.trim())
                  .where((tag) => tag.isNotEmpty)
                  .toList()
                  .cast<String>();
            }
          }
        }
      }
      return ['AI'];
    } catch (e) {
      print('Error getting Gemini tags: $e');
      return ['AI'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error),
                      ElevatedButton(
                        onPressed: _fetchPapers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    PageView.builder(
                      scrollDirection: Axis.vertical,
                      controller: _pageController,
                      itemCount: _papers.length,
                      itemBuilder: (context, index) {
                        return PaperCard(paper: _papers[index]);
                      },
                    ),
                    if (_isFetchingMore)
                      const Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
    );
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    final _SettingsDialog dialog = _SettingsDialog(
      initialApiKey: _geminiApiKey,
      initialQuery: _customQuery,
      initialThreshold: _similarityThreshold,
      initialModel: _model,
      onApiKeyChanged: (key) async {
        await _saveGeminiApiKey(key);
        _paperService = PaperService(key);
      },
      onQueryChanged: _saveCustomQuery,
      onThresholdChanged: (threshold) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('similarityThreshold', threshold);
        setState(() {
          _similarityThreshold = threshold;
        });
      },
      onModelChanged: _saveModel,
      onApply: () {
        _fetchPapers();
      },
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return dialog;
      },
    );
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }
}

class _SettingsDialog extends StatefulWidget {
  final String initialApiKey;
  final String initialQuery;
  final double initialThreshold;
  final String initialModel;
  final Function(String) onApiKeyChanged;
  final Function(String) onQueryChanged;
  final Function(double) onThresholdChanged;
  final Function(String) onModelChanged;
  final Function onApply;

  const _SettingsDialog({
    required this.initialApiKey,
    required this.initialQuery,
    required this.initialThreshold,
    required this.initialModel,
    required this.onApiKeyChanged,
    required this.onQueryChanged,
    required this.onThresholdChanged,
    required this.onModelChanged,
    required this.onApply,
  });

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late TextEditingController _apiKeyController;
  late TextEditingController _queryController;
  late double _threshold;
  late String _selectedModel;

  final List<String> _availableModels = [
    'gemini-2.0-flash-lite-preview-02-05',
    'gemini-2.0-flash-exp',
    'gemini-2.0-pro-exp-02-05',
  ];

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.initialApiKey);
    _queryController = TextEditingController(text: widget.initialQuery);
    _threshold = widget.initialThreshold;
    _selectedModel = widget.initialModel;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                labelText: 'Custom Query',
                hintText: 'Enter your search query',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key (from AI Studio)',
                hintText: 'Enter your API key',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            const Text(
              'Similarity Threshold',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Adjust how similar papers need to be to match your search (0.0 to 1.0)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Slider(
              value: _threshold,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label: _threshold.toStringAsFixed(2),
              onChanged: (value) {
                setState(() {
                  _threshold = value;
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Gemini Model',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Select which Gemini model to use for generating content',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            DropdownButton<String>(
              value: _selectedModel,
              isExpanded: true,
              items: _availableModels.map((String model) {
                return DropdownMenuItem<String>(
                  value: model,
                  child: Text(model, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedModel = newValue;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            widget.onApiKeyChanged(_apiKeyController.text);
            widget.onQueryChanged(_queryController.text);
            widget.onThresholdChanged(_threshold);
            widget.onModelChanged(_selectedModel);
            widget.onApply();
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class PaperCard extends StatefulWidget {
  final Paper paper;

  const PaperCard({super.key, required this.paper});

  @override
  State<PaperCard> createState() => _PaperCardState();
}

class _PaperCardState extends State<PaperCard> {
  int _currentSection = 0;
  final List<String> _sections = [
    'title',
    'abstract1',
    'abstract2',
    'abstract3',
    'metadata',
  ];

  void _nextSection() {
    setState(() {
      _currentSection = (_currentSection + 1) % _sections.length;
    });
  }

  void _previousSection() {
    setState(() {
      _currentSection =
          (_currentSection - 1 + _sections.length) % _sections.length;
    });
  }

  List<String> _splitAbstract() {
    final abstract = widget.paper.abstract;
    final words = abstract.split(' ');
    final wordsPerPart = (words.length / 3).ceil();

    return [
      words.take(wordsPerPart).join(' '),
      words.skip(wordsPerPart).take(wordsPerPart).join(' '),
      words.skip(wordsPerPart * 2).join(' '),
    ];
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _sections.length,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == _currentSection
                ? Colors.white
                : Colors.white.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  Widget _buildContent() {
    final abstractParts = _splitAbstract();

    switch (_sections[_currentSection]) {
      case 'title':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AutoSizeText(
              widget.paper.title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Published: ${widget.paper.publishDate}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Key Contributions:',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 8),
            ...(widget.paper.contributions.isNotEmpty
                ? widget.paper.contributions
                    .map(
                      (contribution) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AutoSizeText(
                                contribution,
                                style: Theme.of(context).textTheme.bodyLarge,
                                textAlign: TextAlign.left,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                minFontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList()
                : [const Text('No contributions found.')]),
            const SizedBox(height: 20),
            _buildProgressIndicator(),
          ],
        );
      case 'abstract1':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Abstract (1/3)',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              abstractParts[0],
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 20),
            _buildProgressIndicator(),
          ],
        );
      case 'abstract2':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Abstract (2/3)',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              abstractParts[1],
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 20),
            _buildProgressIndicator(),
          ],
        );
      case 'abstract3':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Abstract (3/3)',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              abstractParts[2],
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 20),
            _buildProgressIndicator(),
          ],
        );
      case 'metadata':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Paper Info',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Authors:',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            ...widget.paper.authors.map(
              (author) =>
                  Text(author, style: Theme.of(context).textTheme.bodyLarge),
            ),
            const SizedBox(height: 16),
            Text(
              'Published: ${widget.paper.publishDate}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _launchUrl(widget.paper.arxivUrl),
              icon: const Icon(Icons.article_outlined),
              label: const Text('ArXiV'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
            if (widget.paper.githubUrl != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _launchUrl(widget.paper.githubUrl!),
                icon: const Icon(Icons.engineering),
                label: const Text('View on GitHub'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: widget.paper.tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      backgroundColor: Colors.blueGrey.shade700,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            _buildProgressIndicator(),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (TapDownDetails details) {
        // Get the tap position
        final tapPosition = details.localPosition;
        if (tapPosition.dx < MediaQuery.of(context).size.width / 2) {
          _previousSection();
        } else {
          _nextSection();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.blueGrey.shade900],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 40.0,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
