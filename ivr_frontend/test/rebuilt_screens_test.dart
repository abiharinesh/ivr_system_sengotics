import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivr_frontend/features/modules/dms/data/document_repository.dart';
import 'package:ivr_frontend/features/modules/dms/presentation/dms_explorer_screen.dart';
import 'package:ivr_frontend/features/modules/insights/data/service_analytics_repository.dart';
import 'package:ivr_frontend/features/modules/insights/presentation/service_analytics_screen.dart';
import 'package:ivr_frontend/features/modules/ivr_operations/data/ivr_operations_repository.dart';
import 'package:ivr_frontend/features/modules/ivr_operations/presentation/ivr_logs_screen.dart';
import 'package:ivr_frontend/features/modules/ivr_operations/presentation/voice_calls_screen.dart';

/// The four screens rebuilt off mockups.
///
/// Each one shows figures a government officer would act on, so the risk is
/// not that the data is wrong — that is covered server-side — but that the
/// layout breaks on the data it is actually given. A row that overflows at a
/// narrow width, a null the formatter was not expecting, an empty list: these
/// are what the previous pass shipped and only a build caught.
///
/// Every screen is exercised three ways: populated, empty, and at 320px.

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeIvrRepo implements IvrOperationsRepository {
  _FakeIvrRepo({this.voice = const [], this.logs = const [], this.fail = false});

  final List<VoiceCallRecord> voice;
  final List<IvrCallRecord> logs;
  final bool fail;

  @override
  Future<IvrSummary> summary({bool forceRefresh = true}) async {
    if (fail) throw Exception('backend unreachable');
    return const IvrSummary(
      totalCalls: 220,
      callsLast30Days: 220,
      complaintsRaised: 64,
      containmentPct: 29,
      failedProcessing: 70,
      transcribed: 140,
      avgConfidence: 0.81,
    );
  }

  @override
  Future<List<VoiceCallRecord>> voiceCalls({String? search, String? status}) async {
    if (fail) throw Exception('backend unreachable');
    return voice;
  }

  @override
  Future<List<IvrCallRecord>> calls({String? search}) async {
    if (fail) throw Exception('backend unreachable');
    return logs;
  }
}

class _FakeDocRepo implements DocumentRepository {
  _FakeDocRepo({this.docs = const [], this.tree = const []});

  final List<DocumentRecord> docs;
  final List<DocumentFolderNode> tree;

  @override
  Future<List<DocumentFolderNode>> folders() async => tree;

  @override
  Future<DocumentSummary> summary() async => DocumentSummary(
        total: docs.length,
        signed: 0,
        expiringIn30Days: 0,
        totalBytes: 268790403,
        byModule: const [MapEntry('building_permits', 90)],
      );

  @override
  Future<List<DocumentRecord>> list({int? folderId, String? search}) async => docs;
}

class _FakeAnalyticsRepo implements ServiceAnalyticsRepository {
  _FakeAnalyticsRepo({required this.data});

  final ServiceAnalytics data;

  @override
  Future<ServiceAnalytics> overview({int days = 30}) async => data;
}

// ── Fixtures, shaped like what the live database actually returns ────────────

VoiceCallRecord voiceCall({
  int id = 1,
  String? number = '+916349861781',
  String? transcript = 'Two poles opposite the PHC are out.',
  int? complaintId = 113,
  double? confidence = 0.88,
}) =>
    VoiceCallRecord(
      id: id,
      callSid: 'CA784771260111',
      callerNumber: number,
      startedAt: DateTime(2026, 8, 4, 10, 30),
      audioUrl: '/uploads/voice/demo-1.mp3',
      transcript: transcript,
      transcriptEnglish: transcript,
      status: 'completed',
      confidence: confidence,
      attempt: 1,
      complaintId: complaintId,
      complaintStatus: 'pending',
      complaintCategory: 'street_light',
      urgency: 'high',
    );

IvrCallRecord ivrCall({
  String? number = '+919873227832',
  int? duration = 168,
  bool created = false,
  String? error,
}) =>
    IvrCallRecord(
      callSid: 'CA784849580219',
      callerNumber: number,
      callTo: '+914422334455',
      startedAt: DateTime(2026, 8, 4, 9, 15),
      durationSeconds: duration,
      serviceSelected: true,
      selections: const ['2'],
      pollEntered: false,
      finalStatus: 'completed',
      complaintCreated: created,
      complaintId: created ? 88 : null,
      phase1Status: 'completed',
      phase2Status: 'completed',
      lastError: error,
    );

DocumentRecord document({String title = 'Site plan', String? module = 'building_permits'}) =>
    DocumentRecord(
      id: 1,
      title: title,
      fileName: 'site-plan.pdf',
      fileUrl: '/uploads/site-plan.pdf',
      sizeBytes: 3757834,
      mimeType: 'application/pdf',
      version: 1,
      module: module,
      entityType: 'building_permit',
      entityId: 12,
      folderId: 3,
      tags: const [],
      expiresAt: null,
      createdAt: DateTime(2026, 7, 1),
      isSigned: false,
    );

/// Mirrors the figures the live database produced for Coimbatore.
ServiceAnalytics analytics({
  int allTime = 44,
  int sample = 28,
  List<CountBucket> sla = const [
    CountBucket(label: 'breached', count: 70),
    CountBucket(label: 'escalated', count: 2),
    CountBucket(label: 'warning', count: 3),
  ],
  double? satisfaction = 3.4,
}) =>
    ServiceAnalytics(
      windowDays: 30,
      allTime: allTime,
      inWindow: 21,
      open: 16,
      resolved: 28,
      resolutionRatePct: 64,
      avgHours: 90,
      medianHours: 97,
      p90Hours: 138,
      sample: sample,
      slaTracked: 75,
      slaBreached: 70,
      slaCompliancePct: 7,
      slaByStatus: sla,
      satisfaction: satisfaction,
      satisfactionResponses: 10,
      byCategory: const [
        CountBucket(label: 'road', count: 8),
        CountBucket(label: 'water_leak', count: 7),
      ],
      byUrgency: const [CountBucket(label: 'high', count: 12)],
      resolutionByCategory: const [
        CategoryResolution(category: 'garbage', medianHours: 138, resolved: 6),
        CategoryResolution(category: 'water_supply', medianHours: 131, resolved: 5),
      ],
      dailyVolume: [
        for (var i = 0; i < 30; i++)
          CountBucket(label: '2026-07-${(i % 28) + 1}', count: i % 4),
      ],
    );

Future<void> pump(WidgetTester tester, Widget child, {Size size = const Size(1200, 800)}) async {
  await tester.binding.setSurfaceSize(size);
  // Reset inside the test rather than in a global tearDown — setSurfaceSize
  // asserts it is called while a test is running.
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SizedBox.fromSize(size: size, child: child))),
  );
  await tester.pumpAndSettle();
}

void main() {

  group('Voice calls', () {
    testWidgets('shows the transcript, caller and the ticket it raised',
        (tester) async {
      await pump(
        tester,
        VoiceCallsScreen(repository: _FakeIvrRepo(voice: [voiceCall()])),
      );

      expect(find.text('+916349861781'), findsOneWidget);
      expect(find.textContaining('Two poles opposite'), findsOneWidget);
      expect(find.text('Ticket #113'), findsOneWidget);
      // Containment is the number this system exists to move.
      expect(find.text('140'), findsOneWidget);
    });

    testWidgets('says so when a call raised no ticket', (tester) async {
      await pump(
        tester,
        VoiceCallsScreen(
          repository: _FakeIvrRepo(voice: [voiceCall(complaintId: null)]),
        ),
      );
      expect(find.text('No ticket'), findsOneWidget);
    });

    testWidgets('handles a call with no number, transcript or confidence',
        (tester) async {
      await pump(
        tester,
        VoiceCallsScreen(
          repository: _FakeIvrRepo(
            voice: [voiceCall(number: null, transcript: null, confidence: null)],
          ),
        ),
      );
      // Falls back to the call id rather than rendering "null".
      expect(find.text('CA784771260111'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await pump(tester, VoiceCallsScreen(repository: _FakeIvrRepo()));
      expect(find.text('No recorded calls match that'), findsOneWidget);
    });

    testWidgets('offers a retry when the backend is unreachable',
        (tester) async {
      // A separate test rather than a second pump: re-pumping the same widget
      // type reuses the State, and `late final _repo` holds the first
      // repository forever.
      await pump(tester, VoiceCallsScreen(repository: _FakeIvrRepo(fail: true)));
      expect(find.text('Could not load'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('IVR log', () {
    testWidgets('shows what was pressed and where the call ended',
        (tester) async {
      await pump(
        tester,
        IvrLogsScreen(repository: _FakeIvrRepo(logs: [ivrCall()])),
      );

      expect(find.text('+919873227832'), findsOneWidget);
      expect(find.text('2m 48s'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('surfaces the phase that failed', (tester) async {
      await pump(
        tester,
        IvrLogsScreen(
          repository: _FakeIvrRepo(
            logs: [ivrCall(error: 'Recording download timed out after 30s.')],
          ),
        ),
      );
      expect(find.textContaining('timed out'), findsOneWidget);
    });

    testWidgets('"needs a look" hides calls that completed with a ticket',
        (tester) async {
      await pump(
        tester,
        IvrLogsScreen(
          repository: _FakeIvrRepo(logs: [ivrCall(created: true)]),
        ),
      );
      expect(find.text('#88'), findsOneWidget);

      await tester.tap(find.text('Needs a look'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing needs a look'), findsOneWidget);
    });

    testWidgets('handles a call with no duration or number', (tester) async {
      await pump(
        tester,
        IvrLogsScreen(
          repository: _FakeIvrRepo(logs: [ivrCall(number: null, duration: null)]),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Document register', () {
    final tree = [
      const DocumentFolderNode(
        id: 1,
        name: 'Building Permits',
        documentCount: 90,
        children: [
          DocumentFolderNode(
            id: 3,
            name: 'Site Plans',
            documentCount: 0,
            children: [],
          ),
        ],
      ),
    ];

    testWidgets('shows the folder tree with rolled-up counts', (tester) async {
      await pump(
        tester,
        DmsExplorerScreen(
          repository: _FakeDocRepo(docs: [document()], tree: tree),
        ),
      );

      expect(find.text('All documents'), findsOneWidget);
      expect(find.text('Building Permits'), findsOneWidget);
      // Children open by default, or the tree reads as though nothing is filed.
      expect(find.text('Site Plans'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
    });

    testWidgets('shows the file with a readable size', (tester) async {
      await pump(
        tester,
        DmsExplorerScreen(
          repository: _FakeDocRepo(docs: [document()], tree: tree),
        ),
      );
      expect(find.text('Site plan'), findsOneWidget);
      expect(find.textContaining('3.6 MB'), findsOneWidget);
    });

    testWidgets('an empty folder says so', (tester) async {
      await pump(
        tester,
        DmsExplorerScreen(repository: _FakeDocRepo(tree: tree)),
      );
      expect(find.text('This folder is empty'), findsOneWidget);
    });

    testWidgets('a document with no module does not break the row',
        (tester) async {
      await pump(
        tester,
        DmsExplorerScreen(
          repository: _FakeDocRepo(docs: [document(module: null)], tree: tree),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Service analytics', () {
    testWidgets('leads with the median, not the mean', (tester) async {
      await pump(
        tester,
        ServiceAnalyticsScreen(repository: _FakeAnalyticsRepo(data: analytics())),
      );

      // Above 48h the median reads in days — 97h is "4.0d". The mean sits
      // beside it so the spread stays visible rather than hidden.
      expect(find.text('4.0d'), findsOneWidget);
      expect(find.textContaining('mean 90h'), findsOneWidget);
      expect(find.text('7%'), findsOneWidget);
      expect(find.text('3.4'), findsOneWidget);
    });

    testWidgets('the SLA tab emphasises the slowest categories', (tester) async {
      await pump(
        tester,
        ServiceAnalyticsScreen(
          slaFocus: true,
          repository: _FakeAnalyticsRepo(data: analytics()),
        ),
      );
      expect(find.text('SLA performance'), findsOneWidget);
      expect(find.text('Garbage'), findsOneWidget);
      expect(find.text('138h'), findsWidgets);
    });

    testWidgets('a long median is shown in days, not hours', (tester) async {
      await pump(
        tester,
        ServiceAnalyticsScreen(repository: _FakeAnalyticsRepo(data: analytics())),
      );
      // Four days is legible; "97h" makes a reader do arithmetic.
      expect(find.text('4.0d'), findsOneWidget);
      expect(find.text('97h'), findsNothing);
    });

    testWidgets('survives no data at all', (tester) async {
      await pump(
        tester,
        ServiceAnalyticsScreen(
          repository: _FakeAnalyticsRepo(
            data: analytics(allTime: 0, sample: 0, sla: const [], satisfaction: null),
          ),
        ),
      );
      // No satisfaction responses shows a dash, not "null" or "0.0".
      expect(find.text('—'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('narrow layout', () {
    // The bug shipped last time was a Row overflowing at phone width. Every
    // one of these screens has metric tiles and a header row that could do
    // the same.
    const phone = Size(320, 720);

    testWidgets('voice calls', (tester) async {
      await pump(
        tester,
        VoiceCallsScreen(repository: _FakeIvrRepo(voice: [voiceCall()])),
        size: phone,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ivr log', (tester) async {
      await pump(
        tester,
        IvrLogsScreen(repository: _FakeIvrRepo(logs: [ivrCall()])),
        size: phone,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('document register', (tester) async {
      await pump(
        tester,
        DmsExplorerScreen(repository: _FakeDocRepo(docs: [document()])),
        size: phone,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('service analytics', (tester) async {
      await pump(
        tester,
        ServiceAnalyticsScreen(repository: _FakeAnalyticsRepo(data: analytics())),
        size: phone,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
