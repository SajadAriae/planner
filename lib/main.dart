
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzd;
import 'package:timezone/timezone.dart' as tz;

final notif = FlutterLocalNotificationsPlugin();
late SharedPreferences prefs;
final refresh = ValueNotifier<int>(0);

const colors = [
  Colors.teal,
  Colors.indigo,
  Colors.pink,
  Colors.orange,
  Colors.purple,
  Colors.blueGrey,
];

const weekdaysFa = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه'];
const weekdaysShort = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
const weekdayNumbers = [6, 7, 1, 2, 3, 4, 5];
const monthsFa = [
  'فروردین','اردیبهشت','خرداد','تیر','مرداد','شهریور',
  'مهر','آبان','آذر','دی','بهمن','اسفند'
];
const monthsEn = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December'
];

String ds(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String moneyText(num v) =>
    v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

String digits(String s) {
  return s
      .replaceAll('۰','0').replaceAll('۱','1').replaceAll('۲','2')
      .replaceAll('۳','3').replaceAll('۴','4').replaceAll('۵','5')
      .replaceAll('۶','6').replaceAll('۷','7').replaceAll('۸','8')
      .replaceAll('۹','9').replaceAll(',', '').replaceAll('٬', '');
}

String hm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

int minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

String formatDate(DateTime d, bool jalali) {
  if (!jalali) return '${d.year}/${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')}';
  final j = g2j(d.year, d.month, d.day);
  return '${j[0]}/${j[1].toString().padLeft(2,'0')}/${j[2].toString().padLeft(2,'0')}';
}

/* -------------------- Jalali conversion -------------------- */

List<int> g2j(int gy, int gm, int gd) {
  const gdm = [0,31,59,90,120,151,181,212,243,273,304,334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 + 365 * gy + (gy2 + 3) ~/ 4 -
      (gy2 + 99) ~/ 100 + (gy2 + 399) ~/ 400 + gd + gdm[gm - 1];
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

List<int> j2g(int jy, int jm, int jd) {
  var y = jy + 1595;
  var days = -355668 + 365 * y + (y ~/ 33) * 8 + ((y % 33) + 3) ~/ 4 + jd;
  days += jm < 7 ? (jm - 1) * 31 : (jm - 7) * 30 + 186;

  var gy = 400 * (days ~/ 146097);
  days %= 146097;
  if (days > 36524) {
    gy += 100 * ((days - 1) ~/ 36524);
    days = (days - 1) % 36524;
    if (days >= 365) days++;
  }
  gy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    gy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final gd = days + 1;
  const sal = [0,31,59,90,120,151,181,212,243,273,304,334];
  var gm = 0;
  for (var i = 1; i <= 12; i++) {
    final start = sal[i - 1] + 1;
    final end = sal[i] + 1;
    final leap = (gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0;
    final len = i == 2 ? (leap ? 29 : 28) : (i == 4 || i == 6 || i == 9 || i == 11 ? 30 : 31);
    if (gd >= start && gd < start + len) {
      gm = i;
      break;
    }
  }
  if (gm == 0) gm = 12;
  var day = gd - sal[gm - 1];
  if (gm > 2 && (((gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0))) day--;
  return [gy, gm, day];
}

bool isJalaliLeap(int jy) {
  final g1 = DateTime(j2g(jy, 1, 1)[0], j2g(jy, 1, 1)[1], j2g(jy, 1, 1)[2]);
  final g2 = DateTime(j2g(jy + 1, 1, 1)[0], j2g(jy + 1, 1, 1)[1], j2g(jy + 1, 1, 1)[2]);
  return g2.difference(g1).inDays == 366;
}

int jalaliMonthLength(int y, int m) =>
    m <= 6 ? 31 : (m <= 11 ? 30 : (isJalaliLeap(y) ? 30 : 29));

/* -------------------- Persistent data / migration -------------------- */

class Store {
  static List<Map> tasks = [];
  static List<Map> events = [];
  static List<Map> txs = [];
  static List<Map> goals = [];
  static List<Map> habits = [];
  static List<Map> accounts = [];
  static List<Map> budgets = [];
  static List<Map> notes = [];

  static const schema = 2;

  static List<Map> readList(String key) {
    try {
      final raw = prefs.getString(key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static void load() {
    tasks = readList('tasks');
    events = readList('events');
    txs = readList('txs');
    goals = readList('goals');
    habits = readList('habits');
    accounts = readList('accounts');
    budgets = readList('budgets');
    notes = readList('notes');

    // Migration is deliberately additive: old keys are never deleted.
    // Existing tasks/events/transactions remain intact when the app is updated.
    for (final e in events) {
      e['repeat'] ??= 'weekly';
      e['color'] ??= 0;
      e['kind'] ??= 'برنامه';
    }
    for (final x in txs) {
      x['id'] ??= DateTime.now().microsecondsSinceEpoch.toString();
      x['accountId'] ??= 'cash';
      x['note'] ??= '';
    }
    if (!prefs.containsKey('calendarMode')) prefs.setString('calendarMode', 'jalali');
    if (!prefs.containsKey('currency')) prefs.setString('currency', 'تومان');
    if (!prefs.containsKey('schemaVersion')) prefs.setInt('schemaVersion', schema);
    save();
  }

  static Future<void> save() async {
    await prefs.setString('tasks', jsonEncode(tasks));
    await prefs.setString('events', jsonEncode(events));
    await prefs.setString('txs', jsonEncode(txs));
    await prefs.setString('goals', jsonEncode(goals));
    await prefs.setString('habits', jsonEncode(habits));
    await prefs.setString('accounts', jsonEncode(accounts));
    await prefs.setString('budgets', jsonEncode(budgets));
    await prefs.setString('notes', jsonEncode(notes));
    await prefs.setInt('schemaVersion', schema);
  }
}

/* -------------------- Notifications -------------------- */

const notifDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'planner_events',
    'یادآوری برنامه',
    channelDescription: 'یادآوری کلاس‌ها، کارها و رویدادهای برنامه‌ریز',
    importance: Importance.max,
    priority: Priority.high,
  ),
);

Future<void> scheduleAt(int id, String title, String body, DateTime date) async {
  final t = tz.TZDateTime.from(date, tz.local);
  if (!t.isAfter(tz.TZDateTime.now(tz.local))) return;
  await notif.zonedSchedule(
    id, title, body, t, notifDetails,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: null,
  );
}

int eventNotifId(Map e) => (e['id'] is int ? e['id'] as int : int.tryParse('${e['id']}') ?? 1) + 100000;

Future<void> scheduleEvent(Map e) async {
  await notif.cancel(eventNotifId(e));
  final wd = e['wd'] as int?;
  final start = e['s'] as int? ?? 0;
  if (wd == null) return;
  final now = tz.TZDateTime.now(tz.local);
  var candidate = tz.TZDateTime(tz.local, now.year, now.month, now.day);
  while (candidate.weekday != wd || !candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  candidate = candidate.add(Duration(minutes: start - candidate.hour * 60 - candidate.minute));
  if (candidate.isAfter(now)) {
    await notif.zonedSchedule(
      eventNotifId(e),
      e['t'] ?? 'رویداد',
      'شروع تا ۱۰ دقیقه دیگر',
      candidate.subtract(const Duration(minutes: 10)),
      notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}

/* -------------------- App -------------------- */

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzd.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
  prefs = await SharedPreferences.getInstance();

  Store.load();

  await notif.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );
  final android = notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.requestNotificationsPermission();
  await android?.requestExactAlarmsPermission();

  runApp(const PlannerApp());
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: refresh,
      builder: (_, __, ___) {
        final seed = prefs.getInt('clr') ?? 0;
        final dark = prefs.getString('theme') == 'dark';
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'کُنج پلنر',
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: colors[seed % colors.length],
            fontFamily: 'sans',
            scaffoldBackgroundColor: const Color(0xfff7f7f9),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: colors[seed % colors.length],
            brightness: Brightness.dark,
          ),
          builder: (_, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: const Home(),
        );
      },
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  String search = '';

  bool get jalali => prefs.getString('calendarMode') != 'gregorian';
  String get currency => prefs.getString('currency') ?? 'تومان';

  void update() {
    Store.save();
    refresh.value++;
  }

  String dateLabel(DateTime d) => formatDate(d, jalali);

  Future<String?> ask(String hint, [String init = '']) async {
    final c = TextEditingController(text: init);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(hint),
        content: TextField(
          controller: c,
          autofocus: true,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('ثبت')),
        ],
      ),
    );
  }

  Future<TimeOfDay?> timePick({TimeOfDay? initial}) =>
      showTimePicker(context: context, initialTime: initial ?? TimeOfDay.now());

  Future<DateTime?> datePick({DateTime? initial}) async {
    final d = initial ?? DateTime.now();
    return showDialog<DateTime>(
      context: context,
      builder: (_) => CalendarDialog(initial: d, jalali: jalali),
    );
  }

  Future<void> addTask() async {
    final title = await ask('کار جدید');
    if (title == null || title.trim().isEmpty) return;
    final date = await datePick();
    if (date == null) return;
    final time = await timePick();
    final task = {
      'id': DateTime.now().microsecondsSinceEpoch,
      't': title.trim(),
      'done': false,
      'priority': 'medium',
      'r': time == null ? null : DateTime(date.year, date.month, date.day, time.hour, time.minute).toIso8601String(),
    };
    Store.tasks.add(task);
    if (time != null) {
      await scheduleAt(task['id'] as int, 'یادآوری: ${task['t']}', 'زمان انجام کار رسیده', DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }
    update();
  }

  Future<void> addEvent([Map? old]) async {
    final title = await ask('عنوان برنامه / کلاس', old?['t'] ?? '');
    if (title == null || title.trim().isEmpty) return;

    final kind = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('نوع برنامه'),
        children: ['کلاس', 'جلسه', 'ورزش', 'کار', 'شخصی', 'سایر']
            .map((x) => SimpleDialogOption(onPressed: () => Navigator.pop(context, x), child: Text(x)))
            .toList(),
      ),
    );
    if (kind == null) return;

    final weekday = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('روز هفته'),
        children: [
          for (var i = 0; i < 7; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(_, weekdayNumbers[i]),
              child: Text(weekdaysFa[i]),
            ),
        ],
      ),
    );
    if (weekday == null) return;

    final start = await timePick(
      initial: old == null ? const TimeOfDay(hour: 8, minute: 0) : TimeOfDay(hour: (old['s'] as int) ~/ 60, minute: (old['s'] as int) % 60),
    );
    if (start == null) return;
    final end = await timePick(
      initial: old == null ? const TimeOfDay(hour: 10, minute: 0) : TimeOfDay(hour: (old['e'] as int) ~/ 60, minute: (old['e'] as int) % 60),
    );
    if (end == null) return;

    final until = await datePick(initial: old == null ? DateTime.now().add(const Duration(days: 120)) : DateTime.parse(old['to']));
    if (until == null) return;

    if (old != null) {
      await notif.cancel(eventNotifId(old));
      Store.events.remove(old);
    }

    final e = {
      'id': old?['id'] ?? DateTime.now().microsecondsSinceEpoch,
      't': title.trim(),
      'kind': kind,
      'wd': weekday,
      's': minutesOf(start),
      'e': minutesOf(end),
      'from': old?['from'] ?? ds(DateTime.now()),
      'to': ds(until),
      'repeat': 'weekly',
      'color': old?['color'] ?? 0,
    };
    Store.events.add(e);
    await scheduleEvent(e);
    update();
  }

  Future<void> addTransaction([Map? old]) async {
    final amount = TextEditingController(text: old == null ? '' : '${old['a']}');
    final title = TextEditingController(text: old?['t'] ?? '');
    final note = TextEditingController(text: old?['note'] ?? '');
    bool income = old?['inc'] == true;
    String category = old?['c'] ?? 'سایر';

    final cats = ['غذا','حمل‌ونقل','خرید','قبوض','کار','سلامت','آموزش','تفریح','خانه','سایر'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text('تراکنش مالی', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'مبلغ ($currency)', border: const OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'یادداشت', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('هزینه'), icon: Icon(Icons.arrow_upward)),
                    ButtonSegment(value: true, label: Text('درآمد'), icon: Icon(Icons.arrow_downward)),
                  ],
                  selected: {income},
                  onSelectionChanged: (s) => set(() => income = s.first),
                ),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: Text('دسته‌بندی', style: Theme.of(ctx).textTheme.titleSmall)),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final c in cats)
                      ChoiceChip(label: Text(c), selected: category == c, onSelected: (_) => set(() => category = c)),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    final value = int.tryParse(digits(amount.text));
                    if (value == null || value <= 0) return;
                    if (old != null) Store.txs.remove(old);
                    Store.txs.add({
                      'id': old?['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
                      'a': value,
                      'inc': income,
                      'c': category,
                      't': title.text.trim(),
                      'note': note.text.trim(),
                      'd': old?['d'] ?? ds(DateTime.now()),
                      'accountId': old?['accountId'] ?? 'cash',
                    });
                    Navigator.pop(ctx);
                    update();
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('ذخیره تراکنش'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> addGoal() async {
    final title = await ask('هدف جدید');
    if (title == null || title.trim().isEmpty) return;
    final deadline = await datePick();
    if (deadline == null) return;
    Store.goals.add({
      'id': DateTime.now().microsecondsSinceEpoch,
      't': title.trim(),
      'progress': 0,
      'deadline': ds(deadline),
    });
    update();
  }

  Future<void> addHabit() async {
    final title = await ask('عادت جدید');
    if (title == null || title.trim().isEmpty) return;
    Store.habits.add({
      'id': DateTime.now().microsecondsSinceEpoch,
      't': title.trim(),
      'days': <String>[],
    });
    update();
  }

  Widget homeTab() {
    final today = ds(DateTime.now());
    final open = Store.tasks.where((x) => x['done'] != true).length;
    final doneToday = Store.tasks.where((x) => x['done'] == true && x['doneAt'] == today).length;
    final todayEvents = Store.events.where((e) => e['wd'] == DateTime.now().weekday && today.compareTo(e['from']) >= 0 && today.compareTo(e['to']) <= 0).toList()
      ..sort((a,b) => (a['s'] as int).compareTo(b['s'] as int));

    final total = open + doneToday;
    final progress = total == 0 ? 0.0 : doneToday / total;

    return RefreshIndicator(
      onRefresh: () async => update(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('امروز، ${weekdaysFa[(DateTime.now().weekday + 1) % 7]}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ),
              IconButton(onPressed: () => showSettings(), icon: const Icon(Icons.tune_rounded)),
            ],
          ),
          Text(formatDate(DateTime.now(), jalali), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('امروز چه خبر؟', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(20)),
                  const SizedBox(height: 10),
                  Text('$doneToday انجام شده • $open کار باز'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (todayEvents.isNotEmpty)
            Card(
              elevation: 0,
              child: Column(
                children: [
                  const ListTile(title: Text('برنامه امروز', style: TextStyle(fontWeight: FontWeight.bold)), leading: Icon(Icons.event_available)),
                  for (final e in todayEvents)
                    ListTile(
                      leading: CircleAvatar(child: Text('${e['s'] ~/ 60}')),
                      title: Text(e['t']),
                      subtitle: Text('${hm(e['s'])} تا ${hm(e['e'])} • ${e['kind']}'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('خلاصه مالی امروز'),
              subtitle: Text(financeSummary(DateTime.now())),
              onTap: () => setState(() => tab = 3),
            ),
          ),
          const SizedBox(height: 12),
          if (Store.goals.isNotEmpty)
            Card(
              elevation: 0,
              child: Column(
                children: [
                  const ListTile(title: Text('هدف‌های در مسیر', style: TextStyle(fontWeight: FontWeight.bold)), leading: Icon(Icons.flag_outlined)),
                  for (final g in Store.goals.take(4))
                    ListTile(
                      title: Text(g['t']),
                      subtitle: LinearProgressIndicator(value: ((g['progress'] ?? 0) as num) / 100, minHeight: 6),
                      trailing: Text('${g['progress'] ?? 0}%'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String financeSummary(DateTime d) {
    final day = ds(d);
    final l = Store.txs.where((x) => x['d'] == day);
    final income = l.where((x) => x['inc'] == true).fold<int>(0, (p,x) => p + (x['a'] as int));
    final expense = l.where((x) => x['inc'] != true).fold<int>(0, (p,x) => p + (x['a'] as int));
    return 'درآمد ${moneyText(income)} • هزینه ${moneyText(expense)} • مانده ${moneyText(income-expense)} $currency';
  }

  Widget tasksTab() {
    final open = Store.tasks.where((x) => x['done'] != true).toList();
    final done = Store.tasks.where((x) => x['done'] == true).toList().reversed.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      children: [
        Card(
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('کارهای باز'),
            subtitle: Text('${open.length} کار باقی مانده'),
          ),
        ),
        for (final t in open) taskTile(t, false),
        if (done.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.only(top: 16, bottom: 6), child: Text('انجام‌شده‌ها', style: TextStyle(fontWeight: FontWeight.bold))),
          for (final t in done.take(20)) taskTile(t, true),
        ],
      ],
    );
  }

  Widget taskTile(Map t, bool done) {
    return Dismissible(
      key: ValueKey(t['id']),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        notif.cancel(t['id'] is int ? t['id'] : 0);
        Store.tasks.remove(t);
        update();
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        child: CheckboxListTile(
          value: done,
          onChanged: (_) {
            t['done'] = !done;
            t['doneAt'] = done ? null : ds(DateTime.now());
            update();
          },
          title: Text(t['t'], style: done ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
          subtitle: t['r'] != null ? Text('⏰ ${formatDate(DateTime.parse(t['r']), jalali)}  ${t['r'].toString().substring(11,16)}') : const Text('بدون یادآوری'),
          secondary: Icon(t['priority'] == 'high' ? Icons.priority_high : Icons.check_circle_outline),
        ),
      ),
    );
  }

  Widget calendarTab() => PlannerCalendar(
    jalali: jalali,
    events: Store.events,
    tasks: Store.tasks,
    onAddEvent: addEvent,
    onDeleteEvent: (e) async {
      await notif.cancel(eventNotifId(e));
      Store.events.remove(e);
      update();
    },
  );

  Widget goalsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      children: [
        sectionHeader('هدف‌ها', Icons.flag_outlined, onAdd: addGoal),
        for (final g in Store.goals)
          Card(
            elevation: 0,
            child: ListTile(
              title: Text(g['t']),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: ((g['progress'] ?? 0) as num) / 100),
                  const SizedBox(height: 6),
                  Text('مهلت: ${formatDate(DateTime.parse(g['deadline']), jalali)}'),
                ],
              ),
              trailing: SizedBox(
                width: 72,
                child: DropdownButton<int>(
                  value: (g['progress'] ?? 0) as int,
                  isExpanded: true,
                  items: [0,25,50,75,100].map((v) => DropdownMenuItem(value: v, child: Text('$v%'))).toList(),
                  onChanged: (v) { if (v != null) { g['progress'] = v; update(); } },
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        sectionHeader('عادت‌ها', Icons.repeat_rounded, onAdd: addHabit),
        for (final h in Store.habits)
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.local_fire_department_outlined),
              title: Text(h['t']),
              subtitle: Text('روزهای ثبت‌شده: ${(h['days'] as List?)?.length ?? 0}'),
              trailing: IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () {
                  final list = List<String>.from(h['days'] ?? []);
                  final d = ds(DateTime.now());
                  if (!list.contains(d)) list.add(d);
                  h['days'] = list;
                  update();
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget sectionHeader(String title, IconData icon, {VoidCallback? onAdd}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      trailing: onAdd == null ? null : IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline)),
    );
  }

  Widget moneyTab() {
    final now = DateTime.now();
    int sum(bool income, String? from) {
      final l = Store.txs.where((x) => x['inc'] == income && (from == null || (x['d'] as String).compareTo(from) >= 0));
      return l.fold<int>(0, (p,x) => p + (x['a'] as int));
    }

    final income = sum(true, null);
    final expense = sum(false, null);
    final found = Store.txs.where((x) => '${x['t'] ?? ''} ${x['c'] ?? ''} ${x['note'] ?? ''}'.contains(search)).toList().reversed.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'جستجو در تراکنش‌ها...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: search.isEmpty ? null : IconButton(onPressed: () => setState(() => search = ''), icon: const Icon(Icons.clear)),
          ),
          onChanged: (v) => setState(() => search = v.trim()),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('مانده کل', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text('${moneyText(income-expense)} $currency', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _moneyMetric('درآمد', income, Icons.south_west)),
                    Expanded(child: _moneyMetric('هزینه', expense, Icons.north_east)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          child: Column(
            children: [
              const ListTile(title: Text('بودجه‌بندی', style: TextStyle(fontWeight: FontWeight.bold)), leading: Icon(Icons.pie_chart_outline)),
              for (final b in Store.budgets)
                Builder(builder: (_) {
                  final monthKey = ds(DateTime(now.year, now.month));
                  final spent = Store.txs
                      .where((x) => x['inc'] != true && x['c'] == b['c'] && (x['d'] as String).compareTo(monthKey) >= 0)
                      .fold<int>(0, (p, x) => p + (x['a'] as int));
                  final limit = (b['limit'] ?? 0) as int;
                  final ratio = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
                  return ListTile(
                    title: Text(b['c']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: ratio, minHeight: 6),
                        const SizedBox(height: 4),
                        Text('${moneyText(spent)} از ${moneyText(limit)} این ماه'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () { Store.budgets.remove(b); update(); },
                    ),
                  );
                }),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('افزودن بودجه'),
                onTap: addBudget,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text('تراکنش‌ها', style: TextStyle(fontWeight: FontWeight.bold)),
        for (final x in found.take(100))
          Card(
            elevation: 0,
            child: ListTile(
              onTap: () => addTransaction(x),
              leading: CircleAvatar(
                child: Icon(x['inc'] == true ? Icons.south_west : Icons.north_east),
              ),
              title: Text((x['t'] ?? '') == '' ? x['c'] : x['t']),
              subtitle: Text('${x['c']} • ${formatDate(DateTime.parse(x['d']), jalali)}'),
              trailing: Text('${x['inc'] == true ? '+' : '-'}${moneyText(x['a'])}'),
            ),
          ),
      ],
    );
  }

  Widget _moneyMetric(String title, int value, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12)),
        Text(moneyText(value), style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    ]);
  }

  Future<void> addBudget() async {
    final category = await ask('دسته بودجه');
    if (category == null || category.trim().isEmpty) return;
    final amount = await ask('سقف بودجه');
    final value = int.tryParse(digits(amount ?? ''));
    if (value == null || value <= 0) return;
    Store.budgets.add({'id': DateTime.now().microsecondsSinceEpoch, 'c': category.trim(), 'limit': value, 'spent': 0});
    update();
  }

  Future<void> showSettings() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final mode = prefs.getString('calendarMode') ?? 'jalali';
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: [
                const Text('شخصی‌سازی', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                const Text('تقویم اصلی'),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'jalali', label: Text('شمسی')),
                    ButtonSegment(value: 'gregorian', label: Text('میلادی')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) {
                    prefs.setString('calendarMode', s.first);
                    refresh.value++;
                    set(() {});
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('رنگ برنامه'),
                  subtitle: const Text('ظاهر برنامه را شخصی کن'),
                  onTap: () async {
                    final c = await showDialog<int>(
                      context: ctx,
                      builder: (_) => SimpleDialog(
                        title: const Text('انتخاب رنگ'),
                        children: [
                          for (var i=0; i<colors.length; i++)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(_, i),
                              child: Row(children: [CircleAvatar(backgroundColor: colors[i], radius: 12), const SizedBox(width: 10), Text('رنگ ${i+1}')]),
                            )
                        ],
                      ),
                    );
                    if (c != null) {
                      prefs.setInt('clr', c);
                      refresh.value++;
                      set(() {});
                    }
                  },
                ),
                SwitchListTile(
                  value: prefs.getString('theme') == 'dark',
                  title: const Text('حالت تاریک'),
                  onChanged: (v) {
                    prefs.setString('theme', v ? 'dark' : 'light');
                    refresh.value++;
                    set(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('واحد پول'),
                  subtitle: Text(currency),
                  onTap: () async {
                    final v = await showDialog<String>(
                      context: ctx,
                      builder: (_) => SimpleDialog(
                        title: const Text('واحد پول'),
                        children: ['تومان','ریال','دلار','یورو'].map((x) => SimpleDialogOption(onPressed: () => Navigator.pop(_, x), child: Text(x))).toList(),
                      ),
                    );
                    if (v != null) {
                      prefs.setString('currency', v);
                      refresh.value++;
                      set(() {});
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('حفظ اطلاعات هنگام آپدیت'),
                  subtitle: const Text('اطلاعات روی حافظه برنامه نگهداری می‌شود؛ برای نسخه‌های بعدی مهاجرت داده انجام می‌شود.'),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('نسخه داده'),
                  subtitle: Text('Schema ${Store.schema}'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [homeTab(), tasksTab(), calendarTab(), moneyTab(), goalsTab()];
    final titles = ['خانه', 'کارها', 'تقویم', 'مالی', 'اهداف'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tab], style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: showSettings, icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      body: pages[tab],
      floatingActionButton: tab == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                if (tab == 1) addTask();
                if (tab == 2) addEvent();
                if (tab == 3) addTransaction();
                if (tab == 4) addGoal();
              },
              icon: const Icon(Icons.add),
              label: Text(tab == 1 ? 'کار' : tab == 2 ? 'برنامه' : tab == 3 ? 'تراکنش' : 'هدف'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'کارها'),
          NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'تقویم'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_rounded), label: 'مالی'),
          NavigationDestination(icon: Icon(Icons.flag_rounded), label: 'اهداف'),
        ],
      ),
    );
  }
}

/* -------------------- Calendar -------------------- */

class PlannerCalendar extends StatefulWidget {
  final bool jalali;
  final List<Map> events;
  final List<Map> tasks;
  final Future<void> Function([Map?]) onAddEvent;
  final Future<void> Function(Map) onDeleteEvent;

  const PlannerCalendar({
    super.key,
    required this.jalali,
    required this.events,
    required this.tasks,
    required this.onAddEvent,
    required this.onDeleteEvent,
  });

  @override
  State<PlannerCalendar> createState() => _PlannerCalendarState();
}

class _PlannerCalendarState extends State<PlannerCalendar> {
  late DateTime selected;
  late int y;
  late int m;

  @override
  void initState() {
    super.initState();
    selected = dateOnly(DateTime.now());
    final p = widget.jalali ? g2j(selected.year, selected.month, selected.day) : [selected.year, selected.month, selected.day];
    y = p[0]; m = p[1];
  }

  @override
  void didUpdateWidget(covariant PlannerCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jalali != widget.jalali) {
      final p = widget.jalali ? g2j(selected.year, selected.month, selected.day) : [selected.year, selected.month, selected.day];
      y = p[0]; m = p[1];
    }
  }

  int monthLength() => widget.jalali ? jalaliMonthLength(y, m) : DateTime(y, m + 1, 0).day;

  DateTime cellDate(int day) {
    if (widget.jalali) {
      final g = j2g(y, m, day);
      return DateTime(g[0], g[1], g[2]);
    }
    return DateTime(y, m, day);
  }

  int firstOffset() {
    final d = cellDate(1).weekday;
    return (d + 1) % 7; // Saturday = 0
  }

  String monthTitle() => widget.jalali ? '${monthsFa[m-1]} $y' : '${monthsEn[m-1]} $y';

  void moveMonth(int delta) {
    m += delta;
    if (widget.jalali) {
      if (m > 12) { m = 1; y++; }
      if (m < 1) { m = 12; y--; }
    } else {
      if (m > 12) { m = 1; y++; }
      if (m < 1) { m = 12; y--; }
    }
    setState(() {});
  }

  bool same(DateTime a, DateTime b) => ds(a) == ds(b);

  List<Map> eventsFor(DateTime d) {
    final iso = ds(d);
    final wd = d.weekday;
    return widget.events.where((e) {
      final from = e['from'] as String? ?? '0000-00-00';
      final to = e['to'] as String? ?? '9999-99-99';
      return e['wd'] == wd && iso.compareTo(from) >= 0 && iso.compareTo(to) <= 0;
    }).toList()..sort((a,b) => (a['s'] as int).compareTo(b['s'] as int));
  }

  List<Map> tasksFor(DateTime d) {
    final iso = ds(d);
    return widget.tasks.where((t) => (t['r'] as String?)?.substring(0,10) == iso).toList();
  }

  @override
  Widget build(BuildContext context) {
    final len = monthLength();
    final offset = firstOffset();
    final cells = <Widget>[];

    for (var i = 0; i < offset; i++) {
      cells.add(const SizedBox(height: 58));
    }

    for (var day = 1; day <= len; day++) {
      final date = cellDate(day);
      final ev = eventsFor(date);
      final tk = tasksFor(date);
      final isToday = same(date, DateTime.now());
      final isSelected = same(date, selected);

      cells.add(
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => selected = date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 58,
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : isToday ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
              borderRadius: BorderRadius.circular(14),
              border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text('$day', style: TextStyle(fontWeight: isToday ? FontWeight.w900 : FontWeight.w500)),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (ev.isNotEmpty) ...[
                      _dot(context, Colors.deepPurple),
                      const SizedBox(width: 3),
                    ],
                    if (tk.isNotEmpty) _dot(context, Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 100),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => moveMonth(-1), icon: const Icon(Icons.chevron_right)),
                    Expanded(child: Center(child: Text(monthTitle(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)))),
                    IconButton(onPressed: () => moveMonth(1), icon: const Icon(Icons.chevron_left)),
                  ],
                ),
                Row(
                  children: [for (final w in weekdaysShort) Expanded(child: Center(child: Text(w, style: const TextStyle(fontWeight: FontWeight.bold))))],
                ),
                const SizedBox(height: 4),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.0,
                  children: cells,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDate(selected, widget.jalali), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                Text('${weekdaysFa[(selected.weekday + 1) % 7]} • برنامه‌های تکرارشونده و کارهای روز'),
                const SizedBox(height: 12),
                ...eventsFor(selected).map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: const Icon(Icons.event)),
                  title: Text(e['t']),
                  subtitle: Text('${hm(e['s'])} تا ${hm(e['e'])} • ${e['kind']} • هفتگی'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'delete') await widget.onDeleteEvent(e);
                      if (v == 'edit') await widget.onAddEvent(e);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                      PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  ),
                )),
                ...tasksFor(selected).map((t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.task_alt),
                  title: Text(t['t']),
                  subtitle: Text(t['done'] == true ? 'انجام شده' : 'در انتظار انجام'),
                )),
                if (eventsFor(selected).isEmpty && tasksFor(selected).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('برای این روز برنامه‌ای ثبت نشده.'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot(BuildContext context, Color color) => Container(
    width: 6, height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class CalendarDialog extends StatefulWidget {
  final DateTime initial;
  final bool jalali;
  const CalendarDialog({super.key, required this.initial, required this.jalali});

  @override
  State<CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<CalendarDialog> {
  late DateTime selected;
  late int y, m;

  @override
  void initState() {
    super.initState();
    selected = dateOnly(widget.initial);
    final p = widget.jalali ? g2j(selected.year, selected.month, selected.day) : [selected.year, selected.month, selected.day];
    y = p[0]; m = p[1];
  }

  int len() => widget.jalali ? jalaliMonthLength(y,m) : DateTime(y,m+1,0).day;
  DateTime gd(int day) {
    if (widget.jalali) {
      final g = j2g(y,m,day);
      return DateTime(g[0],g[1],g[2]);
    }
    return DateTime(y,m,day);
  }
  int offset() => (gd(1).weekday + 1) % 7;
  void move(int delta) {
    m += delta;
    if (m > 12) { m=1; y++; }
    if (m < 1) { m=12; y--; }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (var i=0;i<offset();i++) cells.add(const SizedBox(height:42));
    for (var day=1;day<=len();day++) {
      final d=gd(day);
      final active=ds(d)==ds(selected);
      cells.add(InkWell(
        onTap: () => setState(() => selected=d),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: active ? Theme.of(context).colorScheme.primary : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text('$day', style: TextStyle(color: active ? Theme.of(context).colorScheme.onPrimary : null))),
        ),
      ));
    }
    final title = widget.jalali ? '${monthsFa[m-1]} $y' : '${monthsEn[m-1]} $y';
    return AlertDialog(
      title: Row(
        children: [
          IconButton(onPressed: ()=>move(-1), icon: const Icon(Icons.chevron_right)),
          Expanded(child: Center(child: Text(title))),
          IconButton(onPressed: ()=>move(1), icon: const Icon(Icons.chevron_left)),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children:[for(final w in weekdaysShort) Expanded(child:Center(child:Text(w,style:const TextStyle(fontWeight:FontWeight.bold))))]),
            const SizedBox(height:4),
            GridView.count(crossAxisCount:7, shrinkWrap:true, physics:const NeverScrollableScrollPhysics(), childAspectRatio:1.1, children:cells),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('لغو')),
        FilledButton(onPressed: ()=>Navigator.pop(context, selected), child: const Text('انتخاب')),
      ],
    );
  }
}
