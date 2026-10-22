import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bundled text; opening this screen performs no network request.
class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.title, required this.asset, super.key});
  final String title;
  final String asset;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: FutureBuilder<String>(
      future: rootBundle.loadString(asset),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Document could not be opened.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            snapshot.data!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        );
      },
    ),
  );
}
