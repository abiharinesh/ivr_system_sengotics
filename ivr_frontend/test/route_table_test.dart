import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural checks on the route table.
///
/// These read the router source rather than pumping the app, because the thing
/// being checked is the *order* routes are declared in — a property of the
/// table itself that no single screen test can see.
///
/// The bug that prompted them: `/tenders/vendor-portal` was declared after
/// `/tenders/:id`. go_router matches in declaration order, so the bidding
/// portal was routed as a tender whose id is the word "vendor-portal", and
/// `int.parse` threw a FormatException that took down the whole app rather
/// than the one route. It reached production.
void main() {
  final source = File('lib/config/app_router.dart').readAsStringSync();
  final lines = source.split(RegExp(r'\r?\n'));

  final routes = <({String path, int line})>[];
  for (var i = 0; i < lines.length; i++) {
    final m = RegExp(r"^\s*path:\s*'([^']+)'").firstMatch(lines[i]);
    if (m != null) routes.add((path: m.group(1)!, line: i + 1));
  }

  test('the router declares routes', () {
    // Guards the parsing above: if the file's shape changes and this finds
    // nothing, the checks below would pass vacuously.
    expect(routes.length, greaterThan(50));
  });

  test('no literal route is shadowed by an earlier pattern route', () {
    final shadowed = <String>[];

    for (final route in routes) {
      if (route.path.contains(':')) continue;
      final segments = route.path.split('/');

      for (final other in routes) {
        if (other.line >= route.line || !other.path.contains(':')) continue;
        final otherSegments = other.path.split('/');
        if (otherSegments.length != segments.length) continue;

        final matches = List.generate(segments.length, (i) => i).every(
          (i) =>
              otherSegments[i].startsWith(':') ||
              otherSegments[i] == segments[i],
        );

        if (matches) {
          shadowed.add(
            '${route.path} (line ${route.line}) is unreachable: '
            '${other.path} (line ${other.line}) matches it first',
          );
        }
      }
    }

    expect(shadowed, isEmpty, reason: shadowed.join('\n'));
  });

  test('no route builder parses an id without handling a bad one', () {
    // `int.parse` in a builder throws on a non-numeric segment, and a throw
    // inside a route builder is not recoverable — the app goes blank. `_byId`
    // parses defensively and shows a message instead.
    final offenders = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains('int.parse(state.pathParameters')) {
        offenders.add('line ${i + 1}: ${lines[i].trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'use _byId(state, ...) instead:\n${offenders.join('\n')}',
    );
  });

  test('the bidding portal is reachable', () {
    // The specific regression, named so a failure says what broke.
    final portal = routes.indexWhere((r) => r.path == '/tenders/vendor-portal');
    final byId = routes.indexWhere((r) => r.path == '/tenders/:id');

    expect(portal, isNot(-1), reason: '/tenders/vendor-portal is not routed');
    expect(byId, isNot(-1), reason: '/tenders/:id is not routed');
    expect(
      portal,
      lessThan(byId),
      reason: '/tenders/vendor-portal must be declared before /tenders/:id',
    );
  });
}
