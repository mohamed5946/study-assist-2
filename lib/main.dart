import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

const _blue = Color(0xFF69B9F4);
const _deepBlue = Color(0xFF2476B8);
const _paleBlue = Color(0xFFEAF6FF);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  await Hive.initFlutter();
  final appData = await Hive.openBox<dynamic>('app_data');
  // Separate local Hive boxes by domain; migrate data from the first prototype once.
  for (final name in ['lectures', 'tasks', 'subjects', 'notes', 'flashcards', 'attendance', 'reminders', 'documents', 'exams']) {
    final box = await Hive.openBox<dynamic>(name);
    if (!box.containsKey('items') && appData.containsKey(name)) {
      final legacy = appData.get(name);
      if (legacy is List) await box.put('items', legacy);
    }
  }
  if ((appData.get('schemaVersion', defaultValue: 0) as int) < 2) {
    await appData.put('schemaVersion', 2);
    await appData.put('databaseMigratedAt', DateTime.now().toIso8601String());
  }
  runApp(const StudyAssistantApp());
}

class StudyAssistantApp extends StatelessWidget {
  const StudyAssistantApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: Hive.box<dynamic>('app_data').listenable(keys: const ['darkMode']),
    builder: (context, box, _) {
      final dark = box.get('darkMode', defaultValue: false) as bool;
      return MaterialApp(
        title: 'Study Assist 2', debugShowCheckedModeBanner: false,
        locale: const Locale('ar'), supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _blue, brightness: Brightness.light), scaffoldBackgroundColor: const Color(0xFFF6FAFE), useMaterial3: true, fontFamily: 'Roboto'),
        darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _blue, brightness: Brightness.dark), useMaterial3: true),
        home: const AppShell(),
      );
    },
  );
}

class AppShell extends StatefulWidget { const AppShell({super.key}); @override State<AppShell> createState() => _AppShellState(); }
class _AppShellState extends State<AppShell> {
  int tab = 0;
  final pages = const [DashboardScreen(), ScheduleScreen(), StudyScreen(), PomodoroScreen(), MoreScreen()];
  final labels = const ['الرئيسية', 'الجدول', 'المذاكرة', 'التركيز', 'المزيد'];
  final icons = const [Icons.home_rounded, Icons.calendar_month_rounded, Icons.menu_book_rounded, Icons.timer_rounded, Icons.grid_view_rounded];
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: IndexedStack(index: tab, children: pages)),
    bottomNavigationBar: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: Container(
      height: 72, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha: .96), borderRadius: BorderRadius.circular(28), border: Border.all(color: _blue.withValues(alpha: .24)), boxShadow: [BoxShadow(color: _deepBlue.withValues(alpha: .10), blurRadius: 22, offset: const Offset(0, 5))]),
      child: Row(children: List.generate(labels.length, (i) => Expanded(child: InkWell(borderRadius: BorderRadius.circular(22), onTap: () => setState(() => tab = i), child: AnimatedContainer(duration: const Duration(milliseconds: 180), margin: const EdgeInsets.all(6), decoration: BoxDecoration(gradient: tab == i ? const LinearGradient(colors: [_blue, _deepBlue]) : null, borderRadius: BorderRadius.circular(22)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icons[i], size: 22, color: tab == i ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(height: 3), FittedBox(fit: BoxFit.scaleDown, child: Text(labels[i], style: TextStyle(fontSize: 11, fontWeight: tab == i ? FontWeight.w700 : FontWeight.w500, color: tab == i ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant))) ])))))),
    ))),
  );
}

Box<dynamic> get store => Hive.box<dynamic>('app_data');
Box<dynamic> get lectureStore => Hive.box<dynamic>('lectures');
Box<dynamic> get taskStore => Hive.box<dynamic>('tasks');
List<Map<String, dynamic>> _readItems(Box<dynamic> box) {
  final raw = box.get('items', defaultValue: <dynamic>[]);
  if (raw is! List) return <Map<String, dynamic>>[];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}
List<Map<String, dynamic>> get lectures => _readItems(lectureStore);
Future<void> saveLectures(List<Map<String, dynamic>> value) => lectureStore.put('items', value);
List<Map<String, dynamic>> get tasks => _readItems(taskStore);
Future<void> saveTasks(List<Map<String, dynamic>> value) => taskStore.put('items', value);

class GlassCard extends StatelessWidget {
  final Widget child; final EdgeInsets padding; final Gradient? gradient;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.gradient});
  @override Widget build(BuildContext context) => RepaintBoundary(child: Container(padding: padding, decoration: BoxDecoration(gradient: gradient, color: gradient == null ? Theme.of(context).colorScheme.surface : null, borderRadius: BorderRadius.circular(24), border: Border.all(color: _blue.withValues(alpha: .18)), boxShadow: [BoxShadow(color: _deepBlue.withValues(alpha: .045), blurRadius: 18, offset: const Offset(0, 5))]), child: child));
}

class DashboardScreen extends StatefulWidget { const DashboardScreen({super.key}); @override State<DashboardScreen> createState() => _DashboardScreenState(); }
class _DashboardScreenState extends State<DashboardScreen> {
  @override Widget build(BuildContext context) => ValueListenableBuilder(valueListenable: store.listenable(), builder: (context, box, _) {
    final now = DateTime.now(); final name = box.get('userName', defaultValue: 'محمد') as String;
    final todays = lectures.where((l) => l['date'] == DateFormat('yyyy-MM-dd').format(now)).toList()..sort((a,b) => (a['time'] as String).compareTo(b['time'] as String));
    final upcoming = todays.where((l) => (l['time'] as String).compareTo(DateFormat('HH:mm').format(now)) >= 0).toList();
    final next = upcoming.isEmpty ? null : upcoming.first;
    final completed = tasks.where((t) => t['done'] == true).length;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 24), children: [
      Text(DateFormat('EEEE، d MMMM yyyy', 'ar').format(now), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 7),
      Text('${now.hour < 12 ? 'صباح الخير' : 'مساء الخير'}، $name 👋', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 20),
      if (next != null) GlassCard(gradient: const LinearGradient(colors: [_blue, _deepBlue], begin: Alignment.topRight, end: Alignment.bottomLeft), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('المحاضرة القادمة', style: TextStyle(color: Colors.white70)), const SizedBox(height: 8), Text('${next['subject']}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text('${next['time']}  •  ${next['place']}', style: const TextStyle(color: Colors.white)), const SizedBox(height: 10), const Text('اليوم', style: TextStyle(color: Colors.white70))]))
      else GlassCard(child: Row(children: [const Icon(Icons.event_available_rounded, color: _deepBlue, size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('مفيش محاضرات النهاردة', style: TextStyle(fontWeight: FontWeight.w700)), Text(todays.isEmpty ? 'يوم مناسب للمذاكرة أو الراحة.' : 'انتهت محاضرات اليوم.', style: Theme.of(context).textTheme.bodySmall)]))])),
      const SizedBox(height: 18),
      Row(children: [Expanded(child: _quickAction(context, Icons.smart_toy_outlined, 'اسأل AI', () => _message(context, 'ميزة شات Groq ستُربط في مرحلة الذكاء الاصطناعي.'))), const SizedBox(width: 8), Expanded(child: _quickAction(context, Icons.picture_as_pdf_outlined, 'رفع PDF', () => _message(context, 'اختيار ملفات PDF سيُفعّل في مرحلة المكتبة.'))), const SizedBox(width: 8), Expanded(child: _quickAction(context, Icons.add_circle_outline, 'محاضرة', () => showLectureDialog(context))) ]),
      const SizedBox(height: 22), _sectionTitle(context, 'محاضرات اليوم'), const SizedBox(height: 10),
      if (todays.isEmpty) GlassCard(child: const Text('جدولك فاضي لحد دلوقتي. أضف محاضرة عشان تظهر هنا.')) else ...todays.map((l) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 58, child: Text('${l['time']}', style: const TextStyle(fontWeight: FontWeight.bold, color: _deepBlue))), Container(width: 2, height: 56, margin: const EdgeInsets.only(left: 8, right: 12), color: _blue.withValues(alpha: .6)), Expanded(child: GlassCard(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${l['subject']}', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text('${l['type']} • ${l['place']}', style: Theme.of(context).textTheme.bodySmall)])), if ((l['room'] as String).isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: _paleBlue, borderRadius: BorderRadius.circular(10)), child: Text(l['room'] as String, style: const TextStyle(color: _deepBlue, fontSize: 11, fontWeight: FontWeight.bold)))])))]))),
      const SizedBox(height: 12), _sectionTitle(context, 'ملخصك'), const SizedBox(height: 10), Row(children: [Expanded(child: _stat(context, Icons.timer_outlined, 'دقائق المذاكرة', '${box.get('studyMinutes', defaultValue: 0)}')), const SizedBox(width: 8), Expanded(child: _stat(context, Icons.task_alt_rounded, 'مهام مكتملة', '$completed')), const SizedBox(width: 8), Expanded(child: _stat(context, Icons.local_fire_department_outlined, 'أيام متتالية', '${box.get('streak', defaultValue: 0)}'))]),
      const SizedBox(height: 18), GlassCard(child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.lightbulb_outline_rounded, color: _deepBlue), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('نصيحة اليوم', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 5), Text('قسّم المذاكرة إلى فترات قصيرة، وخد استراحة بسيطة بين كل فترة والتانية.')]))]))
    ]);
  });
}

Widget _quickAction(BuildContext context, IconData icon, String label, VoidCallback action) => OutlinedButton(onPressed: action, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), side: BorderSide(color: _blue.withValues(alpha: .45))), child: Column(children: [Icon(icon, size: 20), const SizedBox(height: 5), FittedBox(child: Text(label, style: const TextStyle(fontSize: 11)))]));
Widget _sectionTitle(BuildContext context, String title) => Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800));
Widget _stat(BuildContext context, IconData icon, String label, String value) => GlassCard(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _deepBlue, size: 20), const SizedBox(height: 8), Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), Text(label, style: Theme.of(context).textTheme.labelSmall, maxLines: 2)]));
void _message(BuildContext context, String text) => showDialog<void>(context: context, builder: (context) => AlertDialog(content: Text(text), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))]));

Future<void> showLectureDialog(BuildContext context, {Map<String, dynamic>? existing, int? index}) async {
  final subject = TextEditingController(text: existing?['subject'] as String? ?? ''); final time = TextEditingController(text: existing?['time'] as String? ?? '09:00'); final place = TextEditingController(text: existing?['place'] as String? ?? ''); final room = TextEditingController(text: existing?['room'] as String? ?? '');
  String type = existing?['type'] as String? ?? 'محاضرة'; var date = existing?['date'] as String? ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
  final result = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(title: Text(existing == null ? 'إضافة محاضرة' : 'تعديل محاضرة'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: subject, decoration: const InputDecoration(labelText: 'اسم المادة')), TextField(controller: time, decoration: const InputDecoration(labelText: 'الوقت (24 ساعة)')), TextField(controller: place, decoration: const InputDecoration(labelText: 'المكان')), TextField(controller: room, decoration: const InputDecoration(labelText: 'رقم القاعة')), DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'النوع'), items: const [DropdownMenuItem(value: 'محاضرة', child: Text('محاضرة')), DropdownMenuItem(value: 'سيكشن', child: Text('سيكشن'))], onChanged: (v) => setLocal(() => type = v ?? 'محاضرة')), const SizedBox(height: 8), Text('التاريخ: $date'), TextButton.icon(onPressed: () async { final d = await showDatePicker(context: ctx, initialDate: DateTime.tryParse(date) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setLocal(() { date = DateFormat('yyyy-MM-dd').format(d); }); }, icon: const Icon(Icons.calendar_month), label: const Text('اختيار التاريخ'))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))])));
  if (result == true && subject.text.trim().isNotEmpty && RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time.text.trim())) {
    final list = lectures; final item = {'subject': subject.text.trim(), 'time': time.text.trim(), 'place': place.text.trim(), 'room': room.text.trim(), 'type': type, 'date': date};
    if (index != null && index >= 0 && index < list.length) { list[index] = item; } else { list.add(item); }
    await saveLectures(list);
  } else if (result == true) { _message(context, 'تأكد من كتابة اسم المادة والوقت بصيغة صحيحة مثل 09:30.'); }
}

class ScheduleScreen extends StatelessWidget { const ScheduleScreen({super.key}); @override Widget build(BuildContext context) => ValueListenableBuilder(valueListenable: lectureStore.listenable(keys: const ['items']), builder: (context, box, _) { final now = DateTime.now(); final sunday = now.subtract(Duration(days: now.weekday % 7)); final days = List.generate(7, (i) => DateTime(sunday.year, sunday.month, sunday.day + i)); final all = lectures; return ListView(padding: const EdgeInsets.all(18), children: [Row(children: [Expanded(child: Text('الجدول الدراسي', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))), IconButton(onPressed: () => showLectureDialog(context), icon: const Icon(Icons.add_circle, color: _deepBlue), tooltip: 'إضافة محاضرة')]), const SizedBox(height: 8), ...days.map((day) { final date = DateFormat('yyyy-MM-dd').format(day); final items = all.where((l) => l['date'] == date).toList()..sort((a,b) => (a['time'] as String).compareTo(b['time'] as String)); return Padding(padding: const EdgeInsets.only(bottom: 12), child: GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${DateFormat('EEEE', 'ar').format(day)} • ${DateFormat('d/M').format(day)}', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 10), if (items.isEmpty) const Text('يوم راحة', style: TextStyle(color: Colors.grey)) else ...items.map((l) { final idx = all.indexOf(l); return ListTile(contentPadding: EdgeInsets.zero, title: Text('${l['subject']}'), subtitle: Text('${l['time']} • ${l['type']} • ${l['place']}'), leading: const Icon(Icons.event_note_rounded, color: _deepBlue), trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') { await showLectureDialog(context, existing: l, index: idx); } else if (v == 'delete') { final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('حذف المحاضرة؟'), content: Text('هل تريد حذف ${l['subject']}؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نعم، احذف'))])); if (yes == true) { final fresh = lectures..removeAt(idx); await saveLectures(fresh); } } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))])); })]))); })]); }); }

class StudyScreen extends StatefulWidget { const StudyScreen({super.key}); @override State<StudyScreen> createState() => _StudyScreenState(); }
class _StudyScreenState extends State<StudyScreen> { final ctrl = TextEditingController(); @override Widget build(BuildContext context) => ValueListenableBuilder(valueListenable: taskStore.listenable(keys: const ['items']), builder: (context, box, _) { final list = tasks; return ListView(padding: const EdgeInsets.all(18), children: [Text('المذاكرة والمهام', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('مهامك محفوظة محليًا على الجهاز. مزايا PDF وOCR والشات ستُضاف في مراحلها.'), const SizedBox(height: 16), Row(children: [Expanded(child: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'مهمة جديدة', border: OutlineInputBorder()))), const SizedBox(width: 8), IconButton.filled(onPressed: () async { if (ctrl.text.trim().isEmpty) return; await saveTasks([...list, {'title': ctrl.text.trim(), 'done': false}]); ctrl.clear(); }, icon: const Icon(Icons.add), tooltip: 'إضافة مهمة')]), const SizedBox(height: 12), if (list.isEmpty) const GlassCard(child: Text('لا توجد مهام بعد. أضف أول مهمة للمذاكرة.')) else ...list.asMap().entries.map((entry) => Card(child: CheckboxListTile(value: entry.value['done'] == true, title: Text(entry.value['title'] as String), onChanged: (v) async { final updated = tasks; updated[entry.key]['done'] = v ?? false; await saveTasks(updated); }, secondary: IconButton(onPressed: () async { final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('حذف المهمة؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نعم'))])); if (yes == true) { final updated = tasks..removeAt(entry.key); await saveTasks(updated); } }, icon: const Icon(Icons.delete_outline)))))]); }); }

class PomodoroScreen extends StatefulWidget { const PomodoroScreen({super.key}); @override State<PomodoroScreen> createState() => _PomodoroScreenState(); }
class _PomodoroScreenState extends State<PomodoroScreen> { Timer? timer; int focusMins = 25, shortMins = 5, longMins = 15, remaining = 25 * 60, sessions = 0; bool running = false, isBreak = false; @override void dispose() { timer?.cancel(); super.dispose(); } String get clock => '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}'; void start() { if (running) { timer?.cancel(); setState(() => running = false); return; } setState(() => running = true); timer = Timer.periodic(const Duration(seconds: 1), (t) { if (remaining <= 1) { t.cancel(); final completedFocus = !isBreak; setState(() { running = false; if (completedFocus) sessions++; isBreak = !isBreak; remaining = isBreak ? (sessions % 4 == 0 ? longMins : shortMins) * 60 : focusMins * 60; }); if (completedFocus) store.put('studyMinutes', (store.get('studyMinutes', defaultValue: 0) as int) + focusMins); } else { setState(() => remaining--); } }); } void reset() { timer?.cancel(); setState(() { running = false; remaining = (isBreak ? shortMins : focusMins) * 60; }); } @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(22), children: [Text('مؤقّت بومودورو', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 28), Center(child: SizedBox(width: 250, height: 250, child: Stack(alignment: Alignment.center, children: [SizedBox.expand(child: CircularProgressIndicator(value: remaining / ((isBreak ? shortMins : focusMins) * 60), strokeWidth: 12, backgroundColor: _blue.withValues(alpha: .15), color: _deepBlue, strokeCap: StrokeCap.round)), Column(mainAxisSize: MainAxisSize.min, children: [Text(clock, style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w800)), Text(isBreak ? 'استراحة' : 'FOCUS', style: const TextStyle(color: _deepBlue, fontWeight: FontWeight.bold)), Text('${sessions % 4}/4 جلسات', style: Theme.of(context).textTheme.bodySmall)])]))), const SizedBox(height: 25), Row(children: [Expanded(child: _durationChip('تركيز 25', focusMins == 25, () => setState(() { focusMins = 25; if (!running && !isBreak) remaining = 1500; }))), const SizedBox(width: 8), Expanded(child: _durationChip('قصيرة 5', isBreak && remaining <= 300, () => setState(() { isBreak = true; if (!running) remaining = shortMins * 60; }))), const SizedBox(width: 8), Expanded(child: _durationChip('طويلة 15', false, () => setState(() { isBreak = true; if (!running) remaining = longMins * 60; }))) ]), const SizedBox(height: 20), SizedBox(height: 54, child: FilledButton.icon(onPressed: start, icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded), label: Text(running ? 'إيقاف مؤقت' : 'ابدأ التركيز'))), const SizedBox(height: 8), TextButton(onPressed: reset, child: const Text('إعادة ضبط'))]); }
Widget _durationChip(String label, bool selected, VoidCallback onTap) => OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(backgroundColor: selected ? _paleBlue : null, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4)), child: FittedBox(child: Text(label, style: const TextStyle(fontSize: 11))));

class MoreScreen extends StatelessWidget { const MoreScreen({super.key}); @override Widget build(BuildContext context) => ValueListenableBuilder(valueListenable: store.listenable(keys: const ['darkMode', 'userName']), builder: (context, box, _) => ListView(padding: const EdgeInsets.all(18), children: [Text('المزيد والإعدادات', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 12), GlassCard(child: Column(children: [ListTile(leading: const Icon(Icons.person_outline), title: const Text('الملف الشخصي'), subtitle: Text(box.get('userName', defaultValue: 'محمد') as String), onTap: () async { final ctrl = TextEditingController(text: box.get('userName', defaultValue: 'محمد') as String); final name = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('اسم الترحيب'), content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'الاسم')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('حفظ'))])); if (name != null && name.isNotEmpty) await store.put('userName', name); }), const Divider(), SwitchListTile(value: box.get('darkMode', defaultValue: false) as bool, onChanged: (v) => store.put('darkMode', v), secondary: const Icon(Icons.dark_mode_outlined), title: const Text('الوضع الداكن')), const Divider(), ListTile(leading: const Icon(Icons.info_outline), title: const Text('حول Study Assist 2'), subtitle: const Text('نسخة أولية محلية قيد التطوير'))]))])); }
