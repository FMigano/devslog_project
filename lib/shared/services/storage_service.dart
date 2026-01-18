import 'dart:typed_data';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

class StorageService {
  Future<PlatformFile?> pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files.first;
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  // Convert image to base64 data URL WITHOUT compression
  String convertImageToBase64(Uint8List imageData, {bool compress = true}) {
    try {
      print('StorageService: Converting image to base64...');
      print('StorageService: Original size: ${imageData.length} bytes');

      if (!compress) {
        // No compression - just convert to base64
        final base64String = base64Encode(imageData);
        final dataUrl = 'data:image/jpeg;base64,$base64String';
        print('StorageService: No compression - Size: ${imageData.length} bytes');
        return dataUrl;
      }

      // Decode image
      img.Image? image = img.decodeImage(imageData);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize if too large (max 1200px width for better quality)
      if (image.width > 1200) {
        print('StorageService: Resizing image...');
        image = img.copyResize(image, width: 1200);
      }

      // Compress as JPEG with quality 90 (higher quality)
      final compressedBytes = img.encodeJpg(image, quality: 90);
      print('StorageService: Compressed size: ${compressedBytes.length} bytes');

      // Convert to base64
      final base64String = base64Encode(compressedBytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';
      
      print('StorageService: Conversion complete');
      return dataUrl;
    } catch (e) {
      print('StorageService ERROR: $e');
      rethrow;
    }
  }

  // For backward compatibility - returns base64 data URL
  Future<String> uploadPostImage(Uint8List imageData, String fileName) async {
    return convertImageToBase64(imageData);
  }

  // For backward compatibility - returns base64 data URL
  Future<String> uploadProfileImage(Uint8List imageData, String userId) async {
    return convertImageToBase64(imageData);
  }

  // No-op for base64 images
  Future<void> deleteImage(String imageUrl) async {
    // Base64 images don't need deletion
    print('StorageService: Base64 image, no deletion needed');
  }
}
