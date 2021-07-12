import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_sodium/flutter_sodium.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/network.dart';
import 'package:photos/db/location_tag_db.dart';
import 'package:photos/models/location_tag.dart';
import 'package:photos/utils/crypto_util.dart';

class LocationTagService {
  Configuration _config;
  LocationTagsDB _locationTagsDB;
  final _dio = Network.instance.getDio();

  LocationTagService._privateConstructor() {
    _config = Configuration.instance;
    _locationTagsDB = LocationTagsDB.instance;
  }

  static final LocationTagService instance =
      LocationTagService._privateConstructor();

  Future<LocationTag> addTag(LocationClientAttr clientAttr) async {
    final key = CryptoUtil.generateKey();
    var encodedAttributes = json.encode(clientAttr.toJson());
    final encryptedAttr =
        CryptoUtil.encryptSync(utf8.encode(encodedAttributes), key);
    final encryptedKeyData = CryptoUtil.encryptSync(key, _config.getKey());
    return _dio
        .post(
      _config.getHttpEndpoint() + "/locationtag/create",
      data: {
        "encryptedKey": Sodium.bin2base64(encryptedKeyData.encryptedData),
        "keyDecryptionNonce": Sodium.bin2base64(encryptedKeyData.nonce),
        "attributes": {
          "version": 1,
          "encryptedData": Sodium.bin2base64(encryptedAttr.encryptedData),
          "decryptionNonce": Sodium.bin2base64(encryptedAttr.nonce)
        }
      },
      options: Options(
        headers: {
          "X-Auth-Token": _config.getToken(),
        },
      ),
    )
        .then((response) async {
      LocationTag locationTag = getLocationTagFromResponse(response);
      await _locationTagsDB.insert(locationTag);
      return locationTag;
    });
  }

  LocationTag getLocationTagFromResponse(Response<dynamic> response) {
    LocationTag locationTag = LocationTag.fromMap(response.data);
    if (locationTag == null || locationTag.isDeleted ?? false) {
      return locationTag;
    }
    var key = CryptoUtil.decryptSync(
        Sodium.base642bin(locationTag.encryptedKey),
        _config.getKey(),
        Sodium.base642bin(locationTag.keyDecryptionNonce));
    var encryptedData =
        Sodium.base642bin(response.data["attributes"]["encryptedData"]);
    var decryptionNonce =
        Sodium.base642bin(response.data["attributes"]["decryptionNonce"]);
    var jsonEncodedAttributes =
        CryptoUtil.decryptSync(encryptedData, key, decryptionNonce);
    var clientAttr = LocationClientAttr.fromJson(
        json.decode(utf8.decode(jsonEncodedAttributes)));
    locationTag.clientAttr = clientAttr;
    return locationTag;
  }
}
