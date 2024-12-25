import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ppufeedsapp/comments_feed_screen.dart';

class PostsScreen extends StatefulWidget {
  final String authToken;
  final int courseId;
  final int sectionId;

  const PostsScreen({
    Key? key,
    required this.authToken,
    required this.courseId,
    required this.sectionId,
  }) : super(key: key);

  @override
  _PostsScreenState createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  List<dynamic> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://feeds.ppu.edu/api/v1/courses/${widget.courseId}/sections/${widget.sectionId}/posts'),
        headers: {'Authorization': widget.authToken},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _posts = data['posts'];
          _isLoading = false;
          _posts.sort((a, b) =>
              b['date_posted'].compareTo(a['date_posted'])); // الأحدث أولاً
        });
        await fetchCommentsCount();
      } else {
        setState(() {
          _isLoading = false;
        });
        print('Error: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Exception: $e');
    }
  }

  Future<void> fetchCommentsCount() async {
    try {
      for (var post in _posts) {
        final response = await http.get(
          Uri.parse(
              'http://feeds.ppu.edu/api/v1/courses/${widget.courseId}/sections/${widget.sectionId}/posts/${post['id']}/comments'),
          headers: {'Authorization': widget.authToken},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            post['no_of_comments'] = data['comments'].length;
          });
        } else {
          print('Error fetching comments: ${response.body}');
        }
      }
    } catch (e) {
      print('Exception fetching comments: $e');
    }
  }

  Future<void> deletePost(int postId) async {
    try {
      final response = await http.delete(
        Uri.parse(
            'http://feeds.ppu.edu/api/v1/courses/${widget.courseId}/sections/${widget.sectionId}/posts/$postId'),
        headers: {'Authorization': widget.authToken},
      );

      if (response.statusCode == 200) {
        setState(() {
          _posts.removeWhere((post) => post['id'] == postId);
        });

        // إظهار Snackbar عند الحذف
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully!'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        print('Error deleting post: ${response.body}');
      }
    } catch (e) {
      print('Exception deleting post: $e');
    }
  }

  Future<void> _addNewPost(String content) async {
    try {
      final response = await http.post(
        Uri.parse(
            'http://feeds.ppu.edu/api/v1/courses/${widget.courseId}/sections/${widget.sectionId}/posts'),
        headers: {
          'Authorization': widget.authToken,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'body': content}),
      );

      if (response.statusCode == 201) {
        final newPost = jsonDecode(response.body);

        // إضافة المنشور الجديد مباشرة إلى الأعلى في الذاكرة
        setState(() {
          _posts.insert(0, newPost);
        });

        // إعادة تحميل المنشورات من الخادم لتحديثها بشكل كامل
        await fetchPosts(); // تأكد من أنك تستدعي `fetchPosts` بعد إضافة المنشور

        // إظهار Snackbar عند الإضافة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post added successfully!'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        print('Error adding post: ${response.body}');
      }
    } catch (e) {
      print('Exception adding post: $e');
    }
  }

  void _showAddPostDialog() {
    final TextEditingController _newPostController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Post'),
          content: TextField(
            controller: _newPostController,
            decoration: const InputDecoration(
              labelText: 'Post Content',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newPostContent = _newPostController.text.trim();
                if (newPostContent.isNotEmpty) {
                  Navigator.pop(context);
                  _addNewPost(newPostContent);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditPostDialog(int postId, String currentContent) {
    final TextEditingController _postController =
        TextEditingController(text: currentContent);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Post'),
          content: TextField(
            controller: _postController,
            decoration: const InputDecoration(
              labelText: 'Updated Content',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                updatePost(postId, _postController.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> updatePost(int postId, String updatedContent) async {
    try {
      final response = await http.put(
        Uri.parse(
            'http://feeds.ppu.edu/api/v1/courses/${widget.courseId}/sections/${widget.sectionId}/posts/$postId'),
        headers: {
          'Authorization': widget.authToken,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'body': updatedContent}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _posts = _posts.map((post) {
            if (post['id'] == postId) {
              post['body'] = updatedContent;
            }
            return post;
          }).toList();
        });

        // إظهار Snackbar عند التعديل
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('Error updating post: ${response.body}');
      }
    } catch (e) {
      print('Exception updating post: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Posts'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? const Center(
                  child: Text(
                    'No posts available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    final noOfComments =
                        post['no_of_comments'] ?? 'Not available';

                    return Card(
                      child: GestureDetector(
                        // الضغط العادي للنقل إلى التعليقات
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CommentsScreen(
                                authToken: widget.authToken,
                                courseId: widget.courseId,
                                sectionId: widget.sectionId,
                                postId: post['id'],
                              ),
                            ),
                          );
                        },
                        // الضغط المطول لإظهار الخيارات
                        onLongPress: () {
                          _showPostOptionsDialog(post['id'], post['body']);
                        },
                        child: ListTile(
                          title: Text(post['body'] ?? 'No content available'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Author: ${post['author'] ?? 'Unknown author'}'),
                              Text(
                                  'Date: ${post['date_posted'] ?? 'Unknown date'}'),
                              Text('Comments: $noOfComments'),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPostDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showPostOptionsDialog(int postId, String currentContent) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: const Text(
            'Post Options',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text(
                  'Edit Post',
                  style: TextStyle(fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEditPostDialog(
                      postId, currentContent); // فتح نافذة التعديل
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  deletePost(postId); // حذف المنشور
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
