import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:insaat_takip/services/supabase_service.dart';
import 'package:insaat_takip/models/element_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path/path.dart' as path_lib;

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
  String? _currentUserId; // Kullanıcı ID'si
  bool _hasApprovalPermission = false; // Onaylama yetkisi
  String? _projectId; // Elemanın bağlı olduğu projenin ID'si

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
      // Önce doğrudan elementId ile elementi çekelim
      final element = await _supabaseService.getElementById(widget.elementId);
      
      if (!mounted) return;
      
      if (element != null) {
        _element = element;
        
        // Elementin bağlı olduğu kattan projeye ulaşalım
        final floor = await _supabaseService.getFloorById(element.floorId);
        if (floor != null) {
          _projectId = floor.projectId;
          
          // Şimdi yetki kontrolü yapabiliriz
          await _checkUserPermissions();
        }
        
        // Elementin fotoğrafları varsa bunları göster
        if (_element!.photos != null) {
          _photos = _element!.photos!;
        } else {
          // Fotoğrafları ayrıca yükleyelim
          final photos = await _supabaseService.getElementPhotos(widget.elementId);
          if (photos.isNotEmpty) {
            setState(() {
              _photos = photos;
            });
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eleman bulunamadı'),
            backgroundColor: Colors.red,
          ),
        );
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
      print('Fotoğraflar yükleniyor. Element ID: ${_element!.id}');
      
      // Kullanıcı izinlerini kontrol et (kullanıcı giriş yapmış olabilir)
      if (_currentUserId == null) {
        await _checkUserPermissions();
      }
      
      // Doğrudan fotoğrafları çek
      final photos = await _supabaseService.getElementPhotos(_element!.id);
      
      if (!mounted) return;
      
      if (photos.isNotEmpty) {
        setState(() {
          _photos = photos;
          print('Fotoğraflar yüklendi: ${photos.length} fotoğraf');
        });
      } else {
        print('Yüklenecek fotoğraf bulunamadı');
      }
    } catch (e) {
      if (mounted) {
        print('Fotoğraf yükleme hatası: $e');
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Web platformunda sadece kamera ile fotoğraf çekimi desteklenmemektedir.'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      // Mobil platformda
      try {
        // Kamera izinlerini kontrol et
        var status = await Permission.camera.status;
        if (!status.isGranted) {
          status = await Permission.camera.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kamera izni verilmedi. Lütfen ayarlardan izin verin.'),
                ),
              );
            }
            return;
          }
        }
        
        // Doğrudan kamerayı aç
        final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1080,
        );
        
        if (photo != null && mounted) {
          await _uploadPhoto(photo);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fotoğraf çekilirken hata oluştu: $e'),
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
      // Yükleme başladı bildirimi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf yükleniyor...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final String uuid = const Uuid().v4();
      final String fileName = '${_element!.id}/${uuid}_${path_lib.basename(photo.path)}';
      
      print('Element ID: ${_element!.id}');
      print('Fotoğraf yükleme hazırlığı:');
      print('- Dosya adı: $fileName');
      
      // Dosyayı byte array'e çevir
      final Uint8List bytes = await photo.readAsBytes();
      
      // Dosya türünü tespit et
      String contentType = 'image/jpeg';
      if (photo.name.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      } else if (photo.name.toLowerCase().endsWith('.gif')) {
        contentType = 'image/gif';
      }
      
      // Supabase'e yükle
      final String? fileUrl = await _supabaseService.uploadElementPhoto(
        path: fileName,
        file: bytes,
        contentType: contentType,
      );
      
      if (fileUrl == null || fileUrl.isEmpty) {
        throw Exception('Fotoğraf depolama alanına yüklenemedi. Lütfen yetkilendirme ayarlarınızı kontrol edin.');
      }
      
      print('Fotoğraf Supabase\'e yüklendi: $fileUrl');
      
      // PhotoModel oluştur
      final newPhoto = PhotoModel(
        id: uuid,
        url: fileUrl,
        elementId: _element!.id,
        uploadedAt: DateTime.now(),
        approved: null, // İlk başta durumu belirsiz olsun
        localPath: null, // Supabase'e yüklediğimiz için yerel yola ihtiyaç yok
      );
      
      // Veritabanına ekle - 'photos' tablosuna kayıt
      // Yeni yapıda tablomuz: (id, status, element_id, url, created_at)
      final savedPhoto = await _supabaseService.createElementPhoto(newPhoto);
      
      if (savedPhoto != null) {
        // Fotoğrafı listemize ekleyelim
        setState(() {
          _photos.add(savedPhoto);
        });
        
        print('Fotoğraf veritabanına kaydedildi: ${savedPhoto.id}');
      } else {
        print('Fotoğraf veritabanına eklenemedi, lütfen RLS politikalarını kontrol edin');
        // Veritabanına ekleme başarısız olsa bile kullanıcının görebilmesi için listeye ekleyelim
        setState(() {
          _photos.add(newPhoto);
        });
      }
      
      // Başarı bildirimi göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf başarıyla yüklendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Fotoğraf yükleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf yüklenirken hata: $e\n\nLütfen bucket yetkilendirme ayarlarınızı kontrol edin'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
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
            ),
            Expanded(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4,
                child: photo.localPath != null && photo.localPath!.isNotEmpty
                  ? Image.file(
                      File(photo.localPath!),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.error,
                        color: Colors.red,
                      ),
                    )
                  : CachedNetworkImage(
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
            Container(
              color: photo.approved == null 
                ? Colors.grey.shade50 
                : (photo.approved == true ? Colors.green.shade50 : Colors.red.shade50),
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  // Onay durumu yazısını herkese göster
                  if (photo.approved != null) 
                    Text(
                      photo.approved == true ? 'ONAYLANMIŞ FOTOĞRAF' : 'ONAYLANMAMIŞ FOTOĞRAF',
                      style: TextStyle(
                        color: photo.approved == true ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  if (photo.approved != null)
                    const SizedBox(height: 12),
                  
                  // Onaylama/Reddetme butonlarını sadece yetkili kullanıcılara göster
                  if (_hasApprovalPermission)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            final updatedPhoto = photo.copyWith(approved: true);
                            _updatePhotoStatus(updatedPhoto);
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          label: const Text('ONAYLA'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade100,
                            foregroundColor: Colors.green.shade900,
                            elevation: photo.approved == true ? 0 : 3,
                            side: photo.approved == true ? BorderSide(color: Colors.green.shade700, width: 2) : null,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            final updatedPhoto = photo.copyWith(approved: false);
                            _updatePhotoStatus(updatedPhoto);
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text('REDDET'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade900,
                            elevation: photo.approved == false ? 0 : 3,
                            side: photo.approved == false ? BorderSide(color: Colors.red.shade700, width: 2) : null,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fotoğraf onay durumunu güncelleme
  void _updatePhotoStatus(PhotoModel updatedPhoto) async {
    setState(() {
      // Fotoğraf listesinde ilgili fotoğrafı güncelle
      final index = _photos.indexWhere((p) => p.id == updatedPhoto.id);
      if (index != -1) {
        _photos[index] = updatedPhoto;
      }
    });
    
    try {
      // Veritabanında fotoğraf durumunu güncelle
      final status = updatedPhoto.approved == true ? 'approved' : 'rejected';
      await _supabaseService.updatePhotoStatus(updatedPhoto.id, status);
      print('Fotoğraf veritabanında güncellendi: ${updatedPhoto.id}, durum: $status');
    } catch (e) {
      print('Fotoğraf durumu güncelleme hatası: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf durumu güncellenirken hata oluştu. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return;
    }
    
    // Yerel fotoğraflar için işlem bittiğinde bildirim göster
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updatedPhoto.approved == true ? 'Fotoğraf onaylandı' : 'Fotoğraf reddedildi'),
          backgroundColor: updatedPhoto.approved == true ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // Kullanıcı izinlerini kontrol et
  Future<void> _checkUserPermissions() async {
    final user = _supabaseService.getCurrentUser();
    if (user == null || _projectId == null) {
      setState(() {
        _currentUserId = null;
        _hasApprovalPermission = false;
      });
      print('Giriş yapmış kullanıcı veya proje ID bulunamadı');
      return;
    }
    
    setState(() {
      _currentUserId = user.id;
    });
    
    // Projede yetkili mi kontrol et
    final hasPermission = await _supabaseService.hasApprovalPermission(_projectId!, user.id);
    
    setState(() {
      _hasApprovalPermission = hasPermission;
    });
    
    print('Kullanıcı: $_currentUserId, Onaylama yetkisi: $_hasApprovalPermission, Proje: $_projectId');
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
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 80,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Henüz fotoğraf yok',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40),
                                  child: Text(
                                    'Fotoğraf eklemek için aşağıdaki kamera butonuna basın',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _takePhoto,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('FOTOĞRAF EKLE'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _photos.length,
                            itemBuilder: (context, index) {
                              final photo = _photos[index];
                              return GestureDetector(
                                onTap: () => _showPhotoDetail(photo),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: photo.localPath != null && photo.localPath!.isNotEmpty
                                        ? Image.file(
                                            File(photo.localPath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child: Icon(
                                                  Icons.error_outline,
                                                  color: Colors.red,
                                                  size: 40,
                                                ),
                                              ),
                                            ),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: photo.url,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child: Icon(
                                                  Icons.error_outline,
                                                  color: Colors.red,
                                                  size: 40,
                                                ),
                                              ),
                                            ),
                                          ),
                                    ),
                                    // Onay durumu gösterimi sadece onaylanmış veya reddedilmiş fotoğraflar için gösterilsin
                                    if (photo.approved != null) 
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: photo.approved == true
                                                ? Colors.green.withOpacity(0.8)
                                                : Colors.red.withOpacity(0.8),
                                            borderRadius: const BorderRadius.only(
                                              bottomLeft: Radius.circular(8),
                                              bottomRight: Radius.circular(8),
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 8,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                photo.approved == true
                                                  ? Icons.check_circle_outline 
                                                  : Icons.cancel_outlined,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  photo.approved == true ? 'ONAYLANDI' : 'ONAYLANMADI',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
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