import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/paper_provider.dart';
import '../services/user_provider.dart';
// import '../models/user.dart';

import '../widgets/paper_card.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/auth_dialogs.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  final Function(AppTheme) onThemeChanged;
  final AppTheme currentTheme;

  const HomeScreen({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_pageController.position.pixels ==
        _pageController.position.maxScrollExtent) {
      // Fetch more papers when we reach the end of the list
      final paperProvider = Provider.of<PaperProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      paperProvider.fetchMorePapers(userProvider.currentUser?.readPapers ?? []);
    }
  }

  Future<void> _handleSignOut(UserProvider userProvider) async {
    await userProvider.signOut();
  }

  void _handlePaperView(String paperId, UserProvider userProvider,
      PaperProvider paperProvider) async {
    if (userProvider.currentUser != null) {
      await userProvider.markPaperAsRead(paperId);
      // Then remove the viewed paper from the provider's map
      paperProvider.removeReadPaper(paperId);
    }
  }

  void _showLoginDialog(
      UserProvider userProvider, PaperProvider paperProvider) {
    showDialog(
      context: context,
      builder: (context) => LoginDialog(
        onLogin: (email, password) async {
          final success = await userProvider.login(email, password);

          if (success) {
            // Refresh papers with user's read papers
            final readPapers = await userProvider.getReadPapers();

            await paperProvider.refreshPapers(readPapers);
          }
          return success;
        },
        onGoogleSignIn: () async {
          final success = await userProvider.signInWithGoogle();

          if (success) {
            // Refresh papers with user's read papers
            final readPapers = await userProvider.getReadPapers();

            await paperProvider.refreshPapers(readPapers);
          }
          return success;
        },
        onSignUp: (email, password, username) async {
          final success =
              await userProvider.createAccount(email, password, username);

          if (success) {
            // Refresh papers with empty read list for new user
            await paperProvider.refreshPapers([]);
          }
          return success;
        },
      ),
    );
  }

  void _showSettingsDialog(
      PaperProvider paperProvider, UserProvider userProvider) {
    showDialog(
        context: context,
        builder: (context) {
          return SettingsDialog(
            initialApiKey: paperProvider.apiKey,
            initialQuery: paperProvider.query,
            initialThreshold: paperProvider.threshold,
            initialModel: paperProvider.model,
            initialTheme: widget.currentTheme,
            initialCategory: paperProvider.category,
            onApiKeyChanged: (key) => paperProvider.updateApiKey(key),
            onQueryChanged: (query) => paperProvider.updateQuery(query),
            onThresholdChanged: (value) => paperProvider.updateThreshold(value),
            onModelChanged: (model) => paperProvider.updateModel(model),
            onThemeChanged: widget.onThemeChanged,
            onCategoryChanged: (category) =>
                paperProvider.updateCategory(category),
            onApply: () async {
              // Refresh papers with new settings
              await paperProvider
                  .refreshPapers(userProvider.currentUser?.readPapers ?? []);
            },
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to rebuild when the providers change
    return Consumer2<PaperProvider, UserProvider>(
      builder: (context, paperProvider, userProvider, child) {
        final currentUser = userProvider.currentUser;

        return Scaffold(
          appBar: AppBar(
            title: Image.asset(
              'assets/logo.png',
              height: 32,
            ),
            actions: [
              if (currentUser?.username != null) ...[
                Text(currentUser!.username!),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'signout') {
                      _handleSignOut(userProvider);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'signout',
                      child: Text('Sign Out'),
                    ),
                  ],
                ),
              ],
              if (currentUser?.username == null) ...[
                TextButton(
                  onPressed: () =>
                      _showLoginDialog(userProvider, paperProvider),
                  child: const Text('Login'),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => paperProvider
                    .refreshPapers(userProvider.currentUser?.readPapers ?? []),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () =>
                    _showSettingsDialog(paperProvider, userProvider),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: paperProvider.isLoading && paperProvider.papers.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : paperProvider.error.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(paperProvider.error),
                          ElevatedButton(
                            onPressed: () => paperProvider.refreshPapers(
                                userProvider.currentUser?.readPapers ?? []),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : paperProvider.papers.isEmpty
                      ? const Center(
                          child: Text(
                              'No papers found. Try adjusting your search criteria.'))
                      : Stack(
                          children: [
                            PageView.builder(
                              scrollDirection: Axis.vertical,
                              controller: _pageController,
                              itemCount: paperProvider.papers.length,
                              onPageChanged: (index) {
                                if (index > 0 &&
                                    index < paperProvider.papers.length) {
                                  final paperId = paperProvider
                                      .papers[index - 1].key.arxivId;
                                  _handlePaperView(
                                      paperId, userProvider, paperProvider);
                                }
                              },
                              itemBuilder: (context, index) {
                                final entry = paperProvider.papers[index];
                                return PaperCard(
                                  paper: entry.key,
                                  matchingScore: entry.value,
                                  currentUser: currentUser,
                                  userProvider: userProvider,
                                );
                              },
                            ),
                            if (paperProvider.isLoading)
                              const Positioned(
                                bottom: 16,
                                right: 16,
                                child: CircularProgressIndicator(),
                              ),
                          ],
                        ),
        );
      },
    );
  }
}
