import 'package:flutter/material.dart';

class CoursePage extends StatefulWidget {
  const CoursePage({super.key});

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  bool _showBudgeting101 = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8EBB87),
      body: Stack(
        children: [
          // MAIN COURSE LIST
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        hintText: "Search for courses",
                        hintStyle: TextStyle(fontFamily: "Poppins"),
                        suffixIcon: Icon(Icons.filter_list, color: Colors.grey),
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Categories row
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChip("Budgeting", true),
                      _buildChip("Investing", false),
                      _buildChip("Banking", false),
                      _buildChip("Planning", false),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Greeting box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Hi Jane!\nLet's find some courses and learn to earn together!",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recommended section
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

                  // Course cards
                  GestureDetector(
                    onTap: () {
                      setState(() => _showBudgeting101 = true);
                    },
                    child: _buildCourseCard(
                      "Budgeting 101",
                      "Robertson Connie",
                      "No Quiz",
                      "5 Min read",
                      false,
                    ),
                  ),
                  _buildCourseCard("Budgeting Essentials", "Mark Robinson",
                      "Quiz included", "10 Min read", true),
                  _buildCourseCard("Invest Small", "Webb Kyle", "Quiz included",
                      "10 Min read", true),
                  _buildCourseCard("Investment For Beginners", "Webb Landon",
                      "Quiz included", "20 Min read", true),
                  _buildCourseCard("Strategic Budgeting", "Jennifer Lee",
                      "Quiz included", "15 Min read", true),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // DRAGGABLE SHEET FOR BUDGETING 101
          if (_showBudgeting101)
            DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.6,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF346051),
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            setState(() => _showBudgeting101 = false);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title + Star
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Text(
                              "Budgeting 101: A Basic Guide to Managing Your Money",
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.star, color: Colors.orange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Author + Duration
                      Row(
                        children: const [
                          Icon(Icons.person,
                              size: 14, color: Color(0xFFB8B8D2)),
                          SizedBox(width: 4),
                          Text(
                            "Robertson Connie",
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFB8B8D2),
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "5 Min read · Audio course available",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB8B8D2),
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Scrollable text
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "What is Budgeting?",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                "Budgeting is the process of creating a plan for how you'll allocate your money over a given period, typically a month. It allows you to track your income and expenses, helping you manage your finances, achieve financial goals, and avoid overspending.",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9393A3),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              SizedBox(height: 16),

                              Text(
                                "Why Budget?",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                "There are several key reasons to create a budget:\n"
                                    "1.  Financial Awareness : Knowing where your money goes helps you make informed decisions.\n"
                                    "2. Goal Achievement : Budgeting allows you to set and work toward financial goals, such as saving for a vacation, paying off debt, or buying a home.\n"
                                    "3. Debt Management : A budget can help you avoid or manage debt by controlling spending.\n"
                                    "4. Stress Reduction : Having a clear financial plan reduces uncertainty and stress.",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9393A3),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              SizedBox(height: 16),

                              Text(
                                "Steps to Create a Budget",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                "Step 1: Determine Your Income\n"
                                    "Start by calculating your total monthly income. This includes:\n"
                                    "- Your salary or wages (after taxes)\n"
                                    "- Any side income or freelance earnings\n"
                                    "- Other regular sources of income (e.g., rental income, dividends)",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9393A3),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      // Bottom navigation bar always stays
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2B8761),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ""),
        ],
      ),
    );
  }

  // Helpers
  static Widget _buildChip(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey.shade400,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.black : Colors.black87,
        ),
      ),
    );
  }

  static Widget _buildCourseCard(String title, String author, String quiz,
      String duration, bool hasQuiz) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF355E47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  author,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  quiz,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: hasQuiz ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.star_border, color: Colors.orange, size: 20),
              Text(
                duration,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}