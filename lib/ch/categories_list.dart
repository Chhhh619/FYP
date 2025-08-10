import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'custom_category.dart';

class CategoriesListPage extends StatefulWidget {
  const CategoriesListPage({super.key});

  @override
  _CategoriesListPageState createState() => _CategoriesListPageState();
}

class _CategoriesListPageState extends State<CategoriesListPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _currentPage = 0;
  AnimationController? _animationController;
  Animation<Offset>? _slideAnimation;
  late Future<List<Map<String, dynamic>>> _categoryFuture;

  @override
  void initState() {
    super.initState();
    _categoryFuture = _loadCategories();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: const Offset(0.0, 0.0),
        ).animate(
          CurvedAnimation(
            parent: _animationController!,
            curve: Curves.easeInOut,
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSlideAnimation();
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadCategories() async {
    final userId = _auth.currentUser?.uid;
    final snapshot = await _firestore
        .collection('categories')
        .where(
          Filter.or(
            Filter('userId', isEqualTo: userId),
            Filter('userId', isNull: true),
          ),
        )
        .get();
    print(
      'Total categories fetched at ${DateTime.now()}: ${snapshot.docs.length} '
      'with docs: ${snapshot.docs.map((d) => d.data()).toList()}',
    );

    final categories = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'],
        'icon': data['icon'],
        'type': data['type'],
        'userId': data['userId'] ?? data['userId'] ?? null,
        // Handle both fields
      };
    }).toList();

    final filteredCategories = categories.where((cat) {
      final catUserId = cat['userId'];
      return catUserId == null || catUserId == '' || catUserId == userId;
    }).toList();
    print(
      'Filtered categories count at ${DateTime.now()}: ${filteredCategories.length} '
      'with data: ${filteredCategories.map((c) => c['name']).toList()}',
    );
    return filteredCategories;
  }

  void _updateSlideAnimation() {
    if (_animationController == null) return;
    _slideAnimation =
        Tween<Offset>(
          begin: _currentPage == 1
              ? const Offset(-1.0, 0.0)
              : const Offset(1.0, 0.0),
          end: const Offset(0.0, 0.0),
        ).animate(
          CurvedAnimation(
            parent: _animationController!,
            curve: Curves.easeInOut,
          ),
        );
    if (!_animationController!.isAnimating) {
      _animationController!.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableScreenWidth = MediaQuery.of(context).size.width;
    final availableScreenHeight = MediaQuery.of(context).size.height;
    print(
      'Building with _currentPage: $_currentPage, _slideAnimation: $_slideAnimation, '
      'Screen: $availableScreenWidth x $availableScreenHeight',
    );
    return Scaffold(
      backgroundColor: Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(28, 28, 28, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _currentPage == 0 ? 'Expenses' : 'Income',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomCategoryPage(
                    type: _currentPage == 0 ? 'expense' : 'income',
                  ),
                ),
              ).then((_) {
                setState(() {
                  _categoryFuture = _loadCategories(); // Refresh data
                });
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 8, // 80% for the grid
              child: Container(
                color: Color.fromRGBO(28, 28, 28, 1),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _categoryFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Error loading categories',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      );
                    }
                    final categories = snapshot.data ?? [];
                    final filteredCategories = categories
                        .where(
                          (category) =>
                              category['type'] ==
                              (_currentPage == 0 ? 'expense' : 'income'),
                        )
                        .toList();
                    print(
                      'Rendering with _currentPage: $_currentPage, '
                      'filtered count: ${filteredCategories.length}',
                    );

                    if (filteredCategories.isEmpty) {
                      return const Center(
                        child: Text(
                          'No categories available',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      );
                    }

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return SlideTransition(
                              position:
                                  _slideAnimation ??
                                  Tween<Offset>(
                                    begin: Offset.zero,
                                    end: Offset.zero,
                                  ).animate(animation),
                              child: child,
                            );
                          },
                      child: _buildCategoryGrid(
                        _currentPage == 0 ? 'expense' : 'income',
                        filteredCategories,
                        availableScreenWidth,
                        availableScreenHeight,
                      ),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              flex: 2, // 20% for the toggle buttons
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ToggleButtons(
                  isSelected: [_currentPage == 0, _currentPage == 1],
                  onPressed: (index) {
                    setState(() {
                      _currentPage = index;
                      _updateSlideAnimation();
                    });
                  },
                  color: Colors.white,
                  selectedColor: Colors.white,
                  fillColor: Colors.teal.withOpacity(0.8),
                  splashColor: Colors.teal.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  constraints: const BoxConstraints(
                    minWidth: 100,
                    minHeight: 30,
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Expenses', style: TextStyle(fontSize: 14)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Income', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(
    String type,
    List<Map<String, dynamic>> categories,
    double availableScreenWidth,
    double availableScreenHeight,
  ) {
    final categoryList = categories
        .where((category) => category['type'] == type)
        .toList();

    return GridView.builder(
      key: ValueKey<String>(type),
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // Match record_transaction.dart
        crossAxisSpacing: 12, // Match record_transaction.dart
        mainAxisSpacing: 12, // Match record_transaction.dart
        childAspectRatio: 1.0, // Match record_transaction.dart
      ),
      itemCount: categoryList.length,
      itemBuilder: (context, index) {
        final category = categoryList[index];
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              // Match the approximate size from record_transaction.dart (32px icon + 16px padding on each side)
              height: 64,
              // Match the approximate size
              decoration: BoxDecoration(
                color: const Color.fromRGBO(33, 35, 34, 1),
                // Match record_transaction.dart background
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  category['icon'],
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                  ), // Match record_transaction.dart
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                category['name'],
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                // Match record_transaction.dart
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}
