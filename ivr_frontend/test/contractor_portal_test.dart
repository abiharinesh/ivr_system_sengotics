import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivr_frontend/features/modules/tenders/data/contractor_portal_repository.dart';
import 'package:ivr_frontend/features/modules/tenders/presentation/screens/contractor_tenders_screen.dart';

/// The screen a contractor signs in to.
///
/// It replaced four static HTML pages in an iframe, so every assertion here is
/// about it showing real state rather than a picture of one.
void main() {
  Map<String, dynamic> tender({
    required int id,
    required String title,
    String state = 'awaiting_your_quote',
    String? expiresAt,
    Map<String, dynamic>? quote,
    bool won = false,
  }) =>
      {
        'invite_id': id,
        'tender_id': id,
        'title': title,
        'title_ta': null,
        'status': 'published',
        'branch': 'Tiruppur City',
        'district': 'Tiruppur',
        'line_item_count': 3,
        'invited_at': '2026-07-01T00:00:00.000Z',
        'expires_at': expiresAt,
        'submitted_at': null,
        'state': state,
        'my_quote': quote,
        'won': won,
      };

  Map<String, dynamic> payload(List<Map<String, dynamic>> tenders,
          {bool blacklisted = false}) =>
      {
        'contractor': {'id': 7, 'name': 'Sree Enterprises'},
        'blacklisted': blacklisted,
        'totals': {
          'invited': tenders.length,
          'awaiting':
              tenders.where((t) => t['state'] == 'awaiting_your_quote').length,
          'submitted': tenders.where((t) => t['state'] == 'submitted').length,
          'closed': tenders.where((t) => t['state'] == 'closed').length,
        },
        'tenders': tenders,
      };

  Future<void> pump(WidgetTester tester, ContractorPortalRepository repo,
      {Size size = const Size(900, 1400)}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ContractorTendersScreen(repository: repo))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('names the firm and what is waiting on them', (tester) async {
    await pump(
      tester,
      _FakeRepo(payload([
        tender(id: 1, title: 'Storm drain desilting', expiresAt: _inDays(9)),
        tender(id: 2, title: 'Bus shelter construction', expiresAt: _inDays(12)),
      ])),
    );

    expect(find.text('Sree Enterprises'), findsOneWidget);
    expect(find.text('2 invitations need your quote'), findsOneWidget);
  });

  testWidgets('says so when nothing is outstanding', (tester) async {
    await pump(
      tester,
      _FakeRepo(payload([
        tender(id: 1, title: 'Done one', state: 'submitted'),
      ])),
    );

    expect(find.text('Nothing is waiting on you'), findsOneWidget);
  });

  testWidgets('marks an invitation closing within three days as urgent',
      (tester) async {
    await pump(
      tester,
      _FakeRepo(payload([
        tender(id: 1, title: 'Closing soon one', expiresAt: _inDays(2)),
        tender(id: 2, title: 'Plenty of time', expiresAt: _inDays(20)),
      ])),
    );

    expect(find.text('Closing soon'), findsOneWidget);
    expect(find.text('Needs your quote'), findsOneWidget);
  });

  testWidgets('shows what they already quoted', (tester) async {
    await pump(
      tester,
      _FakeRepo(payload([
        tender(
          id: 1,
          title: 'Already quoted',
          state: 'submitted',
          quote: {
            'amount': 760000,
            'submitted_at': '2026-07-10T00:00:00.000Z',
            'outcome': 'pending',
          },
        ),
      ])),
    );

    expect(find.textContaining('You quoted'), findsOneWidget);
    expect(find.textContaining('7,60,000'), findsOneWidget);
  });

  testWidgets('celebrates a tender they won', (tester) async {
    await pump(
      tester,
      _FakeRepo(payload([
        tender(id: 1, title: 'Won this', state: 'submitted', won: true),
      ])),
    );

    expect(find.text('Awarded to you'), findsOneWidget);
  });

  testWidgets('filters to one state and back', (tester) async {
    await pump(
      tester,
      _FakeRepo(payload([
        tender(id: 1, title: 'Open one', expiresAt: _inDays(9)),
        tender(id: 2, title: 'Sent one', state: 'submitted'),
      ])),
    );

    expect(find.text('Open one'), findsOneWidget);
    expect(find.text('Sent one'), findsOneWidget);

    await tester.tap(find.textContaining('Needs a quote'));
    await tester.pumpAndSettle();

    expect(find.text('Open one'), findsOneWidget);
    expect(find.text('Sent one'), findsNothing);

    await tester.tap(find.textContaining('Needs a quote'));
    await tester.pumpAndSettle();

    expect(find.text('Sent one'), findsOneWidget);
  });

  testWidgets('explains an empty list rather than showing a blank page',
      (tester) async {
    await pump(tester, _FakeRepo(payload([])));

    expect(find.text('No invitations yet'), findsOneWidget);
    expect(find.textContaining('invites your firm to quote'), findsOneWidget);
  });

  testWidgets('warns a blacklisted firm', (tester) async {
    await pump(
      tester,
      _FakeRepo(payload([
        tender(id: 1, title: 'Something', expiresAt: _inDays(5)),
      ], blacklisted: true)),
    );

    expect(find.textContaining('currently blacklisted'), findsOneWidget);
  });

  testWidgets('surfaces the reason when the login is not linked to a firm',
      (tester) async {
    // The server refuses rather than defaulting; the screen must say why
    // instead of showing an empty list that looks like "no work for you".
    await pump(
      tester,
      _FailingRepo('This login is not linked to a registered contractor.'),
    );

    expect(find.text('Could not load your tenders'), findsOneWidget);
    expect(find.textContaining('not linked to a registered contractor'),
        findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('survives a narrow phone without overflowing', (tester) async {
    await pump(
      tester,
      _FakeRepo(payload([
        tender(
          id: 1,
          title: 'A rather long tender title that will not fit on one line',
          expiresAt: _inDays(2),
          quote: {
            'amount': 1250000,
            'submitted_at': '2026-07-10T00:00:00.000Z',
            'outcome': 'pending',
          },
        ),
      ])),
      size: const Size(320, 900),
    );

    expect(tester.takeException(), isNull);
  });
}

String _inDays(int n) =>
    DateTime.now().add(Duration(days: n, hours: 2)).toIso8601String();

class _FakeRepo implements ContractorPortalRepository {
  _FakeRepo(this._payload);

  final Map<String, dynamic> _payload;

  @override
  Future<ContractorPortal> myTenders({bool forceRefresh = true}) async =>
      ContractorPortal.fromJson(_payload);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

class _FailingRepo implements ContractorPortalRepository {
  _FailingRepo(this.message);

  final String message;

  @override
  Future<ContractorPortal> myTenders({bool forceRefresh = true}) async =>
      throw Exception(message);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}
