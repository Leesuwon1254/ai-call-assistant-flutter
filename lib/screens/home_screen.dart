import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

import '../services/upload_service.dart';
import '../services/background_service.dart';

const String kServerUrl = 'https://ai-call-assistant-ohi8.onrender.com';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final WebViewController _webViewController;
  bool _autoUploadEnabled = false;
  bool _isUploading = false;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _setupWebView();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoUploadEnabled = prefs.getBool('auto_upload') ?? false;
    });
  }

  void _setupWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() {}),
      ))
      ..loadRequest(Uri.parse(kServerUrl));
  }

  Future<void> _toggleAutoUpload(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_upload', value);
    setState(() => _autoUploadEnabled = value);

    if (value) {
      startBackgroundService();
      _addLog('자동 업로드 활성화');
    } else {
      stopBackgroundService();
      _addLog('자동 업로드 비활성화');
    }
  }

  Future<void> _pickAndUpload() async {
    _addLog('파일 선택 시작...');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result == null || result.files.single.path == null) {
        _addLog('파일 선택 취소됨');
        return;
      }
      setState(() => _isUploading = true);
      _addLog('업로드 중: ${result.files.single.name}');
      final success = await UploadService.uploadFile(result.files.single.path!);
      if (success) {
        _addLog('업로드 완료!');
        _webViewController.loadRequest(Uri.parse('$kServerUrl/customers'));
      } else {
        _addLog('업로드 실패 - 서버 오류');
      }
    } catch (e) {
      _addLog('오류 발생: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _addLog(String msg) {
    setState(() {
      _logs.insert(0, '[${TimeOfDay.now().format(context)}] $msg');
      if (_logs.length > 20) _logs.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d6efd),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.phone, size: 20),
            SizedBox(width: 8),
            Text('AI 통화비서', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: '파일 선택 업로드',
            onPressed: _isUploading ? null : _pickAndUpload,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 자동 업로드 토글 바
          Container(
            color: const Color(0xFFe8f0fe),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.auto_mode, size: 18, color: Color(0xFF0d6efd)),
                const SizedBox(width: 8),
                const Text('통화 녹음 자동 분석',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: _autoUploadEnabled,
                  activeColor: const Color(0xFF0d6efd),
                  onChanged: _toggleAutoUpload,
                ),
              ],
            ),
          ),

          // 업로드 중 프로그레스
          if (_isUploading)
            const LinearProgressIndicator(
              backgroundColor: Color(0xFFe8f0fe),
              color: Color(0xFF0d6efd),
            ),

          // WebView (메인)
          Expanded(
            flex: 3,
            child: WebViewWidget(controller: _webViewController),
          ),

          // 로그 패널
          if (_logs.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              color: const Color(0xFF1e1e2e),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (_, i) => Text(
                  _logs[i],
                  style: const TextStyle(color: Color(0xFF90EE90), fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
