import 'package:flutter/material.dart';
import 'package:insaat_takip/services/supabase_service.dart';
import 'package:insaat_takip/models/project_model.dart';
import 'package:insaat_takip/utils/app_theme.dart';
import 'package:go_router/go_router.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _supabaseService = SupabaseService();
  List<ProjectModel> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Projeler yüklenmeye başlıyor...');
      final user = _supabaseService.getCurrentUser();
      
      if (user != null) {
        print('Kullanıcı ID: ${user.id} - Projeler yükleniyor...');
        final projects = await _supabaseService.getUserProjects(user.id);
        print('Yüklenen proje sayısı: ${projects.length}');
        
        // Proje bilgilerini logla
        if (projects.isNotEmpty) {
          print('==== PROJELER BULUNDU ====');
          for (var project in projects) {
            print('Proje: ${project.name} (ID: ${project.id})');
            print('  Owner ID: ${project.ownerId}');
            print('  Member IDs: ${project.memberIds}');
            print('  Created At: ${project.createdAt}');
            print('------------------');
          }
        } else {
          print('==== HİÇ PROJE BULUNAMADI ====');
          print('Kullanıcı ID: ${user.id}');
          print('Email: ${user.email}');
        }
        
        setState(() {
          _projects = projects;
        });
      } else {
        print('Oturum açmış kullanıcı bulunamadı! Lütfen tekrar giriş yapın.');
        context.go('/login');
      }
    } catch (e) {
      print('Projeler yüklenirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Projeler yüklenirken hata: ${e.toString()}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projelerim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProjects,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        size: 80,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz projeniz yok',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ana sayfadan yeni bir proje oluşturabilir veya mevcut bir projeye katılabilirsiniz',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/home'),
                        icon: const Icon(Icons.home),
                        label: const Text('Ana Sayfaya Git'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProjects,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListView.builder(
                      itemCount: _projects.length,
                      itemBuilder: (context, index) {
                        final project = _projects[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            onTap: () {
                              print('Proje tıklandı: ${project.name} (ID: ${project.id})');
                              context.push('/project/${project.id}');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
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
                                          project.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // Proje sahibi ise
                                      if (project.ownerId == _supabaseService.getCurrentUser()?.id)
                                        const Chip(
                                          label: Text('Sahip'),
                                          backgroundColor: Colors.lightBlue,
                                          labelStyle: TextStyle(color: Colors.white),
                                        ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_ios, size: 16),
                                    ],
                                  ),
                                  if (project.companyName != null && project.companyName!.isNotEmpty)
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
                                            project.companyName!,
                                            style: const TextStyle(
                                              color: AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (project.address != null && project.address!.isNotEmpty)
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
                                              project.address!,
                                              style: const TextStyle(
                                                color: AppTheme.textSecondaryColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
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
            // Zaten Projeler ekranındayız
          } else if (index == 1) {
            // Ana Sayfaya git
            context.go('/home');
          } else if (index == 2) {
            // Profil sayfasına git
            context.go('/profile');
          }
        },
      ),
    );
  }
} 