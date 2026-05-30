import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static const String _prodBaseUrl = 'https://ivr-system-sengotics.vercel.app';
  static const String _localBaseUrl = 'http://localhost:3000';

  /// Override order: `--dart-define=API_BASE_URL=...` → `.env` `API_BASE_URL` → defaults.
  /// Defaults: release builds → prod; debug builds → http://localhost:3000 (web + mobile/desktop).
  /// Web release without an override still falls back to prod for hosted deploys.
  static String get baseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    String? fromEnv;
    try {
      fromEnv = dotenv.env['API_BASE_URL']?.trim();
    } catch (_) {
      // dotenv may not be initialized yet (e.g. in tests); fall through to defaults.
      fromEnv = null;
    }
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }
    if (!kReleaseMode) {
      return _localBaseUrl;
    }
    return _prodBaseUrl;
  }

  /// Frontend origin used when generating shareable web links.
  /// Override order: `--dart-define=WEB_APP_BASE_URL=...` -> `.env` -> current browser origin (web) -> API_BASE_URL.
  static String get webAppBaseUrl {
    const fromDefine = String.fromEnvironment('WEB_APP_BASE_URL', defaultValue: '');
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    String? fromEnv;
    try {
      fromEnv = dotenv.env['WEB_APP_BASE_URL']?.trim();
    } catch (_) {
      fromEnv = null;
    }
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty) return origin;
    }
    return baseUrl;
  }

  static String webUrl(String path) {
    final cleanBase = webAppBaseUrl.endsWith('/')
        ? webAppBaseUrl.substring(0, webAppBaseUrl.length - 1)
        : webAppBaseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$cleanBase$cleanPath';
  }

  /// Public URLs for files served at `/uploads/...` on the API host.
  static String fileUrl(String? relativeOrAbsolute) {
    if (relativeOrAbsolute == null || relativeOrAbsolute.isEmpty) {
      return '';
    }
    if (relativeOrAbsolute.startsWith('http')) {
      return relativeOrAbsolute;
    }
    return '$baseUrl$relativeOrAbsolute';
  }
  // Auth
  static const String login = '/api/auth/login';

  // Super Admin
  static const String saPanchayats = '/api/superadmin/panchayats';
  static const String saUsers = '/api/superadmin/users';
  static const String saComplaints = '/api/superadmin/complaints';
  static const String saStats = '/api/superadmin/stats';
  static const String saDashboardInsights = '/api/superadmin/dashboard/insights';
  static const String saPoles = '/api/superadmin/poles';
  static const String saSttProvider = '/api/superadmin/settings/stt-provider';
  static const String saLlmProvider = '/api/superadmin/settings/llm-provider';
  static const String saDocumentTemplates =
      '/api/superadmin/settings/document-templates';
  static const String paDocumentTemplates =
      '/api/admin/settings/document-templates';
  static const String saElectricians = '/api/superadmin/electricians';
  static const String saExportElectricianResolved =
      '/api/superadmin/exports/electrician-resolved';
  static String saExportJob(int jobId) => '/api/superadmin/exports/$jobId';
  static String saExportDownload(int jobId) =>
      '/api/superadmin/exports/$jobId/download';

  // Panchayat Admin
  static const String paMe = '/api/admin/me';
  static const String paStats = '/api/admin/stats';
  static const String paDashboardInsights = '/api/admin/dashboard/insights';
  static const String paPoles = '/api/admin/poles';
  static const String paComplaints = '/api/admin/complaints';
  static const String paElectricians = '/api/admin/electricians';
  static const String paExportElectricianResolved =
      '/api/admin/exports/electrician-resolved';
  static String paExportJob(int jobId) => '/api/admin/exports/$jobId';
  static String paExportDownload(int jobId) =>
      '/api/admin/exports/$jobId/download';

  // Field agent (pole geophotos)
  static const String agentPoles = '/api/agent/poles';

  // Electrician
  static const String electricianMe = '/api/electrician/me';
  static const String electricianComplaints = '/api/electrician/complaints';

  // Zone Management
  static const String paZones = '/api/admin/zones';
  static const String paZoneLookup = '/api/admin/zones/lookup-boundary';
  static const String saZones = '/api/superadmin/zones';
  static const String saZoneLookup = '/api/superadmin/zones/lookup-boundary';
  static String saZonesForPanchayat(int id) => '/api/superadmin/zones/$id';
}
