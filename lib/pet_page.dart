import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  int petCoinBalance = 0;

  String selectedItemName = 'Cat';
  String petType = 'Cat';
  String selectedPetImage = 'assets/cat.png';
  String? wornItem;

  // 0–4 hearts
  int happiness = 2;

  // TODO: replace with FirebaseAuth.instance.currentUser!.uid
  String userId = "R16tiInPTlDCWzeR83JB";

  final List<Item> purchasedItems = [];

  @override
  void initState() {
    super.initState();
    updatePetImage();
    _listenPetCoins();
  }

  void updatePetImage() {
    setState(() {
      selectedPetImage = PetItemImageMapper.getImageResource(
        petType,
        selectedItemName,
      );
    });
  }

  void _listenPetCoins() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data()!.containsKey('pet_coins')) {
        setState(() => petCoinBalance = doc['pet_coins']);
      }
    });
  }

  Future<void> addPetCoins(int amount) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'pet_coins': petCoinBalance + amount});
  }

  void showStoreItemsDialog() {
    showDialog(
      context: context,
      builder: (context) => StoreItemsDialog(
        userId: userId,
        petCoinBalance: petCoinBalance,
      ),
    );
  }

  void onItemWear(String newImage, String? itemName) {
    setState(() {
      selectedPetImage = newImage;
      wornItem = itemName;
    });
  }

  void showInventoryDialog() {
    showDialog(
      context: context,
      builder: (context) => InventoryDialog(
        userId: userId,
        petType: petType,
        wornItem: wornItem,
        onItemWear: (newImage, itemName) => onItemWear(newImage, itemName),
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
            selectedPetImage =
                PetItemImageMapper.getImageResource(petType, petType);
            if (happiness < 4) happiness += 1;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If your parent Scaffold has a bottomNavigationBar, set:
    // Scaffold(extendBody: true, extendBodyBehindAppBar: true, ...)
    // so the background can render under the bars.

    // Height of your bottom menu (adjust if yours differs)
    const double bottomBarHeight = 64.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,        // show SVG under status bar
        statusBarIconBrightness: Brightness.dark,  // pick to match your bg
      ),
      child: Stack(
        children: [
          // ---- Full-bleed background (under status + bottom bars)
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/pet-bg.svg',
              fit: BoxFit.cover,
            ),
          ),

          // ---- Foreground content: respect only top safe area; we pad the bottom ourselves
          SafeArea(
            top: true,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
                top: 16,
                bottom: bottomBarHeight + 12, // keep content above bottom menu
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

                  // Pet image area (anchored near bottom of the available space)
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

  // ----- UI pieces -----

  Widget _petCoinsWidget() {
    return Container(
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
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                "$petCoinBalance Coins",
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black),
              ),
            ],
          ),
        ],
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
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
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
}
