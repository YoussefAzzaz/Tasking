import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('JOURNAL', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AxisColors.textHigh, fontWeight: FontWeight.bold)),
                const Icon(Icons.mic_rounded, color: AxisColors.secondary),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AxisCard(
              tier: GlassTier.two,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Today, ${DateTime.now().day}/${DateTime.now().month}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AxisColors.textMuted)),
                      Row(
                        children: [
                          const Icon(Icons.mood_rounded, color: AxisColors.tertiary, size: 18),
                          const SizedBox(width: 4),
                          Text('HIGH ENERGY', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.tertiary)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Had a great focus session this morning. Managed to build the habits and notes screen much faster than expected.'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('RECENT NOTES', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AxisColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          
          const SizedBox(height: 12),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _NoteCard(title: 'App Architecture Draft', date: '2 days ago', isMarkdown: true),
                const SizedBox(height: 8),
                _NoteCard(title: 'Grocery List', date: '4 days ago', isMarkdown: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.title, required this.date, required this.isMarkdown});
  final String title;
  final String date;
  final bool isMarkdown;

  @override
  Widget build(BuildContext context) {
    return AxisCard(
      tier: GlassTier.two,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(isMarkdown ? Icons.code_rounded : Icons.article_rounded, color: AxisColors.secondary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AxisColors.textHigh)),
                const SizedBox(height: 2),
                Text(date, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
