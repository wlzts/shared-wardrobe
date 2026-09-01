class Wardrobe {
  final String id;
  final String name;
  final String owner;
  final String description;
  final String visibility; // private / shared
  final String coverImage;
  final DateTime createdAt;
  final DateTime updatedAt;

  Wardrobe({
    required this.id,
    required this.name,
    required this.owner,
    this.description = '',
    this.visibility = 'private',
    this.coverImage = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Wardrobe.fromJson(Map<String, dynamic> json) => Wardrobe(
        id: json['id'],
        name: json['name'],
        owner: json['owner'],
        description: json['description'] ?? '',
        visibility: json['visibility'] ?? 'private',
        coverImage: json['coverImage'] ?? '',
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner': owner,
        'description': description,
        'visibility': visibility,
        'coverImage': coverImage,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class Clothe {
  final String id;
  final String name;
  final String category;
  final String color;
  final String season;
  final String imageUrl;
  final String imagePath; // GitHub path
  final String brand;
  final String notes;
  final DateTime createdAt;

  Clothe({
    required this.id,
    required this.name,
    required this.category,
    this.color = '',
    this.season = '',
    this.imageUrl = '',
    this.imagePath = '',
    this.brand = '',
    this.notes = '',
    required this.createdAt,
  });

  factory Clothe.fromJson(Map<String, dynamic> json) => Clothe(
        id: json['id'],
        name: json['name'],
        category: json['category'] ?? '其他',
        color: json['color'] ?? '',
        season: json['season'] ?? '',
        imageUrl: json['imageUrl'] ?? '',
        imagePath: json['imagePath'] ?? '',
        brand: json['brand'] ?? '',
        notes: json['notes'] ?? '',
        createdAt: DateTime.parse(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'color': color,
        'season': season,
        'imageUrl': imageUrl,
        'imagePath': imagePath,
        'brand': brand,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };
}

class Outfit {
  final String id;
  final String date;
  final List<String> clotheIds;
  final String note;
  final DateTime createdAt;

  Outfit({
    required this.id,
    required this.date,
    required this.clotheIds,
    this.note = '',
    required this.createdAt,
  });

  factory Outfit.fromJson(Map<String, dynamic> json) => Outfit(
        id: json['id'],
        date: json['date'],
        clotheIds: List<String>.from(json['clotheIds'] ?? []),
        note: json['note'] ?? '',
        createdAt: DateTime.parse(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'clotheIds': clotheIds,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };
}

class Recommendation {
  final String id;
  final String fromUser;
  final String toWardrobeId;
  final List<String> clotheIds;
  final String message;
  final String status; // pending / accepted / ignored
  final String? acceptedOutfitDate;
  final DateTime createdAt;
  final DateTime? respondedAt;

  Recommendation({
    required this.id,
    required this.fromUser,
    required this.toWardrobeId,
    required this.clotheIds,
    required this.message,
    this.status = 'pending',
    this.acceptedOutfitDate,
    required this.createdAt,
    this.respondedAt,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation(
        id: json['id'],
        fromUser: json['fromUser'],
        toWardrobeId: json['toWardrobeId'],
        clotheIds: List<String>.from(json['clotheIds'] ?? []),
        message: json['message'] ?? '',
        status: json['status'] ?? 'pending',
        acceptedOutfitDate: json['acceptedOutfitDate'],
        createdAt: DateTime.parse(json['createdAt']),
        respondedAt: json['respondedAt'] != null ? DateTime.parse(json['respondedAt']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUser': fromUser,
        'toWardrobeId': toWardrobeId,
        'clotheIds': clotheIds,
        'message': message,
        'status': status,
        'acceptedOutfitDate': acceptedOutfitDate,
        'createdAt': createdAt.toIso8601String(),
        'respondedAt': respondedAt?.toIso8601String(),
      };
}

class WardrobeData {
  final String wardrobeId;
  final List<Clothe> clothes;
  final List<Outfit> outfits;
  DateTime lastUpdated;

  WardrobeData({
    required this.wardrobeId,
    required this.clothes,
    required this.outfits,
    required this.lastUpdated,
  });

  factory WardrobeData.fromJson(Map<String, dynamic> json) => WardrobeData(
        wardrobeId: json['wardrobeId'] ?? '',
        clothes: (json['clothes'] as List? ?? []).map((e) => Clothe.fromJson(e)).toList(),
        outfits: (json['outfits'] as List? ?? []).map((e) => Outfit.fromJson(e)).toList(),
        lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'wardrobeId': wardrobeId,
        'clothes': clothes.map((e) => e.toJson()).toList(),
        'outfits': outfits.map((e) => e.toJson()).toList(),
        'lastUpdated': lastUpdated.toIso8601String(),
      };
}
