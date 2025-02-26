import 'package:flutter/material.dart';
import '../theme.dart';

class SettingsDialog extends StatefulWidget {
  final String initialApiKey;
  final String initialQuery;
  final double initialThreshold;
  final String initialModel;
  final AppTheme initialTheme;
  final String initialCategory;
  final Function(String) onApiKeyChanged;
  final Function(String) onQueryChanged;
  final Function(double) onThresholdChanged;
  final Function(String) onModelChanged;
  final Function(AppTheme) onThemeChanged;
  final Function(String) onCategoryChanged;
  final VoidCallback onApply;

  const SettingsDialog({
    Key? key,
    required this.initialApiKey,
    required this.initialQuery,
    required this.initialThreshold,
    required this.initialModel,
    required this.initialTheme,
    required this.initialCategory,
    required this.onApiKeyChanged,
    required this.onQueryChanged,
    required this.onThresholdChanged,
    required this.onModelChanged,
    required this.onThemeChanged,
    required this.onCategoryChanged,
    required this.onApply,
  }) : super(key: key);

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _apiKeyController;
  late TextEditingController _queryController;
  late double _threshold;
  late String _model;
  late String _category;
  bool _settingsChanged = false;
  final List<String> _availableModels = [
    'gemini-2.0-flash-lite',
    'gemini-2.0-flash-exp',
    'gemini-2.0-pro-exp-02-05',
  ];

  final Map<String, String> _categoryDescriptions = {
    'cs.AI': 'Artificial Intelligence',
    'cs.AR': 'Hardware Architecture',
    'cs.CC': 'Computational Complexity',
    'cs.CE': 'Computational Engineering, Finance, and Science',
    'cs.CG': 'Computational Geometry',
    'cs.CL': 'Computation and Language',
    'cs.CR': 'Cryptography and Security',
    'cs.CV': 'Computer Vision and Pattern Recognition',
    'cs.CY': 'Computers and Society',
    'cs.DB': 'Databases',
    'cs.DC': 'Distributed, Parallel, and Cluster Computing',
    'cs.DL': 'Digital Libraries',
    'cs.DM': 'Discrete Mathematics',
    'cs.DS': 'Data Structures and Algorithms',
    'cs.ET': 'Emerging Technologies',
    'cs.FL': 'Formal Languages and Automata Theory',
    'cs.GL': 'General Literature',
    'cs.GR': 'Graphics',
    'cs.GT': 'Computer Science and Game Theory',
    'cs.HC': 'Human-Computer Interaction',
    'cs.IR': 'Information Retrieval',
    'cs.IT': 'Information Theory',
    'cs.LG': 'Machine Learning',
    'cs.LO': 'Logic in Computer Science',
    'cs.MA': 'Multiagent Systems',
    'cs.MM': 'Multimedia',
    'cs.MS': 'Mathematical Software',
    'cs.NA': 'Numerical Analysis',
    'cs.NE': 'Neural and Evolutionary Computing',
    'cs.NI': 'Networking and Internet Architecture',
    'cs.OH': 'Other Computer Science',
    'cs.OS': 'Operating Systems',
    'cs.PF': 'Performance',
    'cs.PL': 'Programming Languages',
    'cs.RO': 'Robotics',
    'cs.SC': 'Symbolic Computation',
    'cs.SD': 'Sound',
    'cs.SE': 'Software Engineering',
    'cs.SI': 'Social and Information Networks',
    'cs.SY': 'Systems and Control'
  };

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.initialApiKey);
    _queryController = TextEditingController(text: widget.initialQuery);
    _threshold = widget.initialThreshold;
    _model = widget.initialModel;
    _category = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              // secret mode
              obscureText: true,
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'Enter your Gemini API key',
              ),
              onChanged: (value) {
                setState(() {
                  _settingsChanged = true;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                labelText: 'Search Query',
                hintText: 'Enter your search query',
              ),
              onChanged: (value) {
                setState(() {
                  _settingsChanged = true;
                });
              },
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Matching Threshold: ${(_threshold * 100).toStringAsFixed(0)}%'),
                Slider(
                  value: _threshold,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: (value) {
                    setState(() {
                      _threshold = value;
                      _settingsChanged = true;
                      // Call the callback immediately to ensure the value is updated in the parent
                      widget.onThresholdChanged(_threshold);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _model,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Model',
                isCollapsed: false,
              ),
              items: _availableModels.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _model = value;
                    _settingsChanged = true;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category',
                isCollapsed: false,
              ),
              items: _categoryDescriptions.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Tooltip(
                    message: entry.value,
                    child: Text(
                      entry.value,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _category = value;
                    _settingsChanged = true;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _settingsChanged
              ? () {
                  widget.onApiKeyChanged(_apiKeyController.text);
                  widget.onQueryChanged(_queryController.text);
                  widget.onModelChanged(_model);
                  widget.onCategoryChanged(_category);
                  widget.onApply();
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
