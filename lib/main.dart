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

  const Task({
    required this.id,
    required this.title,
    required this.subject,
    this.isDone = false,
    this.priority = Priority.medium,
  });

  Task copyWith({String? id, String? title, String? subject, bool? isDone, Priority? priority}) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      isDone: isDone ?? this.isDone,
      priority: priority ?? this.priority,
    );
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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Calendar',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim, __) => const FullCalendarModal(),
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
  const FullCalendarModal({super.key});

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
  }

  @override
  Widget build(BuildContext context) {
    final calState = CalendarStateInherited.of(context);
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
    Task(id: '1', title: 'Read Chapter 7 — Organic Chem', subject: 'Chemistry', priority: Priority.high),
    Task(id: '2', title: 'Complete Math problem set', subject: 'Mathematics', isDone: true, priority: Priority.medium),
    Task(id: '3', title: 'Write essay draft', subject: 'English Lit', priority: Priority.medium),
    Task(id: '4', title: 'Review lecture notes', subject: 'Physics', priority: Priority.low),
    Task(id: '5', title: 'Prepare for quiz', subject: 'History', priority: Priority.high),
  ];

  final TextEditingController _addCtrl = TextEditingController();
  String _selectedSubject = 'General';
  Priority _selectedPriority = Priority.medium;

  int get _doneCount => _tasks.where((t) => t.isDone).length;

  void _toggleTask(String id) {
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == id);
      if (idx != -1) _tasks[idx] = _tasks[idx].copyWith(isDone: !_tasks[idx].isDone);
    });
  }

  void _addTask() {
    if (_addCtrl.text.trim().isEmpty) return;
    setState(() {
      _tasks.add(Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _addCtrl.text.trim(),
        subject: _selectedSubject,
        priority: _selectedPriority,
      ));
      _addCtrl.clear();
    });
    Navigator.pop(context);
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTaskSheet(
        controller: _addCtrl,
        selectedSubject: _selectedSubject,
        selectedPriority: _selectedPriority,
        onSubjectChanged: (s) => setState(() => _selectedSubject = s),
        onPriorityChanged: (p) => setState(() => _selectedPriority = p),
        onAdd: _addTask,
      ),
    );
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final pending = _tasks.where((t) => !t.isDone).toList();
    final done = _tasks.where((t) => t.isDone).toList();

    return Scaffold(
      backgroundColor: CeladonColors.cream,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: CeladonColors.sage,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: NotebookBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Header with mini calendar ──
              SliverToBoxAdapter(
                child: ScreenHeader(
                  eyebrow: _weekdayFull(now.weekday).toUpperCase(),
                  title: '${now.day} ${_monthShort(now.month)}',
                  todayTasks: _tasks,
                ),
              ),

              // ── Progress ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(64, 20, 20, 8),
                  child: _ProgressBar(done: _doneCount, total: _tasks.length),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Pending ──
              if (pending.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(64, 0, 20, 8),
                    child: Text('TO DO  ·  ${pending.length}',
                        style: const TextStyle(fontSize: 11, letterSpacing: 1.5,
                            color: CeladonColors.mutedSage, fontWeight: FontWeight.w600)),
                  ),
                ),
                SliverList(delegate: SliverChildBuilderDelegate(
                  (ctx, i) => TaskCard(task: pending[i], onToggle: () => _toggleTask(pending[i].id)),
                  childCount: pending.length,
                )),
              ],

              // ── Done ──
              if (done.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(64, 20, 20, 8),
                    child: Text('DONE  ·  ${done.length}',
                        style: const TextStyle(fontSize: 11, letterSpacing: 1.5,
                            color: CeladonColors.mutedSage, fontWeight: FontWeight.w600)),
                  ),
                ),
                SliverList(delegate: SliverChildBuilderDelegate(
                  (ctx, i) => TaskCard(task: done[i], onToggle: () => _toggleTask(done[i].id)),
                  childCount: done.length,
                )),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  String _weekdayFull(int d) => ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d];
  String _monthShort(int m) => ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
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
  final TextEditingController controller;
  final String selectedSubject;
  final Priority selectedPriority;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<Priority> onPriorityChanged;
  final VoidCallback onAdd;

  const _AddTaskSheet({
    required this.controller,
    required this.selectedSubject,
    required this.selectedPriority,
    required this.onSubjectChanged,
    required this.onPriorityChanged,
    required this.onAdd,
  });

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  late String _subject;
  late Priority _priority;
  final _subjects = ['General', 'Mathematics', 'Physics', 'Chemistry', 'English Lit', 'History', 'Biology', 'CS'];

  @override
  void initState() {
    super.initState();
    _subject = widget.selectedSubject;
    _priority = widget.selectedPriority;
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
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: CeladonColors.ruleLine, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('New Task', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CeladonColors.inkBrown)),
            const SizedBox(height: 16),
            TextField(
              controller: widget.controller,
              autofocus: true,
              style: const TextStyle(fontSize: 15, color: CeladonColors.inkBrown),
              decoration: InputDecoration(
                hintText: 'What do you need to do?',
                hintStyle: const TextStyle(color: CeladonColors.mutedSage),
                filled: true, fillColor: CeladonColors.cream,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CeladonColors.ruleLine)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CeladonColors.ruleLine)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CeladonColors.sage, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onSubmitted: (_) => widget.onAdd(),
            ),
            const SizedBox(height: 14),
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
                    onTap: () { setState(() => _subject = s); widget.onSubjectChanged(s); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? CeladonColors.sage : CeladonColors.cream,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? CeladonColors.sage : CeladonColors.ruleLine),
                      ),
                      child: Text(s, style: TextStyle(fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? Colors.white : CeladonColors.inkBrown)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('Priority:', style: TextStyle(fontSize: 13, color: CeladonColors.inkBrown)),
                const SizedBox(width: 12),
                for (final p in Priority.values)
                  GestureDetector(
                    onTap: () { setState(() => _priority = p); widget.onPriorityChanged(p); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _priority == p ? p.color.withAlpha(30) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _priority == p ? p.color : CeladonColors.ruleLine),
                      ),
                      child: Text(p.label, style: TextStyle(fontSize: 12,
                          fontWeight: _priority == p ? FontWeight.w600 : FontWeight.w400,
                          color: _priority == p ? p.color : CeladonColors.mutedSage)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CeladonColors.sage, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Add to today', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
              ),
            ),
          ],
        ),
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