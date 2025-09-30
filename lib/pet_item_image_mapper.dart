class PetItemImageMapper {
  // Mapping of pet types to items and their asset paths
  static final Map<String, Map<String, String>> petItemImageMap = {
    'Dog': {
      'Dog': 'assets/dog_pet.png',
      'Black Sunglasses': 'assets/dog_with_blacksunglasses.png',
      'Yellow Sunglasses': 'assets/dog_with_yellowsunglasses.png',
      'Black Spectacles': 'assets/dog_with_blackspecs.png',
      'gold_chain': 'assets/dog_with_goldchain.png',
      'Purple Bone Collar': 'assets/dog_with_purplebonecollar.png',
      'Pink Bone Collar': 'assets/dog_with_whitebonecollar.png',
      'Yellow Bone Collar': 'assets/dog_with_yellowbonecollar.png',
      'Pink Ribbon': 'assets/dog_with_ribbonright.png',
    },
    'Cat': {
      'Cat': 'assets/cat_pet.png',
      'Black Sunglasses': 'assets/cat_with_blacksunglasses.png',
      'Yellow Sunglasses': 'assets/cat_with_yellowsunglasses.png',
      'Black Spectacles': 'assets/cat_with_blackspecs.png',
      'gold_chain': 'assets/cat_with_goldchain.png',
      'Purple Bone Collar': 'assets/cat_with_purplebonecollar.png',
      'Pink Bone Collar': 'assets/cat_with_whitebonecollar.png',
      'Yellow Bone Collar': 'assets/cat_with_yellowbonecollar.png',
      'Pink Ribbon': 'assets/cat_with_ribbonright.png',
    }
  };

  static String getImageResource(String petType, String itemName) {
    return petItemImageMap[petType]?[itemName] ??
        'assets/default_pet.png';
  }
}
