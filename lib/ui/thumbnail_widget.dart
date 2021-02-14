import 'package:flutter/material.dart';
import 'package:photos/core/cache/image_cache.dart';
import 'package:photos/core/cache/thumbnail_cache.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/models/file.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/models/file_type.dart';
import 'package:photos/repositories/file_repository.dart';
import 'package:photos/utils/file_util.dart';

class ThumbnailWidget extends StatefulWidget {
  final File file;
  final BoxFit fit;
  const ThumbnailWidget(
    this.file, {
    Key key,
    this.fit = BoxFit.cover,
  }) : super(key: key);
  @override
  _ThumbnailWidgetState createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<ThumbnailWidget> {
  static final _logger = Logger("ThumbnailWidget");
  static final Widget loadingWidget = Container(
    alignment: Alignment.center,
    color: Colors.grey[800],
  );

  bool _hasLoadedThumbnail = false;
  bool _isLoadingThumbnail = false;
  bool _encounteredErrorLoadingThumbnail = false;
  ImageProvider _imageProvider;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    removePendingGetThumbnailRequestIfAny(widget.file);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.file.localID == null) {
      _loadNetworkImage();
    } else {
      _loadLocalImage(context);
    }
    var image;
    if (_imageProvider != null) {
      image = Image(
        image: _imageProvider,
        fit: widget.fit,
      );
    }

    var content;
    if (image != null) {
      if (widget.file.fileType == FileType.video) {
        content = Stack(
          children: [
            image,
            Container(
              height: 64,
              child: Icon(
                Icons.play_circle_outline,
                size: 40,
                color: Colors.white70,
              ),
            ),
          ],
          fit: StackFit.expand,
        );
      } else {
        content = image;
      }
    }
    return Stack(
      children: [
        loadingWidget,
        AnimatedOpacity(
          opacity: content == null ? 0 : 1.0,
          duration: Duration(milliseconds: 400),
          child: content,
        ),
      ],
      fit: StackFit.expand,
    );
  }

  void _loadLocalImage(BuildContext context) {
    if (!_hasLoadedThumbnail &&
        !_encounteredErrorLoadingThumbnail &&
        !_isLoadingThumbnail) {
      _isLoadingThumbnail = true;
      final cachedSmallThumbnail =
          ThumbnailLruCache.get(widget.file, THUMBNAIL_SMALL_SIZE);
      if (cachedSmallThumbnail != null) {
        _imageProvider = Image.memory(cachedSmallThumbnail).image;
        _hasLoadedThumbnail = true;
      } else {
        widget.file.getAsset().then((asset) async {
          if (asset == null || !(await asset.exists)) {
            if (widget.file.uploadedFileID != null) {
              widget.file.localID = null;
              FilesDB.instance.update(widget.file);
              _loadNetworkImage();
            } else {
              FilesDB.instance.deleteLocalFile(widget.file.localID);
              FileRepository.instance.reloadFiles();
            }
            return;
          }
          asset
              .thumbDataWithSize(
            THUMBNAIL_SMALL_SIZE,
            THUMBNAIL_SMALL_SIZE,
            quality: THUMBNAIL_SMALL_SIZE_QUALITY,
          )
              .then((data) {
            if (data != null && mounted) {
              final imageProvider = Image.memory(data).image;
              precacheImage(imageProvider, context).then((value) {
                if (mounted) {
                  setState(() {
                    _imageProvider = imageProvider;
                    _hasLoadedThumbnail = true;
                  });
                }
              });
            }
            ThumbnailLruCache.put(widget.file, THUMBNAIL_SMALL_SIZE, data);
          });
        }).catchError((e) {
          _logger.warning("Could not load image: ", e);
          _encounteredErrorLoadingThumbnail = true;
        });
      }
    }
  }

  void _loadNetworkImage() {
    if (!_hasLoadedThumbnail &&
        !_encounteredErrorLoadingThumbnail &&
        !_isLoadingThumbnail) {
      _isLoadingThumbnail = true;
      final cachedThumbnail = ThumbnailFileLruCache.get(widget.file);
      if (cachedThumbnail != null) {
        _imageProvider = Image.file(cachedThumbnail).image;
        _hasLoadedThumbnail = true;
        return;
      }
      _getThumbnailFromServer();
    }
  }

  void _getThumbnailFromServer() {
    getThumbnailFromServer(widget.file).then((file) async {
      if (file.lengthSync() > THUMBNAIL_DATA_LIMIT) {
        _logger.warning(widget.file.title +
            " has a thumbnail of size " +
            file.lengthSync().toString());
      }
      if (mounted) {
        final imageProvider = Image.file(file).image;
        precacheImage(imageProvider, context).then((value) {
          if (mounted) {
            setState(() {
              _imageProvider = imageProvider;
              _hasLoadedThumbnail = true;
            });
          }
        }).catchError((e) {
          _logger.severe("Could not load image " + widget.file.toString());
          _encounteredErrorLoadingThumbnail = true;
        });
      }
    });
  }

  @override
  void didUpdateWidget(ThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file.generatedID != oldWidget.file.generatedID) {
      setState(() {
        _hasLoadedThumbnail = false;
        _isLoadingThumbnail = false;
        _imageProvider = null;
      });
    }
  }
}
