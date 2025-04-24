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
      // Burada sunucudan kat verileri çekilecek
      // _floor = await _supabaseService.getFloorById(widget.floorId);
      // Geçici çözüm: Projeyi ve katları çekip eşleştirme yap
      final floors = await _supabaseService.getProjectFloors('dummy-project-id');
      _floor = floors.firstWhere(
        (floor) => floor.id == widget.floorId,
        orElse: () => FloorModel(
          id: widget.floorId,
          name: 'Bilinmeyen Kat',
          projectId: 'dummy-project-id',
          createdAt: DateTime.now(),
        ),
      );
      
      _elements = await _supabaseService.getFloorElements(widget.floorId);
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

  void _showAddElementDialog() {
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
                      ElevatedButton.icon(
                        onPressed: _showAddElementDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Eleman Ekle'),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Elemanlar',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: _showAddElementDialog,
                                tooltip: 'Eleman Ekle',
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _elements.length,
                            itemBuilder: (context, index) {
                              final element = _elements[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: InkWell(
                                  onTap: () => context.push('/element/${element.id}'),
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
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                element.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const Icon(Icons.arrow_forward_ios, size: 16),
                                          ],
                                        ),
                                        if (element.photos != null && element.photos!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.photo_library_outlined,
                                                  color: AppTheme.textSecondaryColor,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${element.photos!.length} fotoğraf',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddElementDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
} 