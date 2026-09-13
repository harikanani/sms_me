import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/providers/app_providers.dart';
import '../dashboard/dashboard_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _destinationController = TextEditingController();
  
  int _currentPage = 0;
  bool _smsPermissionGranted = false;
  bool _sendSmsPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final sms = await Permission.sms.status;
    final phone = await Permission.phone.status;
    setState(() {
      _smsPermissionGranted = sms.isGranted;
      _sendSmsPermissionGranted = phone.isGranted || sms.isGranted;
    });
  }

  Future<void> _requestPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.sms,
      Permission.phone,
    ].request();

    setState(() {
      _smsPermissionGranted = statuses[Permission.sms]?.isGranted ?? false;
      _sendSmsPermissionGranted = statuses[Permission.phone]?.isGranted ?? false;
    });
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    final number = _destinationController.text.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid destination phone number')),
      );
      return;
    }

    final notifier = ref.read(appSettingsProvider.notifier);
    await notifier.setDestinationNumber(number);
    await notifier.toggleForwarding(true);
    await notifier.completeOnboarding();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup SMS Forwarder'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Page indicator dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 10,
                    width: _currentPage == index ? 24 : 10,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? primaryColor : Colors.grey[300],
                      borderRadius: BorderRadius.circular(5),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildStep1Welcome(),
                  _buildStep2Permissions(),
                  _buildStep3Destination(),
                  _buildStep4Confirm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Welcome() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 80, color: Colors.blue),
          const SizedBox(height: 24),
          const Text(
            'Private SMS Forwarder',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[300]!),
            ),
            child: const Text(
              'This app automatically forwards selected SMS messages from this phone to a configured phone number.\n\n'
              'It can process sensitive messages such as OTP and banking transaction SMS.\n\n'
              'Only enable this on a phone you own or have explicit permission to manage.',
              style: TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _nextPage,
              child: const Text('I Understand & Accept', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Permissions() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Required Permissions',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'The app needs SMS access to read incoming messages and forward them to your destination number.',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),

          _buildPermissionTile(
            title: 'SMS Access',
            subtitle: 'Read incoming bank & OTP messages',
            isGranted: _smsPermissionGranted,
          ),
          const SizedBox(height: 12),
          _buildPermissionTile(
            title: 'SMS Sending',
            subtitle: 'Send SMS to destination phone number',
            isGranted: _sendSmsPermissionGranted,
          ),

          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.security),
              label: Text(_smsPermissionGranted ? 'Permissions Granted ✓' : 'Grant Permissions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _smsPermissionGranted ? Colors.green[700] : null,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _requestPermissions,
            ),
          ),

          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _smsPermissionGranted ? _nextPage : null,
              child: const Text('Next Step', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Destination() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Destination Phone Number',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the phone number where matching SMS messages should be forwarded.',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _destinationController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Destination Phone Number',
              hintText: '+91 9876543210',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Include country code for best reliability (e.g. +91)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),

          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _nextPage,
              child: const Text('Next Step', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Confirm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to Enable',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Review default settings and enable forwarding.',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSummaryRow('Mode', 'SMS → SMS'),
                  const Divider(),
                  _buildSummaryRow('Forward To', _destinationController.text.trim()),
                  const Divider(),
                  _buildSummaryRow('Default Limit', '3,000 SMS'),
                  const Divider(),
                  _buildSummaryRow('Default Categories', 'OTP, Debit, Credit, Transaction, UPI'),
                ],
              ),
            ),
          ),

          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _finishOnboarding,
              child: const Text('Enable SMS Forwarding', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required bool isGranted,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isGranted ? Colors.green[300]! : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle : Icons.error_outline,
            color: isGranted ? Colors.green[700] : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
