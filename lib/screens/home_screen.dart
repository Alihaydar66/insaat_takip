import 'package:flutter/material.dart';
import 'package:insaat_takip/services/supabase_service.dart';
import 'package:insaat_takip/models/project_model.dart';
import 'package:insaat_takip/utils/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _checkUserLogin();
  }

  Future<void> _checkUserLogin() async {
    final user = _supabaseService.getCurrentUser();
    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _showCreateProjectDialog() {
    final nameController = TextEditingController();
    final companyController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isCreatingProject = false;

    showDialog(
      context: context,
      barrierDismissible: !isCreatingProject,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Yeni Proje Oluştur'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
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
                        labelText: 'Firma Adı',
                        prefixIcon: Icon(Icons.corporate_fare),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Proje Adresi',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isCreatingProject 
                    ? null 
                    : () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: isCreatingProject
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          // Dialog durumunu güncelle
                          setDialogState(() {
                            isCreatingProject = true;
                          });
                          
                          final user = _supabaseService.getCurrentUser();
                          if (user != null) {
                            try {
                              final newProject = ProjectModel(
                                id: const Uuid().v4(), // Otomatik UUID oluştur
                                name: nameController.text.trim(),
                                companyName: companyController.text.trim(),
                                address: addressController.text.trim(),
                                ownerId: user.id,
                                createdAt: DateTime.now(),
                              );
                              
                              await _supabaseService.createProject(newProject);
                              
                              // Başarılı olduğunda dialogu kapat
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Proje başarıyla oluşturuldu'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                
                                // Projeler sayfasına yönlendir
                                context.go('/projects');
                              }
                            } catch (e) {
                              // Hata durumunda bilgilendirme yap ama dialogu kapatma
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Proje oluşturulurken hata: ${e.toString()}'),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                              }
                            } finally {
                              // Her durumda state'i sıfırla
                              if (mounted) {
                                setDialogState(() {
                                  isCreatingProject = false;
                                });
                              }
                            }
                          }
                        }
                      },
                child: isCreatingProject
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Oluştur'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showJoinProjectDialog() {
    final projectCodeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isJoining = false;

    showDialog(
      context: context,
      barrierDismissible: !isJoining,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Projeye Katıl'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: projectCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Proje Kodu',
                      prefixIcon: Icon(Icons.numbers),
                      hintText: 'Projeye ait kodu girin',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen proje kodunu girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Proje kodunu proje sahibinden alabilirsiniz.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isJoining
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: isJoining
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() {
                            isJoining = true;
                          });
                          
                          try {
                            final user = _supabaseService.getCurrentUser();
                            if (user != null) {
                              // Proje kodunu kullanarak projeyi bul ve katıl
                              final shortCode = projectCodeController.text.trim();
                              print('Girilen proje kodu: $shortCode');
                              
                              // Önce kısa kod ile projeyi bul
                              final project = await _supabaseService.findProjectByShortCode(shortCode);
                              
                              if (project == null) {
                                print('Proje bulunamadı: $shortCode');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Bu koda sahip bir proje bulunamadı'),
                                    backgroundColor: AppTheme.errorColor,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                setDialogState(() {
                                  isJoining = false;
                                });
                                return;
                              }
                              
                              print('Proje bulundu: ${project.id}');
                              
                              try {
                                // Projeye katılma işlemi yap
                                await _supabaseService.joinProject(project.id, user.id);
                                
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Projeye başarıyla katıldınız'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  
                                  // Projeler sayfasına yönlendir
                                  context.go('/projects');
                                }
                              } catch (e) {
                                print('Projeye katılma hatası: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Projeye katılırken hata: ${e.toString()}'),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                                setDialogState(() {
                                  isJoining = false;
                                });
                              }
                            }
                          } catch (e) {
                            print('Projeye katılma hatası: $e');
                            if (mounted) {
                              setDialogState(() {
                                isJoining = false;
                              });
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Projeye katılırken hata: ${e.toString()}'),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                            }
                          }
                        }
                      },
                child: isJoining
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Katıl'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.home, size: 24),
            SizedBox(width: 8),
            Text('İnşaat Takip'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showCreateProjectDialog,
            tooltip: 'Yeni Proje Oluştur',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _supabaseService.signOut();
              if (mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.construction,
              size: 100,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 24),
            const Text(
              'İnşaat Takip Uygulaması',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Projelerinizi kolayca yönetin ve takip edin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showCreateProjectDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Yeni Proje'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showJoinProjectDialog,
                      icon: const Icon(Icons.group_add),
                      label: const Text('Projeye Katıl'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Projeler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            // Projeler sayfasına git
            context.go('/projects');
          } else if (index == 1) {
            // Zaten Ana Sayfa ekranındayız
          } else if (index == 2) {
            // Profil sayfasına git
            context.go('/profile');
          }
        },
      ),
    );
  }
} 