import 'dart:async';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/services/billing_service.dart';
import 'package:photos/services/collections_service.dart';
import 'package:photos/services/memories_service.dart';
import 'package:photos/services/sync_service.dart';
import 'package:photos/ui/home_widget.dart';
import 'package:photos/utils/crypto_util.dart';
import 'package:sentry/sentry.dart';
import 'package:super_logging/super_logging.dart';
import 'package:logging/logging.dart';

final _logger = Logger("main");
bool _isInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _runWithLogs(_main);
}

void _main() {
  final SentryClient sentry =
      new SentryClient(dsn: kDebugMode ? SENTRY_DEBUG_DSN : SENTRY_DSN);

  FlutterError.onError = (FlutterErrorDetails details) async {
    FlutterError.dumpErrorToConsole(details, forceReport: true);
    _sendErrorToSentry(sentry, details.exception, details.stack);
  };

  runZoned(
    () async {
      await _init();
      _sync();
      runApp(MyApp());
      BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
    },
    onError: (Object error, StackTrace stackTrace) {
      _sendErrorToSentry(sentry, error, stackTrace);
    },
  );
}

Future _init() async {
  _logger.info("Initializing...");
  InAppPurchaseConnection.enablePendingPurchases();
  CryptoUtil.init();
  await Configuration.instance.init();
  await BillingService.instance.init();
  await CollectionsService.instance.init();
  await SyncService.instance.init();
  await MemoriesService.instance.init();
  _isInitialized = true;
  _logger.info("Initialization done");
}

Future<void> _sync({bool isAppInBackground = false}) async {
  try {
    await SyncService.instance.sync(isAppInBackground: isAppInBackground);
  } catch (e, s) {
    _logger.severe("Sync error", e, s);
  }
}

/// This "Headless Task" is run when app is terminated.
void backgroundFetchHeadlessTask(String taskId) async {
  print("[BackgroundFetch] Headless event received: $taskId");
  if (!_isInitialized) {
    await _runWithLogs(() async {
      await _init();
      await _sync(isAppInBackground: true);
    });
  } else {
    await _sync(isAppInBackground: true);
  }
  BackgroundFetch.finish(taskId);
}

Future _runWithLogs(Function() function) async {
  await SuperLogging.main(LogConfig(
    body: function,
    logDirPath: (await getTemporaryDirectory()).path + "/logs",
    enableInDebugMode: true,
    maxLogFiles: 5,
  ));
}

void _sendErrorToSentry(SentryClient sentry, Object error, StackTrace stack) {
  _logger.shout("Uncaught error", error, stack);
  try {
    sentry.captureException(
      exception: error,
      stackTrace: stack,
    );
    print('Error sent to sentry.io: $error');
  } catch (e) {
    print('Sending report to sentry.io failed: $e');
    print('Original error: $error');
  }
}

class MyApp extends StatelessWidget with WidgetsBindingObserver {
  final _title = 'ente';
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addObserver(this);

    // Configure BackgroundFetch.
    BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15,
          forceAlarmManager: false,
          stopOnTerminate: false,
          startOnBoot: true,
          enableHeadless: true,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresStorageNotLow: false,
          requiresDeviceIdle: false,
          requiredNetworkType: NetworkType.NONE,
        ), (String taskId) async {
      print("[BackgroundFetch] event received: $taskId");
      await _sync(isAppInBackground: true);
      BackgroundFetch.finish(taskId);
    }).then((int status) {
      print('[BackgroundFetch] configure success: $status');
    }).catchError((e) {
      print('[BackgroundFetch] configure ERROR: $e');
    });

    return MaterialApp(
      title: _title,
      theme: ThemeData(
        fontFamily: 'Ubuntu',
        brightness: Brightness.dark,
        hintColor: Colors.grey,
        accentColor: Color.fromRGBO(45, 194, 98, 1.0),
        buttonColor: Color.fromRGBO(45, 194, 98, 1.0),
        buttonTheme: ButtonThemeData().copyWith(
          buttonColor: Color.fromRGBO(45, 194, 98, 1.0),
        ),
        toggleableActiveColor: Colors.green[400],
        scaffoldBackgroundColor: Colors.black,
        backgroundColor: Colors.black,
        appBarTheme: AppBarTheme().copyWith(
          color: Color.fromRGBO(10, 20, 20, 1.0),
        ),
        cardColor: Color.fromRGBO(25, 25, 25, 1.0),
        dialogTheme: DialogTheme().copyWith(
          backgroundColor: Color.fromRGBO(20, 20, 20, 1.0),
        ),
      ),
      home: HomeWidget(_title),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _logger.info("App resumed");
      _sync();
    }
  }
}
