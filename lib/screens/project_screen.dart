import 'package:flutter/material.dart';
import 'package:insaat_takip/services/supabase_service.dart';
import 'package:insaat_takip/models/project_model.dart';
import 'package:insaat_takip/models/floor_model.dart';
import 'package:insaat_takip/utils/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:clipboard/clipboard.dart';

class ProjectScreen extends StatefulWidget {
  final String projectId;

  const ProjectScreen({super.key, required this.projectId});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final _supabaseService = SupabaseService();
  ProjectModel? _project;
  List<FloorModel> _floors = [];
  bool _isLoading = true;
  bool _isOwner = false;
  bool _isAuthorized = false;
  List<Map<String, dynamic>> _projectMembers = [];

  @override
  void initState() {
    super.initState();
    print('ProjectScreen başlatıldı. Proje ID: ${widget.projectId}');
    _loadProjectData();
  }

  Future<void> _loadProjectData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Proje verilerini çek
      print('Proje verisi getiriliyor: ${widget.projectId}');
      _project = await _supabaseService.getProjectById(widget.projectId);
      
      if (_project == null) {
        print('HATA: Proje bulunamadı! ID: ${widget.projectId}');
        throw Exception('Proje bulunamadı');
      } else {
        print('Proje başarıyla getirildi: ${_project!.name}');
        print('Proje sahibi: ${_project!.ownerId}');
        print('Proje üyeleri: ${_project!.memberIds}');
      }
      
      // Projenin katlarını çek
      print('Proje katları getiriliyor: ${widget.projectId}');
      _floors = await _supabaseService.getProjectFloors(widget.projectId);
      print('Getirilen kat sayısı: ${_floors.length}');
      
      // Kullanıcı bilgilerini al
      final user = _supabaseService.getCurrentUser();
      if (user != null) {
        // Proje sahibi mi kontrol et
        final isOwner = _project!.ownerId == user.id;
        
        // Yetki kontrolü yap
        final isAuthorized = isOwner || await _supabaseService.isAuthorizedInProject(widget.projectId, user.id);
        
        // Proje üyelerini getir
        final projectMembers = await _supabaseService.getProjectMembers(widget.projectId);
        
        setState(() {
          _isOwner = isOwner;
          _isAuthorized = isAuthorized;
          _projectMembers = projectMembers;
          print('Yetki durumu: $_isAuthorized');
          print('Proje üyeleri sayısı: ${_projectMembers.length}');
        });
      }
    } catch (e) {
      print('Proje verileri yüklenirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proje verileri yüklenirken hata: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddFloorDialog() {
    // Bu fonksiyonu silip yerine yeni fonksiyonlar ekliyoruz
  }

  // Normal kat ekle (yukarı doğru)
  void _addNormalFloor() async {
    if (_project == null) return;
    
    // Yetki kontrolü
    final currentUser = _supabaseService.getCurrentUser();
    if (currentUser == null) return;
    
    bool hasPermission = _project!.ownerId == currentUser.id;
    if (!hasPermission && _project!.authorizedMemberIds != null) {
      hasPermission = _project!.authorizedMemberIds!.contains(currentUser.id);
    }
    
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kat ekleme yetkiniz bulunmuyor. Sadece proje sahibi veya yetkili üyeler kat ekleyebilir.'),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Mevcut en büyük pozitif kat numarasını bul
    int highestFloorNumber = 0;
    for (var floor in _floors) {
      if (floor.floorNumber > highestFloorNumber) {
        highestFloorNumber = floor.floorNumber;
      }
    }
    
    // Yeni kat numarası
    int newFloorNumber = highestFloorNumber + 1;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Kat adlandırması
      final String katAdi = '$newFloorNumber. Kat';
      
      // Yeni kat oluştur
      final newFloor = FloorModel(
        id: const Uuid().v4(),
        name: katAdi,
        projectId: _project!.id,
        floorNumber: newFloorNumber,
        createdAt: DateTime.now(),
      );
      
      await _supabaseService.createFloor(newFloor);
      
      // Başarılı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$katAdi başarıyla eklendi'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Katları yeniden yükle
      _loadProjectData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kat eklenirken hata: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Eksi kat ekle (aşağı doğru)
  void _addBasementFloor() async {
    if (_project == null) return;
    
    // Yetki kontrolü
    final currentUser = _supabaseService.getCurrentUser();
    if (currentUser == null) return;
    
    bool hasPermission = _project!.ownerId == currentUser.id;
    if (!hasPermission && _project!.authorizedMemberIds != null) {
      hasPermission = _project!.authorizedMemberIds!.contains(currentUser.id);
    }
    
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kat ekleme yetkiniz bulunmuyor. Sadece proje sahibi veya yetkili üyeler kat ekleyebilir.'),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Mevcut en küçük negatif kat numarasını bul
    int lowestFloorNumber = 0;
    for (var floor in _floors) {
      if (floor.floorNumber < lowestFloorNumber) {
        lowestFloorNumber = floor.floorNumber;
      }
    }
    
    // Yeni kat numarası (bir alt bodrum)
    int newFloorNumber = lowestFloorNumber != 0 ? lowestFloorNumber - 1 : -1;
    
    // Eğer lowestFloorNumber 0 ise, -1 ile başlayalım
    if (lowestFloorNumber == 0) {
      newFloorNumber = -1;
    }
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Kat adlandırması - eksi işareti ve sayı ile başlasın
      final String katAdi = '-${newFloorNumber.abs()}. Kat';
      
      // Değişiklik: "-1. Bodrum" yerine "-1. Kat" şeklinde adlandırma
      final newFloor = FloorModel(
        id: const Uuid().v4(),
        name: katAdi, 
        projectId: _project!.id,
        floorNumber: newFloorNumber,
        createdAt: DateTime.now(),
      );
      
      await _supabaseService.createFloor(newFloor);
      
      // Mesajı da güncelleyelim
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$katAdi başarıyla eklendi'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Katları yeniden yükle
      _loadProjectData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kat eklenirken hata: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showProjectMembersDialog() {
    if (_project == null) return;
    
    // Mevcut kullanıcının proje sahibi olup olmadığını kontrol et
    final currentUser = _supabaseService.getCurrentUser();
    final isOwner = currentUser != null && _project!.ownerId == currentUser.id;
    
    // Bu değişken, üye listesinin StatefulBuilder içinde yenilenmesi için
    List<Map<String, dynamic>> localMembers = List.from(_projectMembers);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Proje Üyeleri'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Proje sahibi
                const Text(
                  'Proje Sahibi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: const Text('Proje Sahibi'),
                  subtitle: Text('ID: ${_project!.ownerId.substring(0, 8)}'),
                ),
                
                const SizedBox(height: 16),
                
                // Proje üyeleri
                Row(
                  children: [
                    const Text(
                      'Proje Üyeleri',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    if (isOwner)
                      const Text(
                        'Yetkilendirme',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                  ],
                ),
                
                if (localMembers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Henüz üye yok'),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: localMembers.length,
                      itemBuilder: (context, index) {
                        final member = localMembers[index];
                        final profile = member['profiles'] ?? {};
                        final username = profile['username'] ?? 'Kullanıcı ${index + 1}';
                        final userId = member['user_id'] ?? '';
                        final isAuthorized = member['is_authorized'] ?? false;
                        
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Row(
                            children: [
                              Text(username),
                              if (isAuthorized)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Icon(
                                    Icons.verified_user,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text('ID: ${userId.substring(0, 8)}'),
                          trailing: _isOwner ? Switch(
                            value: isAuthorized,
                            activeColor: Colors.green,
                            onChanged: (value) async {
                              // ÖNEMLİ DEĞİŞİKLİK: StatefulBuilder içindeki setState kullanımı
                              setState(() {
                                // Önce yerel listeyi güncelle (UI için)
                                localMembers[index]['is_authorized'] = value;
                              });
                              
                              // Snackbar göster
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(value 
                                    ? 'Üye yetkili yapılıyor...' 
                                    : 'Üye yetkisi kaldırılıyor...'
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                              
                              // Veritabanına güncelleme yap
                              final success = await _supabaseService.updateMemberAuthorization(
                                widget.projectId, 
                                userId,
                                value
                              );
                              
                              if (success) {
                                // Başarılı feedback
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(value 
                                      ? 'Üye yetkili yapıldı' 
                                      : 'Üye yetkisi kaldırıldı'
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                
                                // Ana widget'taki state'i de güncelle (kalıcı olması için)
                                if (mounted) {
                                  // Eğer widget hala mevcut ise - bu diyalog kapatıldıktan sonra gerçekleşir
                                  _loadProjectData(); // Tüm verileri yeniden yükle
                                }
                              } else {
                                // Hata durumunda yerel listeyi geri al
                                setState(() {
                                  localMembers[index]['is_authorized'] = !value;
                                });
                                
                                // Hata mesajı
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Yetki değiştirilemedi. Lütfen tekrar deneyin.'),
                                    backgroundColor: AppTheme.errorColor,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ) : (isAuthorized 
                              ? const Chip(
                                  label: Text('Yetkili', style: TextStyle(fontSize: 10)),
                                  backgroundColor: Colors.green,
                                  labelStyle: TextStyle(color: Colors.white),
                                  padding: EdgeInsets.all(0),
                                ) 
                              : const Chip(
                                  label: Text('Üye', style: TextStyle(fontSize: 10)),
                                  backgroundColor: Colors.grey,
                                  labelStyle: TextStyle(color: Colors.white),
                                  padding: EdgeInsets.all(0),
                                )
                            ),
                        );
                      },
                    ),
                  ),
                  
                const SizedBox(height: 16),
                
                // Proje kodu
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key, size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Proje Kodu: ${_project!.id.substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          final projectCode = _project!.id.substring(0, 8);
                          FlutterClipboard.copy(projectCode).then((_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Proje kodu kopyalandı'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          });
                        },
                        tooltip: 'Kopyala',
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Proje kodunu paylaşarak diğer kullanıcıları projeye davet edebilirsiniz.\n',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      if (isOwner)
                        const TextSpan(
                          text: 'Proje sahibi olarak üyeleri yetkilendirebilirsiniz. Yetkili üyeler kat ve eleman ekleyebilir, fotoğrafları onaylayabilir.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProjectInfoDialog() {
    if (_project == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Proje Bilgileri'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('Proje Adı'),
              subtitle: Text(_project!.name),
              leading: const Icon(Icons.business),
            ),
            if (_project!.companyName != null && _project!.companyName!.isNotEmpty)
              ListTile(
                title: const Text('Firma'),
                subtitle: Text(_project!.companyName!),
                leading: const Icon(Icons.corporate_fare),
              ),
            if (_project!.address != null && _project!.address!.isNotEmpty)
              ListTile(
                title: const Text('Adres'),
                subtitle: Text(_project!.address!),
                leading: const Icon(Icons.location_on),
              ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Oluşturulma Tarihi'),
              subtitle: Text(
                '${_project!.createdAt.day}/${_project!.createdAt.month}/${_project!.createdAt.year}',
              ),
              leading: const Icon(Icons.calendar_today),
            ),
            // Yetki durumu bildirimi
            const Divider(),
            const Text(
              'Yetki Durumu',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildPermissionInfo(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
  
  // Kullanıcının yetki durumunu gösteren widget
  Widget _buildPermissionInfo() {
    final currentUser = _supabaseService.getCurrentUser();
    
    if (currentUser == null || _project == null) {
      return const Text('Yetki bilgisi alınamıyor');
    }
    
    final isOwner = _project!.ownerId == currentUser.id;
    final isAuthorized = _project!.authorizedMemberIds != null && 
                         _project!.authorizedMemberIds!.contains(currentUser.id);
    
    Color color = Colors.red;
    String text = '';
    String description = '';
    IconData icon = Icons.error_outline;
    
    if (isOwner) {
      color = Colors.purple;
      text = 'Proje Sahibi';
      description = 'Tüm yetkilere sahipsiniz. Üyeleri yetkilendirebilir, kat ve eleman ekleyebilir, fotoğrafları onaylayabilirsiniz.';
      icon = Icons.admin_panel_settings;
    } else if (isAuthorized) {
      color = Colors.green;
      text = 'Yetkili Üye';
      description = 'Kat ve eleman ekleyebilir, fotoğrafları onaylayabilirsiniz.';
      icon = Icons.verified_user;
    } else {
      color = Colors.orange;
      text = 'Standart Üye';
      description = 'Sadece fotoğraf yükleyebilirsiniz. Kat ve eleman ekleme, fotoğraf onaylama yetkileriniz yok.';
      icon = Icons.person;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showDeleteFloorDialog(FloorModel floor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Katı Sil'),
        content: Text('Bu katı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                await _supabaseService.deleteFloor(floor.id);
                _loadProjectData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${floor.name} başarıyla silindi'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kat silinirken hata: ${e.toString()}'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Yetkili mi kontrol et
    final currentUser = _supabaseService.getCurrentUser();
    bool hasPermission = false;
    
    // Yetki kontrolü
    if (_project != null && currentUser != null) {
      // Proje sahibi veya yetkili üye mi?
      hasPermission = _project!.ownerId == currentUser.id;
      if (!hasPermission && _project!.authorizedMemberIds != null) {
        hasPermission = _project!.authorizedMemberIds!.contains(currentUser.id);
      }
    }
    
    return Scaffold(
      appBar: AppBar(
        title: _isLoading
            ? const Text('Yükleniyor...')
            : Text(_project?.name ?? 'Proje'),
        actions: [
          // Proje işlemleri için menü butonu
          if (!_isLoading && _project != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Proje İşlemleri',
              onSelected: (value) => _handleProjectAction(value),
              itemBuilder: (context) => [
                // Düzenle - sadece proje sahibi veya yetkili ise göster
                if (_isOwner || _isAuthorized)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit, color: Colors.blue),
                      title: Text('Projeyi Düzenle'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                
                // Proje Bitir - sadece proje sahibi ise göster
                if (_isOwner)
                  const PopupMenuItem(
                    value: 'complete',
                    child: ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text('Projeyi Bitir'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                
                // Projeden Çık - proje sahibi değilse göster
                if (!_isOwner && currentUser != null)
                  const PopupMenuItem(
                    value: 'leave',
                    child: ListTile(
                      leading: Icon(Icons.exit_to_app, color: Colors.orange),
                      title: Text('Projeden Çık'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                
                // Projeyi Sil - sadece proje sahibi ise göster
                if (_isOwner)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_forever, color: Colors.red),
                      title: Text('Projeyi Sil'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          
          // Üye bilgilerini göster
          if (!_isLoading && _project != null)
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: _showProjectMembersDialog,
              tooltip: 'Proje Üyeleri',
            ),
          // Proje bilgilerini göster
          if (!_isLoading && _project != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showProjectInfoDialog,
              tooltip: 'Proje Bilgileri',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildProjectBody(),
      floatingActionButton: null,
    );
  }

  // Proje işlemlerini ele al
  void _handleProjectAction(String action) {
    switch (action) {
      case 'edit':
        _showEditProjectDialog();
        break;
      case 'complete':
        _showCompleteProjectDialog();
        break;
      case 'leave':
        _showLeaveProjectDialog();
        break;
      case 'delete':
        _showDeleteProjectDialog();
        break;
    }
  }

  // Projeyi düzenleme diyaloğu
  void _showEditProjectDialog() {
    if (_project == null) return;
    
    final nameController = TextEditingController(text: _project!.name);
    final companyController = TextEditingController(text: _project!.companyName ?? '');
    final addressController = TextEditingController(text: _project!.address ?? '');
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projeyi Düzenle'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Proje Adı',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen proje adını girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: 'Firma Adı (İsteğe Bağlı)',
                  prefixIcon: Icon(Icons.corporate_fare),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Adres (İsteğe Bağlı)',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
            ],
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
                
                setState(() {
                  _isLoading = true;
                });
                
                try {
                  // Projeyi güncelle
                  final updatedProject = _project!.copyWith(
                    name: nameController.text.trim(),
                    companyName: companyController.text.trim().isNotEmpty 
                        ? companyController.text.trim() 
                        : _project!.companyName,
                    address: addressController.text.trim().isNotEmpty 
                        ? addressController.text.trim() 
                        : _project!.address,
                  );
                  
                  await _supabaseService.updateProject(updatedProject);
                  
                  // Verileri yeniden yükle
                  await _loadProjectData();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Proje başarıyla güncellendi'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Proje güncellenirken hata: ${e.toString()}'),
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

  // Proje bitirme diyaloğu
  void _showCompleteProjectDialog() {
    if (_project == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projeyi Bitir'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              'Bu projeyi bitmiş olarak işaretlemek istediğinize emin misiniz?',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Not: Bu özellik şu an için geliştirilme aşamasındadır.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
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
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bu özellik yakında kullanıma sunulacaktır.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Projeyi Bitir'),
          ),
        ],
      ),
    );
  }

  // Projeden çıkma diyaloğu
  void _showLeaveProjectDialog() {
    if (_project == null) return;
    
    final currentUser = _supabaseService.getCurrentUser();
    if (currentUser == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projeden Çık'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.exit_to_app, color: Colors.orange, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Bu projeden çıkmak istediğinize emin misiniz?',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Proje: ${_project!.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Dikkat: Projeden çıktıktan sonra, proje sahibinin sizi tekrar davet etmesi gerekecektir.',
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
              Navigator.pop(context); // Dialog'u kapat
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                // Projeden çıkma işlemi
                final success = await _supabaseService.leaveProject(widget.projectId, currentUser.id);
                
                if (success) {
                  // Başarılı mesajı
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${_project!.name} projesinden başarıyla çıktınız'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Projeler sayfasına dön
                  if (mounted) {
                    context.go('/projects');
                  }
                } else {
                  // Hata mesajı
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Projeden çıkarken bir sorun oluştu'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Projeden çıkarken hata: ${e.toString()}'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              } finally {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Projeden Çık'),
          ),
        ],
      ),
    );
  }

  // Projeyi silme diyaloğu
  void _showDeleteProjectDialog() {
    if (_project == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projeyi Sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 64),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bu projeyi silmek istediğinize emin misiniz?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Proje: ${_project!.name}'),
            if (_project!.companyName != null && _project!.companyName!.isNotEmpty)
              Text('Firma: ${_project!.companyName}'),
            const SizedBox(height: 16),
            const Text(
              'UYARI: Bu işlem geri alınamaz!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Projeyi sildiğinizde tüm katlar, elemanlar, fotoğraflar ve üye bilgileri tamamen silinecektir.',
              style: TextStyle(color: Colors.red),
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
              Navigator.pop(context); // Diyaloğu kapat
              
              // Silme işlemini başlat
              _deleteProject();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Projeyi Sil'),
          ),
        ],
      ),
    );
  }
  
  // Proje silme işlemi
  Future<void> _deleteProject() async {
    if (_project == null) return;
    
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
            Text('Proje siliniyor... Lütfen bekleyin.'),
          ],
        ),
      ),
    );
    
    try {
      // Projeyi sil
      final success = await _supabaseService.deleteProject(widget.projectId);
      
      // Yükleme diyaloğunu kapat
      if (mounted) Navigator.pop(context);
      
      if (success) {
        // Başarılı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_project!.name} başarıyla silindi'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Projeler sayfasına yönlendir
        if (mounted) {
          context.go('/projects');
        }
      } else {
        // Hata mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proje silinirken bir hata oluştu'),
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
          content: Text('Proje silinirken bir hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget _buildProjectBody() {
    return Column(
      children: [
        // Proje bilgileri kartı
        if (_project != null)
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.business,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _project!.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_project!.companyName != null && _project!.companyName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 32),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.corporate_fare,
                            color: AppTheme.textSecondaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _project!.companyName!,
                            style: const TextStyle(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_project!.address != null && _project!.address!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 32),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: AppTheme.textSecondaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _project!.address!,
                              style: const TextStyle(
                                color: AppTheme.textSecondaryColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Projeye katılmak için proje kodunu göster
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.key,
                          color: AppTheme.primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Proje Kodu: ${_project!.id.substring(0, 8)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () {
                            // Proje ID'sini panoya kopyala
                            final projectCode = _project!.id.substring(0, 8);
                            FlutterClipboard.copy(projectCode).then((_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Proje kodu kopyalandı'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            });
                          },
                          tooltip: 'Kopyala',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _floors.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.layers_outlined,
                      size: 80,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz kat bulunmuyor',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Yapı katlarını ekleyerek projeye başlayın',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Kat ekleme butonları (+ ve -)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _addNormalFloor,
                          icon: const Icon(Icons.add),
                          label: const Text('Normal Kat Ekle (+)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _addBasementFloor,
                          icon: const Icon(Icons.remove),
                          label: const Text('Eksi Kat Ekle (-)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Katlar',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          // Kat ekleme butonları (+ ve -)
                          Row(
                            children: [
                              // Normal kat ekle
                              Tooltip(
                                message: 'Normal Kat Ekle (+)',
                                child: IconButton(
                                  icon: Icon(Icons.add_circle, color: Colors.blue.shade700, size: 28),
                                  onPressed: _addNormalFloor,
                                ),
                              ),
                              // Bodrum kat ekle
                              Tooltip(
                                message: 'Eksi Kat Ekle (-)',
                                child: IconButton(
                                  icon: Icon(Icons.remove_circle, color: Colors.red.shade700, size: 28),
                                  onPressed: _addBasementFloor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadProjectData,
                        child: ListView.builder(
                          itemCount: _floors.length,
                          itemBuilder: (context, index) {
                            final floor = _floors[index];
                            
                            // Kat numarasına göre renk ve ikon belirle
                            final isPositive = floor.floorNumber > 0;
                            final color = isPositive ? Colors.blue.shade700 : Colors.red.shade700;
                            final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: color.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => context.push('/floor/${floor.id}'),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          icon,
                                          color: color,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              floor.name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Düzenleme butonu önce geliyor
                                      if (_isOwner || _isAuthorized)
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                                          onPressed: () => _showEditFloorDialog(floor),
                                          tooltip: 'Katı Düzenle',
                                        ),
                                      // Silme butonu sonra
                                      if (_isOwner || _isAuthorized)
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                          onPressed: () => _showDeleteFloorDialog(floor),
                                          tooltip: 'Katı Sil',
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ],
    );
  }

  // Eklenecek yeni fonksiyon
  void _showEditFloorDialog(FloorModel floor) {
    final nameController = TextEditingController(text: floor.name);
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
                
                try {
                  final updatedFloor = floor.copyWith(
                    name: nameController.text.trim(),
                  );
                  
                  await _supabaseService.updateFloor(updatedFloor);
                  
                  _loadProjectData();
                  
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
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}