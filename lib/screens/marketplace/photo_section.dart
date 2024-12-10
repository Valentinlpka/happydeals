import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class PhotoSection extends StatefulWidget {
  const PhotoSection({super.key});

  @override
  PhotoSectionState createState() => PhotoSectionState();
}

class PhotoSectionState extends State<PhotoSection> {
  final List<dynamic> _photos = [];

  List<dynamic> getPhotos() {
    return List.from(_photos);
  }

  void setExistingPhotos(List<String> existingPhotoUrls) {
    setState(() {
      _photos.clear();
      _photos.addAll(existingPhotoUrls.map((url) => url as dynamic));
    });
  }

  Widget buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ReorderableGridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _photos.length + 1,
          itemBuilder: (context, index) {
            if (index == _photos.length) {
              return addPhotoButton(key: const ValueKey('add_photo_button'));
            }
            return buildPhotoItem(_photos[index], index,
                key: ValueKey(_photos[index]));
          },
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              if (oldIndex < _photos.length && newIndex < _photos.length) {
                final item = _photos.removeAt(oldIndex);
                _photos.insert(newIndex, item);
              }
            });
          },
        ),
      ],
    );
  }

  Widget buildPhotoItem(dynamic photo, int index, {required Key key}) {
    return MouseRegion(
      key: key,
      child: Stack(
        children: [
          buildPhotoWidget(photo),
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: 1.0,
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: () => removePhoto(index),
                    ),
                    const Text("Appuyer pour l'ordre",
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPhotoWidget(dynamic photo) {
    if (photo is XFile) {
      return Image.file(File(photo.path), fit: BoxFit.cover);
    } else if (photo is Uint8List) {
      return Image.memory(photo, fit: BoxFit.cover);
    } else if (photo is String) {
      return Image.network(photo, fit: BoxFit.cover);
    } else {
      return Container(color: Colors.grey);
    }
  }

  Widget addPhotoButton({required Key key}) {
    return ElevatedButton(
      key: key,
      onPressed: addPhoto,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.zero,
      ),
      child: const Icon(Icons.add_a_photo, size: 40),
    );
  }

  void addPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (kIsWeb) {
          image.readAsBytes().then((bytes) {
            setState(() {
              _photos.add(bytes);
            });
          });
        } else {
          _photos.add(image);
        }
      });
    }
  }

  void removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return buildPhotoSection();
  }
}
