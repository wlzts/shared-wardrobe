import 'dart:convert';
import 'package:http/http.dart' as http;

class GitHubService {
  String username = '';
  String repo = '';
  String token = '';
  String branch = 'main';

  static final GitHubService _instance = GitHubService._internal();
  factory GitHubService() => _instance;
  GitHubService._internal();

  void init({required String username, required String repo, required String token, String branch = 'main'}) {
    this.username = username;
    this.repo = repo;
    this.token = token;
    this.branch = branch;
  }

  bool get isConfigured => username.isNotEmpty && repo.isNotEmpty && token.isNotEmpty;

  Map<String, String> get _headers => {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      };

  String get _apiBase => 'https://api.github.com/repos/$username/$repo';

  Future<Map<String, dynamic>?> getFile(String path) async {
    try {
      final url = '$_apiBase/contents/$path?ref=$branch';
      final res = await http.get(Uri.parse(url), headers: _headers);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map && data['content'] != null) {
          final content = utf8.decode(base64.decode(data['content']));
          return {'content': content, 'sha': data['sha']};
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> putFile(String path, String content, {String? sha, String message = 'update'}) async {
    try {
      final url = '$_apiBase/contents/$path';
      final body = {
        'message': message,
        'content': base64.encode(utf8.encode(content)),
        'branch': branch,
      };
      if (sha != null) body['sha'] = sha;
      final res = await http.put(Uri.parse(url), headers: _headers, body: json.encode(body));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteFile(String path, String sha, {String message = 'delete'}) async {
    try {
      final url = '$_apiBase/contents/$path';
      final body = {'message': message, 'sha': sha, 'branch': branch};
      final res = await http.delete(Uri.parse(url), headers: _headers, body: json.encode(body));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> uploadImage(String path, List<int> bytes, {String? sha, String message = 'upload image'}) async {
    try {
      final url = '$_apiBase/contents/$path';
      final body = {
        'message': message,
        'content': base64.encode(bytes),
        'branch': branch,
      };
      if (sha != null) body['sha'] = sha;
      final res = await http.put(Uri.parse(url), headers: _headers, body: json.encode(body));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  String rawUrl(String path) {
    if (path.isEmpty) return '';
    return 'https://raw.githubusercontent.com/$username/$repo/$branch/$path';
  }
}
