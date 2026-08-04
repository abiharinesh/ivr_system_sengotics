import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ivr_frontend/core/models/user_model.dart';
import 'package:ivr_frontend/features/auth/data/auth_repository.dart';

/// The `must_change_password` flag has to survive three hops: the login
/// response, the local cache it is restored from, and the profile refresh that
/// overwrites the cached copy. Losing it at any one of them lets a provisioned
/// account past the gate, which is exactly the failure this covers.

/// A JWT whose payload decodes to [payload]. Unsigned — `AuthResponse` only
/// reads the claims, it does not verify them.
String fakeJwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg(payload)}.signature';
}

void main() {
  const claims = {
    'sub': 42,
    'email': 'registrar.annur@example.gov.in',
    'role': 'registrar',
    'org_unit_id': 7,
    'permissions': ['vital_events.read'],
    'screens': ['home', 'vital_events'],
  };

  group('login response', () {
    test('carries the flag when the account is still on its issued password', () {
      final r = AuthResponse.fromJson({
        'access_token': fakeJwt(claims),
        'role': 'registrar',
        'org_unit_id': 7,
        'must_change_password': true,
      });

      expect(r.user.mustChangePassword, isTrue);
    });

    test('is false for an account that has set its own password', () {
      final r = AuthResponse.fromJson({
        'access_token': fakeJwt(claims),
        'role': 'registrar',
        'must_change_password': false,
      });

      expect(r.user.mustChangePassword, isFalse);
    });

    test('defaults to false when the server omits it', () {
      // An older server must not lock every user out of the product.
      final r = AuthResponse.fromJson({
        'access_token': fakeJwt(claims),
        'role': 'registrar',
      });

      expect(r.user.mustChangePassword, isFalse);
    });
  });

  group('cache round-trip', () {
    test('survives being written and read back', () {
      const user = UserModel(
        id: 42,
        email: 'registrar.annur@example.gov.in',
        role: 'registrar',
        mustChangePassword: true,
      );

      final restored = UserModel.fromJson(
        jsonDecode(jsonEncode(user.toJson())) as Map<String, dynamic>,
      );

      expect(restored.mustChangePassword, isTrue);
    });

    test('a cleared flag stays cleared', () {
      const user = UserModel(id: 42, email: 'a@b.gov.in', role: 'clerk');

      final restored = UserModel.fromJson(
        jsonDecode(jsonEncode(user.toJson())) as Map<String, dynamic>,
      );

      expect(restored.mustChangePassword, isFalse);
    });
  });

  group('profile refresh', () {
    test('reads the flag from the /me payload', () {
      // The session-restore path overwrites the cached user with this. If the
      // endpoint stops returning the field, the gate silently reopens.
      final fresh = UserModel.fromJson({
        'id': 42,
        'email': 'registrar.annur@example.gov.in',
        'role': 'registrar',
        'must_change_password': true,
      });

      expect(fresh.mustChangePassword, isTrue);
    });
  });

  group('copyWith', () {
    const user = UserModel(
      id: 42,
      email: 'registrar.annur@example.gov.in',
      role: 'registrar',
      orgUnitName: 'Annur Town Panchayat',
      permissions: ['vital_events.read'],
      screens: ['home'],
      mustChangePassword: true,
    );

    test('clears the flag without disturbing anything else', () {
      final after = user.copyWith(mustChangePassword: false);

      expect(after.mustChangePassword, isFalse);
      expect(after.id, user.id);
      expect(after.role, user.role);
      expect(after.orgUnitName, user.orgUnitName);
      expect(after.permissions, user.permissions);
      expect(after.screens, user.screens);
    });

    test('leaves the flag alone when not passed', () {
      expect(user.copyWith(screens: const ['home', 'search']).mustChangePassword,
          isTrue);
    });

    test('produces a value-equal model when nothing changes', () {
      expect(user.copyWith(), equals(user));
    });

    test('compares unequal once the flag differs', () {
      // Equality has to notice, or the bloc emits a state the router ignores.
      expect(user.copyWith(mustChangePassword: false), isNot(equals(user)));
    });
  });

  group('PasswordVerdict', () {
    test('parses a graded candidate', () {
      final v = PasswordVerdict.fromJson({
        'min_length': 10,
        'requirements': ['At least 10 characters'],
        'check': {'ok': false, 'score': 2, 'problems': ['Include a symbol']},
      });

      expect(v.ok, isFalse);
      expect(v.score, 2);
      expect(v.problems, ['Include a symbol']);
      expect(v.minLength, 10);
      expect(v.label, 'Fair');
    });

    test('parses the rules with no candidate graded', () {
      final v = PasswordVerdict.fromJson({
        'min_length': 10,
        'requirements': ['At least 10 characters', 'A digit'],
        'check': null,
      });

      expect(v.ok, isFalse);
      expect(v.problems, isEmpty);
      expect(v.requirements, hasLength(2));
    });

    test('labels every score', () {
      String labelFor(int score) => PasswordVerdict.fromJson({
            'check': {'ok': true, 'score': score, 'problems': []},
          }).label;

      expect(labelFor(0), 'Very weak');
      expect(labelFor(1), 'Weak');
      expect(labelFor(2), 'Fair');
      expect(labelFor(3), 'Strong');
      expect(labelFor(4), 'Very strong');
    });

    test('falls back safely on a malformed payload', () {
      final v = PasswordVerdict.fromJson({});

      expect(v.ok, isFalse);
      expect(v.score, 0);
      expect(v.minLength, 10);
    });
  });
}
