import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiController {
  final String baseUrl;
  static ApiController? _instance;

  ApiController._internal({this.baseUrl = ''});

  factory ApiController({String baseUrl = ''}) {
    _instance ??= ApiController._internal(baseUrl: baseUrl);
    return _instance!;
  }

  Future<dynamic> get(String endpoint) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, dynamic data) async {
    final headers = await _getHeaders(
      additionalHeaders: {"Content-Type": "application/json"},
    );
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, dynamic data) async {
    final headers = await _getHeaders(
      additionalHeaders: {"Content-Type": "application/json"},
    );
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  Future<Map<String, String>> _getHeaders({
    Map<String, String>? additionalHeaders,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final headers = <String, String>{};

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      throw Exception(
        'HTTP Error: ${response.statusCode} - ${response.reasonPhrase}',
      );
    }
  }
}
