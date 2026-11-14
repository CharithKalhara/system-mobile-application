import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://nadu-api.invalid/api/v1/',
);

class ApiClient {
  ApiClient(this._storage)
    : dio = Dio(
        BaseOptions(
          baseUrl: _validatedBaseUrl(),
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 30),
          followRedirects: false,
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.uri.scheme != 'https') {
            return handler.reject(
              DioException(
                requestOptions: options,
                message: 'HTTPS is required.',
              ),
            );
          }
          final token = await _storage.read(key: _tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static const _tokenKey = 'nadu_mobile_access_token';
  final FlutterSecureStorage _storage;
  final Dio dio;

  static String _validatedBaseUrl() {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.path.isEmpty ||
        uri.scheme != 'https') {
      throw StateError(
        'Set API_BASE_URL to the HTTPS /api/v1 endpoint using --dart-define.',
      );
    }
    return apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/';
  }

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
