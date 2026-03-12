import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _prodBaseUrl = 'https://ivr-system-sengotics.vercel.app';
  static const String _localBaseUrl = 'http://localhost:3000';

  static String get baseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    return kReleaseMode ? _prodBaseUrl : _localBaseUrl;
  }
  // Auth
  static const String login = '/api/auth/login';

  // Super Admin
  static const String saPanchayats = '/api/superadmin/panchayats';
  static const String saUsers = '/api/superadmin/users';
  static const String saComplaints = '/api/superadmin/complaints';
  static const String saStats = '/api/superadmin/stats';
  static const String saPoles = '/api/superadmin/poles';
  static const String saSttProvider = '/api/superadmin/settings/stt-provider';
  static const String saLlmProvider = '/api/superadmin/settings/llm-provider';

  // Panchayat Admin
  static const String paMe = '/api/admin/me';
  static const String paStats = '/api/admin/stats';
  static const String paPoles = '/api/admin/poles';
  static const String paComplaints = '/api/admin/complaints';
}
