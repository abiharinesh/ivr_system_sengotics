class ApiConfig {
  static const String baseUrl = 'https://ivr-system-sengotics.vercel.app';

  // Auth
  static const String login = '/api/auth/login';

  // Super Admin
  static const String saPanchayats = '/api/superadmin/panchayats';
  static const String saUsers = '/api/superadmin/users';
  static const String saComplaints = '/api/superadmin/complaints';
  static const String saStats = '/api/superadmin/stats';
  static const String saAiProvider = '/api/superadmin/settings/ai-provider';

  // Panchayat Admin
  static const String paMe = '/api/admin/me';
  static const String paStats = '/api/admin/stats';
  static const String paPoles = '/api/admin/poles';
  static const String paComplaints = '/api/admin/complaints';
}
