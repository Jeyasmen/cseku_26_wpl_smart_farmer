import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _isLoading = true;
  List<dynamic> _posts = [];

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final res = await http.get(
        Uri.parse('http://localhost:5000/api/community/posts'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );

      if (res.statusCode == 200) {
        setState(() {
          _posts = jsonDecode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching posts: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(String postId, int index) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    // Optimistic UI update (আগে UI চেঞ্জ হবে, পরে সার্ভারে যাবে যাতে ফাস্ট মনে হয়)
    setState(() {
      final likes = List<String>.from(_posts[index]['likes'] ?? []);
      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId!);
      }
      _posts[index]['likes'] = likes;
    });

    try {
      await http.put(
        Uri.parse('http://localhost:5000/api/community/posts/$postId/like'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
    } catch (e) {
      _fetchPosts(); // এরর হলে রিফ্রেশ করে আগের অবস্থায় ফিরে যাবে
    }
  }

  // 🚀 Update this method to show commenter name and picture
  void _showCommentsModal(String postId, List comments, int postIndex) {
    final commentController = TextEditingController();
    bool isCommenting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(modalContext).size.height * 0.75,
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Color(0xFFF3faf4),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('মতামত ও পরামর্শ (Comments)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: comments.isEmpty
                        ? const Center(child: Text('প্রথম মন্তব্যটি আপনি করুন!', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: comments.length,
                            itemBuilder: (context, i) {
                              final comment = comments[i];
                              
                              // 🚀 Extract User Info
                              final commenter = comment['userId'] is Map ? comment['userId'] : {};
                              final commenterName = commenter['name'] ?? 'কৃষক';
                              
                              Uint8List? commenterImg;
                              if (commenter['profilePicture'] != null && commenter['profilePicture'].toString().isNotEmpty) {
                                try { commenterImg = base64Decode(commenter['profilePicture']); } catch (e) {}
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 🚀 Show profile picture
                                    CircleAvatar(
                                      radius: 16, 
                                      backgroundColor: const Color(0xFFedf9f1), 
                                      backgroundImage: commenterImg != null ? MemoryImage(commenterImg) : null,
                                      child: commenterImg == null ? const Icon(Icons.person, size: 18, color: Color(0xFF2f8d5c)) : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 🚀 Show name
                                          Text(commenterName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                                          const SizedBox(height: 4),
                                          Text(comment['text'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                        ],
                                      )
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: InputDecoration(
                              hintText: 'আপনার পরামর্শ লিখুন...', 
                              filled: true, 
                              fillColor: const Color(0xFFF3faf4), 
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: isCommenting ? Colors.grey : const Color(0xFF2f8d5c),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 18),
                            onPressed: isCommenting
                                ? null
                                : () async {
                                    final text = commentController.text.trim();
                                    if (text.isEmpty) return;
                                    setModalState(() => isCommenting = true);
                                    
                                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                    try {
                                      final res = await http.post(
                                        Uri.parse('http://localhost:5000/api/community/posts/$postId/comment'),
                                        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'},
                                        body: jsonEncode({'text': text}),
                                      );
                                      if (res.statusCode == 201) {
                                        commentController.clear();
                                        _fetchPosts(); // Refresh to update comment list and counts
                                        Navigator.pop(modalContext);
                                      }
                                    } catch (e) {
                                      // error
                                    } finally {
                                      setModalState(() => isCommenting = false);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreatePostModal() {
    final textController = TextEditingController();
    Uint8List? imageBytes;
    String? base64Image;
    bool isPosting = false;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom, left: 20, right: 20, top: 20),
              decoration: const BoxDecoration(color: Color(0xFFF3faf4), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('নতুন পোস্ট তৈরি করুন', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(modalContext)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: textController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'আপনার ফসলের সমস্যা বা অভিজ্ঞতা লিখুন...', 
                        filled: true, 
                        fillColor: Colors.white, 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (imageBytes != null)
                      Stack(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(imageBytes!, height: 150, width: double.infinity, fit: BoxFit.cover)),
                          Positioned(right: 8, top: 8, child: InkWell(onTap: () => setModalState(() { imageBytes = null; base64Image = null; }), child: const CircleAvatar(backgroundColor: Colors.white, radius: 14, child: Icon(Icons.close, size: 16, color: Colors.red)))),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFedf9f1), foregroundColor: const Color(0xFF2f8d5c), elevation: 0),
                          onPressed: () async {
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                            if (pickedFile != null) {
                              final bytes = await pickedFile.readAsBytes();
                              setModalState(() { imageBytes = bytes; base64Image = base64Encode(bytes); });
                            }
                          },
                          icon: const Icon(Icons.add_photo_alternate, size: 18),
                          label: const Text('ছবি যুক্ত করুন'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white),
                          onPressed: isPosting ? null : () async {
                            if (textController.text.trim().isEmpty) return;
                            setModalState(() => isPosting = true);
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            
                            try {
                              final res = await http.post(
                                Uri.parse('http://localhost:5000/api/community/posts'),
                                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'},
                                body: jsonEncode({'text': textController.text.trim(), 'imageBase64': base64Image}),
                              );
                              if (res.statusCode == 201) {
                                Navigator.pop(modalContext);
                                _fetchPosts();
                              }
                            } catch (e) {
                              // error
                            } finally {
                              setModalState(() => isPosting = false);
                            }
                          },
                          child: isPosting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('পোস্ট করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF3faf4),
      appBar: AppBar(
        title: const Text('কৃষক আড্ডা (Community)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF12362b),
        elevation: 0,
        automaticallyImplyLeading: false, 
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2f8d5c)))
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.forum, size: 60, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('কমিউনিটিতে কোনো পোস্ট নেই।\nপ্রথম পোস্টটি আপনিই করুন!', textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, fontSize: 16)),
                      const SizedBox(height: 20),
                      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white), onPressed: _showCreatePostModal, child: const Text('নতুন পোস্ট লিখুন')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPosts,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 10, bottom: 80),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      final user = post['userId'] ?? {};
                      final likes = List<String>.from(post['likes'] ?? []);
                      final isLiked = currentUserId != null && likes.contains(currentUserId);
                      final comments = post['comments'] ?? [];
                      
                      Uint8List? imageBytes;
                      if (post['imageBase64'] != null && post['imageBase64'].toString().isNotEmpty) {
                        try { imageBytes = base64Decode(post['imageBase64']); } catch (e) {}
                      }

                      Uint8List? userImageBytes;
                      if (user['profilePicture'] != null && user['profilePicture'].toString().isNotEmpty) {
                        try { userImageBytes = base64Decode(user['profilePicture']); } catch (e) {}
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20, 
                                    backgroundColor: const Color(0xFFedf9f1), 
                                    backgroundImage: userImageBytes != null ? MemoryImage(userImageBytes) : null,
                                    child: userImageBytes == null ? const Icon(Icons.person, color: Color(0xFF2f8d5c)) : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(user['name'] ?? 'Unknown Farmer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF18392d))),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on, size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(post['location'] ?? 'Bangladesh', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              Text(post['text'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
                              const SizedBox(height: 12),

                              if (imageBytes != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 300),
                                    child: Image.memory(imageBytes, width: double.infinity, fit: BoxFit.cover),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              const Divider(height: 20),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  InkWell(
                                    onTap: () => _toggleLike(post['_id'], index),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                                      child: Row(
                                        children: [
                                          Icon(isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, size: 20, color: isLiked ? const Color(0xFF2f8d5c) : Colors.grey),
                                          const SizedBox(width: 8),
                                          Text('${likes.length} Likes', style: TextStyle(color: isLiked ? const Color(0xFF2f8d5c) : Colors.grey, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _showCommentsModal(post['_id'], comments, index),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.comment_outlined, size: 20, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Text('${comments.length} Comments', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostModal,
        backgroundColor: const Color(0xFF18392d),
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text('নতুন পোস্ট', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}