import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _senderController = TextEditingController();
  
  Map<String, dynamic>? _simInfo;
  bool _batteryOptimizationIgnored = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _destinationController.text = settings.destinationNumber;
    _loadSimInfoAndBatteryStatus();
  }

  Future<void> _loadSimInfoAndBatteryStatus() async {
    final gateway = ref.read(nativeSmsGatewayProvider);
    final simInfo = await gateway.getSimInfo();
    final batteryIgnored = await gateway.isBatteryOptimizationIgnored();

    setState(() {
      _simInfo = simInfo;
      _batteryOptimizationIgnored = batteryIgnored;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section 1: Destination Number
          _buildSectionHeader('Destination Phone Number'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _destinationController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Forward SMS to',
                      hintText: '+91 9876543210',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final val = _destinationController.text.trim();
                        if (val.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid phone number.')),
                          );
                          return;
                        }
                        await notifier.setDestinationNumber(val);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Destination number updated.')),
                          );
                        }
                      },
                      child: const Text('Save Destination Number'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section 2: Outgoing SIM Selection
          _buildSectionHeader('Outgoing SIM Selection'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select which SIM card to use for sending outgoing SMS (Dual-SIM devices):',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  RadioListTile<int?>(
                    title: const Text('System Default SIM'),
                    subtitle: const Text('Let Android decide the default outgoing SIM'),
                    value: null,
                    groupValue: settings.outgoingSubscriptionId,
                    onChanged: (val) => notifier.setOutgoingSubscriptionId(val),
                  ),
                  if (_simInfo != null && _simInfo!['sims'] is List) ...[
                    for (final sim in (_simInfo!['sims'] as List))
                      RadioListTile<int?>(
                        title: Text(sim['displayName'] ?? 'SIM ${sim['simSlotIndex'] + 1}'),
                        subtitle: Text('Carrier: ${sim['carrierName'] ?? 'Unknown'} (Sub ID: ${sim['subscriptionId']})'),
                        value: sim['subscriptionId'] as int?,
                        groupValue: settings.outgoingSubscriptionId,
                        onChanged: (val) => notifier.setOutgoingSubscriptionId(val),
                      ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section 3: Sender Filtering
          _buildSectionHeader('Sender Filtering'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Sender Filtering'),
                    subtitle: Text(
                      settings.senderFilterEnabled
                          ? 'Only forward SMS from configured senders'
                          : 'Forward matching SMS from all senders',
                    ),
                    value: settings.senderFilterEnabled,
                    onChanged: (val) => notifier.setSenderFilterEnabled(val),
                  ),
                  if (settings.senderFilterEnabled) ...[
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _senderController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'e.g. HDFCBK, SBIINB',
                              labelText: 'Add Allowed Sender Header',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            final val = _senderController.text.trim().toUpperCase();
                            if (val.isNotEmpty && !settings.allowedSenders.contains(val)) {
                              notifier.setAllowedSenders([...settings.allowedSenders, val]);
                              _senderController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: settings.allowedSenders.map((sender) {
                        return Chip(
                          label: Text(sender),
                          onDeleted: () {
                            final updated = settings.allowedSenders.where((s) => s != sender).toList();
                            notifier.setAllowedSenders(updated);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section 4: Battery Optimization Guidance
          _buildSectionHeader('Background Reliability'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _batteryOptimizationIgnored ? Icons.check_circle : Icons.warning_amber,
                        color: _batteryOptimizationIgnored ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _batteryOptimizationIgnored
                              ? 'Excluded from Battery Optimization ✓'
                              : 'Battery Optimization Active (May delay background SMS)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'For reliable background forwarding, please exclude this app from battery optimization and allow background activity.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.battery_saver),
                      label: const Text('Open Battery Optimization Settings'),
                      onPressed: () async {
                        final gateway = ref.read(nativeSmsGatewayProvider);
                        await gateway.requestBatteryOptimizationExemption();
                        _loadSimInfoAndBatteryStatus();
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
