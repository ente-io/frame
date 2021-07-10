import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:photos/models/location.dart';

class LocationTag {
  String id;
  int ownerID;
  String encryptedKey;
  String keyDecryptionNonce;
  bool isDeleted = false;
  int createdAt;
  int updatedAt;

  String userTag;
  String providerTag;
  CoordinatesType coordinateType; // point, box, polygon etc
  List<Location> coordinates;
  double radius; // in meter

  LocationTag();

  Map<String, dynamic> getPrivateAttributes() {
    if (isDeleted != null && isDeleted) {
      throw Exception("invalid state");
    }
    final result = Map<String, dynamic>();
    result["userTag"] = userTag ?? '';
    result["providerTag"] = providerTag ?? '';
    result["coordinateType"] = describeEnum(coordinateType);
    result["radius"] = radius ?? 0.0;
    result["coordinates"] =
        jsonEncode(coordinates.map((i) => i.toJson()).toList());
    return result;
  }

  void applyPrivateAttributes(Map<String, dynamic> attr) {
    if (isDeleted != null && isDeleted) {
      throw Exception("invalid state");
    }

    userTag = attr["userTag"] ?? '';
    providerTag = attr["providerTag"] ?? '';
    coordinateType = getCoordinatesType(attr["coordinateType"]);
    radius = attr["radius"] ?? 0.0;
    coordinates = [];
    if (attr["coordinates"] != null) {
      coordinates = (json.decode(attr["coordinates"]) as List)
          .map((locationMap) => Location.fromMap(locationMap))
          .toList(growable: false);
    }
  }
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

class LocationAttributes {
  int version;
  String encryptedData;
  String decryptionNonce;
}
