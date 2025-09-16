import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Course model with sections
class Course {
  final String id;
  final String shortTitle;
  final String longTitle;
  final String author;
  final String duration;
  final bool hasQuiz;
  final List<Section> sections;

  Course({
    required this.id,
    required this.shortTitle,
    required this.longTitle,
    required this.author,
    required this.duration,
    required this.hasQuiz,
    required this.sections,
  });

  factory Course.fromMap(Map<String, dynamic> data, String docId) {
    return Course(
      id: docId,
      shortTitle: data['shortTitle'] ?? '',
      longTitle: data['longTitle'] ?? '',
      author: data['author'] ?? '',
      duration: data['duration'] ?? '',
      hasQuiz: data['hasQuiz'] ?? false,
      sections: (data['sections'] as List<dynamic>? ?? [])
          .map((s) => Section.fromMap(s))
          .toList(),
    );
  }
}

class Section {
  final String title;
  final String content;

  Section({required this.title, required this.content});

  factory Section.fromMap(Map<String, dynamic> data) {
    return Section(
      title: data['title'] ?? '',
      content: data['content'] ?? '',
    );
  }
}

class CoursePage extends StatefulWidget {
  const CoursePage({super.key});

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  String? _selectedCategory; // null = all
  bool _showFavoritesOnly = false;
  Course? _activeCourse; // for sheet
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    "Budgeting",
    "Investing",
    "Banking",
    "Planning"
  ];

  /// Get courses from Firestore
  Stream<List<Course>> getCourses() {
    return FirebaseFirestore.instance
        .collection('courses')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Course.fromMap(doc.data(), doc.id))
        .toList());
  }

  /// Toggle favourite in Firestore
  Future<void> _toggleFavorite(String courseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
    FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();
    List favourites = snapshot.data()?['favourites'] ?? [];

    if (favourites.contains(courseId)) {
      await userDoc.update({
        'favourites': FieldValue.arrayRemove([courseId])
      });
    } else {
      await userDoc.update({
        'favourites': FieldValue.arrayUnion([courseId])
      });
    }
  }

  /// Check if course is favourited
  Future<bool> _isFavourite(String courseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    List favourites = snapshot.data()?['favourites'] ?? [];
    return favourites.contains(courseId);
  }

  void _openCourse(Course course) {
    setState(() {
      _activeCourse = course;
    });
  }

  Widget _buildChip(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = isSelected ? null : text;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: isSelected
              ? Border.all(color: const Color(0xFF2B8761), width: 2)
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color:
            isSelected ? const Color(0xFF2B8761) : const Color(0xFF858597),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(Course course) {
    return GestureDetector(
      onTap: () => _openCourse(course),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF355E47),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.shortTitle,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  Text("By ${course.author}",
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(
                    course.hasQuiz ? "Quiz included" : "No Quiz",
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.yellow,
                    ),
                  ),
                ],
              ),
            ),
            // Fav star + duration
            Column(
              children: [
                FutureBuilder<bool>(
                  future: _isFavourite(course.id),
                  builder: (context, snapshot) {
                    final isFav = snapshot.data ?? false;
                    return IconButton(
                      icon: Icon(
                        isFav ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                      ),
                      onPressed: () async {
                        await _toggleFavorite(course.id);
                        setState(() {}); // refresh UI
                      },
                    );
                  },
                ),
                Text(
                  course.duration,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8EBB87),
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .get(),
          builder: (context, favSnapshot) {
            if (!favSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // User's favourites
            List favs = favSnapshot.data!['favourites'] ?? [];

            return StreamBuilder<List<Course>>(
              stream: getCourses(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allCourses = snapshot.data!;
                final q = _searchController.text.trim().toLowerCase();

                // Filter courses
                final filtered = allCourses.where((c) {
                  if (_selectedCategory != null &&
                      !c.longTitle
                          .toLowerCase()
                          .contains(_selectedCategory!.toLowerCase())) {
                    return false;
                  }

                  if (_showFavoritesOnly && !favs.contains(c.id)) {
                    return false;
                  }

                  if (q.isNotEmpty &&
                      !c.shortTitle.toLowerCase().contains(q) &&
                      !c.longTitle.toLowerCase().contains(q)) {
                    return false;
                  }

                  return true;
                }).toList();

                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search bar + star
                          Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.search, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      hintText: "Search for courses",
                                      border: InputBorder.none,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _showFavoritesOnly
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.orange,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showFavoritesOnly =
                                      !_showFavoritesOnly;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Category chips
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _categories.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return Row(
                                children: [
                                  _buildChip(cat, isSelected),
                                  const SizedBox(width: 8),
                                ],
                              );
                            }).toList(),
                          ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    "Hi! Need help?",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),

                              ],
                            ),
                          ),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              image: const DecorationImage(
                                image: AssetImage('assets/cat.png'),
                                fit: BoxFit.contain,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "Recommended for you",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (filtered.isEmpty)
                            const Text("No courses found.",
                                style: TextStyle(color: Colors.white70))
                          else
                            ...filtered.map(_buildCourseCard).toList(),
                        ],
                      ),
                    ),

                    // Draggable sheet for active course
                    if (_activeCourse != null)
                      DraggableScrollableSheet(
                        initialChildSize: 0.9,
                        minChildSize: 0.6,
                        maxChildSize: 0.95,
                        builder: (context, scrollController) {
                          final course = _activeCourse!;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFF355E47),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                            ),
                            child: SingleChildScrollView(
                              controller: scrollController,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.arrow_back,
                                            color: Colors.white),
                                        onPressed: () => setState(
                                                () => _activeCourse = null),
                                      ),
                                      Expanded(
                                        child: Text(course.longTitle,
                                            style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white)),
                                      ),
                                      FutureBuilder<bool>(
                                        future: _isFavourite(course.id),
                                        builder: (context, snapshot) {
                                          final isFav = snapshot.data ?? false;
                                          return IconButton(
                                            icon: Icon(
                                              isFav
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: Colors.orange,
                                            ),
                                            onPressed: () async {
                                              await _toggleFavorite(course.id);
                                              setState(() {});
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                      "By ${course.author} • ${course.duration}",
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          color: Colors.white70)),
                                  const SizedBox(height: 24),
                                  ...course.sections.map((s) => Padding(
                                    padding:
                                    const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(s.title,
                                            style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white)),
                                        const SizedBox(height: 6),
                                        Text(s.content,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF9393A3),
                                                fontFamily: 'Poppins')),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
