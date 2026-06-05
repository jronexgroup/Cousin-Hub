import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

class UpdateService {
  static const String _currentVersion = '1.0.0';
  static final _db = FirebaseDatabase.instance;

  // Call this in main.dart after Firebase init
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final snap = await _db.ref('appConfig').get();
      if (!snap.exists) return;
      final config = Map<String, dynamic>.from(snap.value as Map);
      final latestVersion = config['latestVersion'] ?? '1.0.0';
      final updateUrl = config['updateUrl'] ?? '';
      final forceUpdate = config['forceUpdate'] == true;
      final message = config['updateMessage'] ?? 'New features and improvements!';
      final changelog = config['changelog'] ?? '';

      if (_isNewerVersion(latestVersion, _currentVersion)) {
        if (context.mounted) {
          _showUpdateDialog(context,
            currentVersion: _currentVersion,
            latestVersion: latestVersion,
            updateUrl: updateUrl,
            forceUpdate: forceUpdate,
            message: message,
            changelog: changelog,
          );
        }
      }
    } catch (e) {
      print('Update check failed: $e');
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    final l = latest.split('.').map(int.parse).toList();
    final c = current.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required String updateUrl,
    required bool forceUpdate,
    required String message,
    required String changelog,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (_) => _UpdateDialog(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        updateUrl: updateUrl,
        forceUpdate: forceUpdate,
        message: message,
        changelog: changelog,
      ),
    );
  }

  // Download and install APK
  static Future<void> downloadAndInstall(
    BuildContext context, String url,
    ValueNotifier<double> progress) async {
    try {
      // Request install permission (Android)
      var perm = await Permission.requestInstallPackages.request();
      if (!perm.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Allow install from unknown sources in settings'),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: () => openAppSettings(),
            ),
          ));
        }
        perm = await Permission.requestInstallPackages.request();
        if (!perm.isGranted) {
          if (context.mounted) openAppSettings();
          return;
        }
      }

      final dir = await getExternalStorageDirectory();
      final path = '${dir?.path}/cousin_hub_update.apk';
      final file = File(path);

      // Download with progress
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();
      final total = response.contentLength ?? 0;
      int received = 0;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (total > 0) progress.value = received / total;
      }

      await file.writeAsBytes(bytes);
      progress.value = 1.0;

      // Install
      await OpenFile.open(path, type: 'application/vnd.android.package-archive');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')));
    }
  }
}

class _UpdateDialog extends StatefulWidget {
  final String currentVersion, latestVersion, updateUrl, message, changelog;
  final bool forceUpdate;
  const _UpdateDialog({
    required this.currentVersion, required this.latestVersion,
    required this.updateUrl, required this.forceUpdate,
    required this.message, required this.changelog,
  });
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  final _progress = ValueNotifier<double>(0);
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !widget.forceUpdate,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.none,
        child: SizedBox(
          width: double.infinity,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Close button for non-force updates
            if (!widget.forceUpdate)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B1F0A), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 18))))),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Icon
            Container(width: 72, height: 72,
              decoration: BoxDecoration(gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF60A5FA)]),
                borderRadius: BorderRadius.circular(20)),
              child: const Center(child: Text('🚀', style: TextStyle(fontSize: 36)))),
            const SizedBox(height: 16),

            // Title
            const Text('Update Available!', style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.w800, color: Color(0xFF3B1F0A))),
            const SizedBox(height: 6),

            // Version info
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _versionChip(widget.currentVersion, const Color(0xFFF5EDE4), const Color(0xFF8B6F5E)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16, color: Color(0xFF8B6F5E))),
              _versionChip(widget.latestVersion, const Color(0xFFEDE9FE), const Color(0xFF7C3AED)),
            ]),
            const SizedBox(height: 16),

            // Message
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF5EDE4),
                borderRadius: BorderRadius.circular(12)),
              child: Text(widget.message, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF3B1F0A)))),

            // Changelog
            if (widget.changelog.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(12), width: double.infinity,
                decoration: BoxDecoration(color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("What's new:", style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
                  const SizedBox(height: 4),
                  Text(widget.changelog, style: const TextStyle(fontSize: 12,
                    color: Color(0xFF3B1F0A), height: 1.5)),
                ])),
            ],

            const SizedBox(height: 20),

            // Download progress
            if (_downloading) ...[
              ValueListenableBuilder<double>(
                valueListenable: _progress,
                builder: (_, value, __) => Column(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: value, minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)))),
                  const SizedBox(height: 8),
                  Text('${(value * 100).toInt()}% downloaded',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF8B6F5E))),
                ])),
              const SizedBox(height: 16),
            ],

            // Buttons
            if (!_downloading) Row(children: [
              if (!widget.forceUpdate) Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE8D9C5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Later', style: TextStyle(color: Color(0xFF8B6F5E))))),
              if (!widget.forceUpdate) const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () async {
                  setState(() => _downloading = true);
                  await UpdateService.downloadAndInstall(context, widget.updateUrl, _progress);
                  setState(() => _downloading = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                child: Ink(decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF60A5FA)]),
                  borderRadius: BorderRadius.circular(100)),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: const Text('Update Now ⬇️', style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 14)))))),
            ]),
          ]),       // ] inner Column children, ) inner Column
        ),          // ) Padding
        ]),         // ] outer Column children, ) outer Column
      ),            // ) SizedBox
    ));             // ) Dialog, ) WillPopScope
  }

  Widget _versionChip(String version, Color bg, Color text) =>
    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text('v$version', style: TextStyle(fontSize: 13,
        fontWeight: FontWeight.w700, color: text)));
}
