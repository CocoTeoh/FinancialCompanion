import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum QuizMode { playing, result, review }

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

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> data) {
    final rawIndex = data['correctIndex'];
    return QuizQuestion(
      question: data['question'] ?? '',
      options: (data['options'] as List<dynamic>? ?? []).cast<String>(),
      correctIndex:
      rawIndex is int ? rawIndex : int.tryParse(rawIndex.toString()) ?? 0,
    );
  }
}

class CoursePage extends StatefulWidget {
  final String? highlightCourseId;
  const CoursePage({super.key, this.highlightCourseId});


  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _courseKeys = {};
  bool _didScroll = false;

  String? _selectedCategory; // null = all
  bool _showFavoritesOnly = false;
  Course? _activeCourse; // for sheet

  // Quiz state
  bool _inQuiz = false;
  QuizMode _quizMode = QuizMode.playing;
  List<QuizQuestion> _quiz = [];
  int _qIndex = 0;
  int? _selectedOption;
  int _score = 0;
  bool _loadingQuiz = false;

  // Choices per question (for review)
  List<int?> _answers = [];

  // Auto-next feedback state
  bool _showingFeedback = false; // true for 1s after an answer
  bool _locked = false; // ignore taps while showing feedback
  String _bubble = "First question. We can do this!";

  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ["Budgeting", "Investing", "Banking", "Planning"];

  /// Get courses from Firestore
  Stream<List<Course>> getCourses() {
    return FirebaseFirestore.instance
        .collection('courses')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Course.fromMap(doc.data(), doc.id))
        .toList());
  }

  /// Fetch quiz (array field `quizzes` on course doc)
  Future<List<QuizQuestion>> _fetchQuizForCourse(String courseId) async {
    final snap = await FirebaseFirestore.instance
        .collection('courses')
        .doc(courseId)
        .get();
    final data = snap.data();
    final List<dynamic> raw = (data?['quizzes'] as List<dynamic>? ?? []);
    return raw
        .map((m) => QuizQuestion.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> _startQuiz(Course course) async {
    setState(() => _loadingQuiz = true);
    try {
      final q = await _fetchQuizForCourse(course.id);
      setState(() {
        _quiz = q;
        _qIndex = 0;
        _selectedOption = null;
        _score = 0;
        _inQuiz = true;
        _quizMode = QuizMode.playing;

        _answers = List<int?>.filled(q.length, null);

        // feedback state reset + first bubble
        _showingFeedback = false;
        _locked = false;
        _bubble = "First question. We can do this!";
      });
    } finally {
      setState(() => _loadingQuiz = false);
    }
  }

  void _exitQuizToArticle() {
    setState(() {
      _inQuiz = false;
      _quizMode = QuizMode.playing;
      _selectedOption = null;
      _showingFeedback = false;
      _locked = false;
    });
  }

  // Tap handler: show red/green, change bubble, then auto-next in 1s or go to RESULT
  void _onOptionTap(int i) {
    if (_locked || _quiz.isEmpty || _quizMode != QuizMode.playing) return;
    final q = _quiz[_qIndex];
    final correct = i == q.correctIndex;

    // Record answer for review
    _answers[_qIndex] = i;

    setState(() {
      _selectedOption = i;
      _showingFeedback = true;
      _locked = true;
      if (correct) _score++;
      _bubble =
      correct ? "Yayyy! You got the answer" : "Oh noo... We got it wrong";
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_qIndex < _quiz.length - 1) {
        setState(() {
          _qIndex++;
          _selectedOption = null;
          _showingFeedback = false;
          _locked = false;
          _bubble = "Here comes the next one!";
        });
      } else {
        // finished -> results page
        setState(() {
          _quizMode = QuizMode.result;
          _showingFeedback = false;
          _locked = false;
        });
      }
    });
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
      await userDoc.update({'favourites': FieldValue.arrayRemove([courseId])});
    } else {
      await userDoc
          .update({'favourites': FieldValue.arrayUnion([courseId])});
    }
  }

  /// Check if course is favourited
  Future<bool> _isFavourite(String courseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snapshot =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

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
            color: isSelected ? const Color(0xFF2B8761) : const Color(0xFF858597),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(Course course) {
    final key = _courseKeys[course.id] ??= GlobalKey();
    return Container(
        key: key,
        child: GestureDetector(
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
    ));
  }

  // ---------- QUIZ VIEWS ----------

  Widget _buildQuizView(ScrollController scrollController) {
    final total = _quiz.length;
    if (total == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child:
          Text('No quiz found for this course.', style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    final q = _quiz[_qIndex];
    final current = _qIndex + 1;

    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _exitQuizToArticle,
              ),
              Expanded(
                child: Text(
                  'Question $current/$total',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Speech bubble + pet
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Colors.white, // white background
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                      bottomLeft: Radius.circular(15),
                      bottomRight: Radius.circular(0),
                    ),
                  ),
                  child: Text(
                    _bubble,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.black, // black text
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage('assets/cat.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),


            ],
          ),
          const SizedBox(height: 16),

          // Question card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6F1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                q.question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF214235),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Options with feedback colors
          ...List.generate(q.options.length, (i) {
            // Colors
            const defaultBg = Color(0xFF2F5643);
            const selectedBg = Color(0xFF466F5A);
            const correctBg = Color(0xFF78C850); // green
            const wrongBg = Color(0xFFE04F5F); // red

            Color bg;
            if (_showingFeedback) {
              if (i == q.correctIndex) {
                bg = correctBg; // correct answer in green
              } else if (_selectedOption == i) {
                bg = wrongBg; // chosen wrong option in red
              } else {
                bg = defaultBg; // others stay dim
              }
            } else {
              bg = _selectedOption == i ? selectedBg : defaultBg;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _onOptionTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      )
                    ],
                  ),
                  child: Text(
                    q.options[i],
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResultView(ScrollController scrollController) {
    final total = _quiz.length;
    final ratio = total == 0 ? 0.0 : _score / total;
    int stars = 1;
    if (ratio == 1.0) {
      stars = 3;
    } else if (ratio > 0.5) {
      stars = 2;
    } else {
      stars = 1;
    }

    Widget star(int index) {
      final filled = index <= stars;
      return Icon(
        Icons.star,
        size: 28,
        color: filled ? const Color(0xFFFFD54F) : Colors.white30,
      );
    }

    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Close button
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _exitQuizToArticle,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Nice Work",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Image.asset(
            'assets/big-check.png',
            height: 110,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),

          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [star(1), const SizedBox(width: 8), star(2), const SizedBox(width: 8), star(3)],
          ),
          const SizedBox(height: 8),
          Text(
            '$_score/$total Correct!',
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 16),

          // Cat bubble reward text
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE7DAF5).withOpacity(.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              "Wow! You’ve Earned Pet Coins!\nLet's read more to earn more coins!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFF2A2A2A),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Review Answer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _quizMode = QuizMode.review),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A5B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                  textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                child: const Text("Review Answer"),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Play Again
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _quizMode = QuizMode.playing;
                    _qIndex = 0;
                    _score = 0;
                    _answers = List<int?>.filled(_quiz.length, null);
                    _selectedOption = null;
                    _showingFeedback = false;
                    _locked = false;
                    _bubble = "First question. We can do this!";
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8AD03D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                  textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                child: const Text("Play Again"),
              ),
            ),
          ),

          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildReviewView(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Close
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _exitQuizToArticle,
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),

          // Bubble
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6F8D7E),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    "Let's review our answers",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage('assets/cat.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ...List.generate(_quiz.length, (idx) {
            final q = _quiz[idx];
            final chosen = _answers[idx];
            final correctIdx = q.correctIndex;
            final isCorrect = chosen == correctIdx;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF6E9C7F),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question
                  Text(
                    q.question,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 10),



                  // Your choice (if wrong show red X + text)
                  if (chosen != null && !isCorrect)
                    Row(
                      children: [
                        const Icon(Icons.close, color: Color(0xFFE04F5F)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            q.options[chosen],
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Color(0xFFE04F5F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (chosen != null && !isCorrect) const SizedBox(height: 6),

                  // Correct answer (green check)
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF78C850)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          q.options[correctIdx],
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFFCBF1CB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // Play Again button at bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _quizMode = QuizMode.playing;
                    _qIndex = 0;
                    _score = 0;
                    _answers = List<int?>.filled(_quiz.length, null);
                    _selectedOption = null;
                    _showingFeedback = false;
                    _locked = false;
                    _bubble = "First question. We can do this!";
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8AD03D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                  textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                child: const Text("Play Again"),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------- BUILD ----------

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

            // Prefer firstName from Firestore; fall back to other sources
            final authUser = FirebaseAuth.instance.currentUser;
            final data = (favSnapshot.data!.data() as Map<String, dynamic>? ) ?? {};

            // try common key variants
            String userName = '';
            for (final key in ['firstName', 'first_name', 'firstname']) {
              final v = (data[key] ?? '').toString().trim();
              if (v.isNotEmpty) { userName = v; break; }
            }

            if (userName.isEmpty) {
              // if there's a full name, take the first token
              final full = (data['name'] ?? data['username'] ?? authUser?.displayName ?? '')
                  .toString()
                  .trim();
              if (full.isNotEmpty) {
                userName = full.split(' ').first; // "Jane Doe" -> "Jane"
              } else {
                userName = (authUser?.email?.split('@').first ?? 'there');
              }
            }



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

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_didScroll && widget.highlightCourseId != null) {
                    final key = _courseKeys[widget.highlightCourseId];
                    if (key?.currentContext != null) {
                      _didScroll = true;
                      Scrollable.ensureVisible(
                        key!.currentContext!,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                      );
                      setState(() => _activeCourse =
                          filtered.firstWhere((c) => c.id == widget.highlightCourseId));
                    }
                  }
                });

                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search bar + star filter
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

                          // Pet bubble on main list
                          const SizedBox(height: 12),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Bubble (left)
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white, // solid white
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(0), // square BR corner
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    "Hi $userName!\nLets find some courses and learn to earn together!",
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      height: 1.35,
                                      color: Color(0xFF1E293B),

                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Big cat (right)
                              Padding(
                                padding: const EdgeInsets.only(top: 30), // move cat down
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    image: const DecorationImage(
                                      image: AssetImage('assets/cat.png'),
                                      fit: BoxFit.contain,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),

                            ],
                          ),

                          const SizedBox(height: 20),

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
                            child: !_inQuiz
                                ? SingleChildScrollView(
                              controller: scrollController,
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  // Header row: back, title, star over quiz button
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
                                                fontWeight:
                                                FontWeight.bold,
                                                color: Colors.white)),
                                      ),
                                      Column(
                                        children: [
                                          FutureBuilder<bool>(
                                            future:
                                            _isFavourite(course.id),
                                            builder:
                                                (context, snapshot) {
                                              final isFav =
                                                  snapshot.data ?? false;
                                              return IconButton(
                                                icon: Icon(
                                                  isFav
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: Colors.orange,
                                                ),
                                                onPressed: () async {
                                                  await _toggleFavorite(
                                                      course.id);
                                                  setState(() {});
                                                },
                                              );
                                            },
                                          ),
                                          if (course.hasQuiz)
                                            ElevatedButton(
                                              onPressed: _loadingQuiz
                                                  ? null
                                                  : () => _startQuiz(
                                                  course),
                                              style: ElevatedButton
                                                  .styleFrom(
                                                backgroundColor:
                                                const Color(
                                                    0xFF8AD03D),
                                                foregroundColor:
                                                Colors.white,
                                                shape:
                                                RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(10),
                                                ),
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 14,
                                                    vertical: 10),
                                                textStyle: const TextStyle(
                                                    fontFamily:
                                                    'Poppins',
                                                    fontWeight:
                                                    FontWeight.w700),
                                              ),
                                              child: _loadingQuiz
                                                  ? const SizedBox(
                                                  height: 16,
                                                  width: 16,
                                                  child:
                                                  CircularProgressIndicator(
                                                      strokeWidth:
                                                      2,
                                                      color: Colors
                                                          .white))
                                                  : const Text(
                                                  'Take Quiz !'),
                                            ),
                                        ],
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
                                  ...course.sections.map(
                                        (s) => Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 16),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(s.title,
                                              style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 16,
                                                  fontWeight:
                                                  FontWeight.bold,
                                                  color: Colors.white)),
                                          const SizedBox(height: 6),
                                          Text(s.content,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                  Color(0xFF9393A3),
                                                  fontFamily:
                                                  'Poppins')),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                                : (_quizMode == QuizMode.playing
                                ? _buildQuizView(scrollController)
                                : _quizMode == QuizMode.result
                                ? _buildResultView(scrollController)
                                : _buildReviewView(scrollController)),
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
