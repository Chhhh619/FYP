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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));

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
    final snapshot = await _firestore.collection('categories').get();
    print('Total categories fetched at ${DateTime.now()}: ${snapshot.docs.length} '
        'with docs: ${snapshot.docs.map((d) => d.data()).toList()}');

    final categories = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'],
        'icon': data['icon'],
        'type': data['type'],
        'userId': data['userId'], // Now includes null for default categories
      };
    }).toList();

    final filteredCategories = categories.where((cat) {
      final catUserId = cat['userId'];
      return catUserId == null || catUserId == userId;
    }).toList();
    print('Filtered categories count at ${DateTime.now()}: ${filteredCategories.length} '
        'with data: ${filteredCategories.map((c) => c['name']).toList()}');
    return filteredCategories;
  }

  void _updateSlideAnimation() {
    if (_animationController == null) return;
    _slideAnimation = Tween<Offset>(
      begin: _currentPage == 1
          ? const Offset(-1.0, 0.0)
          : const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));
    if (!_animationController!.isAnimating) {
      _animationController!.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building with _currentPage: $_currentPage, _slideAnimation: $_slideAnimation');
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 0),
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
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: _currentPage == 0
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
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
                      .where((category) =>
                  category['type'] ==
                      (_currentPage == 0 ? 'expense' : 'income'))
                      .toList();
                  print('Rendering with _currentPage: $_currentPage, '
                      'filtered count: ${filteredCategories.length}');

                  if (filteredCategories.isEmpty) {
                    return const Center(
                      child: Text(
                        'No categories available',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    );
                  }

                  // Remove _slideAnimation == null check to ensure rendering
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return SlideTransition(
                        position: _slideAnimation ?? Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(animation),
                        child: child,
                      );
                    },
                    child: _buildCategoryGrid(
                      _currentPage == 0 ? 'expense' : 'income',
                      filteredCategories,
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              height: 100,
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
                constraints: const BoxConstraints(minWidth: 120, minHeight: 40),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Expenses', style: TextStyle(fontSize: 16)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Income', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(
      String type,
      List<Map<String, dynamic>> categories,
      ) {
    final categoryList = categories
        .where((category) => category['type'] == type)
        .toList();
    return GridView.builder(
      key: ValueKey<String>(type),
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: categoryList.length,
      itemBuilder: (context, index) {
        final category = categoryList[index];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category['icon'], style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(
              category['name'],
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}