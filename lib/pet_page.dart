import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'pet_item_image_mapper.dart';
import 'item.dart';
import 'store_items_dialog.dart';
import 'inventory_dialog.dart';
import 'pantry_dialog.dart';

class PetPage extends StatefulWidget {
  const PetPage({super.key});
  @override
  State<PetPage> createState() => _PetPageState();
}

class _PetPageState extends State<PetPage> {
  // --- Pet state ---
  String petType = 'Other';                 // 'Cat' when the chosen pet is cat1, otherwise 'Other'
  String? wornItem;                         // outfits (cat only)
  String _basePetAsset = 'assets/default_pet.png'; // raw asset from Firestore for the chosen pet
  String selectedPetImage = 'assets/default_pet.png'; // actually displayed image

  // --- User / coins / mood ---
  int petCoinBalance = 0;
  int happiness = 2; // 0–4 hearts

  String get userId => FirebaseAuth.instance.currentUser!.uid;

  final List<Item> purchasedItems = [];

  @override
  void initState() {
    super.initState();
    _ensurePetCoinsField();
    _listenPetCoins();
    _listenChosenPet(); // <- pulls the selected pet like CoursePage does
  }

  // ------------------ Firestore helpers ------------------

  Future<void> _ensurePetCoinsField() async {
    final ref = FirebaseFirestore.instance.collection('users').doc(userId);
    final snap = await ref.get();
    if (!snap.exists || !(snap.data() ?? {}).containsKey('pet_coins')) {
      await ref.set({'pet_coins': 0}, SetOptions(merge: true));
    }
  }

  void _listenPetCoins() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final data = doc.data();
      if (doc.exists && data != null && data.containsKey('pet_coins')) {
        setState(() => petCoinBalance = (data['pet_coins'] ?? 0) as int);
      }
    });
  }

  /// Listen to the chosen pet like in CoursePage:
  /// users/{uid}/userPet/current { asset: 'assets/pets/dog1.png', key: 'dog1' }
  void _listenChosenPet() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('userPet')
        .doc('current')
        .snapshots()
        .listen((doc) {
      if (!mounted || !doc.exists) return;

      final data = doc.data();
      final asset = (data?['asset'] ?? '').toString().trim(); // e.g., assets/pets/dog1.png
      final key   = (data?['key']   ?? '').toString().trim(); // e.g., cat1

      final fileName = asset.split('/').isNotEmpty
          ? asset.split('/').last.toLowerCase()
          : asset.toLowerCase();

      final isCat = fileName == 'cat1.png' || key.toLowerCase() == 'cat1';

      setState(() {
        _basePetAsset = asset.isNotEmpty ? asset : 'assets/default_pet.png';
        petType = isCat ? 'Cat' : 'Other';
        if (petType != 'Cat') {
          // outfits are cat-only
          wornItem = null;
        }
        _refreshDisplayedPet();
      });

      // DEBUG: uncomment to verify
      // print('Chosen pet -> asset: $_basePetAsset | key: $key | petType: $petType');
    });
  }

  /// Recompute the actual image to display.
  /// - If Cat: use mapper (respecting wornItem).
  /// - Otherwise: display the raw chosen asset from Firestore.
  void _refreshDisplayedPet() {
    if (petType == 'Cat') {
      final item = wornItem ?? 'Cat'; // base cat
      selectedPetImage = PetItemImageMapper.getImageResource('Cat', item);
    } else {
      selectedPetImage = _basePetAsset;
    }
    if (mounted) setState(() {});
  }

  /// One-time dev grant (+500 coins). Long-press the coin card to trigger.
  Future<void> _grantTestCoinsOnce() async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = (snap.data() ?? {}) as Map<String, dynamic>;
      final done = (data['dev_grant500_done'] ?? false) as bool;
      if (done) return; // already granted once

      tx.set(
        userRef,
        {
          'pet_coins': FieldValue.increment(500),
          'dev_grant500_done': true,
        },
        SetOptions(merge: true),
      );
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Granted +500 coins (dev test).')),
    );
  }

  /// Atomic add (safe for concurrent updates)
  Future<void> addPetCoins(int amount) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set({'pet_coins': FieldValue.increment(amount)}, SetOptions(merge: true));
  }

  // ------------------ Dialogs / actions ------------------

  void showStoreItemsDialog() {
    showDialog(
      context: context,
      builder: (context) => StoreItemsDialog(
        userId: userId,
        petCoinBalance: petCoinBalance,
      ),
    );
  }

  void showInventoryDialog() {
    if (petType != 'Cat') {
      _toast('Wardrobe is for the cat only 🙂');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => InventoryDialog(
        userId: userId,
        petType: 'Cat',
        wornItem: wornItem,
        onItemWear: (newImage, itemName) {
          // Inventory passes the composed image for cat, but we keep the
          // mapper API to stay consistent.
          setState(() {
            wornItem = itemName;
            _refreshDisplayedPet();
          });
        },
      ),
    );
  }

  void showPantryDialog() {
    showDialog(
      context: context,
      builder: (context) => PantryDialog(
        userId: userId,
        onFeed: (itemName) {
          setState(() {
            // Feeding resets to base look for cat; for other pets keep chosen asset.
            if (petType == 'Cat') {
              wornItem = null;
              _refreshDisplayedPet();
            }
            if (happiness < 4) happiness += 1;
          });
        },
      ),
    );
  }

  // ------------------ UI ------------------

  @override
  Widget build(BuildContext context) {
    const double bottomBarHeight = 64.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Stack(
        children: [
          // Background illustration
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/pet-bg.svg',
              fit: BoxFit.cover,
            ),
          ),

          // Foreground content
          SafeArea(
            top: true,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
                top: 16,
                bottom: bottomBarHeight + 12, // keep above bottom nav
              ),
              child: Column(
                children: [
                  // Top: Coins + Happiness
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _petCoinsWidget(),
                      _happinessWidget(),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Pet image area (anchored near bottom of available space)
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Image.asset(
                        selectedPetImage,
                        width: 250,
                        height: 250,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 24),
                      _circleButton(Icons.restaurant, showPantryDialog),
                      const SizedBox(width: 24),
                      _circleButton(Icons.store, showStoreItemsDialog),
                      const SizedBox(width: 24),
                      _circleButton(Icons.checkroom, showInventoryDialog),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----- small UI pieces -----

  Widget _petCoinsWidget() {
    return GestureDetector(
      onLongPress: _grantTestCoinsOnce, // dev-only booster
      child: Container(
        margin: const EdgeInsets.only(left: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF317D35), width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(2, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/pet-coin.png', width: 50, height: 50),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Pet Coins",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  "$petCoinBalance",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _happinessWidget() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF317D35), width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(2, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Happiness",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  index < happiness ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                  size: 24,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF9D9BFF), Color(0xFFEE8DD9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          borderRadius: BorderRadius.circular(60),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
