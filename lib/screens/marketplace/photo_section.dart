import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
      _photos.addAll(existingPhotoUrls);
    });
  }

  Widget buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._photos.asMap().entries.map((entry) {
                int idx = entry.key;
                dynamic photo = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      buildPhotoWidget(photo),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => removePhoto(idx),
                        ),
                      ),
                      if (idx > 0)
                        Positioned(
                          left: 0,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => movePhotoLeft(idx),
                          ),
                        ),
                      if (idx < _photos.length - 1)
                        Positioned(
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: () => movePhotoRight(idx),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              ElevatedButton(
                onPressed: addPhoto,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                ),
                child: const Icon(Icons.add_a_photo),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildPhotoWidget(dynamic photo) {
    if (photo is XFile) {
      return Image.network(photo.path,
          width: 100, height: 100, fit: BoxFit.cover);
    } else if (photo is Uint8List) {
      return Image.memory(photo, width: 100, height: 100, fit: BoxFit.cover);
    } else if (photo is String) {
      // Pour les URLs des photos existantes
      return Image.network(photo, width: 100, height: 100, fit: BoxFit.cover);
    } else {
      return Container(width: 100, height: 100, color: Colors.grey);
    }
  }

  void addPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _photos.add(bytes);
        });
      } else {
        setState(() {
          _photos.add(image);
        });
      }
    }
  }

  void removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  void movePhotoLeft(int index) {
    if (index > 0) {
      setState(() {
        var photo = _photos.removeAt(index);
        _photos.insert(index - 1, photo);
      });
    }
  }

  void movePhotoRight(int index) {
    if (index < _photos.length - 1) {
      setState(() {
        var photo = _photos.removeAt(index);
        _photos.insert(index + 1, photo);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildPhotoSection();
  }
}
