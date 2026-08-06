import 'dart:convert';
import 'package:equatable/equatable.dart';

import 'package:ivr_frontend/core/navigation/role_navigation_config.dart'
    show NavScreen;

int _jsonInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? _jsonIntOpt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// One role/org-unit assignment a user holds (mirrors backend `UserRole`).
/// A user can hold several of these; [UserModel.role] always reflects the
/// currently active one (kept in sync via /api/auth/switch-context).
class UserRoleAssignment extends Equatable {
  final int id;
  final String roleName;
  final int? orgUnitId;
  final bool isSuperAdmin;

  const UserRoleAssignment({
    required this.id,
    required this.roleName,
    this.orgUnitId,
    this.isSuperAdmin = false,
  });

  factory UserRoleAssignment.fromJson(Map<String, dynamic> json) {
    return UserRoleAssignment(
      id: _jsonInt(json['id']),
      roleName: (json['name'] as String?) ?? '',
      orgUnitId: _jsonIntOpt(json['org_unit_id']),
      isSuperAdmin: json['is_super_admin'] == true,
    );
  }

  @override
  List<Object?> get props => [id, roleName, orgUnitId, isSuperAdmin];
}

class UserModel extends Equatable {
  final int id;
  final String email;
  final String role;
  final String? phone;
  final int? orgUnitId;
  final String? orgUnitName;
  final String? branchType;
  final String? softwareNameTa;
  final String? softwareNameEn;
  final String? softwareTaglineTa;
  final String? softwareTaglineEn;
  final String? logoUrl;
  final String? secondaryLogoUrl;
  final String? primaryColor;
  final String? district;
  final String? address;
  final String? contactPhone;
  final String? contactEmail;
  final String? ivrNumber;
  final String? employeeCode;
  final String? cadre;
  final String? designation;
  final String? serviceBookNumber;
  final String? photoUrl;
  final DateTime? createdAt;
  final List<UserRoleAssignment> roleAssignments;
  final String accessScope;
  final List<String> permissions;

  /// Screen keys this user may see in the sidebar, resolved server-side from
  /// their role grants. Empty means "server did not say" — see [canSeeScreen].
  final List<String> screens;

  /// The same screens with the route, label, icon and group needed to draw
  /// them, in catalogue order.
  ///
  /// Carried separately from [screens] because the JWT holds only the keys —
  /// a token should not grow every time a module ships — while the sidebar
  /// needs the rest, which arrives from `GET /api/rbac/me/entitlements`.
  final List<NavScreen> nav;

  /// The account is still on the password it was issued. Every provisioned
  /// account starts this way, and the router holds the user on the
  /// change-password screen until it clears.
  final bool mustChangePassword;

  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.phone,
    this.orgUnitId,
    this.orgUnitName,
    this.branchType,
    this.softwareNameTa,
    this.softwareNameEn,
    this.softwareTaglineTa,
    this.softwareTaglineEn,
    this.logoUrl,
    this.secondaryLogoUrl,
    this.primaryColor,
    this.district,
    this.address,
    this.contactPhone,
    this.contactEmail,
    this.ivrNumber,
    this.employeeCode,
    this.cadre,
    this.designation,
    this.serviceBookNumber,
    this.photoUrl,
    this.createdAt,
    this.roleAssignments = const [],
    this.accessScope = 'own_org_unit',
    this.permissions = const [],
    this.screens = const [],
    this.nav = const [],
    this.mustChangePassword = false,
  });

  /// Narrow copy for the few fields that change within a session.
  ///
  /// Only what actually mutates after sign-in is exposed: everything else on
  /// this model comes from the token or the branch record and changing it
  /// locally would put the client out of step with the server.
  UserModel copyWith({
    bool? mustChangePassword,
    List<String>? screens,
    List<NavScreen>? nav,
  }) {
    return UserModel(
      id: id,
      email: email,
      role: role,
      phone: phone,
      orgUnitId: orgUnitId,
      orgUnitName: orgUnitName,
      branchType: branchType,
      softwareNameTa: softwareNameTa,
      softwareNameEn: softwareNameEn,
      softwareTaglineTa: softwareTaglineTa,
      softwareTaglineEn: softwareTaglineEn,
      logoUrl: logoUrl,
      secondaryLogoUrl: secondaryLogoUrl,
      primaryColor: primaryColor,
      district: district,
      address: address,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      ivrNumber: ivrNumber,
      employeeCode: employeeCode,
      cadre: cadre,
      designation: designation,
      serviceBookNumber: serviceBookNumber,
      photoUrl: photoUrl,
      createdAt: createdAt,
      roleAssignments: roleAssignments,
      accessScope: accessScope,
      permissions: permissions,
      screens: screens ?? this.screens,
      nav: nav ?? this.nav,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final panchayat = json['org_unit'] as Map<String, dynamic>?;
    final employee = json['employee'] as Map<String, dynamic>?;
    final rbacRoles = json['rbac_roles'] as List<dynamic>?;
    return UserModel(
      id: _jsonInt(json['id']),
      email: (json['email'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'user',
      phone: json['phone_e164'] as String?,
      orgUnitId: _jsonIntOpt(json['org_unit_id']),
      roleAssignments: rbacRoles
              ?.map((r) => UserRoleAssignment.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const [],
      accessScope: (json['access_scope'] as String?) ?? 'own_org_unit',
      permissions: (json['permissions'] as List<dynamic>?)?.cast<String>() ?? const [],
      screens: (json['screens'] as List<dynamic>?)?.cast<String>() ?? const [],
      // Absent on the JWT, which carries keys alone; filled in from
      // `/api/rbac/me/entitlements`.
      nav: (json['nav'] as List<dynamic>?)
              ?.map((e) => NavScreen.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      mustChangePassword: json['must_change_password'] == true,
      orgUnitName: panchayat?['name'] as String?,
      branchType: panchayat?['branch_type'] as String?,
      softwareNameTa: panchayat?['software_name_ta'] as String?,
      softwareNameEn: panchayat?['software_name_en'] as String?,
      softwareTaglineTa: panchayat?['software_tagline_ta'] as String?,
      softwareTaglineEn: panchayat?['software_tagline_en'] as String?,
      logoUrl: panchayat?['logo_url'] as String?,
      secondaryLogoUrl: panchayat?['secondary_logo_url'] as String?,
      primaryColor: panchayat?['primary_color'] as String?,
      district: panchayat?['district'] as String?,
      address: panchayat?['address'] as String?,
      contactPhone: panchayat?['contact_phone'] as String?,
      contactEmail: panchayat?['contact_email'] as String?,
      ivrNumber: panchayat?['ivr_number'] as String?,
      employeeCode: employee?['employee_code'] as String?,
      cadre: employee?['cadre'] as String?,
      designation: employee?['designation'] as String?,
      serviceBookNumber: employee?['service_book_number'] as String?,
      photoUrl: employee?['photo_url'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String)
              : null,
    );
  }

  String get dynamicSoftwareName {
    if (softwareNameTa != null && softwareNameTa!.isNotEmpty) {
      return softwareNameTa!;
    }
    if (softwareNameEn != null && softwareNameEn!.isNotEmpty) {
      return softwareNameEn!;
    }
    switch (branchType) {
      case 'MUNICIPALITY':
        return 'நகராட்சி குரல்';
      case 'MUNICIPAL_CORPORATION':
        return 'மாநகராட்சி குரல்';
      case 'TOWN_PANCHAYAT':
        return 'பேரூராட்சி குரல்';
      case 'PANCHAYAT_UNION':
        return 'ஊராட்சி ஒன்றிய குரல்';
      case 'DISTRICT_PANCHAYAT':
        return 'மாவட்ட ஊராட்சி குரல்';
      case 'VILLAGE_PANCHAYAT':
      default:
        return 'கிராம ஊராட்சி குரல்';
    }
  }

  /// Currently active role assignment (matches the switched/primary context).
  UserRoleAssignment? get activeRoleAssignment =>
      roleAssignments.isEmpty ? null : roleAssignments.first;

  bool hasPermission(String code) => permissions.contains(code);

  /// Whether a sidebar destination should be rendered for this user.
  ///
  /// A super admin sees everything. Otherwise the answer is the server's
  /// `screens` list — which is what makes the super admin console's toggles
  /// take effect, instead of the sidebar being decided by a hardcoded map of
  /// role-name strings that no administrator can reach.
  ///
  /// An **empty** list is treated as "the server did not tell us", not "this
  /// user may see nothing": a token issued before this field existed, or a
  /// database without the RBAC migration applied, must not lock a legitimate
  /// user out of their own menu. Once the server sends any screens at all, the
  /// list is authoritative.
  bool canSeeScreen(String key) {
    if (isSuperAdmin) return true;
    if (screens.isEmpty) return true;
    return screens.contains(key);
  }

  /// True when the server has actually resolved entitlements for this session.
  bool get hasResolvedScreens => isSuperAdmin || screens.isNotEmpty;

  bool get isSuperAdmin =>
      role == 'super_admin' || roleAssignments.any((r) => r.isSuperAdmin);
  bool get isPanchayatAdmin => role == 'panchayat_admin';
  bool get isAgent => role == 'agent';
  bool get isElectrician => role == 'electrician';
  bool get isPlumber => role == 'plumber';
  bool get isCitizen => role == 'citizen';
  bool get isMunicipalCommissioner => role == 'municipal_commissioner';
  bool get isMunicipalEngineer => role == 'municipal_engineer';
  bool get isRevenueOfficer => role == 'revenue_officer';
  bool get isAssistantEngineer => role == 'assistant_engineer';
  bool get isHealthOfficer => role == 'health_officer';
  bool get isRevenueInspector => role == 'revenue_inspector';
  bool get isJuniorEngineer => role == 'junior_engineer';
  bool get isI3cStaff => role == 'i3c_staff';
  bool get isContractor => role == 'contractor';

  /// Org-unit-scoped field roles share the same org_unit_id as admins.
  bool get isFieldStaff => isAgent || isElectrician || isPlumber || isJuniorEngineer;

  /// Executive-level roles that get the admin shell with full sidebar.
  bool get isExecutive => isSuperAdmin || isPanchayatAdmin || isMunicipalCommissioner || isMunicipalEngineer;

  /// Human-readable display name for the role.
  String get displayRoleName {
    switch (role) {
      case 'super_admin': return 'Super Administrator';
      case 'panchayat_admin': return 'Panchayat Admin';
      case 'municipal_commissioner': return 'Municipal Commissioner';
      case 'municipal_engineer': return 'Municipal Engineer';
      case 'revenue_officer': return 'Revenue Officer';
      case 'assistant_engineer': return 'Assistant Engineer';
      case 'health_officer': return 'Health Officer';
      case 'revenue_inspector': return 'Revenue Inspector';
      case 'junior_engineer': return 'Junior Engineer';
      case 'i3c_staff': return 'I3C Command Center';
      case 'contractor': return 'Contractor / Vendor';
      case 'citizen': return 'Citizen';
      case 'agent': return 'Field Agent';
      case 'electrician': return 'Electrician';
      case 'plumber': return 'Plumber';
      default: return role;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'phone_e164': phone,
      'org_unit_id': orgUnitId,
      'created_at': createdAt?.toIso8601String(),
      'must_change_password': mustChangePassword,
      // Persisted so a reload paints the sidebar from cache on the first
      // frame, rather than showing an empty rail until the entitlements
      // request comes back. Round-trips through `fromJson`.
      'permissions': permissions,
      'screens': screens,
      'nav': nav.map((s) => s.toJson()).toList(),
      'employee': {
        'employee_code': employeeCode,
        'cadre': cadre,
        'designation': designation,
        'service_book_number': serviceBookNumber,
        'photo_url': photoUrl,
      },
      'org_unit': {
        'name': orgUnitName,
        'branch_type': branchType,
        'software_name_ta': softwareNameTa,
        'software_name_en': softwareNameEn,
        'software_tagline_ta': softwareTaglineTa,
        'software_tagline_en': softwareTaglineEn,
        'logo_url': logoUrl,
        'secondary_logo_url': secondaryLogoUrl,
        'primary_color': primaryColor,
        'district': district,
        'address': address,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
        'ivr_number': ivrNumber,
      },
    };
  }

  @override
  List<Object?> get props => [
        id,
        email,
        role,
        phone,
        orgUnitId,
        orgUnitName,
        branchType,
        softwareNameTa,
        softwareNameEn,
        softwareTaglineTa,
        softwareTaglineEn,
        logoUrl,
        secondaryLogoUrl,
        primaryColor,
        district,
        address,
        contactPhone,
        contactEmail,
        ivrNumber,
        employeeCode,
        cadre,
        designation,
        serviceBookNumber,
        photoUrl,
        createdAt,
        roleAssignments,
        accessScope,
        permissions,
        screens,
        mustChangePassword,
      ];
}

class AuthResponse {
  final String accessToken;
  final UserModel user;

  AuthResponse({required this.accessToken, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final token = json['access_token'] as String;

    // Decode JWT payload
    final parts = token.split('.');
    Map<String, dynamic> payload = {};
    if (parts.length == 3) {
      final String normalized = base64Url.normalize(parts[1]);
      final String decoded = utf8.decode(base64Url.decode(normalized));
      payload = jsonDecode(decoded);
    }

    return AuthResponse(
      accessToken: token,
      user: UserModel.fromJson({
        'id': _jsonInt(payload['sub']),
        'email': '${payload['email'] ?? json['email'] ?? ''}',
        'role': '${json['role'] ?? payload['role'] ?? 'user'}',
        'org_unit_id':
            _jsonIntOpt(json['org_unit_id']) ?? _jsonIntOpt(payload['org_unit_id']),
        'org_unit': json['org_unit'],
        'rbac_roles': payload['rbac_roles'],
        'access_scope': payload['access_scope'],
        'permissions': payload['permissions'],
        'screens': payload['screens'],
        // Not on the JWT — the flag is account state, and a token minted
        // before the change would otherwise keep asserting it.
        'must_change_password': json['must_change_password'],
      }),
    );
  }
}
