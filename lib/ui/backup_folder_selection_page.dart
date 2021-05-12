import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/events/backup_folders_updated_event.dart';
import 'package:photos/models/file.dart';
import 'package:photos/ui/collections_gallery_widget.dart';
import 'package:photos/ui/loading_widget.dart';
import 'package:photos/ui/thumbnail_widget.dart';

class BackupFolderSelectionPage extends StatefulWidget {
  const BackupFolderSelectionPage({Key key}) : super(key: key);

  @override
  _BackupFolderSelectionPageState createState() =>
      _BackupFolderSelectionPageState();
}

class _BackupFolderSelectionPageState extends State<BackupFolderSelectionPage> {
  Set<String> _backedupFolders = Set<String>();

  @override
  void initState() {
    _backedupFolders = Configuration.instance.getPathsToBackUp();
    if (_backedupFolders.length == 0) {
      if (io.Platform.isAndroid) {
        _backedupFolders.add("Camera");
      } else {
        _backedupFolders.add("Recents");
      }
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.all(6),
          ),
          Center(
              child: SectionTitle(
            "select folders to preserve",
            alignment: Alignment.center,
          )),
          Padding(
            padding: EdgeInsets.all(16),
          ),
          Expanded(child: _getFolderList()),
          Padding(
            padding: EdgeInsets.all(12),
          ),
          Container(
            padding: EdgeInsets.only(left: 60, right: 60),
            width: double.infinity,
            height: 64,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.fromLTRB(50, 16, 50, 16),
                side: BorderSide(
                  width: 2,
                  color: Theme.of(context).accentColor,
                ),
              ),
              child: Text(
                "preserve",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              onPressed: _backedupFolders.length == 0
                  ? null
                  : () {
                      Configuration.instance.setPathsToBackUp(_backedupFolders);
                      Bus.instance.fire(BackupFoldersUpdatedEvent());
                      Navigator.pop(context);
                    },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              "the files within the folders you select will be encrypted and backed up in the background",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getFolderList() {
    return FutureBuilder<List<File>>(
      future: FilesDB.instance.getLatestLocalFiles(),
      builder: (context, snapshot) {
        Widget child;
        if (snapshot.hasData) {
          snapshot.data.sort((first, second) {
            return first.deviceFolder
                .toLowerCase()
                .compareTo(second.deviceFolder.toLowerCase());
          });
          final List<Widget> foldersWidget = [];
          for (final file in snapshot.data) {
            foldersWidget.add(
              InkWell(
                child: Container(
                  color: _backedupFolders.contains(file.deviceFolder)
                      ? Color.fromRGBO(10, 20, 20, 1.0)
                      : null,
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        child: Expanded(
                          child: Row(
                            children: [
                              _getThumbnail(file),
                              Padding(padding: EdgeInsets.all(10)),
                              Expanded(
                                child: Text(
                                  file.deviceFolder,
                                  style: TextStyle(fontSize: 16, height: 1.5),
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Checkbox(
                        value: _backedupFolders.contains(file.deviceFolder),
                        onChanged: (value) {
                          if (value) {
                            _backedupFolders.add(file.deviceFolder);
                          } else {
                            _backedupFolders.remove(file.deviceFolder);
                          }
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  final value = !_backedupFolders.contains(file.deviceFolder);
                  if (value) {
                    _backedupFolders.add(file.deviceFolder);
                  } else {
                    _backedupFolders.remove(file.deviceFolder);
                  }
                  setState(() {});
                },
              ),
            );
          }

          final scrollController = ScrollController();
          child = Scrollbar(
            isAlwaysShown: true,
            controller: scrollController,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Container(
                color: Colors.white.withOpacity(0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: foldersWidget,
                ),
              ),
            ),
          );
        } else {
          child = loadWidget;
        }
        return Container(
          padding: EdgeInsets.only(left: 40, right: 40),
          child: child,
        );
      },
    );
  }

  Widget _getThumbnail(File file) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4.0),
      child: Container(
        child: ThumbnailWidget(
          file,
          shouldShowSyncStatus: false,
          key: Key("backup_selection_widget" + file.tag()),
        ),
        height: 60,
        width: 60,
      ),
    );
  }
}