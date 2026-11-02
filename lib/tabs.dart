import 'package:flutter/material.dart';
import 'ui.dart';
import 'data.dart';
import 'charts.dart';
import 'xlsx.dart';

// ---------- shared ----------
List<Cred> credsOf(List<Worker> ws) => ws.expand((w) => w.creds).toList();
List<ExpRecord> expOf(List<Worker> ws) => ws.expand((w) => w.experience).toList();
List<Sample> samplesOf(List<Worker> ws) => ws.expand((w) => w.samples).toList();

Widget kpiWrap(List<Widget> cards) => Wrap(spacing: 12, runSpacing: 12, children: cards.map((c) => SizedBox(width: 205, child: c)).toList());

Widget twoCol(bool wide, Widget a, Widget b) => wide
    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 14), Expanded(child: b)])
    : Column(children: [a, const SizedBox(height: 14), b]);

Widget statChips(List<(String, String)> stats) => Wrap(spacing: 10, runSpacing: 10, children: [
      for (final s in stats)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: g100, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(s.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Flexible(child: Text(s.$1, style: const TextStyle(fontSize: 12, color: g600))),
          ]),
        ),
    ]);

Widget sectionHeader(String title, String sub, {List<Widget> actions = const []}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: const TextStyle(fontSize: 12.5, color: g500))),
          ]),
        ),
        if (actions.isNotEmpty) ...[const SizedBox(width: 10), Wrap(spacing: 8, runSpacing: 8, children: actions)],
      ]),
    );

final smallBtn = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
  foregroundColor: slate,
  side: const BorderSide(color: g300),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

final smallLink = TextButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  foregroundColor: slate,
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

void demoSnack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 13)), behavior: SnackBarBehavior.floating));

(Color, Color) statusColors(CredStatus s) => switch (s) {
      CredStatus.expired => (red, redBg),
      CredStatus.expiring => (amber, amberBg),
      CredStatus.valid => (green, greenBg),
      CredStatus.noExpiry => (g600, g100),
    };

// ---------- request verification dialog ----------
Future<void> requestVerificationDialog(BuildContext context, {required String itemLabel, required VoidCallback onRequested}) {
  int mode = 0; // 0 = contact a reference, 1 = ask the worker for proof
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  String? error;
  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Request verification', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(itemLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: g600)),
              const SizedBox(height: 12),
              RadioGroup<int>(
                groupValue: mode,
                onChanged: (v) => setLocal(() { mode = v!; error = null; }),
                child: Column(children: [
                  const RadioListTile<int>(
                    value: 0,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Contact a reference', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text('BuilderFAX asks a supervisor or employer contact to confirm this.', style: TextStyle(fontSize: 12, color: g500)),
                  ),
                  const RadioListTile<int>(
                    value: 1,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Ask the worker for proof', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text('The worker is asked to upload proof of the work - a contract, work order or signed completion note.', style: TextStyle(fontSize: 12, color: g500)),
                  ),
                ]),
              ),
              if (mode == 0) ...[
                const SizedBox(height: 6),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Contact name', labelStyle: TextStyle(fontSize: 13))),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Contact phone number', labelStyle: TextStyle(fontSize: 13), hintText: '+1 ...', hintStyle: TextStyle(fontSize: 13, color: g500)),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    const Icon(Icons.error_outline, size: 15, color: red),
                    const SizedBox(width: 6),
                    Expanded(child: Text(error!, style: const TextStyle(fontSize: 12.5, color: red))),
                  ]),
                ),
              const SizedBox(height: 10),
              const Text('Demo only - no message or call actually goes out.', style: TextStyle(fontSize: 11.5, color: g500, fontStyle: FontStyle.italic)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: slate, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            onPressed: () {
              if (mode == 0 && phoneCtrl.text.trim().isEmpty) {
                setLocal(() => error = 'Add a phone number for the reference, or switch to asking the worker for proof.');
                return;
              }
              Navigator.of(ctx).pop();
              onRequested();
              demoSnack(context, 'Verification request recorded - demo only, nothing was sent.');
            },
            child: const Text('Send request'),
          ),
        ],
      ),
    ),
  );
}

// ---------- credential drawer (right side panel) ----------
void openCredDrawer(BuildContext context, Worker w, Cred c, VoidCallback onChanged) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Credential details',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
      child: child,
    ),
    pageBuilder: (dctx, _, __) {
      final status = credStatus(c);
      final (fg, bg) = statusColors(status);
      final width = MediaQuery.of(dctx).size.width;
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.white,
          child: StatefulBuilder(
            builder: (sctx, setLocal) {
              final key = credKey(w, c);
              final nudged = DemoActions.nudgedCreds.contains(key);
              final canNudge = status == CredStatus.expiring || status == CredStatus.expired;
              Widget row(String label, String value) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 12.5, color: g500))),
                      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    ]),
                  );
              return Container(
                width: width < 420 ? width : 400,
                height: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(c.isBadge ? Icons.military_tech_outlined : Icons.badge_outlined, size: 20, color: c.isBadge ? slate : orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(dctx).pop()),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    Tag(c.isBadge ? 'NCCER badge' : 'Other issuer', c.isBadge ? slate : orange, c.isBadge ? blueBg : const Color(0xFFFFF0EA)),
                    Tag(credStatusLabel(c), fg, bg),
                    if (nudged) const Tag('Nudge sent', green, greenBg, icon: Icons.check_circle_outline),
                  ]),
                  const SizedBox(height: 14),
                  const Divider(),
                  row('Worker', w.name),
                  row('Trade', w.trade),
                  row('Issuer', issuerOf(c.name)),
                  row('Added', fmtDate(c.added)),
                  row('Expires', c.expiry == null ? 'No expiry on file' : fmtDate(c.expiry!)),
                  const Divider(),
                  const SizedBox(height: 10),
                  if (canNudge && !nudged)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: smallBtn,
                        icon: const Icon(Icons.notifications_outlined, size: 16),
                        label: const Text('Nudge worker to renew'),
                        onPressed: () {
                          setLocal(() => DemoActions.nudgedCreds.add(key));
                          onChanged();
                          demoSnack(context, 'Renewal nudge queued for ${w.name} - demo only, nothing was sent.');
                        },
                      ),
                    ),
                  if (nudged)
                    const Row(children: [
                      Icon(Icons.check_circle_outline, size: 15, color: green),
                      SizedBox(width: 6),
                      Expanded(child: Text('Renewal nudge queued - the worker gets a reminder to renew. (Demo: nothing was sent.)', style: TextStyle(fontSize: 12.5, color: g600, height: 1.4))),
                    ]),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: smallLink,
                      icon: const Icon(Icons.open_in_new, size: 15),
                      label: const Text('Open worker profile'),
                      onPressed: () {
                        Navigator.of(dctx).pop();
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkerPage(worker: w)));
                      },
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      );
    },
  );
}

// ---------- 1. overview ----------
class OverviewTab extends StatefulWidget {
  final List<Worker> workers;
  const OverviewTab({super.key, required this.workers});
  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _Report {
  final String title;
  final List<(String, String)> rows;
  final String summary;
  const _Report(this.title, this.rows, this.summary);
}

String _fmtEntries(List<MapEntry<String, int>> es) => es.isEmpty ? '-' : es.map((e) => '${e.key} (${e.value})').join(', ');

class _OverviewTabState extends State<OverviewTab> {
  String credQuery = '';
  final _reportCtrl = TextEditingController();
  _Report? _report;
  bool _reportUnsupported = false;

  @override
  void dispose() {
    _reportCtrl.dispose();
    super.dispose();
  }

  void _generateReport() {
    final q = _reportCtrl.text.trim();
    if (q.isEmpty) return;
    final t = q.toLowerCase();
    final ws = workers;
    final creds = credsOf(ws);
    final recs = expOf(ws);
    final samples = samplesOf(ws);
    final n = ws.length;
    _Report? rep;
    if (t.contains('expir') || t.contains('renewal')) {
      final exp = <(Worker, Cred)>[
        for (final w in ws)
          for (final c in w.creds)
            if (credStatus(c) == CredStatus.expiring || credStatus(c) == CredStatus.expired) (w, c),
      ];
      final expd = exp.where((u) => credStatus(u.$2) == CredStatus.expired).length;
      final topTrade = topEntries(countBy(exp.map((u) => u.$1.trade)), 1);
      rep = _Report('Expiring credential risk', [
        ('Credentials expiring within 90 days', '${exp.length - expd}'),
        ('Already expired', '$expd'),
        ('Most affected trades', _fmtEntries(topEntries(countBy(exp.map((u) => u.$1.trade)), 3))),
        ('Most common expiring credentials', _fmtEntries(topEntries(countBy(exp.map((u) => u.$2.name)), 3))),
      ], exp.isEmpty
          ? 'AI summary (illustrative): no worker-added credentials expire within the next 90 days, so renewal risk is currently low.'
          : 'AI summary (illustrative): ${exp.length} worker-added credentials need renewal attention. The risk concentrates in ${topTrade.first.key} - nudging those workers first covers the largest share of upcoming expiries.');
    } else if (t.contains('sample') || t.contains('photo') || t.contains('video') || t.contains('adoption')) {
      final withS = ws.where((w) => w.samples.isNotEmpty).length;
      final videos = samples.where((sm) => sm.isVideo).length;
      rep = _Report('Work sample adoption', [
        ('Workers with samples', '$withS of $n (${n == 0 ? 0 : (100 * withS / n).round()}%)'),
        ('Total samples', '${samples.length}'),
        ('Videos', '${samples.isEmpty ? 0 : (100 * videos / samples.length).round()}%'),
        ('Top task tags', _fmtEntries(topEntries(countBy(samples.map((sm) => sm.taskTag)), 3))),
      ], 'AI summary (illustrative): only ${n == 0 ? 0 : (100 * withS / n).round()}% of workers show real work. Samples are the strongest skill signal, so the biggest lever is nudging the ${n - withS} workers without any.');
    } else if (t.contains('experience') || t.contains('employer') || t.contains('years')) {
      final withE = ws.where((w) => w.experience.isNotEmpty).length;
      rep = _Report('Work experience depth', [
        ('Workers with experience', '$withE of $n (${n == 0 ? 0 : (100 * withE / n).round()}%)'),
        ('Experience records', '${recs.length}'),
        ('Avg years per worker', n == 0 ? '0' : (ws.fold<double>(0, (a, w) => a + w.yearsExperience) / n).toStringAsFixed(1)),
        ('Top past employers', _fmtEntries(topEntries(countBy(recs.map((e) => e.employer)), 3))),
      ], 'AI summary (illustrative): depth looks solid on paper, but every record is self-reported - the per-record request verification flow is how Rosendin would confirm the ones that matter for a role.');
    } else if (t.contains('credential') || t.contains('badge') || t.contains('nccer') || t.contains('coverage') || t.contains('issuer')) {
      final withC = ws.where((w) => w.creds.isNotEmpty).length;
      final badges = creds.where((c) => c.isBadge).length;
      rep = _Report('Credential coverage', [
        ('Workers with credentials', '$withC of $n (${n == 0 ? 0 : (100 * withC / n).round()}%)'),
        ('Total worker-added credentials', '${creds.length}'),
        ('NCCER badges vs other issuers', '$badges / ${creds.length - badges}'),
        ('Top credential types', _fmtEntries(topEntries(countBy(creds.map((c) => c.name)), 3))),
      ], 'AI summary (illustrative): ${n - withC} workers share no credential at all - closing that gap matters more than adding credentials for workers who already share.');
    }
    setState(() {
      _report = rep;
      _reportUnsupported = rep == null;
    });
  }

  List<Worker> get workers => widget.workers;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 760;
    final n = workers.length;
    final creds = credsOf(workers);
    final recs = expOf(workers);
    final samples = samplesOf(workers);
    final withCreds = workers.where((w) => w.creds.isNotEmpty).length;
    final withExp = workers.where((w) => w.experience.isNotEmpty).length;
    final withSamples = workers.where((w) => w.samples.isNotEmpty).length;

    // needs attention
    final expiring = <(Worker, Cred)>[
      for (final w in workers)
        for (final c in w.creds)
          if (credStatus(c) == CredStatus.expiring || credStatus(c) == CredStatus.expired) (w, c),
    ]..sort((a, b) => a.$2.expiry!.compareTo(b.$2.expiry!));
    final exp30 = expiring.where((e) => credStatus(e.$2) == CredStatus.expiring && e.$2.expiry!.isBefore(demoNow.add(const Duration(days: 30)))).length;

    // latest worker-added items feed
    final feed = <(IconData, String, Worker, DateTime)>[
      for (final w in workers)
        for (final c in w.creds) (Icons.badge_outlined, 'Added credential: ${c.name}', w, c.added),
      for (final w in workers)
        for (final e in w.experience) (Icons.work_history_outlined, 'Added experience: ${e.role} · ${e.employer}', w, e.added),
      for (final w in workers)
        for (final s in w.samples) (s.isVideo ? Icons.videocam_outlined : Icons.photo_outlined, 'Uploaded work sample: ${s.taskTag}', w, s.uploaded),
    ]..sort((a, b) => b.$4.compareTo(a.$4));

    // credentials section
    final badges = creds.where((c) => c.isBadge).length;
    final other = creds.length - badges;
    final topTypes = topEntries(countBy(creds.map((c) => c.name)));
    final exp90 = expiring.length;
    final q = credQuery.trim().toLowerCase();
    final credRows = <(Worker, Cred)>[
      for (final w in workers)
        for (final c in w.creds)
          if (q.isEmpty ||
              c.name.toLowerCase().contains(q) ||
              w.name.toLowerCase().contains(q) ||
              issuerOf(c.name).toLowerCase().contains(q))
            (w, c),
    ]..sort((a, b) {
        int rank(CredStatus s) => switch (s) { CredStatus.expired => 0, CredStatus.expiring => 1, CredStatus.valid => 2, CredStatus.noExpiry => 3 };
        final ra = rank(credStatus(a.$2)), rb = rank(credStatus(b.$2));
        if (ra != rb) return ra.compareTo(rb);
        final ea = a.$2.expiry, eb = b.$2.expiry;
        if (ea != null && eb != null) return ea.compareTo(eb);
        return b.$2.added.compareTo(a.$2.added);
      });

    // experience section
    final buckets = [('0-2 yrs', 0.0, 2.0), ('3-5 yrs', 3.0, 5.0), ('6-10 yrs', 6.0, 10.0), ('10+ yrs', 10.01, 100.0)];
    final bucketCounts = buckets.map((b) => MapEntry(b.$1, workers.where((w) => w.yearsExperience >= b.$2 && w.yearsExperience <= b.$3).length)).toList();
    final topEmployers = topEntries(countBy(recs.map((e) => e.employer)), 6);

    // samples section
    final videos = samples.where((s) => s.isVideo).length;
    final topTags = topEntries(countBy(samples.map((s) => s.taskTag)));
    final uploads = perMonth(samples.map((s) => s.uploaded).where((d) => d.isAfter(daysAgo(183))), 6);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      kpiWrap([
        KpiCard(label: 'Workers sharing profile', value: '$n', icon: Icons.people_outline, sub: 'visible to Rosendin'),
        KpiCard(label: 'With personal credentials', value: '${n == 0 ? 0 : (100 * withCreds / n).round()}%', icon: Icons.badge_outlined, sub: '$withCreds of $n workers'),
        KpiCard(label: 'With work experience', value: '${n == 0 ? 0 : (100 * withExp / n).round()}%', icon: Icons.work_history_outlined, sub: '$withExp of $n workers'),
        KpiCard(label: 'With work samples', value: '${n == 0 ? 0 : (100 * withSamples / n).round()}%', icon: Icons.photo_library_outlined, sub: '$withSamples of $n workers'),
      ]),
      const SizedBox(height: 14),

      // ---- needs attention ----
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sectionHeader('Needs attention', '$exp30 credential${exp30 == 1 ? '' : 's'} expiring in 30 days · $exp90 in 90 days'),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Expiring in 90 days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: g600)),
          const SizedBox(height: 4),
          if (expiring.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nothing expiring in the next 90 days.', style: TextStyle(color: g500, fontSize: 13))),
          for (final u in expiring.take(6)) _expiringRow(u.$1, u.$2),
          if (expiring.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+ ${expiring.length - 6} more in the credentials table below', style: const TextStyle(fontSize: 12, color: g500)),
            ),
        ]),
      ])),
      const SizedBox(height: 14),

      // ---- ask for a report (AI analysis concept) ----
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sectionHeader('Ask for a report', 'Ask for any cut of this worker-added data in plain language. Full concept: AI curates the analysis on live data (proposed, not built). This demo simulates a few example reports from fictional data.'),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _reportCtrl,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.auto_awesome, size: 18), hintText: 'e.g. Which credentials are expiring, and for which trades?', hintStyle: TextStyle(fontSize: 13)),
              onSubmitted: (_) => _generateReport(),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Generate report'),
            onPressed: _generateReport,
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final ex in const ['Which credentials are expiring, and for which trades?', 'How complete is credential coverage across workers?', 'Which workers have the most experience?', 'How is work sample adoption looking?'])
            ActionChip(label: Text(ex, style: const TextStyle(fontSize: 12)), onPressed: () {
              _reportCtrl.text = ex;
              _generateReport();
            }),
        ]),
        if (_reportUnsupported) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: g100, borderRadius: BorderRadius.circular(10)),
            child: const Text('This demo can simulate only the example reports above. The full concept lets an admin ask for any cut of the data and uses AI to curate it - that integration is proposed and not built yet.', style: TextStyle(fontSize: 12.5, color: g600, height: 1.5)),
          ),
        ],
        if (_report != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: blueBg, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(_report!.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
                const Tag('Simulated demo output - not a live AI response', g600, g100, icon: Icons.science_outlined),
              ]),
              const SizedBox(height: 10),
              for (final r in _report!.rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 12.5, color: g600))),
                    Text(r.$2, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
              const SizedBox(height: 10),
              Text(_report!.summary, style: const TextStyle(fontSize: 12.5, color: g600, height: 1.5)),
              const SizedBox(height: 6),
              const Text('Demo: this report is generated locally in the browser from the fictional dataset; no demo report data is sent to any AI service.', style: TextStyle(fontSize: 11.5, color: g500)),
            ]),
          ),
        ],
      ])),
      const SizedBox(height: 14),

      // ---- personal credentials ----
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sectionHeader(
          'Personal credentials',
          'Self-added by workers - separate from what Rosendin assigns. Badge = NCCER-sourced (proposed split).',
          actions: [
            OutlinedButton.icon(style: smallBtn, icon: const Icon(Icons.account_balance_outlined, size: 15), label: const Text('View issuers'), onPressed: _showIssuers),
            OutlinedButton.icon(
              style: smallBtn,
              icon: const Icon(Icons.download_outlined, size: 15),
              label: const Text('Download Excel report'),
              onPressed: () {
                downloadPersonalCredentialsReport(workers);
                demoSnack(context, 'Report downloaded - fictional demo data.');
              },
            ),
          ],
        ),
        statChips([
          ('total', '${creds.length}'),
          ('NCCER badges', '$badges'),
          ('other issuers', '$other'),
          ('expiring in 90 days', '$exp90'),
        ]),
        const SizedBox(height: 14),
        twoCol(wide,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            chartTitle('Badges vs other issuers'),
            Donut(slices: [('NCCER badges', badges, slate), ('Other issuers', other, orange)], centerLabel: 'credentials'),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            chartTitle('Top personal credential types', sub: 'Illustrative sample names only - not real requirement data'),
            HBars(entries: topTypes),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search credential, worker or issuer', hintStyle: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => credQuery = v),
            ),
          ),
          const SizedBox(width: 12),
          Text('${credRows.length} credentials', style: const TextStyle(fontSize: 12.5, color: g500)),
        ]),
        const SizedBox(height: 10),
        Container(
          height: 360,
          decoration: BoxDecoration(border: Border.all(color: g200), borderRadius: BorderRadius.circular(10)),
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowHeight: 40,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('Credential', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: g600))),
                  DataColumn(label: Text('Worker', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: g600))),
                  DataColumn(label: Text('Issuer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: g600))),
                  DataColumn(label: Text('Added', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: g600))),
                  DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: g600))),
                  DataColumn(label: SizedBox.shrink()),
                ],
                rows: [
                  for (final r in credRows)
                    DataRow(onSelectChanged: (_) => openCredDrawer(context, r.$1, r.$2, () => setState(() {})), cells: [
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(r.$2.isBadge ? Icons.military_tech_outlined : Icons.badge_outlined, size: 15, color: r.$2.isBadge ? slate : orange),
                        const SizedBox(width: 7),
                        Text(r.$2.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ])),
                      DataCell(Text(r.$1.name, style: const TextStyle(fontSize: 12.5))),
                      DataCell(Text(issuerOf(r.$2.name), style: const TextStyle(fontSize: 12.5))),
                      DataCell(Text(fmtDate(r.$2.added), style: const TextStyle(fontSize: 12.5, color: g500))),
                      DataCell(Tag(credStatusLabel(r.$2), statusColors(credStatus(r.$2)).$1, statusColors(credStatus(r.$2)).$2)),
                      DataCell(_nudgeCell(r.$1, r.$2)),
                    ]),
                ],
              ),
            ),
          ),
        ),
      ])),
      const SizedBox(height: 14),

      // ---- work experience ----
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sectionHeader('Work experience', 'Roles workers list on their own profile.'),
        statChips([
          ('workers with experience', '${n == 0 ? 0 : (100 * withExp / n).round()}%'),
          ('experience records', '${recs.length}'),
          ('avg years per worker', n == 0 ? '0' : (workers.fold<double>(0, (a, w) => a + w.yearsExperience) / n).toStringAsFixed(1)),
        ]),
        const SizedBox(height: 14),
        twoCol(wide,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            chartTitle('Experience depth', sub: 'Workers by years in the trade'),
            HBars(entries: bucketCounts, color: orange),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            chartTitle('Where workers come from', sub: 'Most common past employers they list'),
            HBars(entries: topEmployers, color: const Color(0xFF7A9BC0)),
          ]),
        ),
      ])),
      const SizedBox(height: 14),

      // ---- work samples ----
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sectionHeader('Work samples', 'Photos and videos of real work - the strongest signal of actual skills, still rare.'),
        statChips([
          ('workers with samples', '${n == 0 ? 0 : (100 * withSamples / n).round()}%'),
          ('total samples', '${samples.length}'),
          ('videos', '${samples.isEmpty ? 0 : (100 * videos / samples.length).round()}%'),
        ]),
        const SizedBox(height: 14),
        twoCol(wide,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            chartTitle('What the work shows', sub: 'Samples by task tag'),
            HBars(entries: topTags, color: const Color(0xFF7A9BC0)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            chartTitle('Uploads by month', sub: 'Last 6 months'),
            Bars(data: uploads, color: const Color(0xFF7A9BC0)),
          ]),
        ),
      ])),
      const SizedBox(height: 14),

      // ---- latest worker-added items ----
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sectionHeader('Latest worker-added items', 'The actual newest entries across all areas - click through to the worker.'),
        for (final f in feed.take(8))
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkerPage(worker: f.$3))),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Icon(f.$1, size: 17, color: slate),
                const SizedBox(width: 10),
                Expanded(child: Text(f.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                Text(f.$3.name, style: const TextStyle(fontSize: 12.5, color: g500)),
                const SizedBox(width: 14),
                SizedBox(width: 96, child: Text(fmtDate(f.$4), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: g500))),
              ]),
            ),
          ),
      ])),
    ]);
  }

  Widget _expiringRow(Worker w, Cred c) {
    final status = credStatus(c);
    final (fg, bg) = statusColors(status);
    return InkWell(
      onTap: () => openCredDrawer(context, w, c, () => setState(() {})),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(w.name, style: const TextStyle(fontSize: 12, color: g500)),
            ]),
          ),
          Tag(credStatusLabel(c), fg, bg),
          const SizedBox(width: 8),
          _nudgeCell(w, c),
        ]),
      ),
    );
  }

  Widget _nudgeCell(Worker w, Cred c) {
    final status = credStatus(c);
    if (status != CredStatus.expiring && status != CredStatus.expired) return const SizedBox.shrink();
    final key = credKey(w, c);
    final nudged = DemoActions.nudgedCreds.contains(key);
    if (nudged) return const Tag('Nudge sent', green, greenBg, icon: Icons.check_circle_outline);
    return OutlinedButton.icon(
      style: smallBtn,
      icon: const Icon(Icons.notifications_outlined, size: 14),
      label: const Text('Nudge'),
      onPressed: () {
        setState(() => DemoActions.nudgedCreds.add(key));
        demoSnack(context, 'Renewal nudge queued for ${w.name} - demo only, nothing was sent.');
      },
    );
  }

  void _showIssuers() {
    final issuers = topEntries(countBy(credsOf(workers).map((c) => issuerOf(c.name))), 20);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Issuers on worker-added credentials', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Issuers seen across the current filter. Illustrative demo data.', style: TextStyle(fontSize: 12, color: g500)),
            const SizedBox(height: 10),
            HBars(entries: issuers),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
      ),
    );
  }
}

// ---------- 2. workers table ----------
class WorkersTab extends StatefulWidget {
  const WorkersTab({super.key});
  @override
  State<WorkersTab> createState() => _WorkersTabState();
}

class _WorkersTabState extends State<WorkersTab> {
  String query = '';
  int sortCol = 7; // last update desc by default
  bool sortAsc = false;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    var rows = allWorkers.where((w) => q.isEmpty || w.name.toLowerCase().contains(q) || w.trade.toLowerCase().contains(q)).toList();
    int cmp<T extends Comparable>(T a, T b) => sortAsc ? a.compareTo(b) : b.compareTo(a);
    rows.sort((a, b) => switch (sortCol) {
          0 => cmp(a.name, b.name),
          1 => cmp(a.trade, b.trade),
          2 => cmp(a.creds.length, b.creds.length),
          3 => cmp(a.creds.where((c) => c.isBadge).length, b.creds.where((c) => c.isBadge).length),
          4 => cmp(a.yearsExperience, b.yearsExperience),
          5 => cmp(a.samples.length, b.samples.length),
          6 => cmp(a.profileComplete, b.profileComplete),
          _ => cmp(a.lastUpdate, b.lastUpdate),
        });

    Widget head(String label, int col) => InkWell(
          onTap: () => setState(() { if (sortCol == col) { sortAsc = !sortAsc; } else { sortCol = col; sortAsc = col < 2; } }),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: g600)),
            Icon(sortCol == col ? (sortAsc ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more, size: 13, color: g500),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search worker or trade', hintStyle: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        const SizedBox(width: 12),
        Text('${rows.length} of ${allWorkers.length} fictional workers', style: const TextStyle(fontSize: 12.5, color: g500)),
      ]),
      const SizedBox(height: 12),
      CardBox(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            headingRowHeight: 44,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 44,
            columns: [
              DataColumn(label: head('Worker', 0)),
              DataColumn(label: head('Trade', 1)),
              DataColumn(label: head('Pers. creds', 2), numeric: true),
              DataColumn(label: head('Badges', 3), numeric: true),
              DataColumn(label: head('Exp (yrs)', 4), numeric: true),
              DataColumn(label: head('Samples', 5), numeric: true),
              DataColumn(label: head('Profile', 6), numeric: true),
              DataColumn(label: head('Last update', 7)),
            ],
            rows: [
              for (final w in rows)
                DataRow(onSelectChanged: (_) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkerPage(worker: w))), cells: [
                  DataCell(Text(w.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  DataCell(Text(w.trade, style: const TextStyle(fontSize: 12.5))),
                  DataCell(Text('${w.creds.length}', style: const TextStyle(fontSize: 13))),
                  DataCell(Text('${w.creds.where((c) => c.isBadge).length}', style: const TextStyle(fontSize: 13))),
                  DataCell(Text(w.yearsExperience.toStringAsFixed(1), style: const TextStyle(fontSize: 13))),
                  DataCell(Text('${w.samples.length}', style: const TextStyle(fontSize: 13))),
                  DataCell(Row(children: [
                    Container(width: 52, height: 6, decoration: BoxDecoration(color: g200, borderRadius: BorderRadius.circular(3)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: w.profileComplete / 100, child: Container(decoration: BoxDecoration(color: w.profileComplete >= 80 ? green : w.profileComplete >= 55 ? amber : red, borderRadius: BorderRadius.circular(3))))),
                    const SizedBox(width: 8),
                    Text('${w.profileComplete}%', style: const TextStyle(fontSize: 12, color: g600)),
                  ])),
                  DataCell(Text(fmtDate(w.lastUpdate), style: TextStyle(fontSize: 12.5, color: w.lastUpdate.isAfter(daysAgo(30)) ? green : w.lastUpdate.isAfter(daysAgo(90)) ? amber : red))),
                ]),
            ],
          ),
        ),
      ),
    ]);
  }
}

// ---------- worker detail (connected journey: analytics -> worker -> their own profile data) ----------
class WorkerPage extends StatefulWidget {
  final Worker worker;
  const WorkerPage({super.key, required this.worker});
  @override
  State<WorkerPage> createState() => _WorkerPageState();
}

class _WorkerPageState extends State<WorkerPage> {
  @override
  Widget build(BuildContext context) {
    final w = widget.worker;
    final wide = MediaQuery.of(context).size.width >= 760;
    final samples = [...w.samples]..sort((a, b) => b.uploaded.compareTo(a.uploaded));
    final exp = [...w.experience]..sort((a, b) => b.added.compareTo(a.added));
    return Scaffold(
      appBar: AppBar(backgroundColor: slateDark, foregroundColor: Colors.white, title: const Text('Worker profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      body: SafeArea(
        child: Column(children: [
          demoBanner(),
          Expanded(child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 14, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CardBox(child: Row(children: [
                  CircleAvatar(radius: 26, backgroundColor: blueBg, child: Text(w.name.split(' ').map((p) => p[0]).take(2).join(), style: const TextStyle(color: slate, fontWeight: FontWeight.w800, fontSize: 18))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(w.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    Text('${w.trade} · ${w.yearsExperience.toStringAsFixed(1)} yrs experience', style: const TextStyle(fontSize: 13, color: g500)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(width: 120, height: 6, decoration: BoxDecoration(color: g200, borderRadius: BorderRadius.circular(3)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: w.profileComplete / 100, child: Container(decoration: BoxDecoration(color: w.profileComplete >= 80 ? green : w.profileComplete >= 55 ? amber : red, borderRadius: BorderRadius.circular(3))))),
                      const SizedBox(width: 8),
                      Text('${w.profileComplete}% complete · updated ${fmtDate(w.lastUpdate)}', style: const TextStyle(fontSize: 12, color: g500)),
                    ]),
                  ])),
                  const SizedBox(width: 10),
                  const Tag('Fictional worker', amber, amberBg),
                ])),
                const SizedBox(height: 14),
                twoCol(wide,
                  CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    chartTitle('Personal credentials', sub: '${w.creds.length} self-added · badge = NCCER-sourced (proposed split)'),
                    if (w.creds.isEmpty) const Text('None added yet.', style: TextStyle(color: g500, fontSize: 13)),
                    for (final c in w.creds)
                      Builder(builder: (_) {
                        final status = credStatus(c);
                        final (fg, bg) = statusColors(status);
                        final key = credKey(w, c);
                        final nudged = DemoActions.nudgedCreds.contains(key);
                        final canNudge = status == CredStatus.expiring || status == CredStatus.expired;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Icon(c.isBadge ? Icons.military_tech_outlined : Icons.badge_outlined, size: 17, color: c.isBadge ? slate : orange),
                            const SizedBox(width: 8),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('${issuerOf(c.name)} · added ${fmtDate(c.added)}', style: const TextStyle(fontSize: 11.5, color: g500)),
                            ])),
                            Tag(credStatusLabel(c), fg, bg),
                            if (canNudge && !nudged) ...[
                              const SizedBox(width: 6),
                              OutlinedButton(
                                style: smallBtn,
                                onPressed: () {
                                  setState(() => DemoActions.nudgedCreds.add(key));
                                  demoSnack(context, 'Renewal nudge queued for ${w.name} - demo only, nothing was sent.');
                                },
                                child: const Text('Nudge'),
                              ),
                            ],
                            if (nudged) ...[const SizedBox(width: 6), const Tag('Nudge sent', green, greenBg)],
                          ]),
                        );
                      }),
                  ])),
                  CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    chartTitle('Work experience', sub: 'From the existing profile section'),
                    if (exp.isEmpty) const Text('Not filled yet.', style: TextStyle(color: g500, fontSize: 13)),
                    for (final e in exp)
                      Builder(builder: (_) {
                        final key = expKey(w, e);
                        final requested = DemoActions.verificationRequests.contains(key);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            const Icon(Icons.work_history_outlined, size: 17, color: slate),
                            const SizedBox(width: 8),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${e.role} · ${e.employer}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('${e.years.toStringAsFixed(1)} yrs · added ${fmtDate(e.added)}', style: const TextStyle(fontSize: 11.5, color: g500)),
                            ])),
                            if (requested)
                              const Tag('Requested', slate, blueBg, icon: Icons.hourglass_top)
                            else
                              TextButton(
                                style: smallLink,
                                onPressed: () => requestVerificationDialog(
                                  context,
                                  itemLabel: '${e.role} · ${e.employer} (${w.name})',
                                  onRequested: () => setState(() => DemoActions.verificationRequests.add(key)),
                                ),
                                child: const Text('Request verification'),
                              ),
                          ]),
                        );
                      }),
                  ])),
                ),
                const SizedBox(height: 14),
                CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  chartTitle('Work samples', sub: '${w.samples.length} samples - same task tags the worker-side add flow uses'),
                  if (samples.isEmpty) const Text('No samples yet.', style: TextStyle(color: g500, fontSize: 13)),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final sm in samples)
                      Builder(builder: (_) {
                        final requested = DemoActions.verificationRequests.contains(sampleKey(w, sm));
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SampleDetailPage(worker: w, sample: sm))).then((_) => setState(() {})),
                          child: Container(
                            width: 168,
                            decoration: BoxDecoration(border: Border.all(color: g200), borderRadius: BorderRadius.circular(12)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                height: 88,
                                decoration: const BoxDecoration(color: blueBg, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                                child: Center(child: Icon(sm.isVideo ? Icons.videocam_outlined : Icons.photo_outlined, size: 30, color: slate)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(sm.taskTag, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    if (requested) ...[const Icon(Icons.hourglass_top, size: 12, color: slate), const SizedBox(width: 3)],
                                    Text(fmtDate(sm.uploaded), style: const TextStyle(fontSize: 11, color: g500)),
                                  ]),
                                ]),
                              ),
                            ]),
                          ),
                        );
                      }),
                  ]),
                ])),
              ]),
            ),
          ))),
        ]),
      ),
    );
  }
}

// ---------- sample detail (same evidence object the worker-side work samples flow produces) ----------
class SampleDetailPage extends StatefulWidget {
  final Worker worker;
  final Sample sample;
  const SampleDetailPage({super.key, required this.worker, required this.sample});
  @override
  State<SampleDetailPage> createState() => _SampleDetailPageState();
}

class _SampleDetailPageState extends State<SampleDetailPage> {
  @override
  Widget build(BuildContext context) {
    final key = sampleKey(widget.worker, widget.sample);
    final requested = DemoActions.verificationRequests.contains(key);
    return Scaffold(
      appBar: AppBar(backgroundColor: slateDark, foregroundColor: Colors.white, title: const Text('Work sample', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      body: SafeArea(
        child: Column(children: [
          demoBanner(),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    height: 300,
                    decoration: BoxDecoration(color: blueBg, borderRadius: BorderRadius.circular(16)),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(widget.sample.isVideo ? Icons.videocam_outlined : Icons.photo_outlined, size: 56, color: slate),
                      const SizedBox(height: 8),
                      Text(widget.sample.isVideo ? 'Video evidence' : 'Photo evidence', style: const TextStyle(fontSize: 13, color: g600, fontWeight: FontWeight.w600)),
                      const Text('Media placeholder in this prototype', style: TextStyle(fontSize: 11.5, color: g500)),
                    ])),
                  ),
                  const SizedBox(height: 14),
                  CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(widget.sample.taskTag, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                      if (requested) const Tag('Verification requested', slate, blueBg, icon: Icons.hourglass_top),
                    ]),
                    const SizedBox(height: 8),
                    Text('${widget.worker.name} · ${widget.worker.trade}', style: const TextStyle(fontSize: 13.5, color: g600, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Uploaded ${fmtDate(widget.sample.uploaded)}', style: const TextStyle(fontSize: 12.5, color: g500)),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('How this gets captured', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Same evidence object as the worker-side work samples flow: the worker adds a photo or video first, task tags are suggested, and verification can be requested on this specific sample when needed.',
                        style: TextStyle(fontSize: 12.5, color: g600, height: 1.5)),
                    if (!requested) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: smallBtn,
                        icon: const Icon(Icons.verified_outlined, size: 15),
                        label: const Text('Request verification'),
                        onPressed: () => requestVerificationDialog(
                          context,
                          itemLabel: '${widget.sample.taskTag} sample (${widget.worker.name})',
                          onRequested: () => setState(() => DemoActions.verificationRequests.add(key)),
                        ),
                      ),
                    ],
                    if (requested)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text('Verification request sent - pending response. (Demo: nothing was actually sent.)', style: TextStyle(fontSize: 12.5, color: g500)),
                      ),
                  ])),
                ]),
              ),
            ),
          )),
        ]),
      ),
    );
  }
}
