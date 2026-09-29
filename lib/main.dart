import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzd;
import 'package:timezone/timezone.dart' as tz;

final notif = FlutterLocalNotificationsPlugin();
late SharedPreferences prefs;

const wdn = {6: 'شنبه', 7: 'یکشنبه', 1: 'دوشنبه', 2: 'سه‌شنبه', 3: 'چهارشنبه', 4: 'پنجشنبه', 5: 'جمعه'};
const wdo = [6, 7, 1, 2, 3, 4, 5];

String ds(DateTime d) => d.toIso8601String().substring(0, 10);
String hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
String n(num v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
String en(String s) => s.replaceAllMapped(RegExp('[۰-۹]'), (m) => '${m[0]!.codeUnitAt(0) - 0x06F0}').replaceAll(',', '').replaceAll('٬', '');
int byStart(Map a, Map b) => (a['s'] as int).compareTo(b['s'] as int);

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

// Weekly repeating reminder, 10 minutes before start. Tehran has no DST, so a fixed zone is safe.
Future<void> schedule(Map e) async {
  final now = tz.TZDateTime.now(tz.local);
  var t = tz.TZDateTime(tz.local, now.year, now.month, now.day).add(Duration(minutes: (e['s'] as int) - 10));
  while (t.weekday != e['wd'] || !t.isAfter(now)) {
    t = t.add(const Duration(days: 1));
  }
  await notif.zonedSchedule(e['id'], e['t'], 'شروع تا ۱۰ دقیقه‌ی دیگر', t, nd,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzd.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
  prefs = await SharedPreferences.getInstance();
  await notif.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  final a = notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await a?.requestNotificationsPermission();
  await a?.requestExactAlarmsPermission();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _H();
}

class _H extends State<Home> {
  int tab = 0;
  @override
  void initState() {
    super.initState();
    D.load();
  }

  void upd() {
    D.save();
    setState(() {});
  }

  Future<String?> ask(String hint) {
    final c = TextEditingController();
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

  Future<void> addTask() async {
    final s = await ask('کار جدید (یک قدم مشخص)');
    if (s != null && s.trim().isNotEmpty) {
      D.tasks.add({'t': s.trim(), 'done': false});
      upd();
    }
  }

  Future<void> addEvent() async {
    final title = await ask('عنوان (مثلاً کلاس ...)');
    if (title == null || title.trim().isEmpty || !mounted) return;
    final wd = await showDialog<int>(
        context: context,
        builder: (_) => SimpleDialog(title: const Text('روز هفته'), children: [
              for (final d in wdo) SimpleDialogOption(onPressed: () => Navigator.pop(context, d), child: Text(wdn[d]!))
            ]));
    if (wd == null || !mounted) return;
    final a = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0), helpText: 'شروع');
    if (a == null || !mounted) return;
    final b = await showTimePicker(
        context: context, initialTime: a.replacing(hour: (a.hour + 2) % 24), helpText: 'پایان');
    if (b == null || !mounted) return;
    final now = DateTime.now();
    final to = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 112)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 730)),
        helpText: 'پایان ترم');
    if (to == null) return;
    final e = {
      'id': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      't': title.trim(),
      'wd': wd,
      's': a.hour * 60 + a.minute,
      'e': b.hour * 60 + b.minute,
      'from': ds(now),
      'to': ds(to)
    };
    D.events.add(e);
    await schedule(e);
    upd();
  }

  Future<void> addTx() async {
    final amt = TextEditingController();
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
                        D.txs.add({'a': v, 'inc': inc, 'c': cat, 'd': ds(DateTime.now())});
                        Navigator.pop(ctx);
                        upd();
                      },
                      child: const Text('ثبت')),
                ]))));
  }

  Widget today() {
    final now = DateTime.now(), t = ds(now);
    final ev = D.events
        .where((e) => e['wd'] == now.weekday && t.compareTo(e['from']) >= 0 && t.compareTo(e['to']) <= 0)
        .toList()
      ..sort(byStart);
    final open = D.tasks.where((k) => k['done'] != true).toList();
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final e in ev)
        Card(
            child: ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(e['t']),
                subtitle: Text('${hm(e['s'])} – ${hm(e['e'])}'))),
      const Padding(
          padding: EdgeInsets.only(top: 12, bottom: 4),
          child: Text('سه کار اصلی امروز', style: TextStyle(fontWeight: FontWeight.bold))),
      for (final k in open.take(3))
        CheckboxListTile(
            value: false,
            title: Text(k['t']),
            onChanged: (_) {
              k['done'] = true;
              upd();
            }),
      if (open.length > 3) Text('+ ${open.length - 3} کار در صف؛ بعد از انجام این‌ها نوبتشونه'),
      if (open.isEmpty) const Text('کاری نمونده. با دکمه‌ی + یک کار ثبت کن.'),
    ]);
  }

  Widget cal() => ListView(children: [
        for (final d in wdo) ...[
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(wdn[d]!, style: const TextStyle(fontWeight: FontWeight.bold))),
          for (final e in D.events.where((e) => e['wd'] == d).toList()..sort(byStart))
            Dismissible(
                key: ValueKey(e['id']),
                background: Container(color: Colors.red),
                onDismissed: (_) {
                  notif.cancel(e['id']);
                  D.events.remove(e);
                  upd();
                },
                child: ListTile(title: Text(e['t']), subtitle: Text('${hm(e['s'])} – ${hm(e['e'])}   تا ${e['to']}'))),
        ]
      ]);

  Widget money() {
    final now = DateTime.now();
    final wk = now.subtract(Duration(days: (now.weekday + 1) % 7));
    int sum(String from, bool inc) => D.txs
        .where((x) => x['inc'] == inc && (x['d'] as String).compareTo(from) >= 0)
        .fold(0, (p, x) => p + (x['a'] as int));
    final froms = {'امروز': ds(now), 'این هفته': ds(wk), 'این ماه': ds(DateTime(now.year, now.month))};
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final f in froms.entries)
        Card(
            child: ListTile(
                title: Text(f.key),
                subtitle: Text('درآمد ${n(sum(f.value, true))}  |  هزینه ${n(sum(f.value, false))}'),
                trailing: Text(n(sum(f.value, true) - sum(f.value, false)),
                    style: const TextStyle(fontWeight: FontWeight.bold)))),
      for (final x in D.txs.reversed.take(30).toList())
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
                title: Text('${x['c']}   ${n(x['a'])}'),
                subtitle: Text(x['d']))),
    ]);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(['امروز', 'برنامه‌ی هفتگی', 'مالی'][tab])),
        body: [today, cal, money][tab](),
        floatingActionButton: FloatingActionButton(
            onPressed: () => [addTask, addEvent, addTx][tab](), child: const Icon(Icons.add)),
        bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.today), label: 'امروز'),
              NavigationDestination(icon: Icon(Icons.calendar_month), label: 'تقویم'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'مالی'),
            ]),
      );
}
