import 'package:equatable/equatable.dart';

/// The top-level client boundary — one government body that "buys" the
/// software (a specific panchayat, panchayat union, municipality,
/// corporation, etc). Distinct from [PanchayatModel]/OrgUnit, which is a
/// hierarchical node *within* a tenant.
class TenantModel extends Equatable {
  final String id;
  final String slug;
  final String name;
  final String? branchTypeHint;
  final String? domain;
  final String? logoUrl;
  final String subscription;
  final int maxBranches;
  final bool isActive;
  final DateTime? createdAt;

  const TenantModel({
    required this.id,
    required this.slug,
    required this.name,
    this.branchTypeHint,
    this.domain,
    this.logoUrl,
    this.subscription = 'enterprise',
    this.maxBranches = 100,
    this.isActive = true,
    this.createdAt,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as String,
      slug: (json['slug'] as String?) ?? json['id'] as String,
      name: (json['name'] as String?) ?? '',
      branchTypeHint: json['branch_type_hint'] as String?,
      domain: json['domain'] as String?,
      logoUrl: json['logo_url'] as String?,
      subscription: (json['subscription'] as String?) ?? 'enterprise',
      maxBranches: (json['max_branches'] as num?)?.toInt() ?? 100,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        slug,
        name,
        branchTypeHint,
        domain,
        logoUrl,
        subscription,
        maxBranches,
        isActive,
        createdAt,
      ];
}

/// Result of provisioning a brand-new tenant via `POST /tenants/provision`.
class TenantProvisionResult extends Equatable {
  final TenantModel tenant;
  final int rootOrgUnitId;
  final String rootOrgUnitName;
  final String adminEmail;
  final String adminRole;

  const TenantProvisionResult({
    required this.tenant,
    required this.rootOrgUnitId,
    required this.rootOrgUnitName,
    required this.adminEmail,
    required this.adminRole,
  });

  factory TenantProvisionResult.fromJson(Map<String, dynamic> json) {
    final rootOrgUnit = json['root_org_unit'] as Map<String, dynamic>;
    final adminUser = json['admin_user'] as Map<String, dynamic>;
    return TenantProvisionResult(
      tenant: TenantModel.fromJson(json['tenant'] as Map<String, dynamic>),
      rootOrgUnitId: (rootOrgUnit['id'] as num).toInt(),
      rootOrgUnitName: rootOrgUnit['name'] as String? ?? '',
      adminEmail: adminUser['email'] as String? ?? '',
      adminRole: adminUser['role'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [tenant, rootOrgUnitId, rootOrgUnitName, adminEmail, adminRole];
}
