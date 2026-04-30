import 'dart:io';
import 'package:http/http.dart' as http;

const String kUploadUrl = 'https://ai-call-assistant-ohi8.onrender.com/upload';

class UploadService {
  static Future<bool> uploadFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final request = http.MultipartRequest('POST', Uri.parse(kUploadUrl));
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    try {
      final response = await request.send().timeout(const Duration(minutes: 5));
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (_) {
      return false;
    }
  }
}
