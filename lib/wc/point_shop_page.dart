import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PointShopPage extends StatefulWidget {
  const PointShopPage({super.key});

  @override
  _PointShopPageState createState() => _PointShopPageState();
}

class _PointShopPageState extends State<PointShopPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _userPoints = 0;
  List<Map<String, dynamic>> _shopItems = [];
  List<String> _ownedBadgeIds = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  final List<String> _categories = ['all', 'exclusive', 'seasonal', 'rare', 'common'];

  @override
  void initState() {
    super.initState();
    _loadUserDataAndShop();
  }

  Future<void> _loadUserDataAndShop() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Load user points and owned badges
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      // Load owned badges
      final badgesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .get();

      final ownedBadgeIds = badgesSnapshot.docs.map((doc) => doc.id).toList();

      // Load shop items
      Query query = _firestore.collection('pointShop').where('isActive', isEqualTo: true);

      if (_selectedCategory != 'all') {
        query = query.where('category', isEqualTo: _selectedCategory);
      }

      final shopSnapshot = await query.orderBy('price').get();
      final now = DateTime.now();

      setState(() {
        _userPoints = userData?['points'] ?? 0;
        _ownedBadgeIds = ownedBadgeIds;
        _shopItems = shopSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Check if seasonal badge is within availability period
          if (data['isSeasonal'] == true) {
            final startDate = data['seasonalStartDate'] != null
                ? (data['seasonalStartDate'] as Timestamp).toDate()
                : null;
            final endDate = data['seasonalEndDate'] != null
                ? (data['seasonalEndDate'] as Timestamp).toDate()
                : null;

            // Only include if within seasonal period or if showing all items
            if (startDate != null && endDate != null) {
              final isWithinPeriod = now.isAfter(startDate) && now.isBefore(endDate);
              if (!isWithinPeriod && _selectedCategory != 'all') {
                return null; // Filter out items not in season
              }
              data['isSeasonallyAvailable'] = isWithinPeriod;
            }
          }

          return {
            'id': doc.id,
            ...data,
          };
        }).where((item) => item != null).cast<Map<String, dynamic>>().toList();
        _isLoading = false;
      });
    } catch (e) {
      // Handle errors
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading shop data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _purchaseBadge(Map<String, dynamic> item) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final price = item['price'] ?? 0;

    if (_userPoints < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough points!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Confirm purchase
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Confirm Purchase', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  item['icon'] ?? '🎖️',
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Premium Badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        item['description'] ?? '',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.grey),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Price:', style: TextStyle(color: Colors.grey)),
                Text(
                  '$price points',
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your balance:', style: TextStyle(color: Colors.grey)),
                Text(
                  '$_userPoints points',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('After purchase:', style: TextStyle(color: Colors.grey)),
                Text(
                  '${_userPoints - price} points',
                  style: TextStyle(
                    color: _userPoints - price >= 0 ? Colors.green : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Purchase'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Use a transaction to ensure atomic updates
      await _firestore.runTransaction((transaction) async {
        // Get current user data
        final userRef = _firestore.collection('users').doc(userId);
        final userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          throw Exception('User document not found');
        }

        final currentPoints = userSnapshot.data()?['points'] ?? 0;

        if (currentPoints < price) {
          throw Exception('Insufficient points');
        }

        // Check if already owned (in case of race condition)
        final badgeRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc(item['badgeId'] ?? item['id']);

        final badgeSnapshot = await transaction.get(badgeRef);

        if (badgeSnapshot.exists) {
          throw Exception('Badge already owned');
        }

        // Deduct points
        transaction.update(userRef, {
          'points': FieldValue.increment(-price),
        });

        // Add badge to user's collection
        transaction.set(badgeRef, {
          'id': item['badgeId'] ?? item['id'],
          'name': item['name'],
          'description': item['description'],
          'icon': item['icon'],
          'category': item['category'],
          'rarity': item['rarity'],
          'earnedAt': FieldValue.serverTimestamp(),
          'purchasedFromShop': true,
          'purchasePrice': price,
        });

        // Record purchase transaction
        final purchaseRef = _firestore.collection('purchases').doc();
        transaction.set(purchaseRef, {
          'userId': userId,
          'itemId': item['id'],
          'itemName': item['name'],
          'price': price,
          'purchasedAt': FieldValue.serverTimestamp(),
          'type': 'badge',
        });

        // Update shop item stock if applicable
        if (item['limitedStock'] == true && item['stock'] != null && item['stock'] > 0) {
          final shopItemRef = _firestore.collection('pointShop').doc(item['id']);
          transaction.update(shopItemRef, {
            'stock': FieldValue.increment(-1),
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item['name']} purchased successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload shop data
      await _loadUserDataAndShop();
    } catch (e) {
      print('Error purchasing badge: $e');
      String errorMessage = 'Failed to purchase badge';

      if (e.toString().contains('already owned')) {
        errorMessage = 'You already own this badge';
      } else if (e.toString().contains('Insufficient points')) {
        errorMessage = 'Not enough points';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildShopItem(Map<String, dynamic> item) {
    final price = item['price'] ?? 0;
    final isOwned = _ownedBadgeIds.contains(item['badgeId'] ?? item['id']);
    final canAfford = _userPoints >= price;
    final stock = item['stock'];
    final isLimited = item['limitedStock'] == true;
    final rarity = item['rarity'] ?? 'common';

    // ADD SEASONAL CHECK
    bool isSeasonallyAvailable = true;
    String seasonalMessage = '';
    if (item['isSeasonal'] == true) {
      final now = DateTime.now();
      final startDate = item['seasonalStartDate'] != null
          ? (item['seasonalStartDate'] as Timestamp).toDate()
          : null;
      final endDate = item['seasonalEndDate'] != null
          ? (item['seasonalEndDate'] as Timestamp).toDate()
          : null;

      if (startDate != null && endDate != null) {
        isSeasonallyAvailable = now.isAfter(startDate) && now.isBefore(endDate);

        if (!isSeasonallyAvailable) {
          if (now.isBefore(startDate)) {
            final daysUntilStart = startDate.difference(now).inDays;
            seasonalMessage = 'Available in ${daysUntilStart} days';
          } else {
            seasonalMessage = 'Season ended';
          }
        } else {
          final daysRemaining = endDate.difference(now).inDays;
          seasonalMessage = '${daysRemaining} days left';
        }
      }
    }

    Color rarityColor;
    switch (rarity.toLowerCase()) {
      case 'legendary':
        rarityColor = Colors.orange;
        break;
      case 'epic':
        rarityColor = Colors.purple;
        break;
      case 'rare':
        rarityColor = Colors.blue;
        break;
      case 'uncommon':
        rarityColor = Colors.green;
        break;
      default:
        rarityColor = Colors.grey;
    }

    return Card(
      color: const Color.fromRGBO(33, 35, 34, 1),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOwned ? Colors.green : rarityColor.withOpacity(0.3),
            width: isOwned ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge icon
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: rarityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(35),
                      border: Border.all(color: rarityColor, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        item['icon'] ?? '🎖️',
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Badge info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['name'] ?? 'Premium Badge',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: rarityColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: rarityColor),
                              ),
                              child: Text(
                                rarity.toUpperCase(),
                                style: TextStyle(
                                  color: rarityColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['description'] ?? 'A premium badge for dedicated users',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // Price and stock
                        Row(
                          children: [
                            Icon(
                              Icons.stars,
                              color: canAfford ? Colors.yellow : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$price points',
                              style: TextStyle(
                                color: canAfford ? Colors.yellow : Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isLimited && stock != null) ...[
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: stock > 0 ? Colors.orange.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  stock > 0 ? 'Stock: $stock' : 'SOLD OUT',
                                  style: TextStyle(
                                    color: stock > 0 ? Colors.orange : Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        // ADD SEASONAL INDICATOR
                        if (item['isSeasonal'] == true && seasonalMessage.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSeasonallyAvailable
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: isSeasonallyAvailable ? Colors.orange : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  seasonalMessage,
                                  style: TextStyle(
                                    color: isSeasonallyAvailable ? Colors.orange : Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Purchase button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isOwned || (isLimited && stock == 0) || !canAfford || !isSeasonallyAvailable
                      ? null
                      : () => _purchaseBadge(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOwned ? Colors.green : Colors.teal,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[700],
                    disabledForegroundColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isOwned
                        ? 'Owned'
                        : !isSeasonallyAvailable
                        ? 'Out of Season'
                        : (isLimited && stock == 0)
                        ? 'Sold Out'
                        : !canAfford
                        ? 'Insufficient Points'
                        : 'Purchase',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                category.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: Colors.teal,
              backgroundColor: const Color.fromRGBO(40, 42, 41, 1),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = category;
                  });
                  _loadUserDataAndShop();
                }
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Point Shop',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.yellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.yellow),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.yellow, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$_userPoints',
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : RefreshIndicator(
        color: Colors.teal,
        backgroundColor: const Color.fromRGBO(33, 35, 34, 1),
        onRefresh: _loadUserDataAndShop,
        child: Column(
          children: [
            // Category filter
            _buildCategoryFilter(),

            // Shop items
            Expanded(
              child: _shopItems.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedCategory == 'all'
                          ? 'No items available in the shop'
                          : 'No items in this category',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check back later for new items!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 32),
                itemCount: _shopItems.length,
                itemBuilder: (context, index) {
                  return _buildShopItem(_shopItems[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}