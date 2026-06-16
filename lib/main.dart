import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'secrets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

// ─── PRESSABLE (shared hover-lift animation) ────────────────────────────────
//
// Wrap any tappable widget to get a tactile hover response on devices with a
// pointer (web/desktop/trackpad/stylus) — scales up slightly and lifts with a
// soft shadow while the pointer rests over it, settling back when it leaves.
// onTap still fires normally for touch devices, which have no hover state.
// Centralized here so every card / chip / button in the app feels consistent.

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double hoverScale;
  final Duration duration;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.hoverScale = 1.04,
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _lift;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 1.0, end: widget.hoverScale)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _lift = Tween<double>(begin: 0.0, end: 6.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onEnter(_) => _ctrl.forward();
  void _onExit(_) => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -_lift.value),
            child: Transform.scale(scale: _scale.value, child: child),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── ADD BUTTON (pinned + button with a playful hover wiggle) ──────────────

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _scale = Tween<double>(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _rotation = Tween<double>(begin: 0.0, end: 0.2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _ctrl.forward(),
      onExit: (_) => _ctrl.reverse(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Transform.scale(
            scale: _scale.value,
            child: Transform.rotate(angle: _rotation.value, child: child),
          ),
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
    );
  }
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

  /// Serialize to Firestore.
  Map<String, dynamic> toFirestore() => {
    'id': id,
    'title': title,
    'subject': subject,
    'isDone': isDone,
    'priority': priority.index,
    'dueDate': dueDate?.millisecondsSinceEpoch,
    'completedAt': completedAt?.millisecondsSinceEpoch,
  };

  /// Deserialize from Firestore.
  factory Task.fromFirestore(Map<String, dynamic> m) => Task(
    id: m['id'] as String,
    title: m['title'] as String,
    subject: m['subject'] as String,
    isDone: (m['isDone'] as bool?) ?? false,
    priority: Priority.values[(m['priority'] as int?) ?? 1],
    dueDate: m['dueDate'] != null ? DateTime.fromMillisecondsSinceEpoch(m['dueDate'] as int) : null,
    completedAt: m['completedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(m['completedAt'] as int) : null,
  );

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
    final k = _key(d);
    _events[k] = event;
    notifyListeners();
    // Persist to Firestore (fire-and-forget)
    _Db.saveCalendarEvent(k, {
      'key': k,
      'type': event.type.index,
      'customLabel': event.customLabel,
    }).catchError((_) {});
  }

  void clearEvent(DateTime d) {
    final k = _key(d);
    _events.remove(k);
    notifyListeners();
    _Db.deleteCalendarEvent(k).catchError((_) {});
  }

  DateTime get focusedMonth => _focusedMonth;
  void setFocusedMonth(DateTime m) {
    _focusedMonth = m;
    notifyListeners();
  }

  /// Load all events from Firestore for this user.
  Future<void> loadFromFirestore() async {
    try {
      final raw = await _Db.loadCalendarEvents();
      for (final m in raw) {
        final k = m['key'] as String;
        final type = DayType.values[(m['type'] as int?) ?? 0];
        final label = m['customLabel'] as String?;
        _events[k] = DayEvent(type: type, customLabel: label);
      }
      notifyListeners();
    } catch (_) {}
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

// ── Firebase Auth wrapper (replaces in-memory _AuthStore)
class _AuthService {
  _AuthService._();
  static final instance = _AuthService._();

  final _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// Returns null on success, human-readable error on failure.
  Future<String?> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    }
  }

  Future<String?> resetPassword(String newPassword) async {
    try {
      await _auth.currentUser!.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    }
  }

  Future<void> logout() => _auth.signOut();

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':    return 'Account already exists. Please sign in.';
      case 'user-not-found':          return 'No account found. Please sign up first.';
      case 'wrong-password':          return 'Incorrect password. Please try again.';
      case 'invalid-email':           return 'Enter a valid email address.';
      case 'weak-password':           return 'Password is too weak (min 6 characters).';
      case 'requires-recent-login':   return 'Please log out and log in again before changing your password.';
      case 'invalid-credential':      return 'Incorrect email or password.';
      default:                        return 'Something went wrong ($code). Please try again.';
    }
  }
}

// ── Firestore helpers
class _Db {
  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static String get uid => FirebaseAuth.instance.currentUser!.uid;

  static DocumentReference get _userDoc => db.collection('users').doc(uid);

  // ── prefs
  static Future<void> savePrefs(Map<String, dynamic> data) =>
      _userDoc.set({'prefs': data}, SetOptions(merge: true));

  static Future<Map<String, dynamic>> loadPrefs() async {
    final snap = await _userDoc.get();
    if (!snap.exists) return {};
    final d = snap.data() as Map<String, dynamic>?;
    return (d?['prefs'] as Map<String, dynamic>?) ?? {};
  }

  // ── tasks
  static CollectionReference get _tasks => _userDoc.collection('tasks');

  static Future<void> saveTask(Map<String, dynamic> data) =>
      _tasks.doc(data['id'] as String).set(data);

  static Future<void> deleteTask(String id) => _tasks.doc(id).delete();

  static Future<List<Map<String, dynamic>>> loadTasks() async {
    final snap = await _tasks.get();
    return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
  }

  // ── study subjects
  static CollectionReference get _studySubjects => _userDoc.collection('study_subjects');

  static Future<void> saveStudySubject(Map<String, dynamic> data) =>
      _studySubjects.doc(data['name'] as String).set(data);

  static Future<void> deleteStudySubject(String name) => _studySubjects.doc(name).delete();

  static Future<List<Map<String, dynamic>>> loadStudySubjects() async {
    final snap = await _studySubjects.get();
    return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
  }

  // ── syllabus subjects
  static CollectionReference get _syllabusSubjects => _userDoc.collection('syllabus_subjects');

  static Future<void> saveSyllabusSubject(String id, Map<String, dynamic> data) =>
      _syllabusSubjects.doc(id).set(data);

  static Future<void> deleteSyllabusSubject(String id) => _syllabusSubjects.doc(id).delete();

  static Future<List<Map<String, dynamic>>> loadSyllabusSubjects() async {
    final snap = await _syllabusSubjects.get();
    return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
  }

  // ── calendar events
  static CollectionReference get _calendarEvents => _userDoc.collection('calendar_events');

  static Future<void> saveCalendarEvent(String key, Map<String, dynamic> data) =>
      _calendarEvents.doc(key).set(data);

  static Future<void> deleteCalendarEvent(String key) => _calendarEvents.doc(key).delete();

  static Future<List<Map<String, dynamic>>> loadCalendarEvents() async {
    final snap = await _calendarEvents.get();
    return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── LOGIN SCREEN ────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // ── Controllers
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool _isSignUp      = false;
  bool _obscure       = true;
  String? _error;

  // ── Subtle fade-in animation for the form
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final email    = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final svc      = _AuthService.instance;
    final err      = _isSignUp
        ? await svc.signUp(email, password)
        : await svc.signIn(email, password);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    // Navigation is handled reactively by StreamBuilder in CeladonApp
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFF2C1206),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen background image
          Image.asset(
            'assets/main_screen.png',
            fit: isWide ? BoxFit.cover : BoxFit.contain,
            alignment: Alignment.center,
          ),

          // ── Login form in the empty center/bottom area of the illustration
          FadeTransition(
            opacity: _fade,
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: size.height * 0.38,
                    left: isWide ? size.width * 0.10 : size.width * 0.08,
                    right: isWide ? size.width * 0.10 : size.width * 0.08,
                    bottom: size.height * 0.16,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: _LoginForm(
                      formKey: _formKey,
                      emailCtrl: _emailCtrl,
                      passCtrl: _passCtrl,
                      isSignUp: _isSignUp,
                      obscure: _obscure,
                      error: _error,
                      onToggleMode: () => setState(() => _isSignUp = !_isSignUp),
                      onToggleObscure: () => setState(() => _obscure = !_obscure),
                      onSubmit: _submit,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Notebook cover panel
class _NotebookCoverPanel extends StatelessWidget {
  final Animation<double> claspPulse;
  final bool coverOpen;
  final VoidCallback? onTap;
  const _NotebookCoverPanel({required this.claspPulse, required this.coverOpen, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF5C2E0A), Color(0xFF3B1E08), Color(0xFF4A2510), Color(0xFF2E1506)],
            ),
          ),
        child: Stack(
          children: [
            // Embossed border frame
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: const Color(0xFFD4A84B).withAlpha(80), width: 1),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: const Color(0xFFD4A84B).withAlpha(40), width: 0.5),
                  ),
                ),
              ),
            ),

            // Title block
            Positioned(
              top: 60, left: 0, right: 0,
              child: Column(
                children: [
                  // Decorative line
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        Expanded(child: Container(height: 0.5, color: const Color(0xFFD4A84B).withAlpha(100))),
                        const SizedBox(width: 10),
                        Icon(Icons.auto_stories_rounded, size: 14, color: const Color(0xFFD4A84B).withAlpha(180)),
                        const SizedBox(width: 10),
                        Expanded(child: Container(height: 0.5, color: const Color(0xFFD4A84B).withAlpha(100))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'CELADON',
                    style: TextStyle(
                      fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w700,
                      color: const Color(0xFFD4A84B).withAlpha(230),
                      shadows: [Shadow(color: Colors.black.withAlpha(120), blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Study Companion',
                    style: TextStyle(
                      fontSize: 11, letterSpacing: 3,
                      color: const Color(0xFFD4A84B).withAlpha(140),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        Expanded(child: Container(height: 0.5, color: const Color(0xFFD4A84B).withAlpha(100))),
                        const SizedBox(width: 10),
                        Icon(Icons.stars_rounded, size: 10, color: const Color(0xFFD4A84B).withAlpha(180)),
                        const SizedBox(width: 10),
                        Expanded(child: Container(height: 0.5, color: const Color(0xFFD4A84B).withAlpha(100))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Pen/pencil illustration (simple)
            Positioned(
              bottom: 90, left: 0, right: 0,
              child: CustomPaint(painter: _PenIllustrationPainter(), child: const SizedBox(height: 60)),
            ),

            // Open me hint
            if (!coverOpen)
              Positioned(
                bottom: 36, left: 0, right: 0,
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: claspPulse,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD4A84B).withAlpha(180)),
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFFD4A84B).withAlpha(18),
                        ),
                        child: const Text(
                          '✦  Open  ✦',
                          style: TextStyle(
                            fontSize: 11, letterSpacing: 3,
                            color: Color(0xFFD4A84B),
                          ),
                        ),
                      ),
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

// ── Login form (notebook page interior)
class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool isSignUp;
  final bool obscure;
  final String? error;
  final VoidCallback onToggleMode;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  const _LoginForm({
    required this.formKey, required this.emailCtrl, required this.passCtrl,
    required this.isSignUp, required this.obscure, this.error,
    required this.onToggleMode, required this.onToggleObscure, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3E9).withAlpha(230),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 24, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: const Color(0xFFD4A84B).withAlpha(80), width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        isSignUp ? 'New Entry' : 'Welcome Back',
                        style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w700,
                          color: CeladonColors.inkBrown,
                        ),
                      ),
                      Text(
                        isSignUp ? 'Create your account' : 'Sign in to continue',
                        style: const TextStyle(fontSize: 12, color: CeladonColors.mutedSage),
                      ),
                      const SizedBox(height: 32),

                      // Email
                      _NotebookField(
                        controller: emailCtrl,
                        label: 'Email',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      _NotebookField(
                        controller: passCtrl,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: obscure,
                        suffix: GestureDetector(
                          onTap: onToggleObscure,
                          child: Icon(
                            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 16, color: CeladonColors.mutedSage,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password required';
                          if (v.length <= 5) return 'Must be more than 5 characters';
                          return null;
                        },
                      ),

                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE8E8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD96060).withAlpha(80)),
                          ),
                          child: Text(error!, style: const TextStyle(fontSize: 11, color: Color(0xFFD96060))),
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: onSubmit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: CeladonColors.inkBrown,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: CeladonColors.inkBrown.withAlpha(80), blurRadius: 8, offset: const Offset(0, 3))],
                            ),
                            child: Center(
                              child: Text(
                                isSignUp ? 'Create Account →' : 'Open My Journal →',
                                style: const TextStyle(fontSize: 14, color: CeladonColors.cream, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Toggle login/signup
                      Center(
                        child: GestureDetector(
                          onTap: onToggleMode,
                          child: Text.rich(
                            TextSpan(
                              text: isSignUp ? 'Already have an account? ' : 'New here? ',
                              style: const TextStyle(fontSize: 11, color: CeladonColors.mutedSage),
                              children: [
                                TextSpan(
                                  text: isSignUp ? 'Sign in' : 'Sign up',
                                  style: const TextStyle(color: CeladonColors.sage, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// Helper widget to avoid passing painters into const context
class _SpiralHolesWidget extends StatelessWidget {
  const _SpiralHolesWidget();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _SpiralHolesPainter());
}

// ── Notebook input field
class _NotebookField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _NotebookField({
    required this.controller, required this.label, required this.icon,
    this.obscure = false, this.keyboardType, this.suffix, this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 13, color: CeladonColors.inkBrown),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: CeladonColors.mutedSage),
        prefixIcon: Icon(icon, size: 16, color: CeladonColors.mutedSage),
        suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 8), child: suffix) : null,
        filled: true,
        fillColor: CeladonColors.cream,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CeladonColors.ruleLine)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CeladonColors.ruleLine)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CeladonColors.inkBrown, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD96060))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD96060), width: 1.5)),
        errorStyle: const TextStyle(fontSize: 9, color: Color(0xFFD96060)),
      ),
    );
  }
}

// ── Welcome overlay + page-flip route
class _WelcomeOverlay extends StatefulWidget {
  final String userName;
  final Widget destination;
  const _WelcomeOverlay({required this.userName, required this.destination});
  @override
  State<_WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends State<_WelcomeOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;
  bool _showMain = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _fade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4)));
    _slide = Tween<double>(begin: 30, end: 0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _ctrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showMain = true);
      });
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_showMain) return widget.destination;
    return Scaffold(
      backgroundColor: CeladonColors.cream,
      body: NotebookBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _slide.value),
              child: Opacity(
                opacity: _fade.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✦', style: TextStyle(fontSize: 28, color: CeladonColors.terracotta)),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome back,',
                      style: const TextStyle(fontSize: 14, color: CeladonColors.mutedSage, letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.userName,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: CeladonColors.inkBrown),
                    ),
                    const SizedBox(height: 16),
                    const Text('Your journal is ready 📖', style: TextStyle(fontSize: 12, color: CeladonColors.mutedSage)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Page flip route (3-D Y-axis flip transition)
class _PageFlipRoute extends PageRouteBuilder {
  final Widget page;
  final String userName;

  _PageFlipRoute({required this.page, required this.userName})
      : super(
          transitionDuration: const Duration(milliseconds: 900),
          reverseTransitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) =>
              _WelcomeOverlay(userName: userName, destination: page),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final flip = Tween<double>(begin: math.pi / 2, end: 0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            return AnimatedBuilder(
              animation: flip,
              builder: (_, c) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(flip.value),
                child: c,
              ),
              child: child,
            );
          },
        );
}

// ── CustomPainters ───────────────────────────────────────────────────────────

class _LeatherTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..color = Colors.white.withAlpha(4);
    for (int i = 0; i < 400; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final w = rng.nextDouble() * 60 + 10;
      canvas.drawLine(Offset(x, y), Offset(x + w, y + rng.nextDouble() * 4 - 2), paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _FaintLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4A84B).withAlpha(12)
      ..strokeWidth = 0.5;
    for (double y = 40; y < size.height; y += 24) {
      canvas.drawLine(Offset(40, y), Offset(size.width - 40, y), paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _RuledPagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CeladonColors.ruleLine
      ..strokeWidth = 0.7;
    for (double y = 32; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _SpiralHolesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFE8E0D0);
    final ring = Paint()..color = const Color(0xFFB8A898)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (double y = 30; y < size.height; y += 40) {
      canvas.drawCircle(Offset(12, y), 6, bg);
      canvas.drawCircle(Offset(12, y), 6, ring);
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _PenIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()..color = const Color(0xFFD4A84B).withAlpha(140)..strokeWidth = 2..style = PaintingStyle.stroke;
    final goldFill = Paint()..color = const Color(0xFFD4A84B).withAlpha(80);
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Pen body
    final path = Path()
      ..moveTo(cx - 60, cy - 4)
      ..lineTo(cx + 50, cy - 4)
      ..lineTo(cx + 50, cy + 4)
      ..lineTo(cx - 60, cy + 4)
      ..close();
    canvas.drawPath(path, goldFill);
    canvas.drawPath(path, gold);
    // Nib
    final nib = Path()
      ..moveTo(cx + 50, cy - 4)
      ..lineTo(cx + 70, cy)
      ..lineTo(cx + 50, cy + 4)
      ..close();
    canvas.drawPath(nib, goldFill);
    canvas.drawPath(nib, gold);
    // Clip ring
    canvas.drawRect(Rect.fromLTWH(cx - 62, cy - 7, 8, 14), goldFill);
    canvas.drawRect(Rect.fromLTWH(cx - 62, cy - 7, 8, 14), gold);
  }
  @override bool shouldRepaint(_) => false;
}

class _DustMote {
  final double x;
  final double yBase;
  final double size;
  final double speed;
  final double phase;
  _DustMote(int seed)
      : x     = (seed * 137.5 % 1.0),
        yBase  = (seed * 91.3  % 1.0),
        size   = (seed * 53.7  % 0.8) + 0.8,
        speed  = (seed * 37.1  % 0.6) + 0.4,
        phase  = (seed * 73.9  % 1.0);
}

class _DustPainter extends CustomPainter {
  final List<_DustMote> motes;
  final double t;
  _DustPainter(this.motes, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFD4A84B).withAlpha(40);
    for (final m in motes) {
      final y = ((m.yBase + t * m.speed + m.phase) % 1.0) * size.height;
      final x = m.x * size.width + math.sin(t * 2 * math.pi + m.phase * 6) * 20;
      canvas.drawCircle(Offset(x, y), m.size, paint);
    }
  }
  @override bool shouldRepaint(_DustPainter old) => old.t != t;
}

class _CornerEmboss extends StatelessWidget {
  final bool flip;
  final bool bottom;
  const _CornerEmboss({this.flip = false, this.bottom = false});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flip ? -1 : 1,
      scaleY: bottom ? -1 : 1,
      child: SizedBox(
        width: 32, height: 32,
        child: CustomPaint(painter: _CornerPainter()),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFD4A84B).withAlpha(160)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 12), const Offset(0, 0), p);
    canvas.drawLine(const Offset(0, 0), const Offset(12, 0), p);
    canvas.drawLine(const Offset(4, 18), const Offset(4, 4), p);
    canvas.drawLine(const Offset(4, 4), const Offset(18, 4), p);
  }
  @override bool shouldRepaint(_) => false;
}

// ─── APP STATE (profile, theme) ─────────────────────────────────────────────────────────

class _AppState extends ChangeNotifier {
  _AppState._();
  static final instance = _AppState._();

  String userEmail = '';
  Uint8List? profileBytes;  // local bytes for display; no remote storage on free plan
  bool darkMode = false;

  void setEmail(String e) { userEmail = e; notifyListeners(); }
  void setProfile(Uint8List? b) { profileBytes = b; notifyListeners(); }

  void toggleDark() {
    darkMode = !darkMode;
    notifyListeners();
    // Persist to Firestore (fire-and-forget)
    if (userEmail.isNotEmpty) {
      _Db.savePrefs({'darkMode': darkMode}).catchError((_) {});
    }
  }

  Future<void> loadPrefs() async {
    try {
      final prefs = await _Db.loadPrefs();
      darkMode = (prefs['darkMode'] as bool?) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  void logout() {
    userEmail    = '';
    profileBytes = null;
    darkMode     = false;
    notifyListeners();
    _AuthService.instance.logout();
  }
}

// ─── APP ROOT ────────────────────────────────────────────────────────────────

class CeladonApp extends StatefulWidget {
  const CeladonApp({super.key});
  @override
  State<CeladonApp> createState() => _CeladonAppState();
}

class _CeladonAppState extends State<CeladonApp> {
  final _appState = _AppState.instance;
  late final StreamSubscription<User?> _authSub;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onStateChange);
    // Listen for Firebase auth state — handles auto-login and logout
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _appState.setEmail(user.email ?? '');
        _appState.loadPrefs();  // load dark mode pref from Firestore
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    _appState.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() => setState(() {});

  ThemeData _buildTheme(bool dark) {
    return ThemeData(
      fontFamily: 'Georgia',
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: dark ? const Color(0xFF1E1A14) : CeladonColors.cream,
      colorScheme: dark
          ? const ColorScheme.dark(
              primary: CeladonColors.sage,
              secondary: CeladonColors.terracotta,
              surface: Color(0xFF2A2318),
            )
          : const ColorScheme.light(
              primary: CeladonColors.sage,
              secondary: CeladonColors.terracotta,
              surface: CeladonColors.pageWhite,
            ),
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = _appState.darkMode;

    return MaterialApp(
      title: 'Celadon',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(false),
      darkTheme: _buildTheme(true),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      // StreamBuilder reacts to login/logout in real-time
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: CeladonColors.cream,
              body: Center(child: CircularProgressIndicator(color: CeladonColors.sage)),
            );
          }
          final user = snap.data;
          if (user != null) {
            // Keep AppState in sync with current user
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_appState.userEmail.isEmpty) {
                _appState.setEmail(user.email ?? '');
                _appState.loadPrefs();
              }
            });
            return _CalendarStateProvider(child: const MainShell());
          }
          return const LoginScreen();
        },
      ),
      onGenerateRoute: (settings) {
        if (settings.name == '/main') {
          final email = settings.arguments as String? ?? '';
          _appState.setEmail(email);
          return _PageFlipRoute(
            page: _CalendarStateProvider(child: const MainShell()),
            userName: email.split('@').first,
          );
        }
        return null;
      },
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
  void initState() {
    super.initState();
    // Load calendar events from Firestore for the current user
    _state.loadFromFirestore();
  }

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
      const StudyScreen(),
      const SyllabusScreen(),
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
      (Icons.menu_book_rounded, 'Study'),
      (Icons.route_rounded, 'Roadmap'),
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
                Pressable(
                  hoverScale: 1.08,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: currentIndex == i ? CeladonColors.sageLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1.0, end: currentIndex == i ? 1.18 : 1.0),
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutBack,
                          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                          child: Icon(items[i].$1,
                              color: currentIndex == i ? CeladonColors.sage : CeladonColors.mutedSage,
                              size: 22),
                        ),
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

class MiniCalendarWidget extends StatefulWidget {
  final List<Task> todayTasks;
  const MiniCalendarWidget({super.key, this.todayTasks = const []});

  @override
  State<MiniCalendarWidget> createState() => _MiniCalendarWidgetState();
}

class _MiniCalendarWidgetState extends State<MiniCalendarWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _tiltCtrl;
  late final Animation<double> _tilt;

  static const _restAngle = -0.06; // subtle tilt — like placed on a desk
  static const _pressAngle = -0.01; // nearly straightens when pressed

  @override
  void initState() {
    super.initState();
    _tiltCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _tilt = Tween<double>(begin: _restAngle, end: _pressAngle)
        .animate(CurvedAnimation(parent: _tiltCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _tiltCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calState = CalendarStateInherited.of(context);
    final now = DateTime.now();
    final todayEvent = calState.eventFor(now);

    return GestureDetector(
      onTapDown: (_) => _tiltCtrl.forward(),
      onTapUp: (_) => _tiltCtrl.reverse(),
      onTapCancel: () => _tiltCtrl.reverse(),
      onTap: () => _openFullCalendar(context),
      child: AnimatedBuilder(
        animation: _tilt,
        builder: (context, child) => Transform.rotate(angle: _tilt.value, child: child),
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
                        else if (widget.todayTasks.isNotEmpty)
                          Text(
                            '${widget.todayTasks.length} tasks',
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

                return _MiniDayCell(
                  dayNum: dayNum,
                  isToday: isToday,
                  event: event,
                );
              }),
            );
          });
        }(),
      ],
    );
  }
}

// ── Mini calendar day cell with hover glow
class _MiniDayCell extends StatefulWidget {
  final int dayNum;
  final bool isToday;
  final DayEvent? event;
  const _MiniDayCell({required this.dayNum, required this.isToday, required this.event});

  @override
  State<_MiniDayCell> createState() => _MiniDayCellState();
}

class _MiniDayCellState extends State<_MiniDayCell> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 1.45)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) { setState(() => _hovered = true); _ctrl.forward(); },
      onExit:  (_) { setState(() => _hovered = false); _ctrl.reverse(); },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: SizedBox(
          width: 13,
          height: 13,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isToday)
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: _hovered ? Colors.white : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: _hovered
                          ? [BoxShadow(color: Colors.white.withAlpha(160), blurRadius: 6)]
                          : null,
                    ),
                  )
                else if (widget.event != null)
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: widget.event!.color.withAlpha(_hovered ? 230 : 180),
                      shape: BoxShape.circle,
                      boxShadow: _hovered
                          ? [BoxShadow(color: widget.event!.color.withAlpha(140), blurRadius: 5)]
                          : null,
                    ),
                  )
                else if (_hovered)
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  '${widget.dayNum}',
                  style: TextStyle(
                    fontSize: 6.5,
                    fontWeight: widget.isToday ? FontWeight.w800 : FontWeight.w400,
                    color: widget.isToday
                        ? const Color(0xFF4A2E14)
                        : widget.event != null
                            ? Colors.white
                            : CeladonColors.calCream,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

              return Pressable(
                hoverScale: 1.15,
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
    return Pressable(
      onTap: onTap,
      hoverScale: 1.06,
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
          // Profile avatar — top right
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _ProfileAvatar(),
          ),
        ],
      ),
    );
  }
}

// ── Profile Avatar button
class _ProfileAvatar extends StatefulWidget {
  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  final _appState = _AppState.instance;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_rebuild);
  }

  @override
  void dispose() {
    _appState.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final bytes   = _appState.profileBytes;
    final initial = _appState.userEmail.isNotEmpty
        ? _appState.userEmail[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () => _ProfileSheet.show(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CeladonColors.terracottaLight,
            border: Border.all(color: CeladonColors.terracotta.withAlpha(120), width: 2),
            image: bytes != null
                ? DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover)
                : null,
            boxShadow: [BoxShadow(color: CeladonColors.softShadow, blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: bytes == null
              ? Center(child: Text(initial, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CeladonColors.terracotta)))
              : null,
        ),
      ),
    );
  }
}

// ── Profile / Settings sheet
class _ProfileSheet {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ProfileSheetContent(),
    );
  }
}

class _ProfileSheetContent extends StatefulWidget {
  const _ProfileSheetContent();
  @override
  State<_ProfileSheetContent> createState() => _ProfileSheetContentState();
}

class _ProfileSheetContentState extends State<_ProfileSheetContent> {
  final _appState = _AppState.instance;
  bool _resetting = false;
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _resetError;
  String? _resetSuccess;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.first.bytes != null) {
      _appState.setProfile(result.files.first.bytes);
      if (mounted) setState(() {});
    }
  }

  void _doResetPassword() async {
    final np = _newPassCtrl.text;
    final cp = _confirmCtrl.text;
    setState(() { _resetError = null; _resetSuccess = null; });
    if (np.length <= 5) { setState(() => _resetError = 'Password must be more than 5 characters'); return; }
    if (np != cp)       { setState(() => _resetError = 'Passwords do not match'); return; }
    final err = await _AuthService.instance.resetPassword(np);
    if (!mounted) return;
    if (err != null) { setState(() => _resetError = err); return; }
    setState(() { _resetSuccess = 'Password updated ✔'; _resetting = false; });
    _newPassCtrl.clear(); _confirmCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final dark    = _appState.darkMode;
    final bytes   = _appState.profileBytes;
    final email   = _appState.userEmail;
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final name    = email.split('@').first;

    final bg   = dark ? const Color(0xFF2A2318) : CeladonColors.pageWhite;
    final fg   = dark ? CeladonColors.cream : CeladonColors.inkBrown;
    final rule = dark ? const Color(0xFF3A3020) : CeladonColors.ruleLine;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: CeladonColors.softShadow, blurRadius: 20)],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(width: 36, height: 4, decoration: BoxDecoration(color: rule, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          // Avatar + name
          GestureDetector(
            onTap: _pickProfileImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CeladonColors.terracottaLight,
                    border: Border.all(color: CeladonColors.terracotta.withAlpha(140), width: 2.5),
                    image: bytes != null
                        ? DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover)
                        : null,
                  ),
                  child: bytes == null
                      ? Center(child: Text(initial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: CeladonColors.terracotta)))
                      : null,
                ),
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: CeladonColors.sage,
                    shape: BoxShape.circle,
                    border: Border.all(color: bg, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg)),
          Text(email, style: const TextStyle(fontSize: 11, color: CeladonColors.mutedSage)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickProfileImage,
            child: Text('Tap avatar to change photo', style: TextStyle(fontSize: 10, color: CeladonColors.sage.withAlpha(180))),
          ),
          const SizedBox(height: 20),

          Divider(color: rule, height: 1),
          const SizedBox(height: 8),

          // ── Reset password (expandable)
          _SheetTile(
            icon: Icons.lock_reset_rounded,
            label: 'Reset Password',
            color: CeladonColors.terracotta,
            fg: fg,
            trailing: Icon(_resetting ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: CeladonColors.mutedSage),
            onTap: () => setState(() { _resetting = !_resetting; _resetError = null; _resetSuccess = null; }),
          ),

          if (_resetting) ...[
            const SizedBox(height: 10),
            _MiniField(controller: _newPassCtrl, label: 'New password', obscure: true),
            const SizedBox(height: 8),
            _MiniField(controller: _confirmCtrl, label: 'Confirm password', obscure: true),
            if (_resetError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_resetError!, style: const TextStyle(fontSize: 10, color: Color(0xFFD96060))),
              ),
            if (_resetSuccess != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_resetSuccess!, style: TextStyle(fontSize: 10, color: CeladonColors.sage)),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _doResetPassword,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: CeladonColors.inkBrown,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: Text('Update Password', style: TextStyle(fontSize: 12, color: CeladonColors.cream, fontWeight: FontWeight.w700))),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          Divider(color: rule, height: 1),

          // ── Theme toggle
          _SheetTile(
            icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            label: dark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
            color: CeladonColors.sage,
            fg: fg,
            trailing: Switch(
              value: dark,
              activeThumbColor: CeladonColors.sage,
              onChanged: (_) { _appState.toggleDark(); setState(() {}); },
            ),
            onTap: () { _appState.toggleDark(); setState(() {}); },
          ),

          Divider(color: rule, height: 1),

          // ── Contact support
          _SheetTile(
            icon: Icons.support_agent_rounded,
            label: 'Contact Support',
            color: const Color(0xFF6A8FA0),
            fg: fg,
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Support: support@celadon.app'),
                  backgroundColor: CeladonColors.inkBrown,
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),

          Divider(color: rule, height: 1),

          _SheetTile(
            icon: Icons.logout_rounded,
            label: 'Log Out',
            color: const Color(0xFFD96060),
            fg: const Color(0xFFD96060),
            onTap: () async {
              Navigator.pop(context);
              _appState.logout();  // also calls FirebaseAuth.signOut()
              // authStateChanges in CeladonApp will rebuild to LoginScreen
            },
          ),
        ],
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color fg;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SheetTile({required this.icon, required this.label, required this.color, required this.fg, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 18, color: CeladonColors.mutedSage),
      onTap: onTap,
    );
  }
}

class _MiniField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  const _MiniField({required this.controller, required this.label, this.obscure = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 13, color: CeladonColors.inkBrown),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11, color: CeladonColors.mutedSage),
        filled: true, fillColor: CeladonColors.cream,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CeladonColors.ruleLine)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CeladonColors.ruleLine)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CeladonColors.sage, width: 1.5)),
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
  final List<Task> _tasks = [];
  bool _loading = true;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        final expired = _tasks.where((t) => t.isExpiredCompleted).map((t) => t.id).toList();
        for (final id in expired) {
          _Db.deleteTask(id).catchError((_) {});
        }
        setState(() => _tasks.removeWhere((t) => t.isExpiredCompleted));
      }
    });
  }

  Future<void> _loadTasks() async {
    try {
      final raw = await _Db.loadTasks();
      final tasks = raw.map(Task.fromFirestore).toList();
      // Remove expired tasks
      final expired = tasks.where((t) => t.isExpiredCompleted).map((t) => t.id).toList();
      for (final id in expired) { _Db.deleteTask(id).catchError((_) {}); }
      if (mounted) setState(() {
        _tasks
          ..clear()
          ..addAll(tasks.where((t) => !t.isExpiredCompleted));
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final task = _tasks[idx];
    final nowDone = !task.isDone;
    final updated = Task(
      id: task.id, title: task.title, subject: task.subject,
      isDone: nowDone, priority: task.priority, dueDate: task.dueDate,
      completedAt: nowDone ? DateTime.now() : null,
    );
    setState(() => _tasks[idx] = updated);
    _Db.saveTask(updated.toFirestore()).catchError((_) {});
  }

  void _deleteTask(String id) {
    setState(() => _tasks.removeWhere((t) => t.id == id));
    _Db.deleteTask(id).catchError((_) {});
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTaskSheet(
        onAdd: (title, subject, priority, dueDate) {
          final newTask = Task(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title, subject: subject,
            priority: priority, dueDate: dueDate,
          );
          setState(() => _tasks.add(newTask));
          _Db.saveTask(newTask.toFirestore()).catchError((_) {});
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: CeladonColors.cream,
        body: Center(child: CircularProgressIndicator(color: CeladonColors.sage)),
      );
    }
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
                              child: _AddButton(onTap: _showAddSheet),
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

class _CompactTaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _CompactTaskCard({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  State<_CompactTaskCard> createState() => _CompactTaskCardState();
}

class _CompactTaskCardState extends State<_CompactTaskCard> with SingleTickerProviderStateMixin {
  late final AnimationController _checkCtrl;
  late final Animation<double> _checkPop;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _checkPop = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 60),
    ]).animate(_checkCtrl);
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  void _handleToggle() {
    // Only pop when transitioning into "done" — undoing doesn't need the flourish
    if (!widget.task.isDone) _checkCtrl.forward(from: 0);
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return Dismissible(
      key: Key('cmp-${task.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFD96060),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 16),
      ),
      child: Pressable(
        hoverScale: 1.015,
        onTap: _handleToggle,
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
                child: AnimatedBuilder(
                  animation: _checkPop,
                  builder: (context, child) => Transform.scale(scale: _checkPop.value, child: child),
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
        // Rotating motivational quote — sits above the bear
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
        const SizedBox(height: 6),
        // Bear image — white background removed via ColorFilter multiply
        Expanded(
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              // R  G  B  A  offset
               1, 0, 0, 0, 0,
               0, 1, 0, 0, 0,
               0, 0, 1, 0, 0,
              -1,-1,-1, 1, 3, // alpha = 1 - average(rgb)  → white→transparent
            ]),
            child: Image.asset(
              'assets/bear.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
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
// ═══════════════════════════════════════════════════════════════════════════════
// ─── SCREEN 2: STUDY HOURS ───────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

/// A single subject entry with goal hours and actual studied hours.
class _SubjectStudy {
  final String name;
  final Color color;
  double goalHours;
  double actualHours;

  _SubjectStudy({
    required this.name,
    required this.color,
    this.goalHours = 1.0,
    this.actualHours = 0.0,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'colorValue': color.toARGB32(),
    'goalHours': goalHours,
    'actualHours': actualHours,
  };

  factory _SubjectStudy.fromMap(Map<String, dynamic> m) => _SubjectStudy(
    name: m['name'] as String,
    color: Color(m['colorValue'] as int),
    goalHours: (m['goalHours'] as num).toDouble(),
    actualHours: (m['actualHours'] as num).toDouble(),
  );
}

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  double _totalGoal = 6.0;
  double _totalActual = 0.0;
  bool _loading = true;

  final List<_SubjectStudy> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final results = await Future.wait([
        _Db.loadStudySubjects(),
        _Db.loadPrefs(),
      ]);
      final raw = results[0] as List<Map<String, dynamic>>;
      final prefs = results[1] as Map<String, dynamic>;
      if (mounted) setState(() {
        _subjects
          ..clear()
          ..addAll(raw.map(_SubjectStudy.fromMap));
        _totalGoal = (prefs['studyGoalHours'] as num?)?.toDouble() ?? 6.0;
        _syncTotalFromSubjects();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Derived ───────────────────────────────────────────────────────────────
  double get _subjectGoalSum => _subjects.fold(0.0, (s, e) => s + e.goalHours);
  double get _subjectActualSum => _subjects.fold(0.0, (s, e) => s + e.actualHours);
  double get _effectiveGoal => _totalGoal > 0 ? _totalGoal : 1;
  double get _progress => (_totalActual / _effectiveGoal).clamp(0.0, 2.0);

  // ── Motivational message based on progress ────────────────────────────────
  String get _motivationalMessage {
    final pct = _progress;
    if (pct >= 1.0) return '🌟 Amazing! You crushed your goal!';
    if (pct >= 0.75) return '💪 Almost there — keep pushing!';
    if (pct >= 0.50) return '📖 Halfway done — great progress!';
    if (pct >= 0.25) return '🌱 Good start — stay focused!';
    if (_totalActual > 0) return '☕ Every minute counts. Keep going!';
    return '✏️ Time to start studying!';
  }

  Color get _motivationalColor {
    final pct = _progress;
    if (pct >= 1.0) return const Color(0xFF4CAF50);
    if (pct >= 0.75) return CeladonColors.sage;
    if (pct >= 0.50) return const Color(0xFF6A8FA0);
    if (pct >= 0.25) return CeladonColors.terracotta;
    return CeladonColors.mutedSage;
  }

  String get _motivationalEmoji {
    final pct = _progress;
    if (pct >= 1.0) return '🎉';
    if (pct >= 0.75) return '🔥';
    if (pct >= 0.50) return '📚';
    if (pct >= 0.25) return '💡';
    return '⏰';
  }

  // ── Sync total from subjects ──────────────────────────────────────────────
  void _syncTotalFromSubjects() {
    setState(() {
      _totalActual = _subjectActualSum;
    });
  }

  // ── Editable number dialog ────────────────────────────────────────────────
  Future<double?> _editNumber(String label, double current) async {
    final ctrl = TextEditingController(text: current.toStringAsFixed(1));
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CeladonColors.pageWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CeladonColors.inkBrown)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(fontSize: 18, color: CeladonColors.inkBrown),
          decoration: InputDecoration(
            suffix: const Text('hrs', style: TextStyle(fontSize: 13, color: CeladonColors.mutedSage)),
            filled: true, fillColor: CeladonColors.cream,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CeladonColors.ruleLine)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CeladonColors.sage, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: CeladonColors.mutedSage))),
          TextButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? current;
              Navigator.pop(ctx, val.clamp(0.0, 24.0));
            },
            child: const Text('Save', style: TextStyle(color: CeladonColors.sage, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _totalActual = _subjectActualSum; // keep in sync
    final pctDisplay = (_progress * 100).round().clamp(0, 200);

    return Scaffold(
      backgroundColor: CeladonColors.cream,
      body: NotebookBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: ScreenHeader(
                  eyebrow: 'STUDY TRACKER',
                  title: 'Today\'s Hours',
                ),
              ),

              // ── Circular progress + total goal/actual ──────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: CeladonColors.pageWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: CeladonColors.calBrown.withAlpha(120)),
                      boxShadow: const [BoxShadow(color: CeladonColors.softShadow, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        // Ring
                        SizedBox(
                          width: 100, height: 100,
                          child: CustomPaint(
                            painter: _ProgressRingPainter(
                              progress: _progress.clamp(0.0, 1.0),
                              trackColor: CeladonColors.ruleLine,
                              fillColor: _motivationalColor,
                            ),
                            child: Center(
                              child: Text(
                                '$pctDisplay%',
                                style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800,
                                  color: _motivationalColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Goal
                              GestureDetector(
                                onTap: () async {
                                  final v = await _editNumber('Daily Study Goal', _totalGoal);
                                  if (v != null) {
                                    setState(() => _totalGoal = v);
                                    _Db.savePrefs({'studyGoalHours': v}).catchError((_) {});
                                  }
                                },
                                child: _HourRow(
                                  label: 'Goal',
                                  hours: _totalGoal,
                                  color: CeladonColors.inkBrown,
                                  icon: Icons.flag_rounded,
                                  editable: true,
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Actual
                              _HourRow(
                                label: 'Studied',
                                hours: _totalActual,
                                color: _motivationalColor,
                                icon: Icons.timer_rounded,
                                editable: false,
                              ),
                              const SizedBox(height: 14),
                              // Motivational message
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _motivationalColor.withAlpha(20),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _motivationalColor.withAlpha(60)),
                                ),
                                child: Row(
                                  children: [
                                    Text(_motivationalEmoji, style: const TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _motivationalMessage,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _motivationalColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Subject-wise header ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 20, 8),
                  child: Row(
                    children: [
                      const Text(
                        'BY SUBJECT',
                        style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: CeladonColors.mutedSage, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _addSubject,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: CeladonColors.sageLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 12, color: CeladonColors.sage),
                              SizedBox(width: 2),
                              Text('Add Subject', style: TextStyle(fontSize: 10, color: CeladonColors.sage, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Subject rows ────────────────────────────────────────────
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _StudySubjectRow(
                    study: _subjects[i],
                    onGoalTap: () async {
                      final v = await _editNumber('${_subjects[i].name} — Goal', _subjects[i].goalHours);
                      if (v != null) {
                        setState(() { _subjects[i].goalHours = v; _syncTotalFromSubjects(); });
                        _Db.saveStudySubject(_subjects[i].toMap()).catchError((_) {});
                      }
                    },
                    onActualTap: () async {
                      final v = await _editNumber('${_subjects[i].name} — Studied', _subjects[i].actualHours);
                      if (v != null) {
                        setState(() { _subjects[i].actualHours = v; _syncTotalFromSubjects(); });
                        _Db.saveStudySubject(_subjects[i].toMap()).catchError((_) {});
                      }
                    },
                    onDelete: () {
                      final name = _subjects[i].name;
                      setState(() { _subjects.removeAt(i); _syncTotalFromSubjects(); });
                      _Db.deleteStudySubject(name).catchError((_) {});
                    },
                  ),
                  childCount: _subjects.length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  void _addSubject() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CeladonColors.pageWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Subject', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CeladonColors.inkBrown)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(fontSize: 15, color: CeladonColors.inkBrown),
          decoration: InputDecoration(
            hintText: 'Subject name',
            hintStyle: const TextStyle(color: CeladonColors.mutedSage),
            filled: true, fillColor: CeladonColors.cream,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CeladonColors.ruleLine)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CeladonColors.sage, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: CeladonColors.mutedSage))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Add', style: TextStyle(color: CeladonColors.sage, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      const palette = [
        Color(0xFF7C9A7E), Color(0xFFD4956A), Color(0xFF6A8FA0),
        Color(0xFF9B8EA0), Color(0xFFA09B6A), Color(0xFFB07878),
      ];
      final newSubject = _SubjectStudy(
        name: name,
        color: palette[_subjects.length % palette.length],
      );
      setState(() => _subjects.add(newSubject));
      _Db.saveStudySubject(newSubject.toMap()).catchError((_) {});
    }
  }
}

// ─── HOUR ROW (total card) ───────────────────────────────────────────────────

class _HourRow extends StatelessWidget {
  final String label;
  final double hours;
  final Color color;
  final IconData icon;
  final bool editable;
  const _HourRow({required this.label, required this.hours, required this.color, required this.icon, this.editable = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(
          '${hours.toStringAsFixed(1)} hrs',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
        ),
        if (editable) ...[
          const SizedBox(width: 4),
          Icon(Icons.edit_rounded, size: 11, color: color.withAlpha(140)),
        ],
      ],
    );
  }
}

// ─── PROGRESS RING PAINTER ───────────────────────────────────────────────────

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;
  _ProgressRingPainter({required this.progress, required this.trackColor, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const strokeWidth = 8.0;

    // Track
    canvas.drawCircle(
      center, radius,
      Paint()..color = trackColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round,
    );

    // Fill arc
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, sweepAngle,
      false,
      Paint()..color = fillColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.progress != progress || old.fillColor != fillColor;
}

// ─── STUDY SUBJECT ROW ───────────────────────────────────────────────────────

class _StudySubjectRow extends StatelessWidget {
  final _SubjectStudy study;
  final VoidCallback onGoalTap;
  final VoidCallback onActualTap;
  final VoidCallback onDelete;
  const _StudySubjectRow({required this.study, required this.onGoalTap, required this.onActualTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final pct = study.goalHours > 0 ? (study.actualHours / study.goalHours).clamp(0.0, 1.0) : 0.0;
    final metGoal = study.actualHours >= study.goalHours && study.goalHours > 0;

    return Dismissible(
      key: Key('study-${study.name}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFD96060),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CeladonColors.pageWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: metGoal ? study.color.withAlpha(120) : CeladonColors.ruleLine),
          boxShadow: const [BoxShadow(color: CeladonColors.softShadow, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + badge
            Row(
              children: [
                Container(
                  width: 4, height: 18,
                  decoration: BoxDecoration(color: study.color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    study.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CeladonColors.inkBrown),
                  ),
                ),
                if (metGoal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('✓ Done', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF4CAF50))),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: CeladonColors.ruleLine,
                valueColor: AlwaysStoppedAnimation(study.color),
              ),
            ),
            const SizedBox(height: 10),
            // Goal / Actual tappable row
            Row(
              children: [
                GestureDetector(
                  onTap: onGoalTap,
                  child: _SubjectHourChip(label: 'Goal', hours: study.goalHours, color: CeladonColors.mutedSage),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onActualTap,
                  child: _SubjectHourChip(label: 'Studied', hours: study.actualHours, color: study.color),
                ),
                const Spacer(),
                Text(
                  '${(pct * 100).round()}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: study.color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectHourChip extends StatelessWidget {
  final String label;
  final double hours;
  final Color color;
  const _SubjectHourChip({required this.label, required this.hours, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 10, color: color)),
          Text('${hours.toStringAsFixed(1)}h', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 2),
          Icon(Icons.edit_rounded, size: 9, color: color.withAlpha(120)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─── SCREEN 3: SYLLABUS ROADMAP ──────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

// Uses geminiApiKey from secrets.dart (gitignored)

/// A chapter/topic extracted from a syllabus.
class _SyllabusChapter {
  final String title;
  final String description;
  bool isDone;
  int assignedDay; // 1-based day number in the plan

  _SyllabusChapter({
    required this.title,
    this.description = '',
    this.isDone = false,
    this.assignedDay = 1,
  });
}

/// A subject with its parsed syllabus and roadmap.
class _SyllabusSubject {
  final String name;
  final Color color;
  final int totalDays;
  final List<_SyllabusChapter> chapters;
  final DateTime createdAt;

  _SyllabusSubject({
    required this.name,
    required this.color,
    required this.totalDays,
    required this.chapters,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get completedCount => chapters.where((c) => c.isDone).length;
  double get progress => chapters.isEmpty ? 0 : completedCount / chapters.length;
  int get currentDay {
    final elapsed = DateTime.now().difference(createdAt).inDays + 1;
    return elapsed.clamp(1, totalDays);
  }
}

class SyllabusScreen extends StatefulWidget {
  const SyllabusScreen({super.key});

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends State<SyllabusScreen> {
  final List<_SyllabusSubject> _subjects = [];
  bool _isLoading = false;
  String? _error;

  // ── Pick file & parse with Gemini ───────────────────────────────────────
  Future<void> _addSyllabus() async {
    // 1. Get subject name and days
    final meta = await _showMetaDialog();
    if (meta == null) return;
    final subjectName = meta.$1;
    final days = meta.$2;

    // 2. Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() { _isLoading = true; _error = null; });

    try {
      // 3. Call Gemini
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: geminiApiKey,
      );

      final prompt = '''
You are a syllabus parser. Analyze the uploaded document and extract ALL chapters/topics/units from it.

Return ONLY a valid JSON array, nothing else. Each element should be:
{"title": "Chapter/Topic name", "description": "Brief 1-line summary of what this covers"}

Rules:
- Extract every distinct chapter, unit, or major topic
- Keep titles concise but descriptive
- Order them in the logical study sequence
- If you can't parse the document, return: [{"title": "Could not parse", "description": "Please try a clearer image or PDF"}]

Return ONLY the JSON array, no markdown, no explanation.
''';

      final mimeType = file.extension == 'pdf' ? 'application/pdf' : 'image/${file.extension}';
      final response = await model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, file.bytes!),
        ]),
      ]);

      final text = response.text ?? '';
      // Extract JSON from response (handle markdown code blocks)
      var jsonStr = text.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceAll(RegExp(r'^```[a-z]*\n?', multiLine: true), '').replaceAll('```', '').trim();
      }

      final List<dynamic> parsed = json.decode(jsonStr);
      final chapters = <_SyllabusChapter>[];
      for (int i = 0; i < parsed.length; i++) {
        final ch = parsed[i];
        final dayAssignment = days > 0 ? ((i * days) ~/ parsed.length) + 1 : 1;
        chapters.add(_SyllabusChapter(
          title: ch['title'] ?? 'Topic ${i + 1}',
          description: ch['description'] ?? '',
          assignedDay: dayAssignment.clamp(1, days),
        ));
      }

      const palette = [
        Color(0xFF7C9A7E), Color(0xFFD4956A), Color(0xFF6A8FA0),
        Color(0xFF9B8EA0), Color(0xFFA09B6A), Color(0xFFB07878),
        Color(0xFF8B7EC7), Color(0xFF5D9B9B),
      ];

      setState(() {
        _subjects.add(_SyllabusSubject(
          name: subjectName,
          color: palette[_subjects.length % palette.length],
          totalDays: days,
          chapters: chapters,
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to parse: ${e.toString().length > 80 ? '${e.toString().substring(0, 80)}...' : e}';
      });
    }
  }

  // ── Meta dialog (subject name + days) ───────────────────────────────
  Future<(String, int)?> _showMetaDialog() async {
    final nameCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '30');
    return showDialog<(String, int)>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CeladonColors.pageWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Syllabus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CeladonColors.inkBrown)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 14, color: CeladonColors.inkBrown),
              decoration: InputDecoration(
                labelText: 'Subject Name',
                labelStyle: const TextStyle(color: CeladonColors.mutedSage, fontSize: 13),
                filled: true, fillColor: CeladonColors.cream,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CeladonColors.ruleLine)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CeladonColors.sage, width: 1.5)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: daysCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 14, color: CeladonColors.inkBrown),
              decoration: InputDecoration(
                labelText: 'Days to finish',
                labelStyle: const TextStyle(color: CeladonColors.mutedSage, fontSize: 13),
                suffix: const Text('days', style: TextStyle(fontSize: 12, color: CeladonColors.mutedSage)),
                filled: true, fillColor: CeladonColors.cream,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CeladonColors.ruleLine)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CeladonColors.sage, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: CeladonColors.mutedSage))),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final days = int.tryParse(daysCtrl.text) ?? 30;
              if (name.isEmpty) return;
              Navigator.pop(ctx, (name, days.clamp(1, 365)));
            },
            child: const Text('Pick File →', style: TextStyle(color: CeladonColors.sage, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CeladonColors.cream,
      body: NotebookBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Header
              SliverToBoxAdapter(
                child: ScreenHeader(
                  eyebrow: 'SYLLABUS',
                  title: 'Roadmap',
                ),
              ),

              // ── Error banner
              if (_error != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD96060).withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFD96060)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(fontSize: 11, color: Color(0xFFD96060)))),
                        GestureDetector(
                          onTap: () => setState(() => _error = null),
                          child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFD96060)),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Loading
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: CeladonColors.sage)),
                          SizedBox(height: 12),
                          Text('AI is reading your syllabus...', style: TextStyle(fontSize: 12, color: CeladonColors.mutedSage, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Empty state
              if (_subjects.isEmpty && !_isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                    child: Column(
                      children: [
                        Icon(Icons.auto_stories_rounded, size: 52, color: CeladonColors.mutedSage.withAlpha(120)),
                        const SizedBox(height: 16),
                        const Text(
                          'No syllabi yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CeladonColors.inkBrown),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Upload a syllabus PDF or image and\nAI will generate your study roadmap',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: CeladonColors.mutedSage, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _isLoading ? null : _addSyllabus,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: CeladonColors.sage,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: CeladonColors.sage.withAlpha(60), blurRadius: 8, offset: const Offset(0, 3))],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Upload Syllabus', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Subject roadmap cards
              if (_subjects.isNotEmpty) ...[
                // Add button row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 24, 8),
                    child: Row(
                      children: [
                        Text(
                          '${_subjects.length} SUBJECT${_subjects.length > 1 ? 'S' : ''}',
                          style: const TextStyle(fontSize: 10, letterSpacing: 1.5, color: CeladonColors.mutedSage, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _isLoading ? null : _addSyllabus,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: CeladonColors.sageLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, size: 12, color: CeladonColors.sage),
                                SizedBox(width: 3),
                                Text('Add Syllabus', style: TextStyle(fontSize: 10, color: CeladonColors.sage, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Subject cards
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _SyllabusCard(
                      subject: _subjects[i],
                      onToggleChapter: (chIdx) {
                        setState(() => _subjects[i].chapters[chIdx].isDone = !_subjects[i].chapters[chIdx].isDone);
                      },
                      onDelete: () => setState(() => _subjects.removeAt(i)),
                    ),
                    childCount: _subjects.length,
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SYLLABUS CARD (expandable) ───────────────────────────────────────────────

class _SyllabusCard extends StatefulWidget {
  final _SyllabusSubject subject;
  final void Function(int chapterIndex) onToggleChapter;
  final VoidCallback onDelete;
  const _SyllabusCard({required this.subject, required this.onToggleChapter, required this.onDelete});

  @override
  State<_SyllabusCard> createState() => _SyllabusCardState();
}

class _SyllabusCardState extends State<_SyllabusCard> {
  bool _expanded = false;

  String get _progressMessage {
    final p = widget.subject.progress;
    if (p >= 1.0) return '🎉 Syllabus complete!';
    if (p >= 0.75) return '🔥 Almost done — final stretch!';
    if (p >= 0.5) return '💪 Halfway through!';
    if (p > 0) return '🌱 Making progress...';
    return '📚 Ready to start';
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subject;
    final pct = (sub.progress * 100).round();

    return Dismissible(
      key: Key('syl-${sub.name}-${sub.createdAt.millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFD96060),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
        decoration: BoxDecoration(
          color: CeladonColors.pageWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sub.color.withAlpha(100)),
          boxShadow: const [BoxShadow(color: CeladonColors.softShadow, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (tappable to expand)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 5, height: 22,
                          decoration: BoxDecoration(color: sub.color, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(sub.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CeladonColors.inkBrown)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: sub.color.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${sub.completedCount}/${sub.chapters.length}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sub.color),
                          ),
                        ),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: CeladonColors.mutedSage),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: sub.progress,
                        minHeight: 5,
                        backgroundColor: CeladonColors.ruleLine,
                        valueColor: AlwaysStoppedAnimation(sub.color),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _progressMessage,
                          style: TextStyle(fontSize: 10, color: sub.color, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Text(
                          '$pct% · ${sub.totalDays} days',
                          style: const TextStyle(fontSize: 10, color: CeladonColors.mutedSage),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Expanded day-by-day roadmap
            if (_expanded) ...[
              Container(height: 1, color: CeladonColors.ruleLine),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group chapters by assigned day
                    for (int day = 1; day <= sub.totalDays; day++)
                      if (sub.chapters.any((c) => c.assignedDay == day))
                        _DayGroup(
                          day: day,
                          isCurrent: day == sub.currentDay,
                          chapters: sub.chapters.where((c) => c.assignedDay == day).toList(),
                          allChapters: sub.chapters,
                          color: sub.color,
                          onToggle: (ch) {
                            final idx = sub.chapters.indexOf(ch);
                            if (idx >= 0) widget.onToggleChapter(idx);
                          },
                        ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── DAY GROUP ────────────────────────────────────────────────────────────────

class _DayGroup extends StatelessWidget {
  final int day;
  final bool isCurrent;
  final List<_SyllabusChapter> chapters;
  final List<_SyllabusChapter> allChapters;
  final Color color;
  final void Function(_SyllabusChapter ch) onToggle;

  const _DayGroup({
    required this.day,
    required this.isCurrent,
    required this.chapters,
    required this.allChapters,
    required this.color,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = chapters.every((c) => c.isDone);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day pill
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isCurrent ? color : (allDone ? color.withAlpha(20) : CeladonColors.cream),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isCurrent ? color : CeladonColors.ruleLine),
            ),
            child: Column(
              children: [
                Text(
                  'Day',
                  style: TextStyle(fontSize: 8, color: isCurrent ? Colors.white70 : CeladonColors.mutedSage),
                ),
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: isCurrent ? Colors.white : (allDone ? color : CeladonColors.inkBrown),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Chapter list for this day
          Expanded(
            child: Column(
              children: chapters.map((ch) {
                return GestureDetector(
                  onTap: () => onToggle(ch),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: ch.isDone ? color.withAlpha(15) : CeladonColors.cream,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ch.isDone ? color.withAlpha(60) : CeladonColors.ruleLine),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ch.isDone ? color : Colors.transparent,
                            border: Border.all(color: ch.isDone ? color : CeladonColors.mutedSage, width: 1.5),
                          ),
                          child: ch.isDone ? const Icon(Icons.check_rounded, size: 9, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ch.title,
                                style: TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w600,
                                  color: ch.isDone ? CeladonColors.mutedSage : CeladonColors.inkBrown,
                                  decoration: ch.isDone ? TextDecoration.lineThrough : null,
                                  decorationColor: CeladonColors.mutedSage,
                                ),
                              ),
                              if (ch.description.isNotEmpty)
                                Text(
                                  ch.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 9.5, color: CeladonColors.mutedSage),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}