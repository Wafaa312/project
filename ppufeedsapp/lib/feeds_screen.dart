import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ppufeedsapp/course_feed_screen.dart';
import 'package:ppufeedsapp/settings_screen.dart';

class FeedsScreen extends StatefulWidget {
  final String authToken;

  const FeedsScreen({super.key, required this.authToken});

  @override
  _FeedsScreenState createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen> {
  List<dynamic> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;
  Set<int> _subscribedCourses = {}; // قائمة الدورات المشتركة

  @override
  void initState() {
    super.initState();
    fetchCourses();
    fetchSubscriptions();
  }

  Future<void> fetchCourses() async {
    try {
      final response = await http.get(
        Uri.parse('http://feeds.ppu.edu/api/v1/courses'),
        headers: {'Authorization': widget.authToken},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> newCourses = data['courses'];

        if (_courses.isNotEmpty && newCourses.length > _courses.length) {
          // إشعار بالدورات الجديدة
          final addedCourses = newCourses.length - _courses.length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إضافة $addedCourses دورة جديدة!'),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        setState(() {
          _courses = newCourses;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'خطأ في جلب البيانات: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ أثناء الاتصال بالخادم: $e';
      });
    }
  }

  Future<void> fetchSubscriptions() async {
    try {
      final response = await http.get(
        Uri.parse('http://feeds.ppu.edu/api/v1/subscriptions'),
        headers: {'Authorization': widget.authToken},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _subscribedCourses = Set<int>.from(
              data['subscriptions'].map<int>((s) => s['course_id']));
        });
      } else {
        print('Error fetching subscriptions: ${response.body}');
      }
    } catch (e) {
      print('Exception fetching subscriptions: $e');
    }
  }

  Future<void> fetchSectionsAndNavigate(int courseId) async {
    try {
      final response = await http.get(
        Uri.parse('http://feeds.ppu.edu/api/v1/courses/$courseId/sections'),
        headers: {'Authorization': widget.authToken},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sections = data['sections'];

        if (sections.isNotEmpty) {
          final sectionId = sections[0]['id']; // اختيار أول قسم متاح
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostsScreen(
                authToken: widget.authToken,
                courseId: courseId,
                sectionId: sectionId,
              ),
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'لا توجد أقسام متاحة لهذه الدورة';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'خطأ في جلب الأقسام: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء الاتصال بالخادم: $e';
      });
    }
  }

  void _toggleSubscription(int courseId) {
    if (_subscribedCourses.contains(courseId)) {
      _unsubscribe(courseId);
    } else {
      _subscribe(courseId);
    }
  }

  Future<void> _subscribe(int courseId) async {
    try {
      final response = await http.post(
        Uri.parse('http://feeds.ppu.edu/api/v1/courses/$courseId/subscribe'),
        headers: {'Authorization': widget.authToken},
      );

      if (response.statusCode == 200) {
        setState(() {
          _subscribedCourses.add(courseId);
        });

        // إشعار عند الاشتراك
        final course = _courses.firstWhere((c) => c['id'] == courseId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم الاشتراك في الدورة: ${course['name']}'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        print('Error subscribing: ${response.body}');
      }
    } catch (e) {
      print('Exception subscribing: $e');
    }
  }

  Future<void> _unsubscribe(int courseId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://feeds.ppu.edu/api/v1/courses/$courseId/unsubscribe'),
        headers: {'Authorization': widget.authToken},
      );

      if (response.statusCode == 200) {
        setState(() {
          _subscribedCourses.remove(courseId);
        });
      } else {
        print('Error unsubscribing: ${response.body}');
      }
    } catch (e) {
      print('Exception unsubscribing: $e');
    }
  }

  void _logout() {
    Navigator.pop(context); // إغلاق القائمة الجانبية
    Navigator.pop(context); // العودة لشاشة تسجيل الدخول
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeds'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Welcome!',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? const Center(child: Text('No courses available at the moment.'))
              : ListView.builder(
                  itemCount: _courses.length,
                  itemBuilder: (context, index) {
                    final course = _courses[index];
                    final isSubscribed =
                        _subscribedCourses.contains(course['id']);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          course['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text('${course['college']}'),
                        trailing: IconButton(
                          icon: Icon(
                            isSubscribed
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isSubscribed ? Colors.green : Colors.grey,
                          ),
                          onPressed: () => _toggleSubscription(course['id']),
                        ),
                        onTap: () {
                          fetchSectionsAndNavigate(course['id']);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
