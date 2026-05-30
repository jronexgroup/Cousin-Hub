import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'dcxpakce2';
  static const String apiKey = '493964167874853';
  static const String apiSecret = 'grWkEG5UMVOzqjrj93GItrvebs8';
  static const String uploadPreset = 'cousin_hub_uploads';

  static Future<String?> uploadImage(File imageFile, {String folder = 'photos'}) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body);
      if (response.statusCode == 200) return json['secure_url'] as String?;
      print('Cloudinary image error: $body');
      return null;
    } catch (e) {
      print('Image upload error: $e');
      return null;
    }
  }

  static Future<String?> uploadVideo(File videoFile, {String folder = 'videos'}) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;
      request.files.add(await http.MultipartFile.fromPath('file', videoFile.path));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body);
      if (response.statusCode == 200) return json['secure_url'] as String?;
      print('Cloudinary video error: $body');
      return null;
    } catch (e) {
      print('Video upload error: $e');
      return null;
    }
  }

  static Future<String?> uploadFile(File file, {String folder = 'files'}) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/raw/upload');
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body);
      if (response.statusCode == 200) return json['secure_url'] as String?;
      return null;
    } catch (e) {
      print('File upload error: $e');
      return null;
    }
  }
}
