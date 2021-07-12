import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:photos/models/location.dart';

class LocationTag {
  final String id;
  final int ownerID;
  final String encryptedKey;
  final String keyDecryptionNonce;
  final bool isDeleted;
  final int createdAt;
  final int updatedAt;

  // null in case of deleted tags
  LocationClientAttr clientAttr;

  LocationTag(this.id, this.ownerID, this.encryptedKey, this.keyDecryptionNonce,
      this.isDeleted, this.createdAt, this.updatedAt);

  factory LocationTag.fromMap(Map<String, dynamic> map) {
    if (map == null) return null;
    var tag = new LocationTag(
      map["id"] as String,
      map["ownerId"] as int,
      map["encryptedKey"] as String,
      map["keyDecryptionNonce"] as String,
      map["isDeleted"] ?? false,
      map["createdAt"] as int,
      map["updatedAt"] as int,
    );
    return tag;
  }

  factory LocationTag.fromJson(String source) =>
      LocationTag.fromMap(json.decode(source));
}

enum CoordinatesType {
  POINT, // single coordinate with radius
  BOX, // leftBottom & rightTop
  POLYGON
}

CoordinatesType getCoordinatesType(String type) {
  return CoordinatesType.values.firstWhere((e) => describeEnum(e) == type,
      orElse: () => CoordinatesType.POINT);
}

class LocationClientAttr {
  final String userTag;
  final String providerTag;
  final CoordinatesType coordinateType; // point, box, polygon etc
  final List<Location> coordinates;
  final double radius; // in meter

  LocationClientAttr(this.userTag, this.providerTag, this.coordinateType,
      this.coordinates, this.radius);

  Map<String, dynamic> toJson() {
    return {
      "userTag": this.userTag,
      "providerTag": this.providerTag,
      "coordinateType": describeEnum(this.coordinateType),
      "coordinates": jsonEncode(coordinates.map((i) => i.toJson()).toList()),
      "radius": this.radius,
    };
  }

  factory LocationClientAttr.fromJson(Map<String, dynamic> jsonData) {
    return LocationClientAttr(
        jsonData['userTag'] ?? '',
        jsonData["providerTag"] ?? '',
        getCoordinatesType(jsonData["coordinateType"]),
        (json.decode(jsonData["coordinates"]) as List)
            .map((locationMap) => Location.fromMap(locationMap))
            .toList(growable: false),
        jsonData["radius"] ?? 0.0);
  }
}
