import 'package:flutter/material.dart';
import 'ui.dart';
import 'data.dart';
import 'xlsx.dart';
import 'tabs.dart' show smallBtn, demoSnack;

class ReportData {
  final String title;
  final String request;
  final List<String> scope;
  final List<(String, String)> stats;
  final List<(String, int)> breakdown;
  final String breakdownTitle;
  final List<String> findings;
  final List<String> columns;
  final List<List<String>> rows;
  final String tableTitle;
  const ReportData({
    required this.title,
    required this.request,
    required this.scope,
    required this.stats,
    required this.breakdown,
    required this.breakdownTitle,
    required this.findings,
    required this.columns,
    required this.rows,
    required this.tableTitle,
  });
}

String _pctOf(int a, int b) => b == 0 ? '0%' : '${(100 * a / b).round()}%';
String _top(Iterable<String> items, [int n = 3]) {
  final es = topEntries(countBy(items), n);
  return es.isEmpty ? '-' : es.map((e) => '${e.key} (${e.value})').join(', ');
}

/// Returns null when the request does not match a demo report type.
ReportData? buildDemoReport(String request, List<Worker> ws) {
  final t = request.toLowerCase();
  final n = ws.length;
  if (t.contains('expir') || t.contains('renewal')) {
    final items = <(Worker, Cred)>[
      for (final w in ws)
        for (final c in w.creds)
          if (credStatus(c) == CredStatus.expiring || credStatus(c) == CredStatus.expired) (w, c),
    ]..sort((a, b) => a.$2.expiry!.compareTo(b.$2.expiry!));
    final expired = items.where((u) => credStatus(u.$2) == CredStatus.expired).length;
    final soon = items.length - expired;
    final byTrade = topEntries(countBy(items.map((u) => u.$1.trade)), 6);
    final workersAffected = items.map((u) => u.$1.name).toSet().length;
    return ReportData(
      title: 'Expiring credential risk',
      request: request,
      scope: [
        'Data: worker-added credentials, all $n workers',
        'Filter: expiry date already passed or within the next 90 days',
        'Sorted by: soonest expiry first',
      ],
      stats: [
        ('Matching credentials', '${items.length}'),
        ('Workers affected', '$workersAffected'),
        ('Expiring in 90 days', '$soon'),
        ('Already expired', '$expired'),
      ],
      breakdownTitle: 'Matching credentials by trade',
      breakdown: [for (final e in byTrade) (e.key, e.value)],
      findings: items.isEmpty
          ? ['No worker-added credentials expire in the next 90 days, so renewal risk is low right now.']
          : [
              '${items.length} credential${items.length == 1 ? '' : 's'} across $workersAffected worker${workersAffected == 1 ? '' : 's'} ${items.length == 1 ? 'needs' : 'need'} renewal attention.',
              'Most affected trade: ${byTrade.first.key} (${byTrade.first.value}).',
              'Most common credentials: ${_top(items.map((u) => u.$2.name))}.',
              'First to expire: ${items.first.$1.name}, ${items.first.$2.name} (${credStatusLabel(items.first.$2).toLowerCase()}).',
              'Suggested next step: nudge the listed workers, soonest expiry first.',
            ],
      tableTitle: 'Matching credentials',
      columns: ['Worker', 'Trade', 'Credential', 'Issuer', 'Expires', 'Status'],
      rows: [
        for (final u in items)
          [u.$1.name, u.$1.trade, u.$2.name, issuerOf(u.$2.name), fmtDate(u.$2.expiry!), credStatusLabel(u.$2)],
      ],
    );
  }
  if (t.contains('sample') || t.contains('photo') || t.contains('video') || t.contains('adoption')) {
    final withS = ws.where((w) => w.samples.isNotEmpty).toList();
    final all = ws.expand((w) => w.samples).toList();
    final videos = all.where((s) => s.isVideo).length;
    final sorted = [...ws]..sort((a, b) => a.samples.length.compareTo(b.samples.length));
    final byTrade = <(String, int)>[
      for (final tr in trades) (tr, ws.where((w) => w.trade == tr && w.samples.isNotEmpty).length),
    ];
    return ReportData(
      title: 'Work sample adoption',
      request: request,
      scope: [
        'Data: work samples (photo/video) uploaded by workers, all $n workers',
        'Filter: none - every worker listed',
        'Sorted by: fewest samples first',
      ],
      stats: [
        ('Workers with samples', '${withS.length} of $n'),
        ('Adoption', _pctOf(withS.length, n)),
        ('Total samples', '${all.length}'),
        ('Videos', _pctOf(videos, all.length)),
      ],
      breakdownTitle: 'Workers with at least one sample, by trade',
      breakdown: byTrade,
      findings: [
        '${_pctOf(withS.length, n)} of workers (${withS.length} of $n) have shared at least one work sample.',
        '${n - withS.length} workers have none - the largest opportunity to nudge.',
        'Most tagged tasks: ${_top(all.map((s) => s.taskTag))}.',
        'Samples are the strongest signal of hands-on skill, so higher adoption helps role matching.',
      ],
      tableTitle: 'Workers and their samples',
      columns: ['Worker', 'Trade', 'Samples', 'Videos', 'Most common task'],
      rows: [
        for (final w in sorted)
          [w.name, w.trade, '${w.samples.length}', '${w.samples.where((s) => s.isVideo).length}', w.samples.isEmpty ? '-' : _top(w.samples.map((s) => s.taskTag), 1).replaceAll(RegExp(r' \(\d+\)'), '')],
      ],
    );
  }
  if (t.contains('experience') || t.contains('employer') || t.contains('years')) {
    final withE = ws.where((w) => w.experience.isNotEmpty).length;
    final recs = ws.expand((w) => w.experience).toList();
    final sorted = [...ws]..sort((a, b) => b.yearsExperience.compareTo(a.yearsExperience));
    final buckets = <(String, int)>[
      ('0-2 yrs', ws.where((w) => w.yearsExperience < 2).length),
      ('2-5 yrs', ws.where((w) => w.yearsExperience >= 2 && w.yearsExperience < 5).length),
      ('5-10 yrs', ws.where((w) => w.yearsExperience >= 5 && w.yearsExperience < 10).length),
      ('10+ yrs', ws.where((w) => w.yearsExperience >= 10).length),
    ];
    final avg = n == 0 ? 0.0 : ws.fold<double>(0, (a, w) => a + w.yearsExperience) / n;
    return ReportData(
      title: 'Work experience depth',
      request: request,
      scope: [
        'Data: worker-added work experience records, all $n workers',
        'Filter: none - every worker listed',
        'Sorted by: most years of experience first',
      ],
      stats: [
        ('Workers with records', '$withE of $n'),
        ('Experience records', '${recs.length}'),
        ('Avg years per worker', avg.toStringAsFixed(1)),
        ('10+ years', '${buckets.last.$2}'),
      ],
      breakdownTitle: 'Workers by years of experience',
      breakdown: buckets,
      findings: [
        '${_pctOf(withE, n)} of workers have added at least one experience record (${recs.length} records in total).',
        'Average experience is ${avg.toStringAsFixed(1)} years; ${buckets.last.$2} workers have 10+ years.',
        'Most common past employers: ${_top(recs.map((e) => e.employer))}.',
        'All records are self-reported. Verification can be requested per record from a worker profile.',
      ],
      tableTitle: 'Workers by experience',
      columns: ['Worker', 'Trade', 'Years', 'Records', 'Most recent employer'],
      rows: [
        for (final w in sorted)
          () {
            final e = [...w.experience]..sort((a, b) => b.added.compareTo(a.added));
            return [w.name, w.trade, w.yearsExperience.toStringAsFixed(1), '${w.experience.length}', e.isEmpty ? '-' : e.first.employer];
          }(),
      ],
    );
  }
  if (t.contains('credential') || t.contains('badge') || t.contains('nccer') || t.contains('coverage') || t.contains('issuer')) {
    final withC = ws.where((w) => w.creds.isNotEmpty).length;
    final creds = ws.expand((w) => w.creds).toList();
    final badges = creds.where((c) => c.isBadge).length;
    final sorted = [...ws]..sort((a, b) => a.creds.length.compareTo(b.creds.length));
    final byIssuer = topEntries(countBy(creds.map((c) => issuerOf(c.name))), 6);
    return ReportData(
      title: 'Credential coverage',
      request: request,
      scope: [
        'Data: worker-added credentials, all $n workers',
        'Filter: none - every worker listed',
        'Sorted by: fewest credentials first',
      ],
      stats: [
        ('Workers with credentials', '$withC of $n'),
        ('Coverage', _pctOf(withC, n)),
        ('Total credentials', '${creds.length}'),
        ('NCCER badges', '$badges'),
      ],
      breakdownTitle: 'Credentials by issuer',
      breakdown: [for (final e in byIssuer) (e.key, e.value)],
      findings: [
        '$withC of $n workers (${_pctOf(withC, n)}) have shared at least one credential.',
        '${n - withC} worker${n - withC == 1 ? '' : 's'} share none.',
        '$badges of ${creds.length} credentials are NCCER badges; ${creds.length - badges} come from other issuers.',
        'Most common credentials: ${_top(creds.map((c) => c.name))}.',
      ],
      tableTitle: 'Workers and their credentials',
      columns: ['Worker', 'Trade', 'Credentials', 'NCCER badges', 'Credential types'],
      rows: [
        for (final w in sorted)
          [w.name, w.trade, '${w.creds.length}', '${w.creds.where((c) => c.isBadge).length}', w.creds.isEmpty ? '-' : w.creds.map((c) => c.name).toSet().join(', ')],
      ],
    );
  }
  return null;
}

class ReportPage extends StatefulWidget {
  final ReportData report;
  const ReportPage({super.key, required this.report});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  static const _pageSize = 15;
  int _shown = _pageSize;

  Widget _stat(String label, String value, bool wide) => Container(
        width: wide ? 190 : (MediaQuery.of(context).size.width - 28 - 36 - 16) / 2,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: g50, border: Border.all(color: g200), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: g600)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final wide = MediaQuery.of(context).size.width >= 760;
    final maxB = r.breakdown.fold<int>(1, (a, b) => b.$2 > a ? b.$2 : a);
    final shown = r.rows.length < _shown ? r.rows.length : _shown;
    return Scaffold(
      appBar: AppBar(backgroundColor: slateDark, foregroundColor: Colors.white, title: const Text('Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      body: SafeArea(
        child: Column(children: [
          demoBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 14, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // request + scope
                    CardBox(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text(r.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          const Tag('Simulated demo output - not a live AI response', g600, g100, icon: Icons.science_outlined),
                        ]),
                        const SizedBox(height: 12),
                        const Text('ADMIN REQUEST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: g500, letterSpacing: 0.6)),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: blueBg, borderRadius: BorderRadius.circular(10)),
                          child: Text('"${r.request}"', style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                        ),
                        const SizedBox(height: 12),
                        const Text('DATA AND FILTERS USED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: g500, letterSpacing: 0.6)),
                        const SizedBox(height: 4),
                        for (final s in r.scope)
                          Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('•  $s', style: const TextStyle(fontSize: 13, color: g600))),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    // findings
                    CardBox(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        chartTitle('Key findings', sub: 'Numbers are calculated from the fictional dataset. Wording is illustrative.'),
                        Wrap(spacing: 10, runSpacing: 10, children: [for (final s in r.stats) _stat(s.$1, s.$2, wide)]),
                        const SizedBox(height: 14),
                        for (final f in r.findings)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Padding(padding: EdgeInsets.only(top: 3, right: 8), child: Icon(Icons.auto_awesome, size: 14, color: slate)),
                              Expanded(child: Text(f, style: const TextStyle(fontSize: 13.5, height: 1.45))),
                            ]),
                          ),
                      ]),
                    ),
                    if (r.breakdown.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      CardBox(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          chartTitle(r.breakdownTitle),
                          for (final b in r.breakdown)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(children: [
                                SizedBox(width: wide ? 190 : 128, child: Text(b.$1, style: const TextStyle(fontSize: 12.5, color: g600), overflow: TextOverflow.ellipsis)),
                                Expanded(
                                  child: Stack(children: [
                                    Container(height: 12, decoration: BoxDecoration(color: g100, borderRadius: BorderRadius.circular(6))),
                                    FractionallySizedBox(widthFactor: b.$2 / maxB, child: Container(height: 12, decoration: BoxDecoration(color: slate, borderRadius: BorderRadius.circular(6)))),
                                  ]),
                                ),
                                SizedBox(width: 36, child: Text('${b.$2}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
                              ]),
                            ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 14),
                    // records
                    CardBox(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: chartTitle(r.tableTitle, sub: '${r.rows.length} record${r.rows.length == 1 ? '' : 's'}')),
                          OutlinedButton.icon(
                            style: smallBtn,
                            icon: const Icon(Icons.download_outlined, size: 15),
                            label: const Text('Download Excel'),
                            onPressed: () {
                              downloadRowsXlsx(r.title, [r.columns, ...r.rows], '${r.title.toLowerCase().replaceAll(' ', '-')}-report.xlsx');
                              demoSnack(context, 'Report downloaded - fictional demo data.');
                            },
                          ),
                        ]),
                        if (r.rows.isEmpty)
                          const Text('No matching records.', style: TextStyle(color: g500, fontSize: 13))
                        else
                          wide
                              ? SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowHeight: 38,
                                    dataRowMinHeight: 40,
                                    dataRowMaxHeight: 48,
                                    columns: [for (final c in r.columns) DataColumn(label: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: g600)))],
                                    rows: [
                                      for (final row in r.rows.take(shown))
                                        DataRow(cells: [for (final c in row) DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 280), child: Text(c, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)))]),
                                    ],
                                  ),
                                )
                              : Column(children: [
                                  for (final row in r.rows.take(shown))
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: g200))),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(row.first, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                        for (var i = 1; i < row.length; i++)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text('${r.columns[i]}: ${row[i]}', style: const TextStyle(fontSize: 12.5, color: g600)),
                                          ),
                                      ]),
                                    ),
                                ]),
                        if (shown < r.rows.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TextButton(onPressed: () => setState(() => _shown += _pageSize), child: Text('Show more (${r.rows.length - shown} remaining)')),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    const Text('Demo only: this report is generated in the browser from the fictional dataset. The AI-curated version, where any requested cut of the data is analysed, is proposed and not built.', style: TextStyle(fontSize: 11.5, color: g500)),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
