import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:insaat_takip/services/supabase_service.dart';
import 'package:insaat_takip/models/element_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

class ElementScreen extends StatefulWidget {
  final String elementId;

  const ElementScreen({super.key, required this.elementId});

  @override
  State<ElementScreen> createState() => _ElementScreenState();
}

class _ElementScreenState extends State<ElementScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  ElementModel? _element;
  bool _isLoading = true;
  List<PhotoModel> _photos = [];
  final ImagePicker _picker = ImagePicker();
  List<CameraDescription>? cameras;

  @override
  void initState() {
    super.initState();
    _loadElement();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kamera başlatılamadı: $e'),
          ),
        );
      }
    }
  }

  Future<void> _loadElement() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Eleman verileri çekilecek
      final elements = await _supabaseService.getFloorElements('dummy-floor-id');
      
      if (!mounted) return;
      
      _element = elements.isEmpty
          ? ElementModel(
              id: widget.elementId,
              name: 'Örnek Eleman',
              floorId: 'dummy-floor-id',
              createdAt: DateTime.now(),
              photos: [],
            )
          : elements.first;
          
      // Fotoğrafları ayrıca yükle
      if (_element != null && _element!.photos != null) {
        _photos = _element!.photos!;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eleman verileri yüklenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Fotoğrafları yeniden yükle
  Future<void> _loadPhotos() async {
    if (!mounted || _element == null) return;
    
    try {
      final elements = await _supabaseService.getFloorElements(_element!.floorId);
      
      if (!mounted) return;
      
      // Elementler içinden bu elementin fotoğraflarını bul
      final currentElement = elements.firstWhere(
        (e) => e.id == _element!.id,
        orElse: () => _element!,
      );
      
      setState(() {
        if (currentElement.photos != null) {
          _photos = currentElement.photos!;
          _element = currentElement;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraflar yüklenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    if (kIsWeb) {
      // Web platformunda
      try {
        final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
        if (photo != null) {
          await _uploadPhoto(photo);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fotoğraf seçilemedi: $e'),
            ),
          );
        }
      }
    } else {
      // Mobil platformda
      try {
        // Kameraların hazır olup olmadığını kontrol et
        if (cameras == null || cameras!.isEmpty) {
          await _initializeCamera();
          if (cameras == null || cameras!.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kullanılabilir kamera bulunamadı. Kamera izinlerini kontrol edin.'),
                ),
              );
            }
            return;
          }
        }
        
        // Kamera izinlerini kontrol et
        var status = await Permission.camera.status;
        if (!status.isGranted) {
          status = await Permission.camera.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kamera izni verilmedi.'),
                ),
              );
            }
            return;
          }
        }
        
        // Kameradan fotoğraf çek
        final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
        if (photo != null) {
          await _uploadPhoto(photo);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fotoğraf çekilemedi: $e'),
            ),
          );
        }
      }
    }
  }

  // Fotoğraf yükleme işlevi
  Future<void> _uploadPhoto(XFile photo) async {
    if (!mounted || _element == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final String uuid = const Uuid().v4();
      final String filePath = '${_element!.id}/$uuid${photo.name.split('.').last.isNotEmpty ? ".${photo.name.split('.').last}" : ".jpg"}';
      
      // Fotoğrafı yükle
      final url = await _supabaseService.uploadElementPhoto(
        path: filePath,
        file: await photo.readAsBytes(),
        contentType: 'image/${photo.name.split('.').last.isNotEmpty ? photo.name.split('.').last : "jpeg"}',
      );
      
      if (url != null) {
        // Fotoğraf kaydını oluştur
        final newPhoto = PhotoModel(
          id: uuid,
          url: url,
          elementId: _element!.id,
          uploadedAt: DateTime.now(),
          approved: false,
        );
        
        await _supabaseService.createElementPhoto(newPhoto);
        
        // Fotoğraf listesini güncelle
        await _loadPhotos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf yüklenirken hata: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPhotoDetail(PhotoModel photo) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Fotoğraf Detayı'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    Navigator.pop(context);
                    if (value == 'approve') {
                      await _supabaseService.updatePhotoStatus(photo.id, 'ONAY');
                    } else if (value == 'reject') {
                      await _supabaseService.updatePhotoStatus(photo.id, 'RED');
                    }
                    if (mounted) {
                      _loadPhotos();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'approve',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Onayla'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reject',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Reddet'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: photo.url,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.error,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
            if (photo.approved)
              Container(
                color: Colors.green,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'ONAYLANDI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (!photo.approved)
              Container(
                color: Colors.red,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'ONAYLANMADI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isLoading 
          ? const Text('Yükleniyor...') 
          : Text(_element?.name ?? 'Eleman'),
        actions: [
          if (!_isLoading && _element != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadElement();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fotoğraflar',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _photos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Henüz fotoğraf yok',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Fotoğraf eklemek için + butonuna basın',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: _photos.length,
                            itemBuilder: (context, index) {
                              final photo = _photos[index];
                              return InkWell(
                                onTap: () => _showPhotoDetail(photo),
                                child: Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: photo.url,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorWidget: (context, url, error) => const Icon(
                                          Icons.error,
                                          color: Colors.red,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          color: photo.approved
                                              ? Colors.green.withAlpha(178)
                                              : Colors.red.withAlpha(178),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                            horizontal: 8,
                                          ),
                                          child: Text(
                                            photo.approved ? 'ONAY' : 'RED',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePhoto,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
} 