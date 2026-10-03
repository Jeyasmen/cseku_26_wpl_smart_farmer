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
      _fetchPosts();
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('পোস্ট ডিলিট করুন', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('আপনি কি নিশ্চিত যে এই পোস্টটি মুছে ফেলতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ডিলিট'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.delete(
        Uri.parse('http://localhost:5000/api/community/posts/$postId'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('পোস্ট সফলভাবে মুছে ফেলা হয়েছে!'), backgroundColor: Colors.red));
        _fetchPosts();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ডিলিট করতে সমস্যা হয়েছে!')));
    }
  }

  void _showEditPostModal(String postId, String currentText) {
    final textController = TextEditingController(text: currentText);
    bool isUpdating = false;

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
                        const Text('পোস্ট এডিট করুন', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(modalContext)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: textController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        filled: true, 
                        fillColor: Colors.white, 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: isUpdating ? null : () async {
                          if (textController.text.trim().isEmpty) return;
                          setModalState(() => isUpdating = true);
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);

                          try {
                            final res = await http.put(
                              Uri.parse('http://localhost:5000/api/community/posts/$postId'),
                              headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'},
                              body: jsonEncode({'text': textController.text.trim()}),
                            );
                            if (res.statusCode == 200) {
                              Navigator.pop(modalContext);
                              _fetchPosts();
                            }
                          } catch (e) {
                            // error
                          } finally {
                            setModalState(() => isUpdating = false);
                          }
                        },
                        child: isUpdating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('আপডেট করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
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

  // 🚀 কমেন্ট ডিলিট ফাংশন
  Future<void> _deleteComment(String postId, String commentId, BuildContext modalContext) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.delete(
        Uri.parse('http://localhost:5000/api/community/posts/$postId/comment/$commentId'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (res.statusCode == 200) {
        Navigator.pop(modalContext); // মোডাল বন্ধ করে 리ফ্রেশ করা হবে
        _fetchPosts();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('কমেন্ট মুছে ফেলা হয়েছে!'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('কমেন্ট ডিলিট করতে সমস্যা হয়েছে!')));
    }
  }

  // 🚀 কমেন্ট এডিট মোডাল
  void _showEditCommentModal(String postId, String commentId, String currentText, BuildContext parentModalContext) {
    final editController = TextEditingController(text: currentText);
    bool isUpdating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (editContext) {
        return StatefulBuilder(
          builder: (context, setEditState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(editContext).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('কমেন্ট এডিট করুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF18392d))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: editController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF3faf4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2f8d5c), foregroundColor: Colors.white),
                      onPressed: isUpdating ? null : () async {
                        if (editController.text.trim().isEmpty) return;
                        setEditState(() => isUpdating = true);
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);

                        try {
                          final res = await http.put(
                            Uri.parse('http://localhost:5000/api/community/posts/$postId/comment/$commentId'),
                            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'},
                            body: jsonEncode({'text': editController.text.trim()}),
                          );
                          if (res.statusCode == 200) {
                            Navigator.pop(editContext); // এডিট মোডাল বন্ধ
                            Navigator.pop(parentModalContext); // কমেন্ট মোডাল বন্ধ
                            _fetchPosts(); // লিস্ট আপডেট
                          }
                        } catch (e) {
                           // error
                        } finally {
                          setEditState(() => isUpdating = false);
                        }
                      },
                      child: isUpdating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('সংরক্ষণ করুন'),
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

  void _showCommentsModal(String postId, List comments, int postIndex) {
    final commentController = TextEditingController();
    bool isCommenting = false;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;

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
                              final commenter = comment['userId'] is Map ? comment['userId'] : {};
                              final commenterName = commenter['name'] ?? 'কৃষক';
                              final bool isTop = commenter['isTopFarmer'] == true;
                              
                              // 🚀 চেক করা যে এই কমেন্টটি ইউজারের নিজের কি না
                              final commentAuthorId = commenter['_id'] ?? commenter['id'] ?? '';
                              final bool isMyComment = currentUserId != null && commentAuthorId == currentUserId;
                              final cId = comment['_id'] ?? comment['id'];

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
                                          Row(
                                            children: [
                                              Text(commenterName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF18392d))),
                                              if (isTop) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                                                  child: const Text('⭐ Top Farmer', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                                                ),
                                              ]
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(comment['text'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                        ],
                                      )
                                    ),
                                    // 🚀 নিজের কমেন্ট হলে ফেসবুকের মতো অপশন দেখাবে
                                    if (isMyComment && cId != null)
                                      PopupMenuButton<String>(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showEditCommentModal(postId, cId, comment['text'] ?? '', modalContext);
                                          } else if (value == 'delete') {
                                            _deleteComment(postId, cId, modalContext);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(value: 'edit', child: Text('এডিট', style: TextStyle(fontSize: 13))),
                                          const PopupMenuItem(value: 'delete', child: Text('ডিলিট', style: TextStyle(fontSize: 13, color: Colors.red))),
                                        ],
                                        icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
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
                                    
                                    try {
                                      final res = await http.post(
                                        Uri.parse('http://localhost:5000/api/community/posts/$postId/comment'),
                                        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authProvider.token}'},
                                        body: jsonEncode({'text': text}),
                                      );
                                      if (res.statusCode == 201) {
                                        commentController.clear();
                                        _fetchPosts();
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
                      final user = post['userId'] is Map ? post['userId'] : {};
                      final postAuthorId = user['_id'] ?? user['id'] ?? '';
                      final likes = List<String>.from(post['likes'] ?? []);
                      final isLiked = currentUserId != null && likes.contains(currentUserId);
                      final comments = post['comments'] ?? [];
                      final bool isAuthorTopFarmer = user['isTopFarmer'] == true;
                      
                      final bool isMyPost = currentUserId != null && postAuthorId == currentUserId;
                      
                      Uint8List? imageBytes;
                      if (post['imageBase64'] != null && post['imageBase64'].toString().isNotEmpty) {
                        try { imageBytes = base64Decode(post['imageBase64']); } catch (e) {}
                      }

                      Uint8List? userImageBytes;
                      if (user['profilePicture'] != null && user['profilePicture'].toString().isNotEmpty) {
                        try { userImageBytes = base64Decode(user['profilePicture']); } catch (e) {}
                      }

                      // 🚀 Parsing Post Text to separate Problem and Solution
                      String fullText = post['text'] ?? '';
                      String problemText = fullText;
                      String? solutionText;

                      if (fullText.contains('✅') || fullText.contains('সমাধান')) {
                        final parts = fullText.split(RegExp(r'(?=✅|🤖 AI সমাধান|👨‍🌾 বিশেষজ্ঞের সমাধান)'));
                        if (parts.isNotEmpty) {
                          problemText = parts[0].trim(); 
                        }
                        if (parts.length > 1) {
                          solutionText = parts.sublist(1).join('\n').trim(); 
                        }
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
                                        Row(
                                          children: [
                                            Text(user['name'] ?? 'Unknown Farmer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF18392d))),
                                            if (isAuthorTopFarmer) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                                                child: const Text('⭐ Top Farmer', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                              ),
                                            ]
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on, size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text('এলাকা: ${post['location'] ?? 'Bangladesh'}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isMyPost)
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showEditPostModal(post['_id'], post['text'] ?? '');
                                        } else if (value == 'delete') {
                                          _deletePost(post['_id']);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16, color: Colors.blue), SizedBox(width: 8), Text('এডিট করুন')])),
                                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('ডিলিট করুন')])),
                                      ],
                                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 🚀 ১. প্রথমে কৃষকের মূল প্রবলেম টেক্সট
                              Text(problemText, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
                              const SizedBox(height: 12),

                              // 🚀 ২. এরপরে ছবির প্রিভিউ (Image) যদি থাকে
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

                              // 🚀 ৩. সবার শেষে হালকা সবুজ রঙের ব্যাকগ্রাউন্ড বক্সে সমাধান বা এআই সাজেশন্স
                              if (solutionText != null && solutionText.isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFeef7f2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFcce8d9)),
                                  ),
                                  child: Text(
                                    solutionText,
                                    style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF18392d), fontWeight: FontWeight.w500),
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