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
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kat Ekle'),
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
                
                final newFloor = FloorModel(
                  id: const Uuid().v4(), // Otomatik UUID oluştur
                  name: nameController.text.trim(),
                  projectId: widget.projectId,
                  createdAt: DateTime.now(),
                );
                
                try {
                  await _supabaseService.createFloor(newFloor);
                  _loadProjectData(); // Listeyi yenile
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kat eklenirken hata: ${e.toString()}'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _showProjectMembersDialog() {
    if (_project == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              const Text(
                'Proje Üyeleri',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              
              if (_project!.memberIds == null || _project!.memberIds!.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Henüz üye yok'),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _project!.memberIds!.length,
                    itemBuilder: (context, index) {
                      final memberId = _project!.memberIds![index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text('Üye ${index + 1}'),
                        subtitle: Text('ID: ${memberId.substring(0, 8)}'),
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
              
              const Text(
                'Proje kodunu paylaşarak diğer kullanıcıları projeye davet edebilirsiniz.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
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
    );
  }

  // Yeni kat ekleme işlevi
  Future<void> _addFloor() async {
    if (_project == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Mevcut kat sayısını bul
      int currentFloorCount = _floors.length;
      
      // Yeni katın numarası
      int newFloorNumber = currentFloorCount + 1;
      
      // Yeni kat oluştur ve Supabase'e ekle
      final newFloor = await _supabaseService.createFloor(
        FloorModel(
          id: const Uuid().v4(),
          name: '$newFloorNumber. Kat',
          projectId: _project!.id,
          createdAt: DateTime.now(),
        ),
      );
      
      // Kat listesini güncelle
      await _loadProjectData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$newFloorNumber. Kat başarıyla eklendi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kat eklenirken hata: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.business, size: 24),
            SizedBox(width: 8),
            Text(_project?.name ?? 'Proje Detayı'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: _showProjectMembersDialog,
            tooltip: 'Proje Üyeleri',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show project options
              showModalBottomSheet(
                context: context,
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Düzenle'),
                      onTap: () {
                        Navigator.pop(context);
                        // Show edit project dialog
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete, color: AppTheme.errorColor),
                      title: const Text('Sil', style: TextStyle(color: AppTheme.errorColor)),
                      onTap: () {
                        Navigator.pop(context);
                        // Show delete confirmation
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                            ElevatedButton.icon(
                              onPressed: _showAddFloorDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Kat Ekle'),
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
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: _showAddFloorDialog,
                                    tooltip: 'Kat Ekle',
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
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      child: InkWell(
                                        onTap: () => context.push('/floor/${floor.id}'),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.layers,
                                                color: AppTheme.primaryColor,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  floor.name,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const Icon(Icons.arrow_forward_ios, size: 16),
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFloor,
        tooltip: 'Kat Ekle',
        child: const Icon(Icons.add),
      ),
    );
  }
}