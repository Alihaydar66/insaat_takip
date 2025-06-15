import 'package:flutter/material.dart';
import 'package:insaat_takip/services/supabase_service.dart';
import 'package:insaat_takip/models/floor_model.dart';
import 'package:insaat_takip/models/element_model.dart';
import 'package:insaat_takip/utils/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class FloorScreen extends StatefulWidget {
  final String floorId;

  const FloorScreen({super.key, required this.floorId});

  @override
  State<FloorScreen> createState() => _FloorScreenState();
}

class _FloorScreenState extends State<FloorScreen> {
  final _supabaseService = SupabaseService();
  FloorModel? _floor;
  List<ElementModel> _elements = [];
  bool _isLoading = true;
  String? _currentUserId;
  bool _hasAuthorization = false;
  String? _projectId;

  @override
  void initState() {
    super.initState();
    _loadFloorData();
  }

  Future<void> _loadFloorData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Kat ID'sinden katı getir
      final floor = await _supabaseService.getFloorById(widget.floorId);
      if (floor != null) {
        setState(() {
          _floor = floor;
          _projectId = floor.projectId;
        });
        
        // Kullanıcı izinlerini kontrol et
        await _checkUserPermissions();
        
        // Elemanları getir
        _elements = await _supabaseService.getFloorElements(widget.floorId);
      } else {
        // Kat bulunamadı
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kat bulunamadı'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kat verileri yüklenirken hata: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
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
  
  // Kullanıcı izinlerini kontrol et
  Future<void> _checkUserPermissions() async {
    final user = _supabaseService.getCurrentUser();
    if (user == null || _projectId == null) {
      setState(() {
        _currentUserId = null;
        _hasAuthorization = false;
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
      _hasAuthorization = hasPermission;
    });
    
    print('Kullanıcı: $_currentUserId, Yetki durumu: $_hasAuthorization, Proje: $_projectId');
  }

  void _showAddElementDialog() {
    // Eğer yetkisi yoksa işlemi engelle
    if (!_hasAuthorization) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Eleman ekleme yetkiniz bulunmuyor. Sadece proje sahibi veya yetkili üyeler eleman ekleyebilir.'),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!mounted) return;
    
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eleman Ekle'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Eleman Adı',
              prefixIcon: Icon(Icons.category),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Lütfen eleman adını girin';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                
                final newElement = ElementModel(
                  id: const Uuid().v4(), // Otomatik UUID oluştur
                  name: nameController.text.trim(),
                  floorId: widget.floorId,
                  createdAt: DateTime.now(),
                );
                
                try {
                  await _supabaseService.createElement(newElement);
                  if (mounted) {
                    _loadFloorData(); // Listeyi yenile
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Eleman eklenirken hata: ${e.toString()}'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isLoading 
          ? const Text('Yükleniyor...') 
          : Text(_floor?.name ?? 'Kat'),
        actions: [
          // Kat düzenleme menüsü
          if (!_isLoading && _floor != null && _hasAuthorization)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Kat İşlemleri',
              onSelected: (value) => _handleFloorAction(value),
              itemBuilder: (context) => [
                // Düzenle seçeneği
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit, color: Colors.blue),
                    title: Text('Katı Düzenle'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                // Sil seçeneği
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Katı Sil'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          
          if (!_isLoading && _floor != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadFloorData();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _elements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.category_outlined,
                        size: 80,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz eleman bulunmuyor',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Yapı elemanlarını ekleyin',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_hasAuthorization) // Yetkili kullanıcılar için buton göster
                        ElevatedButton.icon(
                          onPressed: _showAddElementDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Eleman Ekle'),
                        ),
                      if (!_hasAuthorization) // Yetkisiz kullanıcılar için bilgi mesajı
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Eleman ekleme yetkisine sahip değilsiniz. Sadece fotoğraf ekleyebilirsiniz.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFloorData,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Başlık ve eleman ekleme butonu
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Elemanlar (${_elements.length})',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            // Yetkili kullanıcılara eleman ekleme butonu göster
                            if (_hasAuthorization)
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                                onPressed: _showAddElementDialog,
                                tooltip: 'Eleman Ekle',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        // Eleman listesi
                        Expanded(
                          child: ListView.builder(
                            itemCount: _elements.length,
                            itemBuilder: (context, index) {
                              final element = _elements[index];
                              // Eleman fotoğraf sayısı
                              final photosCount = element.photos?.length ?? 0;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () => context.push('/element/${element.id}'),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.category,
                                              color: AppTheme.primaryColor,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                element.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            // Yetkili kullanıcılar için düzenle/sil butonları
                                            if (_hasAuthorization)
                                              Row(
                                                children: [
                                                  // Düzenle butonu
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                                    onPressed: () => _showEditElementDialog(element),
                                                    tooltip: 'Düzenle',
                                                  ),
                                                  // Sil butonu
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                    onPressed: () => _showDeleteElementDialog(element),
                                                    tooltip: 'Sil',
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                        // Fotoğraf sayısı bilgisi
                                        if (photosCount > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8.0, left: 36),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.photo_library_outlined,
                                                  color: AppTheme.textSecondaryColor,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$photosCount fotoğraf',
                                                  style: const TextStyle(
                                                    color: AppTheme.textSecondaryColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  // Kat işlemlerini ele al
  void _handleFloorAction(String action) {
    switch (action) {
      case 'edit':
        _showEditFloorDialog();
        break;
      case 'delete':
        _showDeleteFloorDialog();
        break;
    }
  }

  // Kat düzenleme diyaloğu
  void _showEditFloorDialog() {
    if (_floor == null) return;
    
    final nameController = TextEditingController(text: _floor!.name);
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Katı Düzenle'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Kat Adı',
              prefixIcon: Icon(Icons.layers),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Lütfen kat adını girin';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                
                final updatedFloor = _floor!.copyWith(
                  name: nameController.text.trim(),
                );
                
                try {
                  await _updateFloor(updatedFloor);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kat başarıyla güncellendi'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kat güncellenirken hata: ${e.toString()}'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }
  
  // Kat güncelleme işlemi
  Future<void> _updateFloor(FloorModel updatedFloor) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _supabaseService.updateFloor(updatedFloor);
      await _loadFloorData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Kat silme diyaloğu
  void _showDeleteFloorDialog() {
    if (_floor == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Katı Sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(
              child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 64),
            ),
            const SizedBox(height: 16),
            Text(
              '${_floor!.name} katını silmek istediğinize emin misiniz?',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'UYARI: Bu işlem geri alınamaz!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Katı sildiğinizde tüm elemanlar ve fotoğraflar silinecektir.',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteFloor();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
  
  // Kat silme işlemi
  Future<void> _deleteFloor() async {
    if (_floor == null) return;
    
    // Yükleme göstergesi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Kat siliniyor... Lütfen bekleyin.'),
          ],
        ),
      ),
    );
    
    try {
      // Katı sil
      final success = await _supabaseService.deleteFloor(_floor!.id);
      
      // Yükleme diyaloğunu kapat
      if (mounted) Navigator.pop(context);
      
      if (success) {
        // Başarılı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_floor!.name} başarıyla silindi'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Proje sayfasına geri dön
        if (mounted && _projectId != null) {
          context.pop();
        }
      } else {
        // Hata mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kat silinirken bir hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Yükleme diyaloğunu kapat
      if (mounted) Navigator.pop(context);
      
      // Hata mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kat silinirken bir hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Eleman düzenleme diyaloğu
  void _showEditElementDialog(ElementModel element) {
    final nameController = TextEditingController(text: element.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eleman Düzenle'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Eleman Adı',
              prefixIcon: Icon(Icons.category),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Lütfen eleman adını girin';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                
                final updatedElement = element.copyWith(
                  name: nameController.text.trim(),
                );
                
                try {
                  setState(() {
                    _isLoading = true;
                  });
                  
                  await _supabaseService.updateElement(updatedElement);
                  await _loadFloorData();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Eleman başarıyla güncellendi'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Eleman güncellenirken hata: ${e.toString()}'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                } finally {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }
  
  // Eleman silme diyaloğu
  void _showDeleteElementDialog(ElementModel element) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elemanı Sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(
              child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 64),
            ),
            const SizedBox(height: 16),
            Text(
              '${element.name} elemanını silmek istediğinize emin misiniz?',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'UYARI: Bu işlem geri alınamaz!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Elemanı sildiğinizde tüm fotoğraflar da silinecektir.',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                setState(() {
                  _isLoading = true;
                });
                
                final success = await _supabaseService.deleteElement(element.id);
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${element.name} başarıyla silindi'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  await _loadFloorData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Eleman silinirken bir hata oluştu'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Eleman silinirken bir hata oluştu: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
} 