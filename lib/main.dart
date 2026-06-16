import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const CeladonApp());
}

// ─── THEME TOKENS ────────────────────────────────────────────────────────────

class CeladonColors {
  static const cream        = Color(0xFFF7F3E9);
  static const inkBrown     = Color(0xFF2C2416);
  static const sage         = Color(0xFF7C9A7E);
  static const terracotta   = Color(0xFFD4956A);
  static const mutedSage    = Color(0xFFB8C4BB);
  static const pageWhite    = Color(0xFFFEFCF7);
  static const ruleLine     = Color(0xFFE2DDD1);
  static const softShadow   = Color(0x14000000);
  static const sageLight    = Color(0xFFE8F0E9);
  static const terracottaLight = Color(0xFFFAEDE4);
  // Calendar warm palette (matches reference)
  static const calBrown     = Color(0xFF6B4423);
  static const calBrownDark = Color(0xFF4A2E14);
  static const calCream     = Color(0xFFD4B896);
  static const calSurface   = Color(0xFF7A4F2D);
}

// ─── DATA MODELS ─────────────────────────────────────────────────────────────

enum Priority {
  high('High', Color(0xFFD4956A)),
  medium('Medium', Color(0xFF7C9A7E)),
  low('Low', Color(0xFFB8C4BB));

  final String label;
  final Color color;
  const Priority(this.label, this.color);
}

class Task {
  final String id;
  final String title;
  final String subject;
  final bool isDone;
  final Priority priority;
  /// null means today
  final DateTime? dueDate;
  /// set when task is marked done
  final DateTime? completedAt;

  Task({
    required this.id,
    required this.title,
    required this.subject,
    this.isDone = false,
    this.priority = Priority.medium,
    this.dueDate,
    this.completedAt,
  });

  Task copyWith({
    String? id,
    String? title,
    String? subject,
    bool? isDone,
    Priority? priority,
    DateTime? dueDate,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      isDone: isDone ?? this.isDone,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  /// True when done AND completed more than 24 h ago.
  bool get isExpiredCompleted {
    if (!isDone || completedAt == null) return false;
    return DateTime.now().difference(completedAt!).inHours >= 24;
  }
}

enum DayType { normal, holiday, workday, custom }

class DayEvent {
  final DayType type;
  final String? customLabel;
  const DayEvent({required this.type, this.customLabel});

  Color get color {
    switch (type) {
      case DayType.holiday:  return const Color(0xFFD4956A);
      case DayType.workday:  return const Color(0xFF7C9A7E);
      case DayType.custom:   return const Color(0xFF9B8EA0);
      case DayType.normal:   return Colors.transparent;
    }
  }

  String get label {
    switch (type) {
      case DayType.holiday:  return 'Holiday';
      case DayType.workday:  return 'Work Day';
      case DayType.custom:   return customLabel ?? 'Event';
      case DayType.normal:   return '';
    }
  }

  IconData get icon {
    switch (type) {
      case DayType.holiday:  return Icons.beach_access_rounded;
      case DayType.workday:  return Icons.work_outline_rounded;
      case DayType.custom:   return Icons.star_border_rounded;
      case DayType.normal:   return Icons.circle;
    }
  }
}

// ─── CALENDAR STATE (shared across screens) ──────────────────────────────────

class CalendarState extends ChangeNotifier {
  final Map<String, DayEvent> _events = {};
  DateTime _focusedMonth = DateTime.now();

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  DayEvent? eventFor(DateTime d) => _events[_key(d)];

  void setEvent(DateTime d, DayEvent event) {
    _events[_key(d)] = event;
    notifyListeners();
  }

  void clearEvent(DateTime d) {
    _events.remove(_key(d));
    notifyListeners();
  }

  DateTime get focusedMonth => _focusedMonth;
  void setFocusedMonth(DateTime m) {
    _focusedMonth = m;
    notifyListeners();
  }
}

// ─── DATE HELPERS ────────────────────────────────────────────────────────────

/// Returns true when [date] falls on today (or is null, meaning "today").
bool _isToday(DateTime? date) {
  if (date == null) return true;
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

/// Returns true when [date] falls within the current Mon–Sun week.
bool _isThisWeek(DateTime? date) {
  if (date == null) return false;
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final weekStart = startOfToday.subtract(Duration(days: now.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 7));
  return !date.isBefore(weekStart) && date.isBefore(weekEnd);
}

/// Returns true when [date] falls within the current calendar month.
bool _isThisMonth(DateTime? date) {
  if (date == null) return false;
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month;
}

// ─── APP ROOT ────────────────────────────────────────────────────────────────

class CeladonApp extends StatelessWidget {
  const CeladonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Celadon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Georgia',
        scaffoldBackgroundColor: CeladonColors.cream,
        colorScheme: const ColorScheme.light(
          primary: CeladonColors.sage,
          secondary: CeladonColors.terracotta,
          surface: CeladonColors.pageWhite,
        ),
        useMaterial3: true,
      ),
      home: _CalendarStateProvider(child: const MainShell()),
    );
  }
}

class _CalendarStateProvider extends StatefulWidget {
  final Widget child;
  const _CalendarStateProvider({required this.child});

  @override
  State<_CalendarStateProvider> createState() => _CalendarStateProviderState();
}

class _CalendarStateProviderState extends State<_CalendarStateProvider> {
  final CalendarState _state = CalendarState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CalendarStateInherited(state: _state, child: widget.child);
  }
}

class CalendarStateInherited extends InheritedNotifier<CalendarState> {
  const CalendarStateInherited({super.key, required CalendarState state, required super.child})
      : super(notifier: state);

  static CalendarState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CalendarStateInherited>()!.notifier!;
  }
}

// ─── MAIN SHELL ──────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const TodayScreen(),
      const WeekScreen(),
      const AllTasksScreen(),
    ];

    return Scaffold(
      backgroundColor: CeladonColors.cream,
      body: screens[_currentIndex],
      bottomNavigationBar: _NotebookNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _NotebookNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _NotebookNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.today_rounded, 'Today'),
      (Icons.date_range_rounded, 'Week'),
      (Icons.list_alt_rounded, 'All Tasks'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: CeladonColors.pageWhite,
        border: Border(top: BorderSide(color: CeladonColors.ruleLine, width: 1.5)),
        boxShadow: [BoxShadow(color: CeladonColors.softShadow, blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < items.length; i++)
                GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: currentIndex == i ? CeladonColors.sageLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(items[i].$1,
                            color: currentIndex == i ? CeladonColors.sage : CeladonColors.mutedSage,
                            size: 22),
                        const SizedBox(height: 3),
                        Text(items[i].$2,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: currentIndex == i ? FontWeight.w700 : FontWeight.w400,
                              color: currentIndex == i ? CeladonColors.sage : CeladonColors.mutedSage,
                              letterSpacing: 0.3,
                            )),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── NOTEBOOK BACKGROUND ──────────────────────────────────────────────────────

class NotebookBackground extends StatelessWidget {
  final Widget child;
  const NotebookBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RuledLinePainter(), child: child);
  }
}

class _RuledLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CeladonColors.ruleLine
      ..strokeWidth = 0.8;
    const lineSpacing = 28.0;
    const startY = 80.0;
    for (double y = startY; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final marginPaint = Paint()
      ..color = const Color(0xFFE8BBBB)
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(52, 0), Offset(52, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── MINI CALENDAR WIDGET (tilted, on every screen) ──────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class MiniCalendarWidget extends StatelessWidget {
  final List<Task> todayTasks;
  const MiniCalendarWidget({super.key, this.todayTasks = const []});

  @override
  Widget build(BuildContext context) {
    final calState = CalendarStateInherited.of(context);
    final now = DateTime.now();
    final todayEvent = calState.eventFor(now);

    return GestureDetector(
      onTap: () => _openFullCalendar(context),
      child: Transform.rotate(
        angle: -0.06, // subtle tilt — like placed on a desk
        child: Container(
          width: 115,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7A4F2D), Color(0xFF4A2E14)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A2E14).withAlpha(100),
                blurRadius: 16,
                offset: const Offset(4, 8),
              ),
              BoxShadow(
                color: Colors.white.withAlpha(30),
                blurRadius: 2,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Month name — big serif like reference
              Text(
                _monthName(now.month).toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: CeladonColors.calCream,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 6),
              // Mini month grid
              _MiniMonthGrid(now: now, calState: calState),
              const SizedBox(height: 8),
              // Today's date big
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${now.day}',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _weekdayShort(now.weekday),
                          style: const TextStyle(
                            fontSize: 8,
                            color: CeladonColors.calCream,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (todayEvent != null)
                          Text(
                            todayEvent.label,
                            style: TextStyle(
                              fontSize: 7,
                              color: todayEvent.color,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else if (todayTasks.isNotEmpty)
                          Text(
                            '${todayTasks.length} tasks',
                            style: const TextStyle(
                              fontSize: 7,
                              color: CeladonColors.calCream,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Tap hint
              const Text(
                'tap to open',
                style: TextStyle(
                  fontSize: 7,
                  color: CeladonColors.calCream,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullCalendar(BuildContext context) {
    // Capture calState BEFORE the dialog opens — the dialog is pushed onto a
    // new Navigator route above CalendarStateInherited, so InheritedWidget
    // lookup would fail inside the modal.
    final calState = CalendarStateInherited.of(context);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Calendar',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim, __) => FullCalendarModal(calState: calState),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(scale: curved, child: child);
      },
    );
  }

  String _monthName(int m) =>
      ['', 'January', 'February', 'March', 'April', 'May', 'June',
       'July', 'August', 'September', 'October', 'November', 'December'][m];
  String _weekdayShort(int d) =>
      ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d];
}

class _MiniMonthGrid extends StatelessWidget {
  final DateTime now;
  final CalendarState calState;
  const _MiniMonthGrid({required this.now, required this.calState});

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(now.year, now.month, 1);
    // offset: Mon=0 ... Sun=6
    int offset = firstDay.weekday - 1;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        // Day labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: dayLabels.map((l) => SizedBox(
            width: 13,
            child: Text(l,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 6.5, color: CeladonColors.calCream, fontWeight: FontWeight.w600)),
          )).toList(),
        ),
        Container(height: 0.5, color: CeladonColors.calCream.withAlpha(80), margin: const EdgeInsets.symmetric(vertical: 3)),
        // Day cells
        ...() {
          final totalCells = offset + daysInMonth;
          final rows = (totalCells / 7).ceil();
          return List.generate(rows, (row) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNum = cellIndex - offset + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox(width: 13, height: 11);
                }
                final isToday = dayNum == now.day;
                final d = DateTime(now.year, now.month, dayNum);
                final event = calState.eventFor(d);

                return SizedBox(
                  width: 13,
                  height: 13,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isToday)
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          )
                        else if (event != null)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: event.color.withAlpha(180),
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 6.5,
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w400,
                            color: isToday
                                ? const Color(0xFF4A2E14)
                                : event != null
                                    ? Colors.white
                                    : CeladonColors.calCream,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            );
          });
        }(),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── FULL CALENDAR MODAL ─────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class FullCalendarModal extends StatefulWidget {
  final CalendarState calState;
  const FullCalendarModal({super.key, required this.calState});

  @override
  State<FullCalendarModal> createState() => _FullCalendarModalState();
}

class _FullCalendarModalState extends State<FullCalendarModal> {
  late DateTime _month;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _month = DateTime(DateTime.now().year, DateTime.now().month);
    // Listen for changes from _DayDetailPanel so the grid re-renders
    widget.calState.addListener(_onCalStateChanged);
  }

  void _onCalStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.calState.removeListener(_onCalStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the CalendarState passed in from the parent context (captured before
    // the dialog was pushed, so it's always valid).
    final calState = widget.calState;
    final now = DateTime.now();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7A4F2D), Color(0xFF3D2010)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 32, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                    icon: const Icon(Icons.chevron_left_rounded, color: CeladonColors.calCream, size: 28),
                  ),
                  Column(
                    children: [
                      Text(
                        _monthName(_month.month).toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: CeladonColors.calCream,
                          letterSpacing: 4,
                        ),
                      ),
                      Text(
                        '${_month.year}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: CeladonColors.calCream,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                    icon: const Icon(Icons.chevron_right_rounded, color: CeladonColors.calCream, size: 28),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Divider(color: CeladonColors.calCream, thickness: 0.5),
            ),

            // ── Day labels ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((l) => SizedBox(
                  width: 36,
                  child: Text(l,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CeladonColors.calCream,
                      letterSpacing: 0.5,
                    )),
                )).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // ── Day grid ──
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildGrid(calState, now),
              ),
            ),

            // ── Selected day panel ──
            if (_selectedDay != null)
              _DayDetailPanel(
                day: _selectedDay!,
                calState: calState,
                onClose: () => setState(() => _selectedDay = null),
                onChanged: () => setState(() {}),
              ),

            const SizedBox(height: 16),

            // ── Legend ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: const Color(0xFFD4956A), label: 'Holiday'),
                  const SizedBox(width: 16),
                  _LegendDot(color: const Color(0xFF7C9A7E), label: 'Work Day'),
                  const SizedBox(width: 16),
                  _LegendDot(color: const Color(0xFF9B8EA0), label: 'Event'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(CalendarState calState, DateTime now) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final offset = firstDay.weekday - 1;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final totalCells = offset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNum = cellIndex - offset + 1;
              if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox(width: 36, height: 36);

              final d = DateTime(_month.year, _month.month, dayNum);
              final isToday = d.day == now.day && d.month == now.month && d.year == now.year;
              final isSelected = _selectedDay != null &&
                  d.day == _selectedDay!.day &&
                  d.month == _selectedDay!.month &&
                  d.year == _selectedDay!.year;
              final event = calState.eventFor(d);

              return GestureDetector(
                onTap: () => setState(() => _selectedDay = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : isToday
                            ? Colors.white.withAlpha(40)
                            : event != null
                                ? event.color.withAlpha(120)
                                : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(color: Colors.white, width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 15,
                        fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected
                            ? const Color(0xFF4A2E14)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  String _monthName(int m) =>
      ['', 'January', 'February', 'March', 'April', 'May', 'June',
       'July', 'August', 'September', 'October', 'November', 'December'][m];
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: CeladonColors.calCream)),
      ],
    );
  }
}

// ─── DAY DETAIL PANEL (inside modal) ─────────────────────────────────────────

class _DayDetailPanel extends StatefulWidget {
  final DateTime day;
  final CalendarState calState;
  final VoidCallback onClose;
  final VoidCallback onChanged;

  const _DayDetailPanel({
    required this.day,
    required this.calState,
    required this.onClose,
    required this.onChanged,
  });

  @override
  State<_DayDetailPanel> createState() => _DayDetailPanelState();
}

class _DayDetailPanelState extends State<_DayDetailPanel> {
  final TextEditingController _customCtrl = TextEditingController();
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.calState.eventFor(widget.day);
    if (existing?.type == DayType.custom) {
      _customCtrl.text = existing?.customLabel ?? '';
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.calState.eventFor(widget.day);
    final d = widget.day;
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${d.day} ${months[d.month]}',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onClose,
                child: const Icon(Icons.close_rounded, color: CeladonColors.calCream, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Type buttons
          Row(
            children: [
              _TypeBtn(label: '🏖 Holiday', active: event?.type == DayType.holiday,
                activeColor: const Color(0xFFD4956A),
                onTap: () { widget.calState.setEvent(d, const DayEvent(type: DayType.holiday)); setState(() => _showCustomInput = false); widget.onChanged(); }),
              const SizedBox(width: 8),
              _TypeBtn(label: '💼 Work', active: event?.type == DayType.workday,
                activeColor: const Color(0xFF7C9A7E),
                onTap: () { widget.calState.setEvent(d, const DayEvent(type: DayType.workday)); setState(() => _showCustomInput = false); widget.onChanged(); }),
              const SizedBox(width: 8),
              _TypeBtn(label: '✏️ Custom', active: event?.type == DayType.custom,
                activeColor: const Color(0xFF9B8EA0),
                onTap: () { setState(() => _showCustomInput = true); widget.onChanged(); }),
            ],
          ),
          // Custom input
          if (_showCustomInput) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Exam, Competition, Trip...',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(120), fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withAlpha(20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withAlpha(60)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withAlpha(60)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_customCtrl.text.trim().isNotEmpty) {
                      widget.calState.setEvent(d, DayEvent(type: DayType.custom, customLabel: _customCtrl.text.trim()));
                      setState(() => _showCustomInput = false);
                      widget.onChanged();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B8EA0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
          // Clear button
          if (event != null && !_showCustomInput) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                widget.calState.clearEvent(d);
                widget.onChanged();
              },
              child: Text(
                'Clear day',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withAlpha(150),
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white.withAlpha(100),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _TypeBtn({required this.label, required this.active, required this.activeColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? activeColor : Colors.white.withAlpha(60)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? Colors.white : Colors.white.withAlpha(180),
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── SCREEN HEADER WITH MINI CALENDAR ────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

/// Reusable header row: mini calendar on left, title content on right
class ScreenHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final List<Task> todayTasks;
  final Widget? subtitle;

  const ScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.todayTasks = const [],
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini calendar — top left
          MiniCalendarWidget(todayTasks: todayTasks),
          const SizedBox(width: 14),
          // Title block
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: const TextStyle(
                      fontSize: 11,
                      color: CeladonColors.terracotta,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: CeladonColors.inkBrown,
                      height: 1.1,
                    ),
                  ),
                  if (subtitle != null) ...[const SizedBox(height: 4), subtitle!],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── SCREEN 1: TODAY ─────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final List<Task> _tasks = [
    Task(
      id: '1', title: 'Read Chapter 7 — Organic Chem',
      subject: 'Chemistry', priority: Priority.high,
      dueDate: DateTime.now(),
    ),
    Task(
      id: '2', title: 'Complete Math problem set',
      subject: 'Mathematics', isDone: true, priority: Priority.medium,
      dueDate: DateTime.now(), completedAt: DateTime.now(),
    ),
    Task(
      id: '3', title: 'Write essay draft',
      subject: 'English Lit', priority: Priority.medium,
      dueDate: DateTime.now(),
    ),
    Task(
      id: '4', title: 'Review lecture notes',
      subject: 'Physics', priority: Priority.low,
      dueDate: DateTime.now().add(const Duration(days: 2)),
    ),
    Task(
      id: '5', title: 'Prepare for quiz',
      subject: 'History', priority: Priority.high,
      dueDate: DateTime.now().add(const Duration(days: 5)),
    ),
    Task(
      id: '6', title: 'Chapter 9 summary',
      subject: 'History', priority: Priority.medium,
      dueDate: DateTime.now().add(const Duration(days: 20)),
    ),
  ];

  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    // Auto-prune completed tasks after 24 h
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _tasks.removeWhere((t) => t.isExpiredCompleted));
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  // ── Computed groups ───────────────────────────────────────────────────────
  List<Task> get _dailyTasks =>
      _tasks.where((t) => !t.isDone && _isToday(t.dueDate)).toList();

  List<Task> get _completedTasks =>
      _tasks.where((t) => t.isDone && !t.isExpiredCompleted).toList();

  List<Task> get _weeklyTasks => _tasks
      .where((t) => !t.isDone && _isThisWeek(t.dueDate) && !_isToday(t.dueDate))
      .toList();

  List<Task> get _monthlyTasks => _tasks
      .where((t) => !t.isDone && _isThisMonth(t.dueDate) && !_isThisWeek(t.dueDate))
      .toList();

  // ── Actions ───────────────────────────────────────────────────────────────
  void _toggleTask(String id) {
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == id);
      if (idx == -1) return;
      final task = _tasks[idx];
      final nowDone = !task.isDone;
      _tasks[idx] = Task(
        id: task.id, title: task.title, subject: task.subject,
        isDone: nowDone, priority: task.priority, dueDate: task.dueDate,
        completedAt: nowDone ? DateTime.now() : null,
      );
    });
  }

  void _deleteTask(String id) {
    setState(() => _tasks.removeWhere((t) => t.id == id));
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTaskSheet(
        onAdd: (title, subject, priority, dueDate) {
          setState(() {
            _tasks.add(Task(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
              subject: subject,
              priority: priority,
              dueDate: dueDate,
            ));
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayAll = _tasks.where((t) => _isToday(t.dueDate)).toList();
    final todayDone = todayAll.where((t) => t.isDone).length;

    return Scaffold(
      backgroundColor: CeladonColors.cream,
      body: NotebookBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header ────────────────────────────────────────────────────
              ScreenHeader(
                eyebrow: _weekdayFull(now.weekday).toUpperCase(),
                title: '${now.day} ${_monthShort(now.month)}',
                todayTasks: _dailyTasks,
              ),

              // ── Today's progress ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(64, 14, 20, 0),
                child: _ProgressBar(done: todayDone, total: todayAll.length),
              ),

              const SizedBox(height: 10),

              // ── Main split ────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ─ LEFT: scrollable task panel in Stack (brown border) ─
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: CeladonColors.pageWhite,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: CeladonColors.calBrown.withAlpha(210),
                                  width: 1.8,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: CeladonColors.softShadow,
                                    blurRadius: 10,
                                    offset: Offset(2, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(19),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 60),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [

                                      // TODAY ────────────────────────────────
                                      _TaskSectionLabel(
                                        label: 'TODAY',
                                        count: _dailyTasks.length,
                                        color: CeladonColors.terracotta,
                                      ),
                                      if (_dailyTasks.isEmpty)
                                        const _EmptySection(message: 'All done! 🎉'),
                                      ..._dailyTasks.map((t) => _CompactTaskCard(
                                            task: t,
                                            onToggle: () => _toggleTask(t.id),
                                            onDelete: () => _deleteTask(t.id),
                                          )),

                                      // COMPLETED ────────────────────────────
                                      if (_completedTasks.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        _TaskSectionLabel(
                                          label: 'DONE',
                                          count: _completedTasks.length,
                                          color: CeladonColors.sage,
                                          subtitle: '· clears in 24h',
                                        ),
                                        ..._completedTasks.map((t) => _CompactTaskCard(
                                              task: t,
                                              onToggle: () => _toggleTask(t.id),
                                              onDelete: () => _deleteTask(t.id),
                                            )),
                                      ],

                                      // THIS WEEK ────────────────────────────
                                      if (_weeklyTasks.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        _TaskSectionLabel(
                                          label: 'THIS WEEK',
                                          count: _weeklyTasks.length,
                                          color: const Color(0xFF6A8FA0),
                                        ),
                                        ..._weeklyTasks.map((t) => _CompactTaskCard(
                                              task: t,
                                              onToggle: () => _toggleTask(t.id),
                                              onDelete: () => _deleteTask(t.id),
                                            )),
                                      ],

                                      // THIS MONTH ───────────────────────────
                                      if (_monthlyTasks.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        _TaskSectionLabel(
                                          label: 'THIS MONTH',
                                          count: _monthlyTasks.length,
                                          color: const Color(0xFF9B8EA0),
                                        ),
                                        ..._monthlyTasks.map((t) => _CompactTaskCard(
                                              task: t,
                                              onToggle: () => _toggleTask(t.id),
                                              onDelete: () => _deleteTask(t.id),
                                            )),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // ─ + button pinned bottom-right inside the panel ──
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: _showAddSheet,
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: CeladonColors.sage,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: CeladonColors.sage.withAlpha(90),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // ─ RIGHT: Bear + quote + water (fixed narrow width) ────
                      SizedBox(
                        width: 148,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: const [
                            Expanded(child: _BearWidget()),
                            SizedBox(height: 6),
                            _WaterReminderCard(),
                            SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  String _weekdayFull(int d) =>
      ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d];
  String _monthShort(int m) =>
      ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
}

// ─── PROGRESS BAR ────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int done;
  final int total;
  const _ProgressBar({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$done of $total tasks complete',
                style: const TextStyle(fontSize: 12, color: CeladonColors.inkBrown, fontWeight: FontWeight.w500)),
            Text('${(pct * 100).round()}%',
                style: const TextStyle(fontSize: 12, color: CeladonColors.sage, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: CeladonColors.ruleLine,
            valueColor: const AlwaysStoppedAnimation(CeladonColors.sage),
          ),
        ),
      ],
    );
  }
}

// ─── TASK CARD ───────────────────────────────────────────────────────────────

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  const TaskCard({super.key, required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text('·', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: task.priority.color.withAlpha(180), fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: task.isDone ? CeladonColors.ruleLine.withAlpha(120) : CeladonColors.pageWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: task.isDone ? CeladonColors.ruleLine : task.priority.color.withAlpha(60),
                  ),
                  boxShadow: task.isDone ? [] : [const BoxShadow(color: CeladonColors.softShadow, blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: task.isDone ? CeladonColors.sage : Colors.transparent,
                        border: Border.all(
                          color: task.isDone ? CeladonColors.sage : CeladonColors.mutedSage,
                          width: 1.5,
                        ),
                      ),
                      child: task.isDone ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.title, style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: task.isDone ? CeladonColors.mutedSage : CeladonColors.inkBrown,
                            decoration: task.isDone ? TextDecoration.lineThrough : null,
                            decorationColor: CeladonColors.mutedSage,
                            height: 1.3,
                          )),
                          const SizedBox(height: 3),
                          Text(task.subject, style: const TextStyle(fontSize: 11, color: CeladonColors.mutedSage, letterSpacing: 0.3)),
                        ],
                      ),
                    ),
                    if (!task.isDone)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: task.priority.color.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(task.priority.label,
                            style: TextStyle(fontSize: 10, color: task.priority.color, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ADD TASK SHEET ───────────────────────────────────────────────────────────

class _AddTaskSheet extends StatefulWidget {
  /// Called with (title, subject, priority, dueDate) when the user taps add.
  final void Function(String title, String subject, Priority priority, DateTime dueDate) onAdd;
  const _AddTaskSheet({required this.onAdd});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _customSubjectCtrl = TextEditingController();
  String _subject = 'General';
  bool _useCustomSubject = false;
  Priority _priority = Priority.medium;
  late DateTime _dueDate;

  final _subjects = [
    'General', 'Mathematics', 'Physics', 'Chemistry',
    'English Lit', 'History', 'Biology', 'CS',
  ];

  @override
  void initState() {
    super.initState();
    _dueDate = DateTime.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _customSubjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: CeladonColors.sage,
            onPrimary: Colors.white,
            surface: CeladonColors.pageWhite,
            onSurface: CeladonColors.inkBrown,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _dueDate.year == now.year &&
        _dueDate.month == now.month &&
        _dueDate.day == now.day;
  }

  String get _dateLabel {
    if (_isToday) return 'Today';
    final tom = DateTime.now().add(const Duration(days: 1));
    if (_dueDate.year == tom.year && _dueDate.month == tom.month && _dueDate.day == tom.day) {
      return 'Tomorrow';
    }
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${_dueDate.day} ${months[_dueDate.month]}';
  }

  String get _effectiveSubject =>
      _useCustomSubject && _customSubjectCtrl.text.trim().isNotEmpty
          ? _customSubjectCtrl.text.trim()
          : _subject;

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    widget.onAdd(title, _effectiveSubject, _priority, _dueDate);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: CeladonColors.pageWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: CeladonColors.ruleLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'New Task',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CeladonColors.inkBrown),
            ),
            const SizedBox(height: 16),

            // ── Task title ───────────────────────────────────────────────
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 15, color: CeladonColors.inkBrown),
              decoration: InputDecoration(
                hintText: 'What do you need to do?',
                hintStyle: const TextStyle(color: CeladonColors.mutedSage),
                filled: true, fillColor: CeladonColors.cream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: CeladonColors.ruleLine),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: CeladonColors.ruleLine),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: CeladonColors.sage, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),

            // ── Date + Priority row ───────────────────────────────────────
            Row(
              children: [
                GestureDetector(
                  onTap: _pickDate,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _isToday ? CeladonColors.cream : CeladonColors.sageLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isToday ? CeladonColors.ruleLine : CeladonColors.sage,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: _isToday ? CeladonColors.mutedSage : CeladonColors.sage,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _dateLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isToday ? CeladonColors.inkBrown : CeladonColors.sage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                for (final p in Priority.values)
                  GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _priority == p ? p.color.withAlpha(30) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _priority == p ? p.color : CeladonColors.ruleLine,
                        ),
                      ),
                      child: Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _priority == p ? FontWeight.w600 : FontWeight.w400,
                          color: _priority == p ? p.color : CeladonColors.mutedSage,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Subject ───────────────────────────────────────────────────
            Row(
              children: [
                const Text(
                  'Subject:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CeladonColors.inkBrown,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _useCustomSubject = !_useCustomSubject;
                    if (!_useCustomSubject) _customSubjectCtrl.clear();
                  }),
                  child: Text(
                    _useCustomSubject ? '← Use preset' : 'Type custom ✏️',
                    style: const TextStyle(
                      fontSize: 11,
                      color: CeladonColors.terracotta,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_useCustomSubject)
              TextField(
                controller: _customSubjectCtrl,
                style: const TextStyle(fontSize: 13, color: CeladonColors.inkBrown),
                decoration: InputDecoration(
                  hintText: 'e.g. Art, Drama, Sports...',
                  hintStyle: const TextStyle(color: CeladonColors.mutedSage, fontSize: 12),
                  filled: true, fillColor: CeladonColors.cream,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CeladonColors.ruleLine),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CeladonColors.ruleLine),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CeladonColors.terracotta, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              )
            else
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _subjects.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final s = _subjects[i];
                    final sel = s == _subject;
                    return GestureDetector(
                      onTap: () => setState(() => _subject = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? CeladonColors.sage : CeladonColors.cream,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? CeladonColors.sage : CeladonColors.ruleLine,
                          ),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                            color: sel ? Colors.white : CeladonColors.inkBrown,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            // ── Add button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CeladonColors.sage,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  _isToday ? 'Add to Today' : 'Schedule for $_dateLabel',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── COMPACT TASK CARD (left panel) ──────────────────────────────────────────

class _CompactTaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _CompactTaskCard({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('cmp-${task.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFD96060),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 16),
      ),
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: task.isDone
                ? CeladonColors.ruleLine.withAlpha(60)
                : CeladonColors.cream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: task.isDone
                  ? CeladonColors.ruleLine
                  : task.priority.color.withAlpha(60),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isDone ? CeladonColors.sage : Colors.transparent,
                    border: Border.all(
                      color: task.isDone ? CeladonColors.sage : CeladonColors.mutedSage,
                      width: 1.5,
                    ),
                  ),
                  child: task.isDone
                      ? const Icon(Icons.check_rounded, size: 9, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: task.isDone ? CeladonColors.mutedSage : CeladonColors.inkBrown,
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                        decorationColor: CeladonColors.mutedSage,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            color: task.priority.color.withAlpha(task.isDone ? 100 : 200),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            task.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9.5, color: CeladonColors.mutedSage),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TASK SECTION LABEL ───────────────────────────────────────────────────────

class _TaskSectionLabel extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final String? subtitle;
  const _TaskSectionLabel({
    required this.label,
    required this.count,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 3, height: 13,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 4),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 9, color: CeladonColors.mutedSage),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── EMPTY SECTION PLACEHOLDER ────────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  final String message;
  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 11,
            color: CeladonColors.mutedSage,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

// ─── BEAR WIDGET ──────────────────────────────────────────────────────────────

class _BearWidget extends StatefulWidget {
  const _BearWidget();

  @override
  State<_BearWidget> createState() => _BearWidgetState();
}

class _BearWidgetState extends State<_BearWidget> {
  static const _quotes = [
    '"You\'re doing amazing!\nKeep going! 🌟"',
    '"Every step forward\nbrings you closer! 📚"',
    '"Believe in yourself —\nyou\'ve got this! 💪"',
    '"Focus now,\nshine later! ✨"',
    '"One task at a time,\nyou\'ll get there! 🎯"',
    '"Your hard work\nwill pay off! 🌱"',
    '"Stay curious,\nstay brilliant! 🔍"',
    '"Great things take time.\nBe patient! ⏳"',
  ];

  int _quoteIdx = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) setState(() => _quoteIdx = (_quoteIdx + 1) % _quotes.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bear drawing fills whatever height is available
        Expanded(
          child: CustomPaint(
            painter: _BearPainter(),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 6),
        // Rotating motivational quote
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Container(
            key: ValueKey(_quoteIdx),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: CeladonColors.sageLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CeladonColors.mutedSage.withAlpha(80)),
            ),
            child: Text(
              _quotes[_quoteIdx],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: CeladonColors.inkBrown,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── BEAR CUSTOM PAINTER ──────────────────────────────────────────────────────

class _BearPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.50;
    final r = math.min(size.width, size.height) * 0.26;

    const furBrown    = Color(0xFFBE7B4A);
    const furLighter  = Color(0xFFD49A60);
    const bodyGreen   = CeladonColors.sage;
    const muzzleCream = Color(0xFFEDD9B5);
    const darkBrown   = Color(0xFF2C2416);
    const innerEar    = Color(0xFFE8A070);
    final cheekPink   = const Color(0xFFE8806A).withAlpha(75);

    // Body / sweater ────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + r + r * 0.50),
          width: r * 1.9,
          height: r * 1.15,
        ),
        Radius.circular(r * 0.55),
      ),
      Paint()..color = bodyGreen,
    );

    // Arms + paws ────────────────────────────────────────────────────────────
    for (final s in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + s * r * 1.02, cy + r * 0.40),
            width: r * 0.46,
            height: r * 0.86,
          ),
          Radius.circular(r * 0.23),
        ),
        Paint()..color = furBrown,
      );
      canvas.drawCircle(
        Offset(cx + s * r * 1.02, cy + r * 0.88),
        r * 0.21,
        Paint()..color = furLighter,
      );
    }

    // Ears (behind head) ─────────────────────────────────────────────────────
    for (final s in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(cx + s * r * 0.65, cy - r * 0.75),
        r * 0.32,
        Paint()..color = furBrown,
      );
      canvas.drawCircle(
        Offset(cx + s * r * 0.65, cy - r * 0.75),
        r * 0.17,
        Paint()..color = innerEar,
      );
    }

    // Head ────────────────────────────────────────────────────────────────────
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = furBrown);

    // Muzzle ──────────────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + r * 0.25),
        width: r * 0.84,
        height: r * 0.58,
      ),
      Paint()..color = muzzleCream,
    );

    // Rosy cheeks ─────────────────────────────────────────────────────────────
    canvas.drawCircle(Offset(cx - r * 0.42, cy + r * 0.15), r * 0.17, Paint()..color = cheekPink);
    canvas.drawCircle(Offset(cx + r * 0.42, cy + r * 0.15), r * 0.17, Paint()..color = cheekPink);

    // Eyes (white sclera + dark pupil + sparkle) ──────────────────────────────
    for (final s in [-1.0, 1.0]) {
      final ex = cx + s * r * 0.27;
      final ey = cy - r * 0.08;
      canvas.drawCircle(Offset(ex, ey), r * 0.13, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(ex + r * 0.04, ey), r * 0.085, Paint()..color = darkBrown);
      canvas.drawCircle(Offset(ex + r * 0.07, ey - r * 0.05), r * 0.028, Paint()..color = Colors.white);
    }

    // Nose ────────────────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + r * 0.06),
        width: r * 0.21,
        height: r * 0.13,
      ),
      Paint()..color = darkBrown,
    );

    // Smile ───────────────────────────────────────────────────────────────────
    canvas.drawPath(
      Path()
        ..moveTo(cx - r * 0.15, cy + r * 0.23)
        ..quadraticBezierTo(cx, cy + r * 0.37, cx + r * 0.15, cy + r * 0.23),
      Paint()
        ..color = darkBrown
        ..strokeWidth = r * 0.055
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── WATER REMINDER CARD ──────────────────────────────────────────────────────

class _WaterReminderCard extends StatelessWidget {
  const _WaterReminderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFDEEDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB0D4E0)),
        boxShadow: const [
          BoxShadow(
            color: CeladonColors.softShadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          Text('💧', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Drink Water!',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3A6E8A),
                  ),
                ),
                Text(
                  'Stay hydrated today 💙',
                  style: TextStyle(fontSize: 9.5, color: Color(0xFF6A9EB0)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── SCREEN 2: WEEK ──────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final taskCounts = [5, 3, 7, 2, 4, 1, 0];
    final doneCounts = [4, 1, 3, 2, 2, 0, 0];

    return Scaffold(
      backgroundColor: CeladonColors.cream,
      body: NotebookBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  eyebrow: 'THIS WEEK',
                  title: _weekRange(weekStart),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    itemCount: 7,
                    itemBuilder: (_, i) {
                      final day = weekStart.add(Duration(days: i));
                      final isToday = day.day == now.day && day.month == now.month;
                      final total = taskCounts[i];
                      final done = doneCounts[i];
                      final pct = total == 0 ? 0.0 : done / total;

                      return Container(
                        width: 80, margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isToday ? CeladonColors.sage : CeladonColors.pageWhite,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: isToday ? CeladonColors.sage : CeladonColors.ruleLine),
                          boxShadow: [BoxShadow(
                            color: isToday ? CeladonColors.sage.withAlpha(60) : CeladonColors.softShadow,
                            blurRadius: 8, offset: const Offset(0, 3),
                          )],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dayLabels[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: isToday ? Colors.white70 : CeladonColors.mutedSage, letterSpacing: 0.5)),
                            const SizedBox(height: 2),
                            Text('${day.day}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                                color: isToday ? Colors.white : CeladonColors.inkBrown)),
                            const Spacer(),
                            if (total > 0) ...[
                              ClipRRect(borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(value: pct, minHeight: 4,
                                  backgroundColor: isToday ? Colors.white30 : CeladonColors.ruleLine,
                                  valueColor: AlwaysStoppedAnimation(isToday ? Colors.white : CeladonColors.terracotta))),
                              const SizedBox(height: 4),
                              Text('$done/$total', style: TextStyle(fontSize: 10,
                                  color: isToday ? Colors.white70 : CeladonColors.mutedSage)),
                            ] else
                              Text('Free', style: TextStyle(fontSize: 11,
                                  color: isToday ? Colors.white60 : CeladonColors.mutedSage,
                                  fontStyle: FontStyle.italic)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(64, 0, 20, 12),
                  child: const Text('BY SUBJECT', style: TextStyle(fontSize: 11, letterSpacing: 1.5,
                      color: CeladonColors.mutedSage, fontWeight: FontWeight.w600)),
                ),
              ),

              SliverList(delegate: SliverChildListDelegate([
                _SubjectRow(subject: 'Mathematics', tasks: 5, color: const Color(0xFF7C9A7E)),
                _SubjectRow(subject: 'Chemistry', tasks: 4, color: const Color(0xFFD4956A)),
                _SubjectRow(subject: 'English Lit', tasks: 3, color: const Color(0xFF9B8EA0)),
                _SubjectRow(subject: 'Physics', tasks: 2, color: const Color(0xFF6A8FA0)),
                _SubjectRow(subject: 'History', tasks: 2, color: const Color(0xFFA09B6A)),
              ])),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  String _weekRange(DateTime start) {
    final end = start.add(const Duration(days: 6));
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (start.month == end.month) return '${start.day}–${end.day} ${months[start.month]}';
    return '${start.day} ${months[start.month]} – ${end.day} ${months[end.month]}';
  }
}

class _SubjectRow extends StatelessWidget {
  final String subject;
  final int tasks;
  final Color color;
  const _SubjectRow({required this.subject, required this.tasks, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          const SizedBox(width: 36),
          const SizedBox(width: 12),
          Container(width: 4, height: 40, margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: CeladonColors.pageWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CeladonColors.ruleLine)),
              child: Row(
                children: [
                  Text(subject, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CeladonColors.inkBrown)),
                  const Spacer(),
                  Text('$tasks tasks', style: const TextStyle(fontSize: 12, color: CeladonColors.mutedSage)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── SCREEN 3: ALL TASKS ─────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class AllTasksScreen extends StatelessWidget {
  const AllTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = {
      'Today': [
        Task(id: 'a1', title: 'Read Chapter 7 — Organic Chem', subject: 'Chemistry', priority: Priority.high),
        Task(id: 'a2', title: 'Complete Math problem set', subject: 'Mathematics', isDone: true, priority: Priority.medium),
      ],
      'Tomorrow': [
        Task(id: 'b1', title: 'Lab report write-up', subject: 'Physics', priority: Priority.high),
        Task(id: 'b2', title: 'Vocabulary quiz prep', subject: 'English Lit', priority: Priority.low),
      ],
      'This Week': [
        Task(id: 'c1', title: 'Chapter 9 summary', subject: 'History', priority: Priority.medium),
        Task(id: 'c2', title: 'Practice integration problems', subject: 'Mathematics', priority: Priority.medium),
        Task(id: 'c3', title: 'Group study session', subject: 'General', priority: Priority.low),
      ],
    };

    return Scaffold(
      backgroundColor: CeladonColors.cream,
      body: NotebookBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(eyebrow: 'ALL TASKS', title: 'Everything'),
              ),
              for (final entry in groups.entries) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(64, 20, 20, 8),
                    child: Text(entry.key.toUpperCase(),
                        style: const TextStyle(fontSize: 11, letterSpacing: 1.5,
                            color: CeladonColors.mutedSage, fontWeight: FontWeight.w600)),
                  ),
                ),
                SliverList(delegate: SliverChildBuilderDelegate(
                  (ctx, i) => TaskCard(task: entry.value[i], onToggle: () {}),
                  childCount: entry.value.length,
                )),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}