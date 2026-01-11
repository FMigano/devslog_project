import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final image = await _picker.pickImage(source: source);
      return image;
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadImage(Uint8List imageData, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putData(
        imageData,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadPostImage(Uint8List imageData, String postId) async {
    return uploadImage(imageData, 'posts/$postId/${DateTime.now().millisecondsSinceEpoch}.jpg');
  }

  Future<String?> uploadProfileImage(Uint8List imageData, String userId) async {
    return uploadImage(imageData, 'profiles/$userId/avatar.jpg');
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Handle error
    }
  }
}
