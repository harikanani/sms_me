import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/app_providers.dart';
import 'data/local/app_database.dart';
import 'data/local/preferences_service.dart';
import 'data/native/native_sms_gateway.dart';
import 'data/transports/sms_forwarding_transport.dart';
import 'domain/entities/incoming_sms.dart';
import 'domain/services/forwarding_counter.dart';
import 'domain/services/forwarding_queue.dart';
import 'domain/services/sms_processor.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      child: const SmsForwarderApp(),
    ),
  );
}

/// Top-level or static background SMS handler called by native Kotlin when SMS is received in background
@pragma('vm:entry-point')
Future<void> handleBackgroundSms(Map<String, dynamic> smsMap) async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPrefs = await SharedPreferences.getInstance();
  final prefsService = PreferencesService(sharedPrefs);

  final db = AppDatabase();
  final counter = ForwardingCounter(prefsService);
  final queue = ForwardingQueue(db);
  final gateway = MethodChannelNativeSmsGateway();
  final transport = SmsForwardingTransport(gateway);

  final processor = SmsProcessor(
    prefsService,
    db,
    counter,
    queue,
    transport,
  );

  final incoming = IncomingSms.fromJson(smsMap);
  await processor.processIncomingSms(incoming);
}

class SmsForwarderApp extends ConsumerStatefulWidget {
  const SmsForwarderApp({super.key});

  @override
  ConsumerState<SmsForwarderApp> createState() => _SmsForwarderAppState();
}

class _SmsForwarderAppState extends ConsumerState<SmsForwarderApp> {
  @override
  void initState() {
    super.initState();
    _initGatewayListener();
  }

  Future<void> _initGatewayListener() async {
    final gateway = ref.read(nativeSmsGatewayProvider);
    if (gateway is MethodChannelNativeSmsGateway) {
      gateway.setOnSmsReceivedCallback((smsMap) async {
        final processor = ref.read(smsProcessorProvider);
        final incoming = IncomingSms.fromJson(smsMap);
        await processor.processIncomingSms(incoming);
        ref.read(appSettingsProvider.notifier).refresh();
        ref.invalidate(historyListProvider);
      });
      await gateway.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      title: 'SMS Forwarder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: settings.onboardingCompleted
          ? const DashboardScreen()
          : const OnboardingScreen(),
    );
  }
}
