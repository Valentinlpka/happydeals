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
    return ReorderableGridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _photos.length + (_photos.length < 5 ? 1 : 0),
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
    );
  }

  Widget buildPhotoItem(dynamic photo, int index, {required Key key}) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: buildPhotoWidget(photo),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.4),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: Colors.white,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () => removePhoto(index),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Photo ${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
      return Image.file(
        File(photo.path),
        fit: BoxFit.cover,
      );
    } else if (photo is Uint8List) {
      return Image.memory(
        photo,
        fit: BoxFit.cover,
      );
    } else if (photo is String) {
      return Image.network(
        photo,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[100],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: Colors.grey[400],
              ),
            ),
          );
        },
      );
    }
    return Container(color: Colors.grey[100]);
  }

  Widget addPhotoButton({required Key key}) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          style: BorderStyle.solid,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: addPhoto,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                size: 32,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 8),
              Text(
                'Ajouter',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
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
