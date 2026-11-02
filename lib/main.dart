import 'package:flutter/material.dart';
import 'ui.dart';
import 'data.dart';
import 'tabs.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Rosendin Analytics - BuilderFAX',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Shell(),
      );
}

enum RangeFilter { m6, m12, all }
String rangeLabel(RangeFilter r) => switch (r) { RangeFilter.m6 => 'Last 6 months', RangeFilter.m12 => 'Last 12 months', RangeFilter.all => 'All time' };
int rangeMonths(RangeFilter r) => switch (r) { RangeFilter.m6 => 6, RangeFilter.m12 => 12, RangeFilter.all => 16 };
DateTime rangeStart(RangeFilter r) => switch (r) {
      RangeFilter.m6 => daysAgo(183),
      RangeFilter.m12 => daysAgo(365),
      RangeFilter.all => DateTime(2020),
    };

const tabDefs = [
  (Icons.grid_view_rounded, 'Overview'),
  (Icons.badge_outlined, 'Personal credentials'),
  (Icons.work_history_outlined, 'Work experience'),
  (Icons.photo_library_outlined, 'Work samples'),
  (Icons.people_outline, 'Workers'),
];

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  String trade = 'All trades';
  RangeFilter range = RangeFilter.m6;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 940;
    final workers = filteredWorkers(trade);
    final body = Column(children: [
      demoBanner(),
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 14, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _header(wide),
                const SizedBox(height: 18),
                if (!wide) _tabChips(),
                _tabBody(workers),
              ]),
            ),
          ),
        ),
      ),
    ]);
    return Scaffold(
      body: SafeArea(
        child: wide ? Row(children: [_sidebar(), Expanded(child: body)]) : Column(children: [_topbar(), Expanded(child: body)]),
      ),
    );
  }

  Widget _tabBody(List<Worker> workers) => switch (tab) {
        0 => OverviewTab(workers: workers, range: range),
        1 => CredentialsTab(workers: workers, range: range),
        2 => ExperienceTab(workers: workers, range: range),
        3 => SamplesTab(workers: workers, range: range),
        _ => const WorkersTab(),
      };

  Widget _header(bool wide) {
    final filters = Wrap(spacing: 10, runSpacing: 10, children: [
      SizedBox(
        width: 240,
        child: DropdownButtonFormField<String>(
          initialValue: trade,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.handyman_outlined, size: 18)),
          items: ['All trades', ...trades].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => trade = v!),
        ),
      ),
      SizedBox(
        width: 180,
        child: DropdownButtonFormField<RangeFilter>(
          initialValue: range,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.date_range, size: 18)),
          items: RangeFilter.values.map((r) => DropdownMenuItem(value: r, child: Text(rangeLabel(r), style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => range = v!),
        ),
      ),
    ]);
    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Rosendin Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        const SizedBox(width: 10),
        const Tag('New', orange, Color(0xFFFFF0EA)),
      ]),
      const SizedBox(height: 4),
      const Text('What Rosendin workers add themselves - personal credentials, work experience and work samples.',
          style: TextStyle(fontSize: 13.5, color: g500)),
    ]);
    return wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), filters])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), filters]);
  }

  Widget _tabChips() => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < tabDefs.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: () => setState(() => tab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: tab == i ? slate : Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: tab == i ? slate : g300),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(tabDefs[i].$1, size: 15, color: tab == i ? Colors.white : g600),
                      const SizedBox(width: 6),
                      Text(tabDefs[i].$2, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tab == i ? Colors.white : g600)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      );

  Widget _navItem(IconData icon, String label, {bool active = false, bool disabled = false, VoidCallback? onTap, int? count}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: active ? Colors.white.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(icon, size: 17, color: disabled ? Colors.white38 : Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: disabled ? Colors.white38 : Colors.white))),
              if (count != null) Text('$count', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ]),
          ),
        ),
      );

  Widget _navSection(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 12, 6),
        child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Colors.white54)),
      );

  Widget _sidebar() => Container(
        width: 244,
        color: slateDark,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 22, 12, 4),
            child: Row(children: [
              Icon(Icons.verified_user_outlined, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('BuilderFAX', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 12, 6),
            child: Text('Rosendin back office', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
          ),
          _navSection('Existing - not in this prototype'),
          _navItem(Icons.dashboard_outlined, 'Dashboard', disabled: true),
          _navItem(Icons.assignment_ind_outlined, 'Assigned credentials', disabled: true),
          _navSection('Rosendin Analytics'),
          for (var i = 0; i < tabDefs.length; i++)
            _navItem(tabDefs[i].$1, tabDefs[i].$2, active: tab == i, onTap: () => setState(() => tab = i)),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text('Worker-added data only. Assigned credential analytics stay under Workbench.', style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4)),
          ),
        ]),
      );

  Widget _topbar() => Container(
        color: slateDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: const Row(children: [
          Icon(Icons.verified_user_outlined, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('BuilderFAX', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          SizedBox(width: 6),
          Text('· Rosendin back office', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      );
}
