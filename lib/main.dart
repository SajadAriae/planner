import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzd;
import 'package:timezone/timezone.dart' as tz;
 
final notif = FlutterLocalNotificationsPlugin();
late SharedPreferences prefs;
final seed = ValueNotifier<int>(0);
bool jal = true;
const seeds = [Colors.teal, Colors.indigo, Colors.pink, Colors.orange, Colors.purple, Colors.blueGrey];
const wdn = {6: 'شنبه', 7: 'یکشنبه', 1: 'دوشنبه', 2: 'سه‌شنبه', 3: 'چهارشنبه', 4: 'پنجشنبه', 5: 'جمعه'};
const wdo = [6, 7, 1, 2, 3, 4, 5];
const hope = [
  'امروز لازم نیست کامل باشی؛ یک قدم کوچیک هم حساب می‌شه.',
  'هر کاری که امروز انجام دادی، از دیروز جلوترت می‌بره.',
  'خسته شدن یعنی تلاش کردی. کمی نفس بکش و ادامه بده.',
  'کارهای بزرگ از همین قدم‌های کوچیک ساخته می‌شن.',
  'روزهای سخت‌تر از این رو هم رد کردی؛ این روز هم رد می‌شه.',
  'نتیجه‌ی امروزت ممکنه فردا معلوم بشه. به مسیر اعتماد کن.',
  'هر روز یه شروع تازه‌ست. همین الان یه کار کوچیک رو شروع کن.'
];
 
String ds(DateTime d) => d.toIso8601String().substring(0, 10);
String hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
String n(num v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
String en(String s) => s.replaceAllMapped(RegExp('[۰-۹]'), (m) => '${m[0]!.codeUnitAt(0) - 0x06F0}').replaceAll(',', '').replaceAll('٬', '');
int byStart(Map a, Map b) => (a['s'] as int).compareTo(b['s'] as int);
 
List<int> g2j(int gy, int gm, int gd) {
  const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 + 365 * gy + (gy2 + 3) ~/ 4 - (gy2 + 99) ~/ 100 + (gy2 + 399) ~/ 400 + gd + gdm[gm - 1];
  var jy = -1595 + 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return [jy, jm, jd];
}
 
String fd(String iso) {
  if (!jal) return iso.substring(0, 10);
  final p = iso.substring(0, 10).split('-').map(int.parse).toList();
  final j = g2j(p[0], p[1], p[2]);
  return '${j[0]}/${j[1].toString().padLeft(2, '0')}/${j[2].toString().padLeft(2, '0')}';
}
 
class D {
  static List<Map> tasks = [], events = [], txs = [];
  static void load() {
    List<Map> r(String k) => (jsonDecode(prefs.getString(k) ?? '[]') as List).cast<Map>();
    tasks = r('tasks');
    events = r('events');
    txs = r('txs');
  }
 
  static void save() {
    prefs.setString('tasks', jsonEncode(tasks));
    prefs.setString('events', jsonEncode(events));
    prefs.setString('txs', jsonEncode(txs));
  }
}
 
const nd = NotificationDetails(
    android: AndroidNotificationDetails('ev', 'یادآوری برنامه', importance: Importance.max, priority: Priority.high));
 
Future<void> zs(int id, String t, String b, tz.TZDateTime w, {bool weekly = true}) => notif.zonedSchedule(id, t, b, w, nd,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: weekly ? DateTimeComponents.dayOfWeekAndTime : null);
 
// Next occurrence of weekday `wd` at minute-of-day `m` (Tehran has no DST, so a fixed zone is safe).
tz.TZDateTime nextAt(int wd, int m) {
  final now = tz.TZDateTime.now(tz.local);
  var t = tz.TZDateTime(tz.local, now.year, now.month, now.day).add(Duration(minutes: m));
  while (t.weekday != wd || !t.isAfter(now)) {
    t = t.add(const Duration(days: 1));
  }
  return t;
}
 
Future<void> schedule(Map e) => zs(e['id'], e['t'], 'شروع تا ۱۰ دقیقه‌ی دیگر', nextAt(e['wd'], (e['s'] as int) - 10));
 
Future<void> scheduleTask(Map k) async {
  final t = tz.TZDateTime.from(DateTime.parse(k['r']), tz.local);
  if (t.isAfter(tz.TZDateTime.now(tz.local))) await zs(k['id'], 'یادآوری: ${k['t']}', 'زمانش رسیده', t, weekly: false);
}
 
Future<void> scheduleHope(int m) async {
  for (var i = 1; i <= 7; i++) {
    await notif.cancel(900000 + i);
    if (m >= 0) await zs(900000 + i, 'یه پیام برای تو', hope[i - 1], nextAt(i, m));
  }
}
 
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzd.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
  prefs = await SharedPreferences.getInstance();
  seed.value = prefs.getInt('clr') ?? 0;
  jal = prefs.getBool('jal') ?? true;
  await notif.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  final a = notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await a?.requestNotificationsPermission();
  await a?.requestExactAlarmsPermission();
  runApp(const App());
}
 
class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => ValueListenableBuilder<int>(
      valueListenable: seed,
      builder: (c, i, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(useMaterial3: true, colorSchemeSeed: seeds[i]),
            builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
            home: const Home(),
          ));
}
 
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _H();
}
 
class _H extends State<Home> {
  int tab = 0;
  String q = '';
  @override
  void initState() {
    super.initState();
    D.load();
  }
 
  void upd() {
    D.save();
    setState(() {});
  }
 
  Future<String?> ask(String hint, [String init = '']) {
    final c = TextEditingController(text: init);
    return showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              content: TextField(
                  controller: c,
                  autofocus: true,
                  decoration: InputDecoration(hintText: hint),
                  onSubmitted: (v) => Navigator.pop(context, v)),
              actions: [TextButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('ثبت'))],
            ));
  }
 
  void settings() => showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (ctx, set) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('رنگ برنامه'),
                const SizedBox(height: 8),
                Wrap(spacing: 10, children: [
                  for (var i = 0; i < seeds.length; i++)
                    GestureDetector(
                        onTap: () {
                          seed.value = i;
                          prefs.setInt('clr', i);
                        },
                        child: CircleAvatar(backgroundColor: seeds[i], radius: 16))
                ]),
                SwitchListTile(
                    title: const Text('نمایش تاریخ شمسی'),
                    value: jal,
                    onChanged: (v) {
                      jal = v;
                      prefs.setBool('jal', v);
                      set(() {});
                      setState(() {});
                    }),
                ListTile(
                    title: const Text('پیام امیدبخش روزانه'),
                    subtitle: Text((prefs.getInt('hope') ?? -1) < 0 ? 'خاموش' : hm(prefs.getInt('hope')!)),
                    onTap: () async {
                      final t = await showTimePicker(
                          context: ctx, initialTime: const TimeOfDay(hour: 9, minute: 0), helpText: 'ساعت پیام');
                      if (t == null) return;
                      prefs.setInt('hope', t.hour * 60 + t.minute);
                      await scheduleHope(t.hour * 60 + t.minute);
                      set(() {});
                    },
                    trailing: TextButton(
                        onPressed: () async {
                          prefs.setInt('hope', -1);
                          await scheduleHope(-1);
                          set(() {});
                        },
                        child: const Text('خاموش'))),
              ]))));
 
  Future<void> addTask() async {
    final s = await ask('کار جدید (یک قدم مشخص)');
    if (s == null || s.trim().isEmpty || !mounted) return;
    final k = <String, dynamic>{'id': DateTime.now().millisecondsSinceEpoch ~/ 1000, 't': s.trim(), 'done': false};
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now.subtract(const Duration(days: 1)),
        lastDate: now.add(const Duration(days: 730)),
        helpText: 'روز یادآوری (بستن = بدون یادآوری)');
    if (d != null && mounted) {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay.now(), helpText: 'ساعت یادآوری');
      if (t != null) {
        k['r'] = DateTime(d.year, d.month, d.day, t.hour, t.minute).toIso8601String();
        await scheduleTask(k);
      }
    }
    D.tasks.add(k);
    upd();
  }
 
  Future<void> addEvent([Map? o]) async {
    final title = await ask('عنوان (مثلاً کلاس ...)', o?['t'] ?? '');
    if (title == null || title.trim().isEmpty || !mounted) return;
    final wd = await showDialog<int>(
        context: context,
        builder: (_) => SimpleDialog(title: const Text('روز هفته'), children: [
              for (final d in wdo) SimpleDialogOption(onPressed: () => Navigator.pop(context, d), child: Text(wdn[d]!))
            ]));
    if (wd == null || !mounted) return;
    final a = await showTimePicker(
        context: context,
        initialTime: o != null ? TimeOfDay(hour: o['s'] ~/ 60, minute: o['s'] % 60) : const TimeOfDay(hour: 8, minute: 0),
        helpText: 'شروع');
    if (a == null || !mounted) return;
    final b = await showTimePicker(
        context: context,
        initialTime: o != null ? TimeOfDay(hour: o['e'] ~/ 60, minute: o['e'] % 60) : a.replacing(hour: (a.hour + 2) % 24),
        helpText: 'پایان');
    if (b == null || !mounted) return;
    final now = DateTime.now();
    final to = await showDatePicker(
        context: context,
        initialDate: o != null ? DateTime.parse(o['to']) : now.add(const Duration(days: 112)),
        firstDate: DateTime(2020),
        lastDate: now.add(const Duration(days: 730)),
        helpText: 'پایان ترم');
    if (to == null) return;
    final e = {
      'id': o?['id'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      't': title.trim(),
      'wd': wd,
      's': a.hour * 60 + a.minute,
      'e': b.hour * 60 + b.minute,
      'from': o?['from'] ?? ds(now),
      'to': ds(to)
    };
    if (o != null) {
      notif.cancel(o['id']);
      D.events.remove(o);
    }
    D.events.add(e);
    await schedule(e);
    upd();
  }
 
  Future<void> addTx() async {
    final amt = TextEditingController(), ttl = TextEditingController();
    bool inc = false;
    String cat = 'سایر';
    const cats = ['غذا', 'حمل‌ونقل', 'خرید', 'قبوض', 'کار', 'سایر'];
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => StatefulBuilder(
            builder: (ctx, set) => Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: ttl, decoration: const InputDecoration(labelText: 'عنوان')),
                  TextField(
                      controller: amt,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'مبلغ (تومان)')),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('هزینه')),
                        ButtonSegment(value: true, label: Text('درآمد'))
                      ],
                      selected: {inc},
                      onSelectionChanged: (s) => set(() => inc = s.first)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: [
                    for (final k in cats)
                      ChoiceChip(label: Text(k), selected: cat == k, onSelected: (_) => set(() => cat = k))
                  ]),
                  const SizedBox(height: 8),
                  FilledButton(
                      onPressed: () {
                        final v = int.tryParse(en(amt.text));
                        if (v == null) return;
                        D.txs.add({'a': v, 'inc': inc, 'c': cat, 't': ttl.text.trim(), 'd': ds(DateTime.now())});
                        Navigator.pop(ctx);
                        upd();
                      },
                      child: const Text('ثبت')),
                ]))));
  }
 
  Widget tasks() {
    final now = DateTime.now(), t = ds(now), nowIso = now.toIso8601String();
    final wk = ds(now.subtract(Duration(days: (now.weekday + 1) % 7)));
    final ev = D.events
        .where((e) => e['wd'] == now.weekday && t.compareTo(e['from']) >= 0 && t.compareTo(e['to']) <= 0)
        .toList()
      ..sort(byStart);
    final open = D.tasks.where((k) => k['done'] != true).toList();
    final done = D.tasks.where((k) => k['done'] == true && k['doneAt'] == t).toList();
    Widget tile(Map k, bool d) => Dismissible(
        key: ObjectKey(k),
        background: Container(color: Colors.red),
        onDismissed: (_) {
          notif.cancel(k['id'] ?? 0);
          D.tasks.remove(k);
          upd();
        },
        child: CheckboxListTile(
            value: d,
            title: Text(k['t'],
                style: d ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey) : null),
            subtitle: k['r'] != null ? Text('⏰ ${fd(k['r'])}  ${(k['r'] as String).substring(11, 16)}') : null,
            onChanged: (_) {
              k['done'] = !d;
              k['doneAt'] = d ? null : t;
              if (!d) notif.cancel(k['id'] ?? 0);
              upd();
            }));
    Widget rep(String label, String from) {
      final dn = D.tasks.where((k) => k['done'] == true && ((k['doneAt'] ?? '') as String).compareTo(from) >= 0).length;
      final od = open.where((k) {
        final r = k['r'] as String?;
        return r != null && r.compareTo(nowIso) < 0 && r.substring(0, 10).compareTo(from) >= 0;
      }).length;
      return ListTile(dense: true, title: Text(label), trailing: Text('انجام‌شده $dn   |   عقب‌افتاده $od'));
    }
 
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final e in ev)
        Card(
            child: ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(e['t']),
                subtitle: Text('${hm(e['s'])} – ${hm(e['e'])}'))),
      const Padding(
          padding: EdgeInsets.only(top: 12, bottom: 4),
          child: Text('کارهای در انتظار', style: TextStyle(fontWeight: FontWeight.bold))),
      for (final k in open) tile(k, false),
      if (open.isEmpty) const Text('کاری نمونده. با دکمه‌ی + یک کار ثبت کن.'),
      if (done.isNotEmpty)
        const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 4),
            child: Text('انجام‌شده‌ی امروز', style: TextStyle(fontWeight: FontWeight.bold))),
      for (final k in done) tile(k, true),
      const Divider(height: 32),
      const Text('گزارش کارها', style: TextStyle(fontWeight: FontWeight.bold)),
      Card(child: Column(children: [rep('امروز', t), rep('این هفته', wk), rep('این ماه', ds(DateTime(now.year, now.month)))])),
    ]);
  }
 
  Widget cal() => ListView(children: [
        for (final d in wdo) ...[
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(wdn[d]!, style: const TextStyle(fontWeight: FontWeight.bold))),
          for (final e in D.events.where((e) => e['wd'] == d).toList()..sort(byStart))
            ListTile(
                onTap: () => addEvent(e),
                title: Text(e['t']),
                subtitle: Text('${hm(e['s'])} – ${hm(e['e'])}   تا ${fd(e['to'])}'),
                trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      notif.cancel(e['id']);
                      D.events.remove(e);
                      upd();
                    })),
        ]
      ]);
 
  Widget money() {
    final now = DateTime.now();
    final wk = now.subtract(Duration(days: (now.weekday + 1) % 7));
    int sum(Iterable<Map> l, bool inc) => l.where((x) => x['inc'] == inc).fold(0, (p, x) => p + (x['a'] as int));
    Iterable<Map> since(String from) => D.txs.where((x) => (x['d'] as String).compareTo(from) >= 0);
    final froms = {'امروز': ds(now), 'این هفته': ds(wk), 'این ماه': ds(DateTime(now.year, now.month))};
    final found = D.txs.where((x) => '${x['t'] ?? ''} ${x['c']}'.contains(q)).toList().reversed.toList();
    return ListView(padding: const EdgeInsets.all(12), children: [
      TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'جستجو در عنوان یا دسته'),
          onChanged: (v) => setState(() => q = v.trim())),
      if (q.isNotEmpty)
        Card(
            child: ListTile(
                title: Text('${found.length} بار'),
                subtitle: Text('درآمد ${n(sum(found, true))}  |  هزینه ${n(sum(found, false))}')))
      else
        for (final f in froms.entries)
          Card(
              child: ListTile(
                  title: Text(f.key),
                  subtitle: Text('درآمد ${n(sum(since(f.value), true))}  |  هزینه ${n(sum(since(f.value), false))}'),
                  trailing: Text(n(sum(since(f.value), true) - sum(since(f.value), false)),
                      style: const TextStyle(fontWeight: FontWeight.bold)))),
      for (final x in found.take(q.isEmpty ? 30 : 500))
        Dismissible(
            key: ObjectKey(x),
            background: Container(color: Colors.red),
            onDismissed: (_) {
              D.txs.remove(x);
              upd();
            },
            child: ListTile(
                dense: true,
                leading: Icon(x['inc'] == true ? Icons.south_west : Icons.north_east,
                    color: x['inc'] == true ? Colors.green : Colors.red),
                title: Text((x['t'] ?? '') != '' ? x['t'] : x['c']),
                subtitle: Text('${x['c']} • ${fd(x['d'])}'),
                trailing: Text(n(x['a'])))),
    ]);
  }
 
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
            title: Text(['کارها', 'برنامه‌ی هفتگی', 'مالی'][tab]),
            actions: [IconButton(icon: const Icon(Icons.settings), onPressed: settings)]),
        body: [tasks, cal, money][tab](),
        floatingActionButton: FloatingActionButton(
            onPressed: () => [addTask, addEvent, addTx][tab](), child: const Icon(Icons.add)),
        bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.checklist), label: 'کارها'),
              NavigationDestination(icon: Icon(Icons.calendar_month), label: 'تقویم'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'مالی'),
            ]),
      );
}
 
