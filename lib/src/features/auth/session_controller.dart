import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

enum SessionStatus { loading, signedOut, signedIn }

class SessionState {
  const SessionState(this.status, {this.name, this.email, this.error});

  final SessionStatus status;
  final String? name;
  final String? email;
  final String? error;
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  late ApiClient _api;

  @override
  SessionState build() {
    _api = ref.read(apiClientProvider);
    Future.microtask(_restore);
    return const SessionState(SessionStatus.loading);
  }

  Future<void> _restore() async {
    try {
      final token = await _api.readToken();
      if (token == null) {
        state = const SessionState(SessionStatus.signedOut);
        return;
      }
      final response = await _api.dio.get('me');
      final data = _payload(response.data);
      state = SessionState(
        SessionStatus.signedIn,
        name: data['name']?.toString(),
        email: data['email']?.toString(),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        await _api.clearToken();
      }
      state = SessionState(SessionStatus.signedOut, error: _message(error));
    } catch (_) {
      state = const SessionState(SessionStatus.signedOut);
    }
  }

  Future<void> login(String email, String password) async {
    state = const SessionState(SessionStatus.loading);
    try {
      final response = await _api.dio.post(
        'auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      final data = _payload(response.data);
      final token = data['token']?.toString();
      if (token == null || token.isEmpty) {
        throw const FormatException(
          'The server response did not include a token.',
        );
      }
      await _api.saveToken(token);
      final user = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'])
          : data;
      state = SessionState(
        SessionStatus.signedIn,
        name: user['name']?.toString(),
        email: user['email']?.toString() ?? email.trim(),
      );
    } on DioException catch (error) {
      state = SessionState(SessionStatus.signedOut, error: _message(error));
    } on FormatException catch (error) {
      state = SessionState(SessionStatus.signedOut, error: error.message);
    } on StateError catch (error) {
      state = SessionState(SessionStatus.signedOut, error: error.message);
    }
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('auth/logout');
    } catch (_) {
      // Always clear the device token, even when the server cannot be reached.
    }
    await _api.clearToken();
    state = const SessionState(SessionStatus.signedOut);
  }
}

Map<String, dynamic> _payload(dynamic body) {
  if (body is! Map) throw const FormatException('Unexpected server response.');
  final root = Map<String, dynamic>.from(body);
  return root['data'] is Map ? Map<String, dynamic>.from(root['data']) : root;
}

String _message(DioException error) {
  if (error.response?.statusCode == 401) {
    return 'Email or password is incorrect.';
  }
  if (error.response?.statusCode == 403) {
    return 'This account is not authorised for mobile entry.';
  }
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout) {
    return 'Could not reach Nadu System. Check your internet connection.';
  }
  final body = error.response?.data;
  if (body is Map && body['message'] is String) {
    return body['message'] as String;
  }
  return 'Sign in could not be completed. Please try again.';
}
