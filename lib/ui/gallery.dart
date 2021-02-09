import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:huge_listview/huge_listview.dart';
import 'package:logging/logging.dart';
import 'package:photos/events/event.dart';
import 'package:photos/models/file.dart';
import 'package:photos/models/selected_files.dart';
import 'package:photos/ui/common_elements.dart';
import 'package:photos/ui/detail_page.dart';
import 'package:photos/ui/gallery_app_bar_widget.dart';
import 'package:photos/ui/loading_widget.dart';
import 'package:photos/ui/thumbnail_widget.dart';
import 'package:photos/utils/date_time_util.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class Gallery extends StatefulWidget {
  final List<File> Function() syncLoader;
  final Future<List<File>> Function(int creationStartTime, int creationEndTime,
      {int limit}) asyncLoader;
  final Future<List<int>> allCreationTimesFuture;
  final bool shouldLoadAll;
  final Stream<Event> reloadEvent;
  final SelectedFiles selectedFiles;
  final String tagPrefix;
  final Widget headerWidget;
  final bool isHomePageGallery;

  Gallery({
    this.syncLoader,
    this.allCreationTimesFuture,
    this.asyncLoader,
    this.shouldLoadAll = false,
    this.reloadEvent,
    this.headerWidget,
    @required this.selectedFiles,
    @required this.tagPrefix,
    this.isHomePageGallery = false,
  });

  @override
  _GalleryState createState() {
    return _GalleryState();
  }
}

class _GalleryState extends State<Gallery> with TickerProviderStateMixin {
  static final int kLoadLimit = 200;
  static final int kEagerLoadTrigger = 10;

  final Logger _logger = Logger("Gallery");
  final List<List<File>> _collatedFiles = List<List<File>>();
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();
  final _scrollKey = GlobalKey<DraggableScrollbarState>();

  ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  bool _requiresLoad = false;
  bool _hasLoadedAll = false;
  bool _isLoadingNext = false;
  bool _hasDraggableScrollbar = false;
  List<File> _files;
  int _lastIndex = 0;

  @override
  void initState() {
    _requiresLoad = true;
    if (widget.reloadEvent != null) {
      widget.reloadEvent.listen((event) {
        _logger.info("Building gallery because reload event fired updated");
        if (mounted) {
          setState(() {
            _cache.clear();
            _requiresLoad = true;
          });
        }
      });
    }
    widget.selectedFiles.addListener(() {
      _logger.info("Building gallery because selected files updated");
      setState(() {
        _requiresLoad = false;
        if (!_hasDraggableScrollbar) {
          _saveScrollPosition();
        }
      });
    });
    if (widget.asyncLoader == null || widget.shouldLoadAll) {
      _hasLoadedAll = true;
    }
    _itemPositionsListener.itemPositions.addListener(_updateScrollbar);
    super.initState();
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_updateScrollbar);
    super.dispose();
  }

  int kPageSize = 10;
  final _cache = Map<int, Future<List<List<File>>>>();

  @override
  Widget build(BuildContext context) {
    _logger.info("Building " + widget.tagPrefix);
    return FutureBuilder(
      future: widget.allCreationTimesFuture,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          final creationTimes = snapshot.data;
          final collatedTimes = _collateCreationTimes(creationTimes);
          _logger.info("Days fetched " + collatedTimes.length.toString());
          return HugeListView<List<File>>(
            key: _hugeListViewKey,
            controller: ItemScrollController(),
            pageSize: kPageSize,
            startIndex: _pageIndex,
            totalCount: collatedTimes.length,
            pageFuture: (pageIndex) {
              _logger.info("Loading page " + pageIndex.toString());
              _pageIndex = pageIndex;
              if (!_cache.containsKey(pageIndex)) {
                final endTimeIndex =
                    min(pageIndex * kPageSize, collatedTimes.length - 1);
                final endTime = collatedTimes[endTimeIndex][0];
                final startTimeIndex =
                    min((pageIndex + 1) * kPageSize, collatedTimes.length - 1);
                final startTime = collatedTimes[startTimeIndex]
                    [collatedTimes[startTimeIndex].length - 1];
                _cache[pageIndex] = widget
                    .asyncLoader(startTime, endTime)
                    .then((files) => _clubFiles(files));
              }
              return _cache[pageIndex];
            },
            placeholderBuilder: (context, pageIndex) {
              var index = min(pageIndex * kPageSize, collatedTimes.length - 1);
              var day = _getDay(collatedTimes[index][0]);
              return PlaceHolderWidget(
                  day: day, count: collatedTimes[index].length);
            },
            waitBuilder: (_) {
              return loadWidget;
            },
            emptyResultBuilder: (_) {
              return nothingToSeeHere;
            },
            itemBuilder: (context, index, files) {
              return Column(
                children: <Widget>[
                  _getDay(files[0].creationTime),
                  _getGallery(files)
                ],
              );
            },
            thumbBuilder: (Color backgroundColor, Color drawColor,
                double height, int index) {
              final monthAndYear = getMonthAndYear(
                  DateTime.fromMicrosecondsSinceEpoch(collatedTimes[index][0]));
              return ScrollBarThumb(
                  backgroundColor, drawColor, height, monthAndYear);
            },
            velocityThreshold: 128,
          );
        } else {
          return loadWidget;
        }
      },
    );
  }

  int _pageIndex = 0;
  final _hugeListViewKey = GlobalKey<HugeListViewState>();

  // Widget _onDataLoaded() {
  //   _logger.info("Data loaded");
  //   if (_files.isEmpty) {
  //     final children = List<Widget>();
  //     if (widget.headerWidget != null) {
  //       children.add(widget.headerWidget);
  //     }
  //     children.add(Expanded(child: nothingToSeeHere));
  //     return CustomScrollView(
  //       slivers: [
  //         SliverFillRemaining(
  //           hasScrollBody: false,
  //           child: Column(
  //             mainAxisAlignment: MainAxisAlignment.spaceAround,
  //             children: children,
  //           ),
  //         )
  //       ],
  //     );
  //   }
  //   _collateFiles();
  //   final itemCount =
  //       _collatedFiles.length + (widget.headerWidget == null ? 1 : 2);
  //   _hasDraggableScrollbar = itemCount > 25 || _files.length > 50;
  //   var gallery;
  // if (!_hasDraggableScrollbar) {
  //   _scrollController = ScrollController(initialScrollOffset: _scrollOffset);
  //   gallery = ListView.builder(
  //     itemCount: itemCount,
  //     itemBuilder: _buildListItem,
  //     controller: _scrollController,
  //     cacheExtent: 1500,
  //     addAutomaticKeepAlives: true,
  //   );
  //   return gallery;
  // }
  // gallery = DraggableScrollbar.semicircle(
  //   key: _scrollKey,
  //   initialScrollIndex: _lastIndex,
  //   labelTextBuilder: (position) {
  //     final index =
  //         min((position * itemCount).floor(), _collatedFiles.length - 1);
  //     return Text(
  //       getMonthAndYear(DateTime.fromMicrosecondsSinceEpoch(
  //           _collatedFiles[index][0].creationTime)),
  //       style: TextStyle(
  //         color: Colors.black,
  //         backgroundColor: Colors.white,
  //         fontSize: 14,
  //       ),
  //     );
  //   },
  //   labelConstraints: BoxConstraints.tightFor(width: 100.0, height: 36.0),
  //   onChange: (position) {
  //     final index =
  //         min((position * itemCount).floor(), _collatedFiles.length - 1);
  //     if (index == _lastIndex) {
  //       return;
  //     }
  //     _lastIndex = index;
  //     _itemScrollController.jumpTo(index: index);
  //   },
  //   child: ScrollablePositionedList.builder(
  //     itemCount: itemCount,
  //     itemBuilder: _buildListItem,
  //     itemScrollController: _itemScrollController,
  //     initialScrollIndex: _lastIndex,
  //     minCacheExtent: 1500,
  //     addAutomaticKeepAlives: true,
  //     physics: _MaxVelocityPhysics(velocityThreshold: 128),
  //     itemPositionsListener: _itemPositionsListener,
  //   ),
  //   itemCount: itemCount,
  // );
  //   if (widget.isHomePageGallery) {
  //     gallery = Container(
  //       margin: const EdgeInsets.only(bottom: 50),
  //       child: gallery,
  //     );
  //     if (widget.selectedFiles.files.isNotEmpty) {
  //       gallery = Stack(children: [
  //         gallery,
  //         Container(
  //           height: 60,
  //           child: GalleryAppBarWidget(
  //             GalleryAppBarType.homepage,
  //             null,
  //             widget.selectedFiles,
  //           ),
  //         ),
  //       ]);
  //     }
  //   }
  //   return gallery;
  // }

  // Widget _buildListItem(BuildContext context, int index) {
  //   // if (_shouldLoadNextItems(index)) {
  //   //   // Eagerly load next batch
  //   //   _loadNextItems();
  //   // }
  //   var fileIndex;
  //   if (widget.headerWidget != null) {
  //     if (index == 0) {
  //       return widget.headerWidget;
  //     }
  //     fileIndex = index - 1;
  //   } else {
  //     fileIndex = index;
  //   }
  //   if (fileIndex == _collatedFiles.length) {
  //     if (widget.asyncLoader != null) {
  //       if (!_hasLoadedAll) {
  //         return loadWidget;
  //       } else {
  //         return Container();
  //       }
  //     }
  //   }
  //   if (fileIndex < 0 || fileIndex >= _collatedFiles.length) {
  //     return Container();
  //   }
  //   var files = _collatedFiles[fileIndex];
  //   return Column(
  //     children: <Widget>[_getDay(files[0].creationTime), _getGallery(files)],
  //   );
  // }

  // // bool _shouldLoadNextItems(int index) =>
  // //     widget.asyncLoader != null &&
  // //     !_isLoadingNext &&
  // //     (index >= _collatedFiles.length - kEagerLoadTrigger) &&
  // //     !_hasLoadedAll;

  // // void _loadNextItems() {
  // //   _isLoadingNext = true;
  // //   widget.asyncLoader(_files[_files.length - 1], kLoadLimit).then((files) {
  // //     setState(() {
  // //       _isLoadingNext = false;
  // //       _saveScrollPosition();
  // //       if (files.length < kLoadLimit) {
  // //         _hasLoadedAll = true;
  // //       }
  // //       _files.addAll(files);
  // //     });
  // //   });
  // // }

  void _saveScrollPosition() {
    _scrollOffset = _scrollController.offset;
  }

  Widget _getDay(int timestamp) {
    String title = _getDayTitle(timestamp);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 0, 8),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(fontSize: 16),
      ),
    );
  }

  String _getDayTitle(int timestamp) {
    final date = DateTime.fromMicrosecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    var title = getDayAndMonth(date);
    if (date.year == now.year && date.month == now.month) {
      if (date.day == now.day) {
        title = "Today";
      } else if (date.day == now.day - 1) {
        title = "Yesterday";
      }
    }
    if (date.year != DateTime.now().year) {
      title += " " + date.year.toString();
    }
    return title;
  }

  Widget _getGallery(List<File> files) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.only(bottom: 12),
      physics:
          NeverScrollableScrollPhysics(), // to disable GridView's scrolling
      itemBuilder: (context, index) {
        return _buildFile(context, files[index]);
      },
      itemCount: files.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
      ),
    );
  }

  Widget _buildFile(BuildContext context, File file) {
    return GestureDetector(
      onTap: () {
        if (widget.selectedFiles.files.isNotEmpty) {
          _selectFile(file);
        } else {
          _routeToDetailPage(file, context);
        }
      },
      onLongPress: () {
        HapticFeedback.lightImpact();
        _selectFile(file);
      },
      child: Container(
        margin: const EdgeInsets.all(2.0),
        decoration: BoxDecoration(
          border: widget.selectedFiles.files.contains(file)
              ? Border.all(
                  width: 4.0,
                  color: Theme.of(context).accentColor,
                )
              : null,
        ),
        child: Hero(
          tag: widget.tagPrefix + file.tag(),
          child: ThumbnailWidget(file),
        ),
      ),
    );
  }

  void _selectFile(File file) {
    widget.selectedFiles.toggleSelection(file);
  }

  void _routeToDetailPage(File file, BuildContext context) {
    final page = DetailPage(
      _files,
      _files.indexOf(file),
      widget.tagPrefix,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return page;
        },
      ),
    );
  }

  void _collateFiles() {
    final dailyFiles = List<File>();
    final collatedFiles = List<List<File>>();
    for (int index = 0; index < _files.length; index++) {
      if (index > 0 &&
          !_areFromSameDay(
              _files[index - 1].creationTime, _files[index].creationTime)) {
        final collatedDailyFiles = List<File>();
        collatedDailyFiles.addAll(dailyFiles);
        collatedFiles.add(collatedDailyFiles);
        dailyFiles.clear();
      }
      dailyFiles.add(_files[index]);
    }
    if (dailyFiles.isNotEmpty) {
      collatedFiles.add(dailyFiles);
    }
    _collatedFiles.clear();
    _collatedFiles.addAll(collatedFiles);
  }

  List<List<File>> _clubFiles(List<File> files) {
    final dailyFiles = List<File>();
    final collatedFiles = List<List<File>>();
    for (int index = 0; index < files.length; index++) {
      if (index > 0 &&
          !_areFromSameDay(
              files[index - 1].creationTime, files[index].creationTime)) {
        final collatedDailyFiles = List<File>();
        collatedDailyFiles.addAll(dailyFiles);
        collatedFiles.add(collatedDailyFiles);
        dailyFiles.clear();
      }
      dailyFiles.add(files[index]);
    }
    if (dailyFiles.isNotEmpty) {
      collatedFiles.add(dailyFiles);
    }
    return collatedFiles;
  }

  List<List<int>> _collateCreationTimes(List<int> creationTimes) {
    final dailyTimes = List<int>();
    final collatedTimes = List<List<int>>();
    for (int index = 0; index < creationTimes.length; index++) {
      if (index > 0 &&
          !_areFromSameDay(creationTimes[index - 1], creationTimes[index])) {
        final collatedDailyTimes = List<int>();
        collatedDailyTimes.addAll(dailyTimes);
        collatedTimes.add(collatedDailyTimes);
        dailyTimes.clear();
      }
      dailyTimes.add(creationTimes[index]);
    }
    if (dailyTimes.isNotEmpty) {
      collatedTimes.add(dailyTimes);
    }
    return collatedTimes;
  }

  bool _areFromSameDay(int firstCreationTime, int secondCreationTime) {
    var firstDate = DateTime.fromMicrosecondsSinceEpoch(firstCreationTime);
    var secondDate = DateTime.fromMicrosecondsSinceEpoch(secondCreationTime);
    return firstDate.year == secondDate.year &&
        firstDate.month == secondDate.month &&
        firstDate.day == secondDate.day;
  }

  void _updateScrollbar() {
    final index = _itemPositionsListener.itemPositions.value.first.index;
    _lastIndex = index;
    _scrollKey.currentState?.setPosition(index / _collatedFiles.length);
  }
}

class PlaceHolderWidget extends StatelessWidget {
  const PlaceHolderWidget({
    Key key,
    @required this.day,
    @required this.count,
  }) : super(key: key);

  final Widget day;
  final int count;

  static final _gridViewCache = Map<int, GridView>();

  @override
  Widget build(BuildContext context) {
    if (!_gridViewCache.containsKey(count)) {
      _gridViewCache[count] = GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.only(bottom: 12),
        physics: NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.all(2.0),
            color: Colors.grey[800],
          );
        },
        itemCount: count,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
        ),
      );
    }
    return Column(
      children: <Widget>[
        day,
        _gridViewCache[count],
      ],
    );
  }
}

class ScrollBarThumb extends StatelessWidget {
  final backgroundColor;
  final drawColor;
  final height;
  final title;

  const ScrollBarThumb(
    this.backgroundColor,
    this.drawColor,
    this.height,
    this.title, {
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withOpacity(0.8),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.black,
              backgroundColor: Colors.transparent,
              fontSize: 14,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(2),
        ),
        CustomPaint(
          foregroundPainter: _ArrowCustomPainter(drawColor),
          child: Material(
            elevation: 4.0,
            child: Container(
                constraints: BoxConstraints.tight(Size(height * 0.6, height))),
            color: backgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(height),
              bottomLeft: Radius.circular(height),
              topRight: Radius.circular(4.0),
              bottomRight: Radius.circular(4.0),
            ),
          ),
        ),
      ],
    );
  }
}

class _MaxVelocityPhysics extends AlwaysScrollableScrollPhysics {
  final double velocityThreshold;

  _MaxVelocityPhysics({@required this.velocityThreshold, ScrollPhysics parent})
      : super(parent: parent);

  @override
  bool recommendDeferredLoading(
      double velocity, ScrollMetrics metrics, BuildContext context) {
    return velocity.abs() > velocityThreshold;
  }

  @override
  _MaxVelocityPhysics applyTo(ScrollPhysics ancestor) {
    return _MaxVelocityPhysics(
        velocityThreshold: velocityThreshold, parent: buildParent(ancestor));
  }
}

class _ArrowCustomPainter extends CustomPainter {
  final Color drawColor;

  _ArrowCustomPainter(this.drawColor);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = drawColor;
    const width = 12.0;
    const height = 8.0;
    final baseX = size.width / 2;
    final baseY = size.height / 2;

    canvas.drawPath(
        trianglePath(Offset(baseX - 4.0, baseY - 2.0), width, height, true),
        paint);
    canvas.drawPath(
        trianglePath(Offset(baseX - 4.0, baseY + 2.0), width, height, false),
        paint);
  }

  static Path trianglePath(
      Offset offset, double width, double height, bool isUp) {
    return Path()
      ..moveTo(offset.dx, offset.dy)
      ..lineTo(offset.dx + width, offset.dy)
      ..lineTo(offset.dx + (width / 2),
          isUp ? offset.dy - height : offset.dy + height)
      ..close();
  }
}
