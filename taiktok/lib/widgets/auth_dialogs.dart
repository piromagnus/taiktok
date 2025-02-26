import 'package:flutter/material.dart';

class LoginDialog extends StatefulWidget {
  final Future<bool> Function(String email, String password) onLogin;
  final Future<bool> Function() onGoogleSignIn;
  final Future<bool> Function(String email, String password, String username)
      onSignUp;

  const LoginDialog({
    Key? key,
    required this.onLogin,
    required this.onGoogleSignIn,
    required this.onSignUp,
  }) : super(key: key);

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Login'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _error,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            // const SizedBox(height: 16),

            // const SizedBox(height: 16),
            // const Text('or'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() {
                        _isLoading = true;
                        _error = '';
                      });

                      try {
                        final success = await widget.onGoogleSignIn();
                        if (success) {
                          Navigator.of(context).pop();
                        } else {
                          setState(() {
                            _error = 'Failed to sign in with Google';
                          });
                        }
                      } catch (e) {
                        setState(() {
                          _error = e.toString();
                        });
                      } finally {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    },
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Don\'t have an account?'),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (context) => SignUpDialog(
                    onSignUp: widget.onSignUp,
                  ),
                );
              },
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() {
                      _isLoading = true;
                      _error = '';
                    });
                    try {
                      final success = await widget.onLogin(
                        _emailController.text,
                        _passwordController.text,
                      );
                      if (success) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() {
                          _error = 'Invalid email or password';
                        });
                      }
                    } catch (e) {
                      print(e);
                      setState(() {
                        _error = e.toString();
                      });
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign In'),
        ),
      ],
    );
  }
}

class SignUpDialog extends StatefulWidget {
  final Future<bool> Function(String email, String password, String username)
      onSignUp;

  const SignUpDialog({
    Key? key,
    required this.onSignUp,
  }) : super(key: key);

  @override
  State<SignUpDialog> createState() => _SignUpDialogState();
}

class _SignUpDialogState extends State<SignUpDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign Up'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a username';
                }
                return null;
              },
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _error,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        _isLoading
            ? const CircularProgressIndicator()
            : TextButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() {
                      _isLoading = true;
                      _error = '';
                    });

                    try {
                      final success = await widget.onSignUp(
                        _emailController.text,
                        _passwordController.text,
                        _usernameController.text,
                      );
                      if (success) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() {
                          _error = 'Failed to create account';
                        });
                      }
                    } catch (e) {
                      setState(() {
                        _error = e.toString();
                      });
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                },
                child: const Text('Sign Up'),
              ),
      ],
    );
  }
}
