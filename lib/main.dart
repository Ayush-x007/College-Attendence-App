import 'package:flutter/material.dart';
import 'dart:typed_data'; 
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

// Global Notifier for Theme Management
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

// --- SUPABASE CLIENT & SESSION MANAGER ---
final supabase = Supabase.instance.client;

class AppSession {
  static String? userId;
  static String? userName;
  static String? role; // 'student' or 'teacher'
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved theme from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final savedThemeIndex = prefs.getInt('theme_mode') ?? 0; // 0 = system, 1 = light, 2 = dark
  themeNotifier.value = ThemeMode.values[savedThemeIndex];

  // --- INITIALIZE SUPABASE ---
  await Supabase.initialize(
    url: 'https://acgmagdsskmjqnezjoiz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFjZ21hZ2Rzc2ttanFuZXpqb2l6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU1Mjc4OTAsImV4cCI6MjA5MTEwMzg5MH0.LeW-bsyy89tKF73_cxlu8l82i0VqUOQWg0MYkBrzxGM', 
  );

  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Campus Portal',
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: currentMode,
          home: const SplashScreen(),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1565C0),
        onPrimary: Colors.white,
        secondary: Color(0xFF00897B),
        tertiary: Color(0xFF1976D2), 
        surface: Colors.white,
        onSurface: Colors.black87,
        error: Colors.redAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12.0))),
      ),
      useMaterial3: true,
    );
  }

  // FIXED: Pure Black Background with Professional Accents
  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black, // Reverted to Pure Black
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF64B5F6), // Soft professional blue (No Neon)
        onPrimary: Colors.black,
        secondary: Color(0xFF4DB6AC), // Soft professional muted teal (No Neon)
        tertiary: Color(0xFF81D4FA), 
        surface: Color(0xFF121212), // Slightly elevated cards to contrast with pure black
        onSurface: Colors.white,
        error: Color(0xFFE57373),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black, // Pure Black AppBar
        foregroundColor: Color(0xFF64B5F6),
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF121212),
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12.0)),
          side: BorderSide(color: Color(0xFF2C2C2C), width: 1.0),
        ),
      ),
      useMaterial3: true,
    );
  }
}

// ============================================================================
// ==================== SPLASH SCREEN (AUTO-LOGIN LOGIC) ======================
// ============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  Future<void> _checkSavedLogin() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    final userId = prefs.getString('userId');
    final userName = prefs.getString('userName');

    if (!mounted) return;

    if (role != null && userId != null && userName != null) {
      AppSession.role = role;
      AppSession.userId = userId;
      AppSession.userName = userName;

      if (role == 'student') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigation()));
      } else if (role == 'teacher') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TeacherMainNavigation()));
      }
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 100, color: Colors.white),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ============================== LOGIN SCREEN ================================
// ============================================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _regNoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    String regNo = _regNoController.text.trim();
    String password = _passwordController.text;

    if (regNo.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter both ID and Password')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      final studentData = await supabase.from('students').select().eq('registration_number', regNo).eq('password_hash', password).maybeSingle();

      if (studentData != null) {
        AppSession.userId = studentData['registration_number'];
        AppSession.userName = studentData['name'];
        AppSession.role = 'student';

        await prefs.setString('userId', AppSession.userId!);
        await prefs.setString('userName', AppSession.userName!);
        await prefs.setString('role', AppSession.role!);

        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigation()));
        return;
      }

      final teacherData = await supabase.from('teachers').select().eq('teacher_id', regNo).eq('password_hash', password).maybeSingle();

      if (teacherData != null) {
        AppSession.userId = teacherData['teacher_id'];
        AppSession.userName = teacherData['name'];
        AppSession.role = 'teacher';

        await prefs.setString('userId', AppSession.userId!);
        await prefs.setString('userName', AppSession.userName!);
        await prefs.setString('role', AppSession.role!);

        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TeacherMainNavigation()));
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid ID or Password'), backgroundColor: Colors.redAccent));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Database Error: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _regNoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.school, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              const Text('Campus Portal', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Sign in to continue', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              const SizedBox(height: 48),

              TextField(
                controller: _regNoController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Registration No. / Employee ID', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ========================= 1. STUDENT PORTAL CODE ===========================
// ============================================================================

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [const HomeTab(), const ScheduleTab(), const ExamsTab(), const FeedbackTab()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Schedule'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Exams'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Feedback'),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  Future<Map<String, dynamic>> fetchHomeData() async {
    final announcements = await supabase.from('announcements').select().order('publish_date', ascending: false).limit(5);
    final dues = await supabase.from('student_dues').select().eq('registration_number', AppSession.userId!).eq('is_paid', false);
    final deadlines = await supabase.from('deadlines').select().order('due_date', ascending: true).limit(3);
    
    Map<String, dynamic> stats = {'theory': 0.0, 'lab': 0.0, 'total': 0.0};
    int classesNeededFor75 = 0;

    try {
      final allRecords = await supabase.from('attendance_records').select('''
        status,
        schedules (
          subjects (
            subject_type
          )
        )
      ''').eq('registration_number', AppSession.userId!);
      
      int totalConducted = 0;
      int totalAttended = 0;
      
      int theoryConducted = 0;
      int theoryAttended = 0;
      
      int labConducted = 0;
      int labAttended = 0;

      for (var r in allRecords) {
        totalConducted++;
        bool isPresent = r['status'] == 'Present';
        if (isPresent) totalAttended++;

        String type = 'Theory'; 
        if (r['schedules'] != null && r['schedules'] is Map) {
          var sched = r['schedules'];
          if (sched['subjects'] != null && sched['subjects'] is Map) {
             type = sched['subjects']['subject_type']?.toString() ?? 'Theory';
          }
        }

        if (type == 'Theory') {
          theoryConducted++;
          if (isPresent) theoryAttended++;
        } else if (type == 'Lab') {
          labConducted++;
          if (isPresent) labAttended++;
        }
      }

      if (totalConducted > 0) {
        double overallPercent = (totalAttended / totalConducted) * 100;
        stats['total'] = overallPercent;
        
        if (theoryConducted > 0) {
          stats['theory'] = (theoryAttended / theoryConducted) * 100;
        }
        if (labConducted > 0) {
          stats['lab'] = (labAttended / labConducted) * 100;
        }

        if (overallPercent < 75.0) {
          classesNeededFor75 = (3 * totalConducted) - (4 * totalAttended);
          if (classesNeededFor75 < 0) classesNeededFor75 = 0;
        }
      }
    } catch (e) {
      debugPrint("Error fetching dynamic stats: $e");
    }

    return {
      'announcements': announcements, 
      'dues': dues, 
      'deadlines': deadlines, 
      'stats': stats, 
      'classesNeeded': classesNeededFor75
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${AppSession.userName?.split(" ")[0] ?? "Student"}', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.account_circle, size: 32),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchHomeData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          final data = snapshot.data!;
          final announcements = data['announcements'] as List<dynamic>;
          final dues = data['dues'] as List<dynamic>;
          final deadlines = data['deadlines'] as List<dynamic>;
          final stats = data['stats'];

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const SectionHeader(title: 'Campus Updates'),
              const SizedBox(height: 12),
              if (announcements.isEmpty) const Text("No recent updates.")
              else SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: announcements.map((a) => AnnouncementCard(
                    title: a['title'] ?? 'Notice',
                    date: a['publish_date'].toString().split('T')[0],
                    department: a['department'] ?? 'Campus',
                    isUrgent: a['is_urgent'] ?? false
                  )).toList(),
                ),
              ),
              const SizedBox(height: 32),

              const SectionHeader(title: 'Attendance Overview'),
              const SizedBox(height: 16),
              AttendanceSummaryCard(
                theoryPercent: (stats['theory'] ?? 0).toDouble(), 
                labPercent: (stats['lab'] ?? 0).toDouble(), 
                totalPercent: (stats['total'] ?? 0).toDouble()
              ),
              
              if (data['classesNeeded'] > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Attendance Warning', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                            const SizedBox(height: 4),
                            Text(
                              'You need to attend the next ${data['classesNeeded']} classes consecutively to reach the 75% threshold.',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),

              const SectionHeader(title: 'Upcoming Deadlines'),
              const SizedBox(height: 10),
              if (deadlines.isEmpty) const Text("No upcoming deadlines. 🎉")
              else ...deadlines.map((d) => DeadlineTile(
                title: d['title'], subtitle: d['subtitle'] ?? '', date: d['due_date'].toString(),
                icon: Icons.assignment, iconColor: Colors.blue
              )).toList(),

              const SizedBox(height: 32),
              const SectionHeader(title: 'Course Fees & Dues'),
              const SizedBox(height: 10),
              if (dues.isEmpty) const Text("No pending dues! 🎉")
              else ...dues.map((d) => DuesCard(title: d['title'], amount: '₹${d['amount']}', dueDate: d['due_date'].toString())).toList(),
            ],
          );
        },
      ),
    );
  }
}

class ScheduleTab extends StatelessWidget {
  const ScheduleTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Schedule & Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [Tab(text: 'Today\'s Classes', icon: Icon(Icons.schedule)), Tab(text: 'Semester Details', icon: Icon(Icons.fact_check_outlined))],
          ),
        ),
        body: const TabBarView(children: [DailyScheduleView(), SemesterAttendanceView()]),
      ),
    );
  }
}

class DailyScheduleView extends StatelessWidget {
  const DailyScheduleView({super.key});

  Future<List<Map<String, dynamic>>> fetchTodaySchedule() async {
    String todayStr = DateTime.now().weekday.toString();
    String todayDate = DateTime.now().toIso8601String().split('T')[0]; 

    final classMap = await supabase.from('student_classes').select('class_id').eq('registration_number', AppSession.userId!).maybeSingle();
    if (classMap == null) return [];
    
    final schedule = await supabase.from('schedules')
      .select('*, subjects(id, name), teachers(name)')
      .eq('class_id', classMap['class_id'])
      .eq('day_of_week', todayStr)
      .order('start_time', ascending: true);

    final attendanceRecords = await supabase.from('attendance_records')
      .select('status, schedule_id, attendance_date')
      .eq('registration_number', AppSession.userId!)
      .eq('attendance_date', todayDate);

    Map<int, bool> todayPresence = {};
    for (var record in attendanceRecords) {
      int schedId = record['schedule_id'];
      todayPresence[schedId] = record['status'] == 'Present';
    }

    List<Map<String, dynamic>> combinedSchedule = [];
    for (var s in schedule) {
      int schedId = s['id'];
      combinedSchedule.add({
        ...s,
        'is_marked': todayPresence.containsKey(schedId),
        'is_present': todayPresence[schedId] ?? false,
      });
    }

    return combinedSchedule;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchTodaySchedule(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text("Error fetching schedule: ${snapshot.error}"));

        final classes = snapshot.data ?? [];
        if (classes.isEmpty) return const Center(child: Text('No classes scheduled for today! 🌴', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)));

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final c = classes[index];
            final subjName = c['subjects']?['name'] ?? 'Unknown Subject';
            final teacherName = c['teachers']?['name'] ?? 'Unknown Faculty';
            final timeStr = "${c['start_time']} - ${c['end_time']}";

            bool isMarked = c['is_marked'] == true;
            bool isPresent = c['is_present'] == true;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ClassTimelineCard(
                time: timeStr, 
                subject: subjName, 
                room: c['room'] ?? 'TBD', 
                faculty: teacherName, 
                isPresent: isMarked ? isPresent : null,
              ),
            );
          },
        );
      }
    );
  }
}

class SemesterAttendanceView extends StatelessWidget {
  const SemesterAttendanceView({super.key});

  Future<List<Map<String, dynamic>>> fetchAttendance() async {
    try {
      final records = await supabase.from('attendance_records')
        .select('''
          status, 
          attendance_date, 
          schedules (
            subjects (
              name
            )
          )
        ''')
        .eq('registration_number', AppSession.userId!);

      Map<String, Map<String, dynamic>> grouped = {};
      
      for(var r in records) {
        String sub = 'General';
        
        if (r['schedules'] != null && r['schedules'] is Map) {
          var sched = r['schedules'];
          if (sched['subjects'] != null && sched['subjects'] is Map) {
             sub = sched['subjects']['name']?.toString() ?? 'General';
          }
        }

        if (!grouped.containsKey(sub)) {
          grouped[sub] = {
            'subject': sub, 
            'attended': 0, 
            'total': 0, 
            'history': <Map<String, String>>[] 
          };
        }
        
        grouped[sub]!['total'] = (grouped[sub]!['total'] as int) + 1;
        if (r['status'] == 'Present') {
          grouped[sub]!['attended'] = (grouped[sub]!['attended'] as int) + 1;
        }

        String recDate = r['attendance_date']?.toString().split('T')[0] ?? 'Unknown Date';
        String recStatus = r['status']?.toString() ?? 'Absent';
        
        (grouped[sub]!['history'] as List<Map<String, String>>).add({
          'date': recDate,
          'status': recStatus
        });
      }
      
      var resultList = grouped.values.toList();
      resultList.sort((a, b) => a['subject'].toString().compareTo(b['subject'].toString()));
      
      for(var item in resultList) {
         (item['history'] as List<Map<String, String>>).sort((a,b) => a['date'].toString().compareTo(b['date'].toString()));
      }
      
      return resultList;
    } catch (e) {
      debugPrint("Semester Attendance Error: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchAttendance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        
        final subjects = snapshot.data ?? [];
        if(subjects.isEmpty) return const Center(child: Text("No attendance records found.", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)));

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('Semester - Detailed Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...subjects.map((sub) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: DetailedAttendanceCard(
                subject: sub['subject'] as String, 
                attended: sub['attended'] as int, 
                total: sub['total'] as int,
                lastUpdated: 'Recently', 
                history: sub['history'] as List<Map<String, String>>
              ),
            )).toList(),
          ],
        );
      }
    );
  }
}

class ExamsTab extends StatefulWidget {
  const ExamsTab({super.key});
  @override
  State<ExamsTab> createState() => _ExamsTabState();
}

class _ExamsTabState extends State<ExamsTab> {
  String selectedSemester = '6';
  final List<String> semesters = ['1', '2', '3', '4', '5', '6', '7', '8'];

  Future<List<dynamic>> fetchResults() async {
    return await supabase.from('exam_results')
      .select('*, subjects(name)')
      .eq('registration_number', AppSession.userId!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Academic Results', style: TextStyle(fontWeight: FontWeight.bold))),
      body: FutureBuilder<List<dynamic>>(
        future: fetchResults(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final results = snapshot.data ?? [];

          // Group by Subject
          Map<String, Map<String, dynamic>> grouped = {};
          for(var r in results) {
            String sub = r['subjects']?['name'] ?? 'General';
            if(!grouped.containsKey(sub)) {
               grouped[sub] = {'totalMarks': 0.0, 'maxMarks': 0.0, 'breakdown': <String, String>{}};
            }
            grouped[sub]!['totalMarks'] += (r['marks_obtained'] ?? 0);
            grouped[sub]!['maxMarks'] += (r['max_marks'] ?? 0);
            grouped[sub]!['breakdown'][r['exam_type'] ?? 'Exam'] = "${r['marks_obtained']} / ${r['max_marks']}";
          }
          
          // SORT RESULTS ALPHABETICALLY BY SUBJECT
          var sortedEntries = grouped.entries.toList();
          sortedEntries.sort((a, b) => a.key.compareTo(b.key));

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Semester:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedSemester,
                          icon: const Icon(Icons.arrow_drop_down),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                          items: semesters.map((String sem) => DropdownMenuItem(value: sem, child: Text("Sem $sem"))).toList(),
                          onChanged: (String? newValue) => setState(() => selectedSemester = newValue!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    const Text('Subject Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (sortedEntries.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("No results published yet."))),
                    ...sortedEntries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: SubjectMarksCard(
                        subject: e.key, 
                        grade: (e.value['maxMarks'] > 0 && e.value['totalMarks'] / e.value['maxMarks'] >= 0.8) ? 'A' : 'B',
                        totalMarks: (e.value['totalMarks'] as double).toInt(), 
                        maxMarks: (e.value['maxMarks'] as double).toInt(),
                        breakdown: e.value['breakdown']
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}

class FeedbackTab extends StatefulWidget {
  const FeedbackTab({super.key});
  @override
  State<FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<FeedbackTab> {
  int? selectedSubjectId;
  List<dynamic> subjects = [];
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final data = await supabase.from('subjects').select('id, name').order('name', ascending: true);
    setState(() => subjects = data);
  }

  Future<void> _submitFeedback() async {
    if (selectedSubjectId == null || _feedbackController.text.isEmpty) return;
    try {
      final alloc = await supabase.from('teacher_allocations').select('teacher_id').eq('subject_id', selectedSubjectId!).limit(1).maybeSingle();
      String? tId = alloc?['teacher_id'];

      await supabase.from('doubts').insert({
        'registration_number': AppSession.userId,
        'teacher_id': tId, 
        'subject_id': selectedSubjectId,
        'question': _feedbackController.text,
      });
      _feedbackController.clear();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message Sent to Faculty!')));
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask & Feedback', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select Subject', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: selectedSubjectId,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Select..."),
              items: subjects.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
              onChanged: (val) => setState(() => selectedSubjectId = val),
            ),
            const SizedBox(height: 20),
            const Text('Your Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _feedbackController, maxLines: 5, decoration: const InputDecoration(hintText: 'Type doubt here...', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
              onPressed: _submitFeedback,
              child: const Text('Submit to Faculty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.flight_takeoff),
              label: const Text('Apply for Official Leave'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaveApplicationScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class LeaveApplicationScreen extends StatefulWidget {
  const LeaveApplicationScreen({super.key});

  @override
  State<LeaveApplicationScreen> createState() => _LeaveApplicationScreenState();
}

class _LeaveApplicationScreenState extends State<LeaveApplicationScreen> {
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked;
        else _endDate = picked;
      });
    }
  }

  Future<void> _submitApplication() async {
    if (_startDate == null || _endDate == null || _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date cannot be before start date')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.from('leave_applications').insert({
        'student_reg': AppSession.userId,
        'start_date': _startDate!.toIso8601String().split('T')[0],
        'end_date': _endDate!.toIso8601String().split('T')[0],
        'reason': _reasonController.text,
        'status': 'Pending'
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave Application Submitted!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Leave')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_startDate == null ? 'Start Date' : _startDate!.toIso8601String().split('T')[0]),
                    onPressed: () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(_endDate == null ? 'End Date' : _endDate!.toIso8601String().split('T')[0]),
                    onPressed: () => _selectDate(context, false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _reasonController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Reason for Leave',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _isLoading ? null : _submitApplication,
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit to Proctor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Uint8List? _imageBytes; 
  final ImagePicker _picker = ImagePicker();
  late Future<Map<String, dynamic>> _profileFuture;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    _profileFuture = supabase.from('students').select('*, courses(course_name), branches(branch_name)').eq('registration_number', AppSession.userId!).single();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 80);
      if (pickedFile != null) {
        
        final bytes = await pickedFile.readAsBytes();
        
        setState(() {
          _imageBytes = bytes;
          _isUploading = true;
        });
        
        final String path = 'student_${AppSession.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        await supabase.storage.from('avatars').uploadBinary(
          path, 
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg')
        );
        
        final String imageUrl = supabase.storage.from('avatars').getPublicUrl(path);

        await supabase.from('students').update({'avatar_url': imageUrl}).eq('registration_number', AppSession.userId!);

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated successfully!'), backgroundColor: Colors.green));
        
        setState(() {
          _isUploading = false;
          _loadProfile(); 
        });
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e'), backgroundColor: Colors.redAccent));
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(leading: const Icon(Icons.photo_library), title: const Text('Photo Gallery'), onTap: () { Navigator.of(context).pop(); _pickAndUploadImage(ImageSource.gallery); }),
              ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Camera'), onTap: () { Navigator.of(context).pop(); _pickAndUploadImage(ImageSource.camera); }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Profile', style: TextStyle(fontWeight: FontWeight.bold)), actions: [
        IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()))),
      ]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _imageBytes == null) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data;
          if (data == null && _imageBytes == null) return const Center(child: Text("Profile not found"));

          String? avatarUrl = data?['avatar_url'];

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              VirtualIDCard(
                name: data?['name'] ?? 'N/A', 
                regNo: data?['registration_number'] ?? 'N/A', 
                course: '${data?['courses']?['course_name'] ?? ''} - ${data?['branches']?['branch_name'] ?? ''}', 
                bloodGroup: data?['blood_group'] ?? 'N/A'
              ),
              const SizedBox(height: 32),

              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      backgroundImage: _imageBytes != null 
                          ? MemoryImage(_imageBytes!) 
                          : (avatarUrl != null ? NetworkImage(avatarUrl) : null) as ImageProvider?,
                      child: (_imageBytes == null && avatarUrl == null) 
                          ? Icon(Icons.person, size: 60, color: Theme.of(context).colorScheme.primary) 
                          : null,
                    ),
                    if (_isUploading)
                      const Positioned.fill(
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        radius: 20,
                        child: IconButton(icon: Icon(Icons.edit, size: 20, color: Theme.of(context).colorScheme.onPrimary), onPressed: () => _showImageSourceActionSheet(context)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Text(data?['name'] ?? '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              const SizedBox(height: 4),
              Center(child: Text('Student', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500))),
              
              const SizedBox(height: 32),
              Text('Academic Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 16),
              ProfileDetailRow(label: 'Registration No.', value: data?['registration_number'] ?? 'N/A'), const Divider(height: 24),
              ProfileDetailRow(label: 'Course', value: data?['courses']?['course_name'] ?? 'N/A'), const Divider(height: 24),
              ProfileDetailRow(label: 'Branch', value: data?['branches']?['branch_name'] ?? 'N/A'), const Divider(height: 24),
              ProfileDetailRow(label: 'Domain', value: data?['domain'] ?? 'N/A'), const Divider(height: 30),
              ProfileDetailRow(label: 'Semester', value: data?['semester']?.toString() != null ? '${data?['semester']}th Semester' : 'N/A'),
              const SizedBox(height: 32),
              
              Text('Personal Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 16),
              ProfileDetailRow(label: 'Email', value: data?['email'] ?? 'N/A'), const Divider(height: 24),
              ProfileDetailRow(label: 'Phone No.', value: data?['phone_number'] ?? 'N/A'), const Divider(height: 24),
              ProfileDetailRow(label: 'Parent\'s No.', value: data?['parents_number'] ?? 'N/A'), const Divider(height: 24),
              ProfileDetailRow(label: 'Address', value: data?['address'] ?? 'N/A'),
            ],
          );
        }
      ),
    );
  }
}

// ============================================================================
// ========================= 2. TEACHER PORTAL CODE ===========================
// ============================================================================

class TeacherMainNavigation extends StatefulWidget {
  const TeacherMainNavigation({super.key});
  @override
  State<TeacherMainNavigation> createState() => _TeacherMainNavigationState();
}

class _TeacherMainNavigationState extends State<TeacherMainNavigation> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [const TeacherHomeTab(), const TeacherAttendanceTab(), const TeacherResultsTab(), const TeacherDoubtsTab(), const TeacherStudentStatsTab()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.grading_outlined), selectedIcon: Icon(Icons.grading), label: 'Results'), 
          NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: 'Doubts'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Alerts'),
        ],
      ),
    );
  }
}

class TeacherHomeTab extends StatefulWidget {
  const TeacherHomeTab({super.key});
  @override
  State<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends State<TeacherHomeTab> {
  final TextEditingController _announcementController = TextEditingController();
  bool _isUrgent = false;

  Future<Map<String, int>> fetchDashboardStats() async {
    String today = DateTime.now().weekday.toString();
    
    final scheduleRes = await supabase.from('schedules').select('id').eq('teacher_id', AppSession.userId!).eq('day_of_week', today);
    final doubtsRes = await supabase.from('doubts').select('id').eq('teacher_id', AppSession.userId!);
    
    return {
      'classesToday': scheduleRes.length,
      'doubts': doubtsRes.length,
    };
  }

  Future<void> _publishNotice() async {
    if (_announcementController.text.trim().isEmpty) return;
    try {
      await supabase.from('announcements').insert({
        'title': _announcementController.text.trim(),
        'department': 'Faculty',
        'is_urgent': _isUrgent,
        'publisher_id': AppSession.userId
      });
      _announcementController.clear();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Published!'), backgroundColor: Colors.green));
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.account_circle, size: 32),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherProfileScreen())),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('Welcome back,\n${AppSession.userName ?? 'Professor'}!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          FutureBuilder<Map<String, int>>(
            future: fetchDashboardStats(),
            builder: (context, snapshot) {
              final stats = snapshot.data ?? {'classesToday': 0, 'doubts': 0};
              return Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherScheduleTab())),
                      child: _buildStatCard(context, 'Classes Today', stats['classesToday'].toString(), Icons.class_, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(context, 'Doubts', stats['doubts'].toString(), Icons.mark_email_unread, color: Colors.orange)),
                ],
              );
            }
          ),
          
          const SizedBox(height: 32),
          const SectionHeader(title: 'Publish Announcement'),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(controller: _announcementController, maxLines: 3, decoration: const InputDecoration(hintText: 'Type notice...', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Mark as Urgent'), 
                          Switch(value: _isUrgent, activeColor: Colors.redAccent, onChanged: (val) => setState(() => _isUrgent = val)),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send), label: const Text('Publish'),
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                        onPressed: _publishNotice,
                      )
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, {required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32), const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class TeacherStudentStatsTab extends StatelessWidget {
  const TeacherStudentStatsTab({super.key});

  Future<List<dynamic>> fetchLowAttendance() async {
    return await supabase
        .from('overall_attendance')
        .select('*, students(name)')
        .lt('attendance_percentage', 75.0)
        .order('attendance_percentage', ascending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Low Attendance Alerts', style: TextStyle(fontWeight: FontWeight.bold))),
      body: FutureBuilder<List<dynamic>>(
        future: fetchLowAttendance(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final defaulters = snapshot.data ?? [];
          if (defaulters.isEmpty) return const Center(child: Text("Great! No students have attendance below 75%."));

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: defaulters.length,
            itemBuilder: (context, index) {
              final d = defaulters[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.withOpacity(0.5))),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 36),
                  title: Text(d['students']?['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Reg No: ${d['registration_number']}\nClasses Attended: ${d['attended_classes']}/${d['total_classes']}"),
                  trailing: Text(
                    "${double.parse(d['attendance_percentage'].toString()).toStringAsFixed(1)}%", 
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)
                  ),
                ),
              );
            }
          );
        },
      )
    );
  }
}

class TeacherScheduleTab extends StatelessWidget {
  const TeacherScheduleTab({super.key});

  Future<List<dynamic>> fetchTeacherSchedule() async {
    String today = DateTime.now().weekday.toString();
    return await supabase.from('schedules')
      .select('*, subjects(name), classes(name)')
      .eq('teacher_id', AppSession.userId!)
      .eq('day_of_week', today)
      .order('start_time', ascending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Schedule', style: TextStyle(fontWeight: FontWeight.bold))),
      body: FutureBuilder<List<dynamic>>(
        future: fetchTeacherSchedule(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final classes = snapshot.data ?? [];
          if(classes.isEmpty) return const Center(child: Text("No classes scheduled today."));

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final c = classes[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ClassTimelineCard(
                  time: "${c['start_time']} - ${c['end_time']}",
                  subject: c['subjects']?['name'] ?? 'Unknown',
                  room: c['room'] ?? 'TBD',
                  faculty: c['classes']?['name'] ?? 'Unknown Class',
                  isPresent: null 
                ),
              );
            },
          );
        }
      ),
    );
  }
}

class TeacherAttendanceTab extends StatefulWidget {
  const TeacherAttendanceTab({super.key});
  @override
  State<TeacherAttendanceTab> createState() => _TeacherAttendanceTabState();
}

class _TeacherAttendanceTabState extends State<TeacherAttendanceTab> {
  int? selectedClassId;
  int? selectedSubjectId;
  int? selectedScheduleId; 
  List<dynamic> classes = [];
  List<dynamic> subjects = [];
  List<dynamic> schedules = []; 
  Map<String, bool> attendanceState = {};

  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    final allocations = await supabase
        .from('teacher_allocations')
        .select('subjects(id, name), classes(id, name)')
        .eq('teacher_id', AppSession.userId!);

    String today = DateTime.now().weekday.toString();
    final todaySchedules = await supabase
        .from('schedules')
        .select('id, start_time, end_time')
        .eq('teacher_id', AppSession.userId!)
        .eq('day_of_week', today)
        .order('start_time', ascending: true);

    List<dynamic> uniqueSubjects = [];
    List<dynamic> uniqueClasses = [];
    Set<int> subjectIds = {};
    Set<int> classIds = {};

    for (var row in allocations) {
      var sub = row['subjects'];
      var cls = row['classes'];

      if (sub != null && !subjectIds.contains(sub['id'])) {
        subjectIds.add(sub['id']);
        uniqueSubjects.add(sub);
      }
      if (cls != null && !classIds.contains(cls['id'])) {
        classIds.add(cls['id']);
        uniqueClasses.add(cls);
      }
    }
    
    uniqueSubjects.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    uniqueClasses.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

    setState(() {
      subjects = uniqueSubjects;
      classes = uniqueClasses;
      schedules = todaySchedules;
    });
  }

  Future<List<dynamic>> _fetchStudents() async {
    if (selectedClassId == null) return [];
    List<dynamic> data = await supabase.from('student_classes').select('students(registration_number, name)').eq('class_id', selectedClassId!);
    
    data.sort((a, b) => a['students']['registration_number'].toString().compareTo(b['students']['registration_number'].toString()));

    for (var s in data) {
      String reg = s['students']['registration_number'];
      if (!attendanceState.containsKey(reg)) {
        attendanceState[reg] = true;
      }
    }
    return data;
  }

  Future<void> _submitAttendance() async {
    if (selectedClassId == null || selectedSubjectId == null || selectedScheduleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select Class, Subject, and Schedule first')));
      return;
    }

    try {
      String todayDate = DateTime.now().toIso8601String().split('T')[0];
      
      List<Map<String, dynamic>> records = [];
      attendanceState.forEach((reg, isPresent) {
        records.add({ 
          'schedule_id': selectedScheduleId, 
          'registration_number': reg, 
          'status': isPresent ? 'Present' : 'Absent',
          'attendance_date': todayDate
        });
      });

      await supabase.from('attendance_records').upsert(records, onConflict: 'registration_number, schedule_id, attendance_date');
      setState(() => _isSubmitted = true);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance Uploaded!'), backgroundColor: Colors.green));
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take Attendance')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: selectedSubjectId,
                  decoration: const InputDecoration(labelText: 'Select Subject', border: OutlineInputBorder()),
                  items: subjects.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                  onChanged: _isSubmitted ? null : (val) => setState(() => selectedSubjectId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedClassId,
                  decoration: const InputDecoration(labelText: 'Select Class/Batch', border: OutlineInputBorder()),
                  items: classes.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['name']))).toList(),
                  onChanged: _isSubmitted ? null : (val) {
                    setState(() { selectedClassId = val; attendanceState.clear(); });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedScheduleId,
                  decoration: const InputDecoration(labelText: 'Select Schedule', border: OutlineInputBorder()),
                  items: schedules.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text("${s['start_time']} - ${s['end_time']}"))).toList(),
                  onChanged: _isSubmitted ? null : (val) => setState(() => selectedScheduleId = val),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _fetchStudents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text("Error fetching students: ${snapshot.error}"));
                
                final students = snapshot.data ?? [];
                if (students.isEmpty) return const Center(child: Text("Select a class to view students."));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final st = students[index]['students'];
                    bool isP = attendanceState[st['registration_number']] ?? true;
                    
                    return Card(
                      child: ListTile(
                        title: Text(st['name']), subtitle: Text(st['registration_number']),
                        trailing: _isSubmitted 
                          ? Icon(isP ? Icons.check : Icons.close, color: isP ? Colors.green : Colors.red)
                          : Switch(value: isP, activeColor: Colors.green, onChanged: (v) => setState(() => attendanceState[st['registration_number']] = v)),
                      ),
                    );
                  },
                );
              }
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
              onPressed: _isSubmitted ? () => setState(()=> _isSubmitted = false) : _submitAttendance,
              child: Text(_isSubmitted ? 'EDIT' : 'SUBMIT ATTENDANCE'),
            ),
          ),
        ],
      ),
    );
  }
}

class TeacherResultsTab extends StatefulWidget {
  const TeacherResultsTab({super.key});
  @override
  State<TeacherResultsTab> createState() => _TeacherResultsTabState();
}

class _TeacherResultsTabState extends State<TeacherResultsTab> {
  int? selectedClassId;
  int? selectedSubjectId;
  String selectedExam = 'Class Test';
  
  List<dynamic> classes = [];
  List<dynamic> subjects = [];
  final List<String> exams = ['Class Test', 'Quiz Test', 'Surprise Test', 'Assignment', 'Mid-Term Exam'];
  
  final Map<String, TextEditingController> _marksControllers = {};
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    final allocations = await supabase
        .from('teacher_allocations')
        .select('subjects(id, name), classes(id, name)')
        .eq('teacher_id', AppSession.userId!);

    List<dynamic> uniqueSubjects = [];
    List<dynamic> uniqueClasses = [];
    Set<int> subjectIds = {};
    Set<int> classIds = {};

    for (var row in allocations) {
      var sub = row['subjects'];
      var cls = row['classes'];

      if (sub != null && !subjectIds.contains(sub['id'])) {
        subjectIds.add(sub['id']);
        uniqueSubjects.add(sub);
      }
      if (cls != null && !classIds.contains(cls['id'])) {
        classIds.add(cls['id']);
        uniqueClasses.add(cls);
      }
    }

    uniqueSubjects.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    uniqueClasses.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

    setState(() {
      subjects = uniqueSubjects;
      classes = uniqueClasses;
    });
  }

  Future<List<dynamic>> _fetchStudents() async {
    if (selectedClassId == null) return [];
    List<dynamic> data = await supabase.from('student_classes').select('students(registration_number, name)').eq('class_id', selectedClassId!);
    
    data.sort((a, b) => a['students']['registration_number'].toString().compareTo(b['students']['registration_number'].toString()));

    for (var s in data) {
      String reg = s['students']['registration_number'];
      if (!_marksControllers.containsKey(reg)) {
        _marksControllers[reg] = TextEditingController();
      }
    }
    return data;
  }

  Future<void> _submitResults() async {
    if(selectedSubjectId == null || selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select Subject and Class.')));
      return;
    }
    try {
      List<Map<String, dynamic>> records = [];
      _marksControllers.forEach((reg, ctrl) {
        if(ctrl.text.isNotEmpty) {
          records.add({
            'registration_number': reg, 'subject_id': selectedSubjectId, 'exam_type': selectedExam,
            'marks_obtained': double.tryParse(ctrl.text) ?? 0, 'max_marks': 50 
          });
        }
      });
      
      if(records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No marks entered.')));
        return;
      }

      await supabase.from('exam_results').insert(records);
      setState(() => _isSubmitted = true);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Results Uploaded!'), backgroundColor: Colors.green));
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Results')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: selectedSubjectId, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                  items: subjects.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                  onChanged: _isSubmitted ? null : (val) => setState(() => selectedSubjectId = val),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedClassId, decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                  items: classes.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['name']))).toList(),
                  onChanged: _isSubmitted ? null : (val) => setState(() { selectedClassId = val; _marksControllers.clear(); }),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedExam, decoration: const InputDecoration(labelText: 'Exam', border: OutlineInputBorder()),
                  items: exams.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
                  onChanged: _isSubmitted ? null : (val) => setState(() => selectedExam = val!),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _fetchStudents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final students = snapshot.data ?? [];
                if(students.isEmpty) return const Center(child: Text("Select a class to view students."));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final st = students[index]['students'];
                    return Card(
                      child: ListTile(
                        title: Text(st['name']), subtitle: Text(st['registration_number']),
                        trailing: SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _marksControllers[st['registration_number']], enabled: !_isSubmitted,
                            keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Marks'),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
              onPressed: _isSubmitted ? () => setState(()=> _isSubmitted = false) : _submitResults,
              child: Text(_isSubmitted ? 'EDIT RESULTS' : 'UPLOAD RESULTS'),
            ),
          ),
        ],
      ),
    );
  }
}

class TeacherDoubtsTab extends StatelessWidget {
  const TeacherDoubtsTab({super.key});

  Future<List<dynamic>> fetchDoubts() async {
    return await supabase.from('doubts').select('*, students(name, registration_number), subjects(name)').eq('teacher_id', AppSession.userId!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Doubts')),
      body: FutureBuilder<List<dynamic>>(
        future: fetchDoubts(),
        builder: (context, snapshot) {
          if(snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final doubts = snapshot.data ?? [];
          if(doubts.isEmpty) return const Center(child: Text("Inbox is empty!"));

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: doubts.length,
            itemBuilder: (context, index) {
              final d = doubts[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['subjects']?['name'] ?? 'General', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('From: ${d['students']?['name'] ?? 'Unknown'} (${d['students']?['registration_number'] ?? ''})', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(d['question'] ?? ''),
                    ],
                  ),
                ),
              );
            },
          );
        }
      )
    );
  }
}

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});
  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  Uint8List? _imageBytes; 
  final ImagePicker _picker = ImagePicker();
  late Future<Map<String, dynamic>> _profileFuture;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    _profileFuture = supabase.from('teachers').select('*, departments(dept_name)').eq('teacher_id', AppSession.userId!).single();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 80);
      if (pickedFile != null) {
        
        final bytes = await pickedFile.readAsBytes();
        
        setState(() {
          _imageBytes = bytes;
          _isUploading = true;
        });
        
        final String path = 'faculty_${AppSession.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        await supabase.storage.from('avatars').uploadBinary(
          path, 
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg')
        );
        
        final String imageUrl = supabase.storage.from('avatars').getPublicUrl(path);

        await supabase.from('teachers').update({'avatar_url': imageUrl}).eq('teacher_id', AppSession.userId!);

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated successfully!'), backgroundColor: Colors.green));
        
        setState(() {
          _isUploading = false;
          _loadProfile(); 
        });
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e'), backgroundColor: Colors.redAccent));
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(leading: const Icon(Icons.photo_library), title: const Text('Photo Gallery'), onTap: () { Navigator.of(context).pop(); _pickAndUploadImage(ImageSource.gallery); }),
              ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Camera'), onTap: () { Navigator.of(context).pop(); _pickAndUploadImage(ImageSource.camera); }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Faculty Profile', style: TextStyle(fontWeight: FontWeight.bold)), actions: [
        IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()))),
      ]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _imageBytes == null) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data;
          if (data == null && _imageBytes == null) return const Center(child: Text("Profile not found"));

          String? avatarUrl = data?['avatar_url'];

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      backgroundImage: _imageBytes != null 
                          ? MemoryImage(_imageBytes!) 
                          : (avatarUrl != null ? NetworkImage(avatarUrl) : null) as ImageProvider?,
                      child: (_imageBytes == null && avatarUrl == null) 
                          ? Icon(Icons.person, size: 60, color: Theme.of(context).colorScheme.primary) 
                          : null,
                    ),
                    if (_isUploading)
                      const Positioned.fill(
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        radius: 20,
                        child: IconButton(icon: Icon(Icons.edit, size: 20, color: Theme.of(context).colorScheme.onPrimary), onPressed: () => _showImageSourceActionSheet(context)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Text(data?['name'] ?? '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
              Center(child: Text(data?['designation'] ?? 'Faculty', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500))),
              const SizedBox(height: 32),
              
              const Text('Employment Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ProfileDetailRow(label: 'Employee ID', value: data?['teacher_id'] ?? ''), const Divider(),
              ProfileDetailRow(label: 'Department', value: data?['departments']?['dept_name'] ?? 'N/A'), const Divider(),
              ProfileDetailRow(label: 'Primary Subject', value: data?['primary_subject'] ?? 'N/A'),
              
              const SizedBox(height: 32),
              const Text('Contact Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ProfileDetailRow(label: 'Email', value: data?['email'] ?? 'N/A'), const Divider(),
              ProfileDetailRow(label: 'Phone No.', value: data?['phone_no'] ?? 'N/A'), const Divider(),
              ProfileDetailRow(label: 'Cabin', value: data?['cabin'] ?? 'N/A'),
            ],
          );
        }
      ),
    );
  }
}

// ============================================================================
// ==================== SHARED UTILS (Cards, UI Elements) =====================
// ============================================================================
class AnnouncementCard extends StatelessWidget {
  final String title; final String date; final String department; final bool isUrgent;
  const AnnouncementCard({super.key, required this.title, required this.date, required this.department, this.isUrgent = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280, margin: const EdgeInsets.only(right: 16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isUrgent ? Colors.redAccent.withOpacity(0.1) : Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: isUrgent ? Border.all(color: Colors.redAccent.shade200) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(department, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
            if (isUrgent) const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 16),
          ]),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(date, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
        ],
      ),
    );
  }
}
class SectionHeader extends StatelessWidget { final String title; const SectionHeader({super.key, required this.title}); @override Widget build(BuildContext context) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)); }
class DuesCard extends StatelessWidget { final String title; final String amount; final String dueDate; const DuesCard({super.key, required this.title, required this.amount, required this.dueDate}); @override Widget build(BuildContext context) => Card(elevation: 2, child: ListTile(leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Due by: $dueDate'), trailing: Text(amount, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)))); }
class DeadlineTile extends StatelessWidget { final String title; final String subtitle; final String date; final IconData icon; final Color iconColor; const DeadlineTile({super.key, required this.title, required this.subtitle, required this.date, required this.icon, required this.iconColor}); @override Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle), trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Due', style: TextStyle(fontSize: 12, color: Colors.grey)), Text(date, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error))])); }
class AttendanceSummaryCard extends StatelessWidget { final double theoryPercent; final double labPercent; final double totalPercent; const AttendanceSummaryCard({super.key, required this.theoryPercent, required this.labPercent, required this.totalPercent}); @override Widget build(BuildContext context) => Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [CircularIndicator(title: 'Theory', percentage: theoryPercent), CircularIndicator(title: 'Lab', percentage: labPercent), CircularIndicator(title: 'Total', percentage: totalPercent)]))); }
class CircularIndicator extends StatelessWidget { final String title; final double percentage; const CircularIndicator({super.key, required this.title, required this.percentage}); Color _getProgressColor(double percent) { if (percent < 60) return Colors.redAccent; if (percent < 80) return Colors.orange; return Colors.green; } @override Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [Stack(alignment: Alignment.center, children: [SizedBox(width: 80, height: 80, child: TweenAnimationBuilder<double>(tween: Tween<double>(begin: 0, end: percentage / 100), duration: const Duration(milliseconds: 1200), curve: Curves.easeOutCubic, builder: (context, value, _) => CircularProgressIndicator(value: value, strokeWidth: 8, backgroundColor: Theme.of(context).dividerColor.withOpacity(0.1), valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(percentage)), strokeCap: StrokeCap.round))), Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface))]), const SizedBox(height: 16), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]); }

class ClassTimelineCard extends StatelessWidget { 
  final String time; 
  final String subject; 
  final String room; 
  final String faculty; 
  final bool? isPresent; 

  const ClassTimelineCard({
    super.key, 
    required this.time, 
    required this.subject, 
    required this.room, 
    required this.faculty, 
    this.isPresent
  }); 

  @override 
  Widget build(BuildContext context) {
    bool isMarked = isPresent != null;
    Widget? trailingIcon;
    if (isPresent == true) {
      trailingIcon = const Icon(Icons.check_circle, color: Colors.green);
    } else if (isPresent == false) {
      trailingIcon = const Icon(Icons.cancel, color: Colors.redAccent);
    }

    return Card(
      elevation: isMarked ? 0 : 2, 
      color: isMarked ? Theme.of(context).disabledColor.withOpacity(0.05) : null, 
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Icon(Icons.access_time, color: isMarked ? Colors.grey : Theme.of(context).colorScheme.primary), 
            Text(time, style: TextStyle(fontSize: 12, color: isMarked ? Colors.grey : null))
          ]
        ), 
        title: Text(subject, style: TextStyle(fontWeight: FontWeight.bold, color: isMarked ? Colors.grey : null)), 
        subtitle: Text('$room • $faculty'), 
        trailing: trailingIcon, 
      )
    ); 
  } 
}

class ProfileDetailRow extends StatelessWidget { final String label; final String value; const ProfileDetailRow({super.key, required this.label, required this.value}); @override Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: 16, color: Theme.of(context).hintColor)), Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))]); }
class VirtualIDCard extends StatelessWidget { final String name; final String regNo; final String course; final String bloodGroup; const VirtualIDCard({super.key, required this.name, required this.regNo, required this.course, required this.bloodGroup}); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('VIRTUAL ID', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8), fontWeight: FontWeight.bold, letterSpacing: 2)), Icon(Icons.qr_code_2, color: Theme.of(context).colorScheme.onPrimary, size: 40)]), const SizedBox(height: 20), Text(name, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(course, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9), fontSize: 16)), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Reg No.', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8), fontSize: 12)), Text(regNo, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.bold))]), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Blood Group', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8), fontSize: 12)), Text(bloodGroup, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.bold))])])])); }

class DetailedAttendanceCard extends StatelessWidget { 
  final String subject; 
  final int attended; 
  final int total; 
  final String lastUpdated; 
  final List<dynamic> history; 
  const DetailedAttendanceCard({super.key, required this.subject, required this.attended, required this.total, required this.lastUpdated, required this.history}); 
  @override 
  Widget build(BuildContext context) { 
    double percentage = total == 0 ? 0 : (attended / total) * 100; 
    bool isShort = percentage < 75.0; 
    return Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isShort ? Colors.red.shade300 : Colors.transparent)), child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () { showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => AttendanceHistorySheet(subject: subject, history: history)); }, child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(subject, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isShort ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(color: isShort ? Colors.red : Colors.green, fontWeight: FontWeight.bold)))]), const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Classes: $attended / $total', style: TextStyle(color: Theme.of(context).hintColor)), Text('Tap for history', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500))]), if (isShort) const Padding(padding: EdgeInsets.only(top: 8.0), child: Text('⚠️ Attendance Shortage', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)))])))); 
  } 
}

class AttendanceHistorySheet extends StatelessWidget { 
  final String subject; 
  final List<dynamic> history; 
  const AttendanceHistorySheet({super.key, required this.subject, required this.history}); 
  @override 
  Widget build(BuildContext context) { 
    return FractionallySizedBox(heightFactor: 0.6, child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(context).dividerColor.withOpacity(0.3), borderRadius: BorderRadius.circular(10)))), Text('$subject History', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16), Expanded(child: ListView.builder(itemCount: history.length, itemBuilder: (context, index) { final record = history[index] as Map<String, dynamic>; final bool isPresent = record['status'] == 'Present'; return ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: isPresent ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), child: Icon(isPresent ? Icons.check_circle : Icons.cancel, color: isPresent ? Colors.green : Colors.redAccent)), title: Text(record['date']!, style: const TextStyle(fontWeight: FontWeight.w500)), trailing: Text(record['status']!, style: TextStyle(color: isPresent ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold))); }))] ))); 
  } 
}

class SubjectMarksCard extends StatelessWidget { final String subject; final String grade; final int totalMarks; final int maxMarks; final Map<String, String> breakdown; const SubjectMarksCard({super.key, required this.subject, required this.grade, required this.totalMarks, required this.maxMarks, required this.breakdown}); @override Widget build(BuildContext context) { Color gradeColor = totalMarks >= 80 ? Colors.green : (totalMarks >= 60 ? Colors.orange : Colors.red); return Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias, child: Theme(data: Theme.of(context).copyWith(dividerColor: Colors.transparent), child: ExpansionTile(backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.05), title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), subtitle: Text('Total: $totalMarks / $maxMarks'), trailing: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: gradeColor.withOpacity(0.1), shape: BoxShape.circle), child: Text(grade, style: TextStyle(color: gradeColor, fontWeight: FontWeight.bold, fontSize: 18))), children: [Padding(padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0), child: Column(children: breakdown.entries.map((entry) => Padding(padding: const EdgeInsets.symmetric(vertical: 6.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(entry.key, style: TextStyle(color: Theme.of(context).hintColor)), Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w600))]))).toList()))]))); } }

// ============================================================================
// ==================== SETTINGS & ACCOUNT MANAGEMENT =========================
// ============================================================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Appearance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentMode, _) {
              return ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('App Theme'),
                trailing: DropdownButton<ThemeMode>(
                  value: currentMode,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down),
                  onChanged: (ThemeMode? newTheme) async {
                    if (newTheme != null) {
                      themeNotifier.value = newTheme;
                      
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('theme_mode', newTheme.index);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('System Default')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Light Mode')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark Mode')),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Account Security', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Change Password'),
            subtitle: const Text('Update your login password via OTP'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              AppSession.userId = null;
              AppSession.userName = null;
              AppSession.role = null;
              
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  int _currentStep = 0;
  String _selectedMethod = 'Email';
  
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;

  void _verifyContact() {
    if (_contactController.text.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP sent successfully! (Mock: Enter 1234)'), backgroundColor: Colors.green),
    );
    setState(() => _currentStep = 1);
  }

  void _verifyOTP() {
    if (_otpController.text == '1234') {
      setState(() => _currentStep = 2);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid OTP'), backgroundColor: Colors.redAccent));
    }
  }

  void _updatePassword() async {
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match!'), backgroundColor: Colors.redAccent));
      return;
    }

    try {
      String table = AppSession.role == 'teacher' ? 'teachers' : 'students';
      String idColumn = AppSession.role == 'teacher' ? 'teacher_id' : 'registration_number';

      await supabase.from(table).update({
        'password_hash': _newPasswordController.text
      }).eq(idColumn, AppSession.userId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password Changed Successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  void dispose() {
    _contactController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Stepper(
        currentStep: _currentStep,
        type: StepperType.vertical,
        controlsBuilder: (context, details) => const SizedBox.shrink(), 
        steps: [
          Step(
            title: const Text('Verify Identity'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Radio<String>(value: 'Email', groupValue: _selectedMethod, activeColor: Theme.of(context).colorScheme.primary, onChanged: (val) => setState(() => _selectedMethod = val!)),
                    const Text('Email'),
                    const SizedBox(width: 20),
                    Radio<String>(value: 'Phone', groupValue: _selectedMethod, activeColor: Theme.of(context).colorScheme.primary, onChanged: (val) => setState(() => _selectedMethod = val!)),
                    const Text('Phone'),
                  ],
                ),
                TextField(
                  controller: _contactController,
                  decoration: InputDecoration(labelText: 'Enter Registered $_selectedMethod', border: const OutlineInputBorder(), prefixIcon: Icon(_selectedMethod == 'Email' ? Icons.email : Icons.phone)),
                  keyboardType: _selectedMethod == 'Email' ? TextInputType.emailAddress : TextInputType.phone,
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _verifyContact, style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary), child: const Text('Send OTP')),
              ],
            ),
          ),
          Step(
            title: const Text('Enter OTP'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: _otpController, decoration: const InputDecoration(labelText: '4-Digit OTP', border: OutlineInputBorder(), prefixIcon: Icon(Icons.message)), keyboardType: TextInputType.number, maxLength: 4),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _verifyOTP, style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary), child: const Text('Verify OTP')),
              ],
            ),
          ),
          Step(
            title: const Text('Create New Password'),
            isActive: _currentStep >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _newPasswordController, obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureNew = !_obscureNew)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController, obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _updatePassword,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Update Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}