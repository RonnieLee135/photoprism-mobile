import 'package:drag_select_grid_view/drag_select_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photoprism/api/api.dart';
import 'package:photoprism/common/album_manager.dart';
import 'package:photoprism/common/hexcolor.dart';
import 'package:photoprism/common/photo_manager.dart';
import 'package:photoprism/common/transparent_route.dart';
import 'package:photoprism/model/moments_time.dart';
import 'package:photoprism/model/photoprism_model.dart';
import 'package:photoprism/pages/photoview.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'package:photoprism/widgets/lazy_tile.dart';
import 'package:photoprism/widgets/selectable_tile.dart';
import 'package:provider/provider.dart';

class PhotosPage extends StatelessWidget {
  final ScrollController _scrollController;
  final String albumId;

  PhotosPage({Key key, this.albumId}) : _scrollController = ScrollController();

  // static Future loadPhotosFromNetworkOrCache(
  //     PhotoprismModel model, String photoprismUrl, String albumId) async {
  //   print("loadPhotosFromNetworkOrCache: AlbumID:" + albumId);
  //   var key = 'photosList';
  //   key += albumId;
  //   SharedPreferences sp = await SharedPreferences.getInstance();
  //   if (sp.containsKey(key)) {
  //     final parsed =
  //         json.decode(sp.getString(key)).cast<Map<String, dynamic>>();
  //     List<Photo> photoList =
  //         parsed.map<Photo>((json) => Photo.fromJson(json)).toList();
  //     if (albumId == "") {
  //       model.photoprismPhotoManager.setPhotoList(photoList);
  //     } else {
  //       model.photoprismAlbumManager.setPhotoListOfAlbum(photoList, albumId);
  //     }
  //     return;
  //   }
  //   await loadPhotos(model, photoprismUrl, albumId);
  // }

  void _scrollListener() async {
    if (_scrollController.position.extentAfter < 500) {
      //await Photos.loadMorePhotos(
      //    Provider.of<PhotoprismModel>(context), photoprismUrl, albumId);
    }
  }

  Future<int> refreshPhotosPull(BuildContext context) async {
    print('refreshing photos..');
    // final PhotoprismModel model = Provider.of<PhotoprismModel>(context);
    // await PhotosPage.loadPhotos(model, model.photoprismUrl, "");
    // await PhotosPage.loadPhotosFromNetworkOrCache(
    //     model, model.photoprismUrl, "");
    return 0;
  }

  archiveSelectedPhotos(BuildContext context) async {
    List<String> selectedPhotos = [];
    final PhotoprismModel model = Provider.of<PhotoprismModel>(context);

    model.gridController.selection.selectedIndexes.forEach((element) {
      selectedPhotos
          .add(PhotoManager.getPhotos(context, "")[element].photoUUID);
    });
    PhotoManager.archivePhotos(context, selectedPhotos, albumId);
  }

  _selectAlbumDialog(BuildContext context) {
    PhotoprismModel model = Provider.of<PhotoprismModel>(context);

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Select album'),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                  itemCount: model.albums.length,
                  itemBuilder: (BuildContext ctxt, int index) {
                    return GestureDetector(
                        onTap: () {
                          addPhotosToAlbum(model.albums[index].id, context);
                        },
                        child: Card(
                            child: ListTile(
                                title: Text(model.albums[index].name))));
                  }),
            ),
          );
        });
  }

  addPhotosToAlbum(albumId, context) async {
    Navigator.pop(context);

    final PhotoprismModel model = Provider.of<PhotoprismModel>(context);
    List<String> selectedPhotos = [];

    model.gridController.selection.selectedIndexes.forEach((element) {
      selectedPhotos
          .add(PhotoManager.getPhotos(context, "")[element].photoUUID);
    });

    model.gridController.clear();
    AlbumManager.addPhotosToAlbum(context, albumId, selectedPhotos);
  }

  Text getMonthFromOffset(BuildContext context, double offset) {
    double currentPhoto = PhotoManager.getPhotosCount(context, albumId) *
        _scrollController.offset /
        (_scrollController.position.maxScrollExtent -
            _scrollController.position.minScrollExtent);
    for (MomentsTime m in PhotoManager.getCummulativeMonthCount(context)) {
      if (m.count >= currentPhoto) {
        return Text("${m.month}/${m.year}");
      }
    }

    return Text("");
  }

  @override
  Widget build(BuildContext context) {
    final PhotoprismModel model = Provider.of<PhotoprismModel>(context);
    DragSelectGridViewController gridController =
        Provider.of<PhotoprismModel>(context)
            .photoprismCommonHelper
            .getGridController();

    _scrollController.addListener(_scrollListener);

    if (model.momentsTime.length == 0) {
      Api.loadMomentsTime(context);
      return Text("", key: ValueKey("photosGridView"));
    }

    int tileCount = PhotoManager.getPhotosCount(context, albumId);

    //if (Photos.getPhotoList(context, albumId).length == 0) {
    //  return IconButton(onPressed: () => {}, icon: Icon(Icons.add));
    //}
    return Scaffold(
        appBar: albumId == ""
            ? AppBar(
                title: model.gridController.selection.selectedIndexes.length > 0
                    ? Text(model.gridController.selection.selectedIndexes.length
                        .toString())
                    : Text("PhotoPrism"),
                backgroundColor: HexColor(model.applicationColor),
                leading:
                    model.gridController.selection.selectedIndexes.length > 0
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              model.gridController.selection = Selection({});
                            },
                          )
                        : null,
                actions:
                    model.gridController.selection.selectedIndexes.length > 0
                        ? <Widget>[
                            IconButton(
                              icon: const Icon(Icons.archive),
                              tooltip: 'Archive photos',
                              onPressed: () {
                                archiveSelectedPhotos(context);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              tooltip: 'Add to album',
                              onPressed: () {
                                _selectAlbumDialog(context);
                              },
                            ),
                          ]
                        : <Widget>[
                            IconButton(
                              icon: const Icon(Icons.cloud_upload),
                              tooltip: 'Upload photo',
                              onPressed: () {
                                model.photoprismUploader
                                    .selectPhotoAndUpload(context);
                              },
                            )
                          ],
              )
            : null,
        body: RefreshIndicator(
            child: OrientationBuilder(builder: (context, orientation) {
          return DraggableScrollbar.semicircle(
            labelTextBuilder: albumId == ""
                ? (double offset) => getMonthFromOffset(context, offset)
                : null,
            heightScrollThumb: 50.0,
            controller: _scrollController,
            child: DragSelectGridView(
                key: ValueKey('photosGridView'),
                scrollController: _scrollController,
                gridController: gridController,
                physics: AlwaysScrollableScrollPhysics(),
                gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: orientation == Orientation.portrait ? 3 : 6,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: tileCount,
                itemBuilder: (context, index, selected) {
                  return SelectableTile(
                      key: ValueKey("PhotoTile"),
                      index: index,
                      context: context,
                      gridController: gridController,
                      selected: selected,
                      onTap: () {
                        Provider.of<PhotoprismModel>(context)
                            .photoprismCommonHelper
                            .setPhotoViewScaleState(
                                PhotoViewScaleState.initial);
                        Navigator.push(
                            context,
                            TransparentRoute(
                              builder: (context) =>
                                  FullscreenPhotoGallery(index, albumId),
                            ));
                      },
                      child: Hero(
                        tag: index.toString(),
                        createRectTween: (begin, end) {
                          return RectTween(begin: begin, end: end);
                        },
                        child: LazyTile(
                          index: index,
                          albumId: albumId,
                        ),
                      ));
                }),
          );
        }), onRefresh: () async {
          return await refreshPhotosPull(context);
        }));
  }
}
