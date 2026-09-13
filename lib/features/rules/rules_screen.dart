import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/entities/forwarding_rule.dart';

class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
  final TextEditingController _customKeywordController = TextEditingController();
  final TextEditingController _excludeKeywordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forwarding Rules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to Defaults',
            onPressed: () {
              notifier.setActiveRules(DefaultRules.allDefaults);
              notifier.setGlobalExcludeKeywords(['offer', 'promotion', 'sale']);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reset to default forwarding rules.')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Global Exclude Keywords
          _buildSectionHeader('Global Exclude Keywords'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SMS containing any of these keywords will NEVER be forwarded:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _excludeKeywordController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. electricity bill, offer',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final kw = _excludeKeywordController.text.trim();
                          if (kw.isNotEmpty && !settings.globalExcludeKeywords.contains(kw)) {
                            notifier.setGlobalExcludeKeywords([
                              ...settings.globalExcludeKeywords,
                              kw,
                            ]);
                            _excludeKeywordController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: settings.globalExcludeKeywords.map((kw) {
                      return Chip(
                        avatar: const Icon(Icons.block, size: 16, color: Colors.red),
                        label: Text(kw),
                        onDeleted: () {
                          final updated = settings.globalExcludeKeywords.where((k) => k != kw).toList();
                          notifier.setGlobalExcludeKeywords(updated);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Built-in & Custom Forwarding Categories
          _buildSectionHeader('Active Rule Categories'),
          for (int i = 0; i < settings.activeRules.length; i++) ...[
            _buildRuleCard(settings.activeRules[i], i, settings, notifier),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 20),

          // Add Custom Keyword Rule
          _buildSectionHeader('Add Custom Keyword Rule'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _customKeywordController,
                    decoration: const InputDecoration(
                      labelText: 'Custom Keyword (e.g. electricity bill)',
                      hintText: 'Enter keyword or phrase',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Add Custom Keyword Rule'),
                      onPressed: () {
                        final kw = _customKeywordController.text.trim();
                        if (kw.isEmpty) return;

                        final customRule = ForwardingRule(
                          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                          name: 'Custom: "$kw"',
                          includeKeywords: [kw],
                        );

                        notifier.setActiveRules([...settings.activeRules, customRule]);
                        _customKeywordController.clear();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added custom rule for "$kw"')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(
    ForwardingRule rule,
    int index,
    AppSettingsState settings,
    AppSettingsNotifier notifier,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(rule.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${rule.includeKeywords.length} include keywords',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Switch(
          value: rule.isEnabled,
          onChanged: (val) {
            final updatedRules = List<ForwardingRule>.from(settings.activeRules);
            updatedRules[index] = rule.copyWith(isEnabled: val);
            notifier.setActiveRules(updatedRules);
          },
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Include Keywords:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: rule.includeKeywords.map((kw) {
                    return Chip(
                      label: Text(kw, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.blue[50],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
