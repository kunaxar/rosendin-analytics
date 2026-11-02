import 'dart:math';

// ---------- models ----------
class Cred {
  final String name;
  final bool isBadge; // NCCER badge vs other issuer
  final DateTime added;
  final DateTime? expiry;
  const Cred(this.name, this.isBadge, this.added, this.expiry);
}

class ExpRecord {
  final String employer;
  final String role;
  final double years;
  final DateTime added;
  const ExpRecord(this.employer, this.role, this.years, this.added);
}

class Sample {
  final String taskTag;
  final bool isVideo;
  final DateTime uploaded;
  const Sample(this.taskTag, this.isVideo, this.uploaded);
}

class Worker {
  final String name;
  final String trade;
  final double yearsExperience;
  final List<Cred> creds;      // personal, self-added only
  final List<ExpRecord> experience;
  final List<Sample> samples;
  final int profileComplete;   // 0..100
  final DateTime lastUpdate;
  const Worker(this.name, this.trade, this.yearsExperience, this.creds, this.experience, this.samples, this.profileComplete, this.lastUpdate);
}

// ---------- fictional source lists ----------
const firstNames = ['Marcus','Derek','Jose','Tyler','Brandon','Miguel','Aaron','Chris','Ray','Hector','Sam','Dustin','Kyle','Angel','Ramon','Brett','Corey','Ivan','Jake','Luis','Nate','Oscar','Paul','Ricky','Shane','Tony','Victor','Wade','Alex','Brian','Cody','Daniel','Erik','Frank','Gary','Henry','Israel','James','Kevin','Lance','Marco','Noah','Omar','Peter','Raul','Steve','Travis','Vince','Will','Zach','Cesar','Danny','Edgar','Felix','Gilbert','Hugo','Joel','Kenny','Leo','Mario','Nick'];
const lastNames = ['Rivera','Carter','Lopez','Brooks','Nguyen','Garcia','Miller','Davis','Reyes','Coleman','Flores','Barnes','Ortiz','Jenkins','Perry','Butler','Simmons','Foster','Powell','Long','Patterson','Hughes','Washington','Morales','Griffin','Hayes','Myers','Ford','Hamilton','Graham','Sullivan','Wallace','Woods','Cole','West','Jordan','Owens','Fisher','Ellis','Harrison'];
const trades = ['Journeyman Electrician','Apprentice Electrician','Foreman','Low-Voltage Technician','Solar Installer','Estimator'];
const tradeWeights = [0.34, 0.26, 0.10, 0.12, 0.10, 0.08];
const badgeNames = ['NCCER Core','NCCER Electrical Level 1','NCCER Electrical Level 2','NCCER Electrical Level 3','NCCER Power Line Worker'];
const otherCredNames = ['OSHA 10','OSHA 30','NFPA 70E','First Aid / CPR','Forklift (sit-down)','MEWP / scissor lift','State journeyman card','CDL Class B','Confined space','Fall protection'];
const employers = ['Helix Electric','Redwood Electric Co.','Bayline Electric','Summit Power Systems','Pacific Grid Contractors','Copperline Services','Atlas Power Group','Beacon Electrical','Truevolt Inc.','Northgate Electric'];
const taskTags = ['Conduit bending','Panel wiring','Cable pulling','Terminations','Switchgear install','Blueprint layout','Solar array mount','Underground rough-in'];

// ---------- dataset (deterministic, fictional) ----------
final DateTime demoNow = DateTime.now();
DateTime daysAgo(int d) => demoNow.subtract(Duration(days: d));

List<Worker> buildWorkers() {
  final r = Random(42);
  String pickTrade() {
    final x = r.nextDouble();
    double acc = 0;
    for (var i = 0; i < trades.length; i++) { acc += tradeWeights[i]; if (x < acc) return trades[i]; }
    return trades.first;
  }
  final used = <String>{};
  final out = <Worker>[];
  for (var i = 0; i < 64; i++) {
    String name;
    do { name = '${firstNames[r.nextInt(firstNames.length)]} ${lastNames[r.nextInt(lastNames.length)]}'; } while (!used.add(name));
    final trade = pickTrade();
    final baseYears = switch (trade) {
      'Apprentice Electrician' => 0.5 + r.nextDouble() * 3.5,
      'Foreman' => 10 + r.nextDouble() * 12,
      'Estimator' => 6 + r.nextDouble() * 10,
      _ => 3 + r.nextDouble() * 14,
    };
    // personal credentials
    final creds = <Cred>[];
    if (r.nextDouble() < 0.78) {
      final nBadges = r.nextDouble() < 0.55 ? 1 + r.nextInt(3) : 0;
      for (var b = 0; b < nBadges; b++) {
        creds.add(Cred(badgeNames[r.nextInt(badgeNames.length)], true, daysAgo(r.nextInt(400)), null));
      }
      final nOther = r.nextInt(4);
      for (var c = 0; c < nOther; c++) {
        final hasExpiry = r.nextDouble() < 0.7;
        final added = daysAgo(30 + r.nextInt(700));
        final expiry = hasExpiry ? added.add(Duration(days: 365 * (2 + r.nextInt(3)))) : null;
        creds.add(Cred(otherCredNames[r.nextInt(otherCredNames.length)], false, added, expiry));
      }
    }
    // experience records
    final exp = <ExpRecord>[];
    if (r.nextDouble() < 0.85) {
      final n = 1 + r.nextInt(3);
      for (var e = 0; e < n; e++) {
        exp.add(ExpRecord(employers[r.nextInt(employers.length)], trade, 0.5 + r.nextDouble() * 6, daysAgo(r.nextInt(400))));
      }
    }
    // work samples
    final samples = <Sample>[];
    if (r.nextDouble() < 0.44) {
      final n = 1 + r.nextInt(6);
      for (var s = 0; s < n; s++) {
        samples.add(Sample(taskTags[r.nextInt(taskTags.length)], r.nextDouble() < 0.22, daysAgo(r.nextInt(240))));
      }
    }
    final complete = (35 + r.nextInt(65)).clamp(0, 100);
    out.add(Worker(name, trade, double.parse(baseYears.toStringAsFixed(1)), creds, exp, samples, complete, daysAgo(r.nextInt(160))));
  }
  return out;
}

final List<Worker> allWorkers = buildWorkers();

// ---------- aggregation helpers ----------
class MonthCount {
  final String label; // e.g. "Jun"
  final DateTime monthStart;
  final int value;
  const MonthCount(this.label, this.monthStart, this.value);
}

const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
String mLabel(DateTime d) => monthNames[d.month - 1];

List<Worker> filteredWorkers(String trade) => trade == 'All trades' ? allWorkers : allWorkers.where((w) => w.trade == trade).toList();

List<MonthCount> perMonth(Iterable<DateTime> dates, int monthsBack) {
  final now = DateTime(demoNow.year, demoNow.month, 1);
  final buckets = <String, int>{};
  for (final d in dates) {
    final m = DateTime(d.year, d.month, 1);
    buckets['${m.year}-${m.month}'] = (buckets['${m.year}-${m.month}'] ?? 0) + 1;
  }
  final out = <MonthCount>[];
  for (var i = monthsBack - 1; i >= 0; i--) {
    final m = DateTime(now.year, now.month - i, 1);
    out.add(MonthCount(mLabel(m), m, buckets['${m.year}-${m.month}'] ?? 0));
  }
  return out;
}

Map<String, int> countBy(Iterable<String> items) {
  final m = <String, int>{};
  for (final i in items) m[i] = (m[i] ?? 0) + 1;
  return m;
}

List<MapEntry<String, int>> topEntries(Map<String, int> m, [int n = 8]) {
  final l = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return l.take(n).toList();
}

String fmtDate(DateTime d) => '${monthNames[d.month - 1]} ${d.day}, ${d.year}';
