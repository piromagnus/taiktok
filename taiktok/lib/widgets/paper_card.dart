import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
// import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/paper.dart';
import '../models/user.dart';
import '../services/user_provider.dart';
import '../widgets/auth_dialogs.dart';

class PaperCard extends StatefulWidget {
  final Paper paper;
  final double matchingScore;
  final AppUser? currentUser;
  final UserProvider userProvider;

  const PaperCard({
    Key? key,
    required this.paper,
    required this.matchingScore,
    required this.currentUser,
    required this.userProvider,
  }) : super(key: key);

  @override
  State<PaperCard> createState() => _PaperCardState();
}

class _PaperCardState extends State<PaperCard> {
  int _currentSection = 0;
  bool _isBookmarked = false;
  final List<String> _sections = [
    'overview',
    'contributions',
    'abstract1',
    'abstract2',
    'abstract3',
    'metadata'
  ];
  bool _leftTapped = false;
  bool _rightTapped = false;

  @override
  void initState() {
    super.initState();
    _checkBookmarkStatus();
  }

  @override
  void didUpdateWidget(PaperCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser?.id != widget.currentUser?.id) {
      _checkBookmarkStatus();
    }
  }

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

  Future<void> _checkBookmarkStatus({bool updateState = true}) async {
    final isBookmarked =
        await widget.userProvider.isPaperBookmarked(widget.paper.arxivId);
    if (!mounted) return;

    if (updateState) {
      setState(() {
        _isBookmarked = isBookmarked;
      });
    }
  }

  Future<void> _handleBookmarkTap() async {
    if (await widget.userProvider.isAnonymous()) {
      // Show login dialog for anonymous users
      final loginResult = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Authentication Required'),
          content: const Text('Please login to bookmark papers.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                showDialog(
                  context: context,
                  builder: (context) => LoginDialog(
                    onLogin: (email, password) async {
                      final success =
                          await widget.userProvider.login(email, password);
                      if (success) {
                        await widget.userProvider
                            .toggleBookmark(widget.paper.arxivId);
                        await _checkBookmarkStatus();
                      }
                      return success;
                    },
                    onGoogleSignIn: () async {
                      final success =
                          await widget.userProvider.signInWithGoogle();
                      if (success) {
                        await widget.userProvider
                            .toggleBookmark(widget.paper.arxivId);
                        await _checkBookmarkStatus();
                      }
                      return success;
                    },
                    onSignUp: (email, password, username) async {
                      final success = await widget.userProvider.createAccount(
                        email,
                        password,
                        username,
                      );
                      if (success) {
                        await widget.userProvider
                            .toggleBookmark(widget.paper.arxivId);
                        await _checkBookmarkStatus();
                      }
                      return success;
                    },
                  ),
                );
              },
              child: const Text('Login'),
            ),
          ],
        ),
      );

      if (loginResult != true) return;
      return;
    }

    final success =
        await widget.userProvider.toggleBookmark(widget.paper.arxivId);
    if (success && mounted) {
      setState(() {
        _isBookmarked = !_isBookmarked;
      });
    }

    // Show error if there was one
    if (!success && widget.userProvider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.userProvider.error!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<String> _splitAbstract() {
    final abstract = widget.paper.abstract;
    final avgLength = abstract.length ~/ 3;
    final List<String> parts = [];

    int start = 0;
    for (int i = 0; i < 3; i++) {
      int end = start + avgLength;
      if (i == 2) end = abstract.length;

      while (end < abstract.length && abstract[end] != ' ') {
        end++;
      }
      parts.add(abstract.substring(start, end).trim());
      start = end;
    }

    return parts;
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _sections.length,
        (index) => GestureDetector(
          onTap: () {
            setState(() {
              _currentSection = index;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  index == _currentSection ? Colors.cyanAccent : Colors.white,
            ),
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
      case 'overview':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AutoSizeText(
                widget.paper.title,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lightbulb_outline),
                const SizedBox(width: 8),
                Text(
                  'Matching Score: ',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  '${(widget.matchingScore * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Problem:',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)
                  .copyWith(color: Colors.cyan),
            ),
            const SizedBox(height: 4),
            Text(
              widget.paper.problemSolved,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Task:',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)
                  .copyWith(color: Colors.cyan),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.paper.taskType}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: widget.paper.tags
                  .map((tag) => Chip(
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        side: BorderSide(
                          width: 2,
                          color: Colors.cyan.withAlpha(200),
                        ),
                        label: Text(tag),
                      ))
                  .toList(),
            ),
            const Spacer(),
            _buildProgressIndicator(),
          ],
        );
      case 'contributions':
        return Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Key Contributions',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...(widget.paper.contributions.isNotEmpty
                ? widget.paper.contributions
                    .map(
                      (contribution) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withAlpha(50),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(255, 210, 158, 236)
                                    .withAlpha(40),
                                spreadRadius: 3,
                                blurRadius: 4,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
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
                                  maxLines: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList()
                : [const Text('No contributions found.')]),
            const Spacer(),
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
            AutoSizeText(
              abstractParts[0],
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.left,
              maxLines: 15,
              overflow: TextOverflow.ellipsis,
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
            AutoSizeText(
              abstractParts[1],
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.left,
              maxLines: 15,
              overflow: TextOverflow.ellipsis,
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
            AutoSizeText(
              abstractParts[2],
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.left,
              maxLines: 15,
              overflow: TextOverflow.ellipsis,
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
              'Category:',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              widget.paper.category,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Authors:',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            ...widget.paper.authors.map(
              (author) => AutoSizeText(
                author,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.left,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                minFontSize: 10,
              ),
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
    return Card(
      elevation: 8,
      margin: const EdgeInsets.all(16),
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTapDown: (details) {
          final tapPosition = details.localPosition;
          // Check if tap is on bookmark area
          // final bookmarkArea = details.localPosition.dx > MediaQuery.of(context).size.width - 60;
          // if (bookmarkArea) {
          //   return; // Ignore taps in bookmark area
          // }

          // 2/3 bottom
          final isBottom =
              tapPosition.dy > 1 * MediaQuery.of(context).size.height / 4;
          final isLeft = isBottom &&
              tapPosition.dx < MediaQuery.of(context).size.width / 4;
          final isRight = isBottom &&
              tapPosition.dx > 3 * MediaQuery.of(context).size.width / 4;
          setState(() {
            _leftTapped = isLeft;
            _rightTapped = isRight;
          });
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              setState(() {
                _leftTapped = false;
                _rightTapped = false;
              });
            }
          });

          if (isLeft) {
            _previousSection();
          } else if (isRight) {
            _nextSection();
          }
        },
        child: Stack(
          children: [
            Container(
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: Theme.of(context).brightness == Brightness.dark
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.25, 0.75, 1.0],
                        colors: [
                          const Color.fromARGB(255, 34, 0, 50)
                              .withValues(alpha: 2), // 0.95 * 255 = 242
                          const Color(0xFF1A1B26),
                          const Color(0xFF2A2B36),
                          const Color.fromARGB(255, 3, 65, 63)
                              .withValues(alpha: 1), // 0.9 * 255 = 230
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.surfaceContainer,
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                        ],
                      ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.cyan.withValues(alpha: 128), // 0.5 * 255 = 128
                  width: 1,
                ),
                boxShadow: Theme.of(context).brightness == Brightness.dark
                    ? [
                        // BoxShadow(
                        //   color: Theme.of(context)
                        //       .colorScheme
                        //       .surface
                        //       .withValues(alpha: 100), // 0.1 * 255 = 26
                        //   blurRadius: 50,
                        //   spreadRadius: 5,
                        // ),
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 8), // 0.05 * 255 = 13
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildContent(),
              ),
            ),
            // Bookmark button

            // Left half overlay
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width / 2,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _leftTapped ? 0.02 : 0.0,
                child: Container(
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.centerLeft,
                      radius: 1,
                      stops: const [0.0, 0.7, 1.0],
                      colors: [
                        // Colors.cyan.withValues(alpha: 10),
                        // Colors.transparent,
                        // Colors.transparent,
                        // Colors.cyan.withValues(alpha: 2),
                        // Colors.cyan.withValues(alpha: 10),
                        Colors.cyan.withValues(alpha: 10),
                        Colors.cyan.withValues(alpha: 5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Right half overlay
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width / 2,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _rightTapped ? 0.02 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.centerRight,
                      radius: 1,
                      stops: const [0.0, 0.7, 1.0],
                      colors: [
                        // Colors.cyan.withValues(alpha: 10),
                        // Colors.transparent,
                        // Colors.transparent,
                        // Colors.cyan.withValues(alpha: 2),
                        // Colors.cyan.withValues(alpha: 10),
                        Colors.cyan.withValues(alpha: 10),
                        Colors.cyan.withValues(alpha: 5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: _isBookmarked ? Colors.red : null,
                ),
                onPressed: _handleBookmarkTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
