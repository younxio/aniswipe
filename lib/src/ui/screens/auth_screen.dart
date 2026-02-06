import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80),
            const SizedBox(height: 24),
            Text(
              'Welcome to AniSwipe',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 48),
            // Navigation buttons
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/login');
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/signup');
                    },
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
