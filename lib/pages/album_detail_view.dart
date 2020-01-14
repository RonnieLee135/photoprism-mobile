import 'package:drag_select_grid_view/drag_select_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:photoprism/api/albums.dart';
import 'package:photoprism/api/api.dart';
import 'package:photoprism/api/photos.dart';
import 'package:photoprism/common/hexcolor.dart';
import 'package:photoprism/model/album.dart';
import 'package:photoprism/model/photo.dart';
import 'package:photoprism/model/photoprism_model.dart';
import 'package:provider/provider.dart';

class AlbumDetailView extends StatelessWidget {
  PhotoprismModel _model;
  final Album _album;
  final TextEditingController _renameAlbumTextFieldController;

  AlbumDetailView(this._album)
      : _renameAlbumTextFieldController = new TextEditingController();

  void renameAlbum(BuildContext context) async {
    // close rename dialog
    Navigator.pop(context);

    List<Album> albums = Albums.getAlbumList(context);
    String oldAlbumName = _album.name;

    // rename album name in local album list
    for (var i = 0; i < albums.length; i++) {
      if (albums[i].id == _album.id) {
        albums[i].name = _renameAlbumTextFieldController.text;
      }
    }
    _model.notifyListeners();

    // rename remote album
    var status = await Api.renameAlbum(
        _album.id, _renameAlbumTextFieldController.text, _model.photoprismUrl);

    // check renaming success
    // if renaming failed, local album name will be renamed to original name
    if (status != 0) {
      for (var i = 0; i < albums.length; i++) {
        if (albums[i].id == _album.id) {
          albums[i].name = oldAlbumName;
        }
      }
      _model.notifyListeners();
      _model.photoprismMessage.showMessage("Renaming album failed.");
    }
  }

  void deleteAlbum(BuildContext context) async {
    // close delete dialog
    Navigator.pop(context);

    // delete remote album
    var status = await Api.deleteAlbum(_album.id, _model.photoprismUrl);

    // check if successful
    if (status != 0) {
      _model.photoprismMessage.showMessage("Deleting album failed.");
    } else {
      // go back to albums view
      Navigator.pop(context);

      // remove local album from album list
      List<Album> albums = Albums.getAlbumList(context);
      for (var i = 0; i < albums.length; i++) {
        if (albums[i].id == _album.id) {
          albums.removeAt(i);
        }
      }
      _model.photoprismAlbumManager.setAlbumList(albums);
      _model.notifyListeners();
    }
  }

  void _removePhotosFromAlbum(BuildContext context) async {
    // save all selected photos in list
    List<String> selectedPhotos = [];
    _model.gridController.selection.selectedIndexes.forEach((element) {
      selectedPhotos
          .add(Photos.getPhotoList(context, _album.id)[element].photoUUID);
    });

    // remove remote photos from album
    var status = await Api.removePhotosFromAlbum(
        _album.id, selectedPhotos, _model.photoprismUrl);

    // check if successful
    if (status != 0) {
      _model.photoprismMessage
          .showMessage("Removing photos from album failed.");
    } else {
      // create new photo list for current album without removed photos
      List<Photo> photosOfAlbum = Photos.getPhotoList(context, _album.id);
      List<Photo> photosOfAlbumNew = [];
      for (var i = 0; i < photosOfAlbum.length; i++) {
        if (!selectedPhotos.contains(photosOfAlbum[i].photoUUID)) {
          photosOfAlbumNew.add(photosOfAlbum[i]);
        }
      }
      _model.photoprismAlbumManager
          .setPhotoListOfAlbum(photosOfAlbumNew, _album.id);

      // update image count of local album
      List<Album> albums = Albums.getAlbumList(context);
      Album currentAlbum;
      for (var i = 0; i < albums.length; i++) {
        if (albums[i].id == _album.id) {
          currentAlbum = albums[i];
        }
      }
      currentAlbum.imageCount = currentAlbum.imageCount - selectedPhotos.length;
    }
    _model.notifyListeners();
    // deselect selected photos
    _model.gridController.clear();
  }

  @override
  Widget build(BuildContext context) {
    this._model = Provider.of<PhotoprismModel>(context);
    int _selectedPhotosCount =
        _model.gridController.selection.selectedIndexes.length;
    return Scaffold(
      appBar: AppBar(
        title: _selectedPhotosCount > 0
            ? Text(_selectedPhotosCount.toString())
            : Text(_album.name),
        leading: _selectedPhotosCount > 0
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _model.gridController.selection = Selection({});
                },
              )
            : null,
        actions: _selectedPhotosCount > 0
            ? <Widget>[
                PopupMenuButton<int>(
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem(
                      value: 2,
                      child: Text("Remove from album"),
                    ),
                  ],
                  onSelected: (choice) {
                    _removePhotosFromAlbum(context);
                  },
                ),
              ]
            : <Widget>[
                // overflow menu
                PopupMenuButton<int>(
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem(
                      value: 0,
                      child: Text("Rename album"),
                    ),
                    PopupMenuItem(
                      value: 1,
                      child: Text("Delete album"),
                    ),
                  ],
                  onSelected: (choice) {
                    if (choice == 0) {
                      _showRenameAlbumDialog(context);
                    } else if (choice == 1) {
                      _showDeleteAlbumDialog(context);
                    }
                  },
                ),
              ],
      ),
      body: Photos(context: context, albumId: _album.id),
    );
  }

  _showRenameAlbumDialog(BuildContext context) async {
    _renameAlbumTextFieldController.text = _album.name;
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Rename album'),
            content: TextField(
              controller: _renameAlbumTextFieldController,
            ),
            actions: <Widget>[
              FlatButton(
                child: Text('Cancel'),
                textColor: HexColor(_model.applicationColor),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              FlatButton(
                child: Text('Rename album'),
                textColor: HexColor(_model.applicationColor),
                onPressed: () {
                  renameAlbum(context);
                },
              )
            ],
          );
        });
  }

  _showDeleteAlbumDialog(BuildContext context) async {
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Delete album?'),
            content: Text(
                'Are you sure you want to delete this album? Your photos will not be deleted.'),
            actions: <Widget>[
              FlatButton(
                child: Text('Cancel'),
                textColor: HexColor(_model.applicationColor),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              FlatButton(
                child: Text('Delete album'),
                textColor: HexColor(_model.applicationColor),
                onPressed: () {
                  deleteAlbum(context);
                },
              )
            ],
          );
        });
  }
}
