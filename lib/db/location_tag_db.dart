import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photos/models/location_tag.dart';
import 'package:sqflite/sqflite.dart';

class LocationTagsDB {
  static final _databaseName = "ente.location_tag.db";
  static final table = "location_tag";
  int _databaseVersion = 1;

  static final columnID = 'id';
  static final columnOwnerId = 'owner_id';
  static final columnEncryptionKey = 'encryption_key';
  static final columnKeyDecryptionNonce = 'encryption_nonce';
  static final columnUpdatedAt = 'updated_at';
  static final columnCreatedAt = 'created_at';
  static final columnProvider = 'provider'; // manual,map_box, gMap etc
  static final columnIsDeleted = 'is_deleted';

  // columns below this section at sent to the server in encrypted form.

  // name by the user
  static final columnUserTag = 'user_tag';

  // name via third party provider
  static final columnProviderTag = 'provider_tag';

  // point, boundary, polygon
  static final columnCoordinateType = 'coordinate_type';

  // single for point type, multiple of others
  static final columnCoordinates = 'coordinates';

  // only required in point based tags
  static final columnRadius = 'radius';

  LocationTagsDB._privateConstructor();
  static final LocationTagsDB instance = LocationTagsDB._privateConstructor();

  static Database _database;

  Future<Database> get database async {
    if (_database != null) return _database;
    _database = await _initDatabase();
    insert(new LocationTag());
    return _database;
  }

  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
                CREATE TABLE $table (
                  $columnID TEXT PRIMARY KEY NOT NULL,
                  $columnOwnerId INTEGER NOT NULL,
                  $columnEncryptionKey TEXT NOT NULL,
                  $columnKeyDecryptionNonce TEXT NOT NULL,
                  $columnUpdatedAt INTEGER,
                  $columnCreatedAt INTEGER,
                  $columnProvider TEXT DEFAULT 'USER',
                  $columnIsDeleted INTEGER NOT NULL DEFAULT 0,
                  $columnUserTag TEXT NOT NULL,
                  $columnProviderTag TEXT NOT NULL DEFAULT '',
                  $columnCoordinateType TEXT NOT NULL,
                  $columnCoordinates TEXT,
                  $columnRadius REAL DEFAULT 0.0
                )
                ''');
  }

  Future<void> clearTable() async {
    final db = await instance.database;
    await db.delete(table);
  }

  Future<int> insert(LocationTag tag) async {
    final db = await instance.database;
    return db.insert(
      table,
      _getRowForLocationTag(tag),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, dynamic> _getRowForLocationTag(LocationTag tag) {
    final Map<String, dynamic> row = new Map<String, dynamic>();
    row[columnID] = tag.id;
    row[columnOwnerId] = tag.ownerID;
    row[columnEncryptionKey] = tag.encryptedKey;
    row[columnKeyDecryptionNonce] = tag.keyDecryptionNonce;
    row[columnUpdatedAt] = tag.updatedAt;
    row[columnCreatedAt] = tag.createdAt;
    if (tag.isDeleted != null && tag.isDeleted) {
      row[columnIsDeleted] = 1;
    } else {
      row[columnIsDeleted] = 0;
    }
    row[columnIsDeleted] = tag.isDeleted;
    row[columnUserTag] = tag.userTag;
    row[columnProviderTag] = tag.providerTag;
    row[columnRadius] = tag.radius;
    row[columnCoordinateType] = describeEnum(tag.coordinateType);
    row[columnCoordinates] = jsonEncode(tag.coordinates);

    return row;
  }
}
