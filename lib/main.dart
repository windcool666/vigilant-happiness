import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '每日计划',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DailyPlannerScreen(),
    );
  }
}

class DailyTask {
  final String title;
  final TimeOfDay time;

  DailyTask(this.title, this.time);

  Map<String, dynamic> toMap() => {
        'title': title,
        'hour': time.hour,
        'minute': time.minute,
      };

  static DailyTask fromMap(Map<String, dynamic> map) => DailyTask(
        map['title'] ?? '',
        TimeOfDay(hour: map['hour'] ?? 0, minute: map['minute'] ?? 0),
      );

  String toJson() => jsonEncode(toMap());
  static DailyTask? fromJson(String? jsonString) =>
      jsonString == null ? null : fromMap(jsonDecode(jsonString));
}

class DailyPlannerScreen extends StatefulWidget {
  const DailyPlannerScreen({super.key});

  @override
  State<DailyPlannerScreen> createState() => _DailyPlannerScreenState();
}

class _DailyPlannerScreenState extends State<DailyPlannerScreen> {
  List<DailyTask> tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final taskStrings = prefs.getStringList('tasks') ?? [];
    setState(() {
      tasks = taskStrings
          .map((s) => DailyTask.fromJson(s)!)
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final taskStrings = tasks.map((task) => task.toJson()).toList();
    await prefs.setStringList('tasks', taskStrings);
  }

  Future<void> _addTask() async {
    final titleController = TextEditingController();
    TimeOfDay? selectedTime = TimeOfDay.now();

    final nameResult = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('任务名称'),
        content: TextField(controller: titleController),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, titleController.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (nameResult?.isNotEmpty == true) {
      final picked = await showTimePicker(
        context: context,
        initialTime: selectedTime!,
      );
      if (picked != null) {
        final newTask = DailyTask(nameResult!, picked);
        setState(() {
          tasks.add(newTask);
          tasks.sort((a, b) => a.time.compareTo(b.time));
        });
        _saveTasks();
        _scheduleNotification(newTask);
      }
    }
  }

  void _scheduleNotification(DailyTask task) {
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      task.time.hour,
      task.time.minute,
    );

    // 如果时间已过，设为明天
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    flutterLocalNotificationsPlugin.zonedSchedule(
      tasks.indexOf(task),
      '提醒',
      task.title,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_planner_channel',
          '每日计划提醒',
          channelDescription: '每日任务提醒通知',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的每日计划')),
      body: tasks.isEmpty
          ? const Center(child: Text('暂无任务，点击 + 添加'))
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return ListTile(
                  title: Text(task.title),
                  subtitle: Text('${task.time.format(context)} 提醒'),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: const Icon(Icons.add),
      ),
    );
  }
}
