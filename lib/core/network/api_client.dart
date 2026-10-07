import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../errors/app_exception.dart';

class ApiClient {
  ApiClient({required this.config, this.tokenProvider, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final AppConfig config;
  final Future<String?> Function()? tokenProvider;
  final http.Client _http;

  bool get isConfigured => config.apiConfigured;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    if (!isConfigured) {
      throw const UnavailableException('The security service is not configured on this build.');
    }
    final token = await tokenProvider?.call();
    final response = await _http.post(
      Uri.parse('${config.apiBaseUrl}$path'),
      headers: {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = decoded is Map ? decoded['error']?.toString() : null;
      throw AppException('api', message ?? 'Request failed.');
    }
    return Map<String, dynamic>.from(decoded as Map);
  }
}
