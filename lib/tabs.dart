import 'package:flutter/material.dart';
import 'ui.dart';
import 'data.dart';
import 'charts.dart';
import 'main.dart' show RangeFilter, rangeMonths, rangeStart;

// ---------- shared ----------
List<Cred> credsOf(List<Worker> ws) => ws.expand((w) => w.creds).toList();
List<ExpRecord> expOf(List<Worker> ws) => ws.expand((w) => w.experience).toList();
List<Sample> samplesOf(List<Worker> ws) => ws.expand((w) => w.samples).toList();
int expiringWithin(List<Worker> ws, int days) {
  final limit = demoNow.add(Duration(days: days));
  return credsOf(ws).where((c) => c.expiry != null && c.expiry!.isAfter(demoNow) && c.expiry!.isBefore(limit)).length;
}

Widget kpiWrap(List<Widget> cards) => Wrap(spacing: 12, runSpacing: 12, children: cards.map((c) => SizedBox(width: 205, child: c)).toList());

Widget twoCol(bool wide, Widget a, Widget b) => wide
    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 14), Expanded(child: b)])
    : Column(children: [a, const SizedBox(height: 14), b]);

class Insight extends StatelessWidget {
  final IconData icon; final Color color; final String text;
  const Insight(this.icon, this.color, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: color), const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45))),
        ]),
      );
}

// ---------- 1. overview ----------
class OverviewTab extends StatelessWidget {
  final List<Worker> workers; final RangeFilter range;
  const OverviewTab({super.key, required this.workers, required this.range});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 760;
    final n = workers.length;
    final withCreds = workers.where((w) => w.creds.isNotEmpty).length;
    final withExp = workers.where((w) => w.experience.isNotEmpty).length;
    final withSamples = workers.where((w) => w.samples.isNotEmpty).length;
    final avgComplete = n == 0 ? 0 : (workers.fold<int>(0, (a, w) => a + w.profileComplete) / n).round();
    final start = rangeStart(range);
    final months = rangeMonths(range);
    final credAdds = perMonth(credsOf(workers).map((c) => c.added).where((d) => d.isAfter(start)), months);
    final expAdds = perMonth(expOf(workers).map((e) => e.added).where((d) => d.isAfter(start)), months);
    final sampleAdds = perMonth(samplesOf(workers).map((s) => s.uploaded).where((d) => d.isAfter(start)), months);
    final fresh30 = workers.where((w) => w.lastUpdate.isAfter(daysAgo(30))).length;
    final fresh90 = workers.where((w) => !w.lastUpdate.isAfter(daysAgo(30)) && w.lastUpdate.isAfter(daysAgo(90))).length;
    final stale = n - fresh30 - fresh90;
    final expiring = expiringWithin(workers, 30);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      kpiWrap([
        KpiCard(label: 'Workers sharing profile', value: '$n', icon: Icons.people_outline, sub: 'visible to Rosendin'),
        KpiCard(label: 'With personal credentials', value: '${n == 0 ? 0 : (100 * withCreds / n).round()}%', icon: Icons.badge_outlined, sub: '$withCreds of $n workers'),
        KpiCard(label: 'With work experience', value: '${n == 0 ? 0 : (100 * withExp / n).round()}%', icon: Icons.work_history_outlined, sub: '$withExp of $n workers'),
        KpiCard(label: 'With work samples', value: '${n == 0 ? 0 : (100 * withSamples / n).round()}%', icon: Icons.photo_library_outlined, sub: '$withSamples of $n workers'),
        KpiCard(label: 'Avg profile completeness', value: '$avgComplete%', icon: Icons.donut_large, sub: 'six wallet sections'),
      ]),
      const SizedBox(height: 14),
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        chartTitle('What workers are adding', sub: 'Self-added items per month - credentials, experience records, work samples'),
        GroupedBars(
          labels: credAdds.map((m) => m.label).toList(),
          series: [credAdds.map((m) => m.value).toList(), expAdds.map((m) => m.value).toList(), sampleAdds.map((m) => m.value).toList()],
          colors: const [slate, orange, Color(0xFF7A9BC0)],
          seriesNames: const ['Credentials added', 'Experience updates', 'Samples uploaded'],
        ),
      ])),
      const SizedBox(height: 14),
      twoCol(wide,
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          chartTitle('Profile freshness', sub: 'When workers last updated anything. 30/90-day windows are proposed'),
          Donut(slices: [('Last 30 days', fresh30, green), ('31-90 days', fresh90, amber), ('90+ days', stale, red)], centerLabel: 'workers'),
        ])),
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          chartTitle('What stands out', sub: 'Computed from the current filter. Windows and buckets are proposed defaults, not confirmed policy'),
          Insight(Icons.badge_outlined, slate, '${credsOf(workers).length} personal credentials sit on worker profiles, added by workers themselves - separate from what Rosendin assigns.'),
          Insight(Icons.schedule, amber, '$expiring personal credential${expiring == 1 ? '' : 's'} expire${expiring == 1 ? 's' : ''} in the next 30 days. Renewal reminders go to the worker; Rosendin sees the count.'),
          Insight(Icons.photo_library_outlined, const Color(0xFF7A9BC0), 'Only ${n == 0 ? 0 : (100 * withSamples / n).round()}% of workers show actual work samples. Samples are the strongest signal of real skills and are still rare.'),
          Insight(Icons.update, red, '$stale of $n workers have not updated their profile in 90+ days - their data may not reflect current skills.'),
        ])),
      ),
    ]);
  }
}

// ---------- 2. personal credentials ----------
class CredentialsTab extends StatelessWidget {
  final List<Worker> workers; final RangeFilter range;
  const CredentialsTab({super.key, required this.workers, required this.range});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 760;
    final creds = credsOf(workers);
    final badges = creds.where((c) => c.isBadge).length;
    final other = creds.length - badges;
    final exp30 = expiringWithin(workers, 30);
    final exp90 = expiringWithin(workers, 90) - exp30;
    final adds = perMonth(creds.map((c) => c.added).where((d) => d.isAfter(rangeStart(range))), rangeMonths(range));
    final topTypes = topEntries(countBy(creds.map((c) => c.name)));
    final upcoming = <(String, Cred)>[
      for (final w in workers)
        for (final c in w.creds)
          if (c.expiry != null && c.expiry!.isAfter(demoNow)) (w.name, c),
    ]..sort((a, b) => a.$2.expiry!.compareTo(b.$2.expiry!));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      kpiWrap([
        KpiCard(label: 'Personal credentials', value: '${creds.length}', icon: Icons.badge_outlined, sub: 'self-added by workers'),
        KpiCard(label: 'NCCER badges', value: '$badges', icon: Icons.military_tech_outlined, sub: 'received from NCCER'),
        KpiCard(label: 'Other issuers', value: '$other', icon: Icons.account_balance_outlined, sub: 'OSHA, state cards, more'),
        KpiCard(label: 'Expiring in 30 days', value: '$exp30', icon: Icons.schedule, accent: exp30 > 0 ? red : slate, sub: exp30 > 0 ? 'needs attention' : 'nothing urgent'),
      ]),
      const SizedBox(height: 14),
      twoCol(wide,
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          chartTitle('Badges vs other issuers', sub: 'Proposed split: NCCER-sourced vs any other issuer'),
          Donut(slices: [('NCCER badges', badges, slate), ('Other issuers', other, orange)], centerLabel: 'credentials'),
        ])),
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          chartTitle('Top personal credential types', sub: 'Illustrative sample names only - not real requirement data'),
          HBars(entries: topTypes),
        ])),
      ),
      const SizedBox(height: 14),
      twoCol(wide,
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          chartTitle('Credentials added by month', sub: 'Fresh additions show active workers'),
          Bars(data: adds),
        ])),
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          chartTitle('Expiring soon', sub: '$exp30 in 30 days · $exp90 more in 31-90 days'),
          if (upcoming.isEmpty) const Text('No dated expiries on file.', style: TextStyle(color: g500, fontSize: 13)),
          for (final u in upcoming.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.$2.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(u.$1, style: const TextStyle(fontSize: 12, color: g500)),
                  ]),
                ),
                Tag(fmtDate(u.$2.expiry!), u.$2.expiry!.isBefore(demoNow.add(const Duration(days: 30))) ? red : amber, u.$2.expiry!.isBefore(demoNow.add(const Duration(days: 30))) ? redBg : amberBg),
              ]),
            ),
        ])),
      ),
    ]);
  }
}

// ---------- 3. work experience ----------
class ExperienceTab extends StatelessWidget {
  final List<Worker> workers; final RangeFilter range;
  const ExperienceTab({super.key, required this.workers, required this.range});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 760;
    final n = workers.length;
    final withExp = workers.where((w) => w.experience.isNotEmpty).length;
    final avgYears = n == 0 ? 0.0 : workers.fold<double>(0, (a, w) => a + w.yearsExperience) / n;
    final recs = expOf(workers);
    final updated30 = workers.where((w) => w.experience.any((e) => e.added.isAfter(daysAgo(30)))).length;
    final byTrade = <String, List<double>>{};
    for (final w in workers) byTrade.putIfAbsent(w.trade, () => []).add(w.yearsExperience);
    final tradeRows = byTrade.entries.map((e) => MapEntry(e.key, (e.value.reduce((a, b) => a + b) / e.value.length))).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final buckets = [('0-2 yrs', 0.0, 2.0), ('3-5 yrs', 3.0, 5.0), ('6-10 yrs', 6.0, 10.0), ('10+ yrs', 10.01, 100.0)];
    final bucketCounts = buckets.map((b) => MapEntry(b.$1, workers.where((w) => w.yearsExperience >= b.$2 && w.yearsExperience <= b.$3).length)).toList();
    final adds = perMonth(recs.map((e) => e.added).where((d) => d.isAfter(rangeStart(range))), rangeMonths(range));
    final topEmployers = topEntries(countBy(recs.map((e) => e.employer)), 6);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      kpiWrap([
        KpiCard(label: 'With work experience', value: '${n == 0 ? 0 : (100 * withExp / n).round()}%', icon: Icons.work_history_outlined, sub: '$withExp of $n workers'),
        KpiCard(label: 'Avg years of experience', value: avgYears.toStringAsFixed(1), icon: Icons.timeline, sub: 'across listed roles'),
        KpiCard(label: 'Experience records', value: '${recs.length}', icon: Icons.format_list_bulleted, sub: 'roles with employers listed'),
        KpiCard(label: 'Updated in last 30 days', value: '$updated30', icon: Icons.update, sub: 'workers with fresh entries'),
      ]),
      const SizedBox(height: 14),
      twoCol(wide,
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          chartTitle('Experience depth', sub: 'Workers by years in the trade'),
          HBars(entries: bucketCounts, color: orange),
        ])),
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          chartTitle('Avg years by trade', sub: 'Helps match workers to the right jobs'),
          HBars(entries: tradeRows.map((e) => MapEntry(e.key, e.value.round())).toList()),
        ])),
      ),
      const SizedBox(height: 14),
      twoCol(wide,
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          chartTitle('Experience added by month', sub: 'Updates to the existing profile section over time'),
          Bars(data: adds, color: orange),
        ])),
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          chartTitle('Where workers come from', sub: 'Most common past employers they list'),
          HBars(entries: topEmployers, color: const Color(0xFF7A9BC0)),
        ])),
      ),
    ]);
  }
}

// ---------- 4. work samples ----------
class SamplesTab extends StatelessWidget {
  final List<Worker> workers; final RangeFilter range;
  const SamplesTab({super.key, required this.workers, required this.range});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 760;
    final n = workers.length;
    final samples = samplesOf(workers);
    final withSamples = workers.where((w) => w.samples.isNotEmpty).length;
    final videos = samples.where((s) => s.isVideo).length;
    final avg = withSamples == 0 ? 0.0 : samples.length / withSamples;
    final adds = perMonth(samples.map((s) => s.uploaded).where((d) => d.isAfter(rangeStart(range))), rangeMonths(range));
    final topTags = topEntries(countBy(samples.map((s) => s.taskTag)));
    final recent = <(Worker, Sample)>[
      for (final w in workers)
        for (final s in w.samples) (w, s),
    ]..sort((a, b) => b.$2.uploaded.compareTo(a.$2.uploaded));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      kpiWrap([
        KpiCard(label: 'Workers with samples', value: '${n == 0 ? 0 : (100 * withSamples / n).round()}%', icon: Icons.photo_library_outlined, sub: '$withSamples of $n workers'),
        KpiCard(label: 'Total samples', value: '${samples.length}', icon: Icons.collections_outlined, sub: 'photos and videos of real work'),
        KpiCard(label: 'Avg per active worker', value: avg.toStringAsFixed(1), icon: Icons.stacked_bar_chart, sub: 'among workers with samples'),
        KpiCard(label: 'Videos', value: '${samples.isEmpty ? 0 : (100 * videos / samples.length).round()}%', icon: Icons.videocam_outlined, sub: '$videos of ${samples.length} uploads'),
      ]),
      const SizedBox(height: 14),
      twoCol(wide,
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          chartTitle('What the work shows', sub: 'Samples by task tag'),
          HBars(entries: topTags, color: const Color(0xFF7A9BC0)),
        ])),
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          chartTitle('Uploads by month', sub: 'Fresh samples mean workers are engaged'),
          Bars(data: adds, color: const Color(0xFF7A9BC0)),
        ])),
      ),
      const SizedBox(height: 14),
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        chartTitle('Latest samples', sub: 'Most recent uploads across workers'),
        for (final r in recent.take(8))
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkerPage(worker: r.$1))),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(r.$2.isVideo ? Icons.videocam_outlined : Icons.photo_outlined, size: 18, color: slate),
                const SizedBox(width: 10),
                Expanded(child: Text(r.$2.taskTag, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                Text(r.$1.name, style: const TextStyle(fontSize: 12.5, color: g500)),
                const SizedBox(width: 14),
                SizedBox(width: 96, child: Text(fmtDate(r.$2.uploaded), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: g500))),
              ]),
            ),
          ),
      ])),
    ]);
  }
}

// ---------- 5. workers table ----------
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
class WorkerPage extends StatelessWidget {
  final Worker worker;
  const WorkerPage({super.key, required this.worker});

  @override
  Widget build(BuildContext context) {
    final w = worker;
    final wide = MediaQuery.of(context).size.width >= 760;
    final samples = [...w.samples]..sort((a, b) => b.uploaded.compareTo(a.uploaded));
    final exp = [...w.experience]..sort((a, b) => b.added.compareTo(a.added));
    return Scaffold(
      appBar: AppBar(backgroundColor: slateDark, foregroundColor: Colors.white, title: const Text('Worker profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      body: SafeArea(
        child: SingleChildScrollView(
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
                ])),
                const SizedBox(height: 14),
                twoCol(wide,
                  CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    chartTitle('Personal credentials', sub: '${w.creds.length} self-added · badge = NCCER-sourced (proposed split)'),
                    if (w.creds.isEmpty) const Text('None added yet.', style: TextStyle(color: g500, fontSize: 13)),
                    for (final c in w.creds)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Icon(c.isBadge ? Icons.military_tech_outlined : Icons.badge_outlined, size: 17, color: c.isBadge ? slate : orange),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('Added ${fmtDate(c.added)}', style: const TextStyle(fontSize: 11.5, color: g500)),
                          ])),
                          if (c.expiry != null)
                            Tag(c.expiry!.isBefore(demoNow) ? 'Expired' : 'Exp ${fmtDate(c.expiry!)}', c.expiry!.isBefore(demoNow) ? red : c.expiry!.isBefore(demoNow.add(const Duration(days: 90))) ? amber : g600, c.expiry!.isBefore(demoNow) ? redBg : c.expiry!.isBefore(demoNow.add(const Duration(days: 90))) ? amberBg : g100),
                        ]),
                      ),
                  ])),
                  CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    chartTitle('Work experience', sub: 'From the existing profile section'),
                    if (exp.isEmpty) const Text('Not filled yet.', style: TextStyle(color: g500, fontSize: 13)),
                    for (final e in exp)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          const Icon(Icons.work_history_outlined, size: 17, color: slate),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${e.role} · ${e.employer}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('${e.years.toStringAsFixed(1)} yrs · added ${fmtDate(e.added)}', style: const TextStyle(fontSize: 11.5, color: g500)),
                          ])),
                        ]),
                      ),
                  ])),
                ),
                const SizedBox(height: 14),
                CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  chartTitle('Work samples', sub: '${w.samples.length} samples - same task tags the worker-side add flow uses'),
                  if (samples.isEmpty) const Text('No samples yet.', style: TextStyle(color: g500, fontSize: 13)),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final sm in samples)
                      Container(
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
                              Text(fmtDate(sm.uploaded), style: const TextStyle(fontSize: 11, color: g500)),
                            ]),
                          ),
                        ]),
                      ),
                  ]),
                ])),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
