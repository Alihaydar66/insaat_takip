import 'package:flutter/material.dart';
import 'package:insaat_takip/services/supabase_service.dart';
import 'package:insaat_takip/models/user_model.dart';
import 'package:insaat_takip/utils/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as path;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabaseService = SupabaseService();
  UserModel? _user;
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _professionController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _phoneController = TextEditingController();
    _professionController = TextEditingController();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _supabaseService.getCurrentUser();
      if (currentUser != null) {
        final userProfile = await _supabaseService.getUserProfile(currentUser.id);
        
        setState(() {
          _user = userProfile;
          if (userProfile != null) {
            _usernameController.text = userProfile.username;
            _phoneController.text = userProfile.phone ?? '';
            _professionController.text = userProfile.profession ?? '';
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil verileri yüklenirken hata: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedUser = _user!.copyWith(
        username: _usernameController.text.trim(),
        phone: _phoneController.text.trim(),
        profession: _professionController.text.trim(),
      );
      
      await _supabaseService.updateUserProfile(updatedUser);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil güncellendi'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      
      // Profil verilerini yenile
      _loadUserProfile();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil güncellenirken hata: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      
      if (image != null) {
        setState(() {
          _isLoading = true;
        });
        
        // Kullanıcı ID'si ve tarih ile benzersiz dosya adı oluştur
        final fileName = 'profile_${_user!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        try {
          // Fotoğrafı yükle
          final url = await _supabaseService.uploadPhoto(image.path, fileName);
          
          // Kullanıcı profilini güncelle
          final updatedUser = _user!.copyWith(photoUrl: url);
          await _supabaseService.updateUserProfile(updatedUser);
          
          // Profil bilgilerini yenile
          await _loadUserProfile();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profil fotoğrafı güncellendi'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Profil resmi yüklenirken hata: ${e.toString()}'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf seçilirken hata: ${e.toString()}'),
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

  Widget _buildProfileAvatar() {
    return GestureDetector(
      onTap: _pickProfileImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 64,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            backgroundImage: _user?.photoUrl != null
                ? CachedNetworkImageProvider(_user!.photoUrl!)
                : null,
            child: _user?.photoUrl == null
                ? const Icon(
                    Icons.person,
                    size: 64,
                    color: AppTheme.primaryColor,
                  )
                : null,
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.3),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('Kullanıcı profili bulunamadı'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildProfileAvatar(),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Kullanıcı Adı',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Kullanıcı adı gerekli';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Telefon',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _professionController,
                          decoration: const InputDecoration(
                            labelText: 'Meslek',
                            prefixIcon: Icon(Icons.work),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _updateProfile,
                          child: const Text('Profili Güncelle'),
                        ),
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.settings),
                          title: const Text('Ayarlar'),
                          onTap: () {
                            // Ayarlar ekranına git
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Bu özellik henüz aktif değil'),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.help_outline),
                          title: const Text('Yardım'),
                          onTap: () {
                            // Yardım ekranına git
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Bu özellik henüz aktif değil'),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('Hakkında'),
                          onTap: () {
                            // Hakkında ekranına git
                            showAboutDialog(
                              context: context,
                              applicationName: 'İnşaat Takip',
                              applicationVersion: '1.0.0',
                              applicationIcon: const Icon(
                                Icons.business,
                                color: AppTheme.primaryColor,
                                size: 50,
                              ),
                              children: [
                                const Text(
                                  'Bu uygulama inşaat projelerinin takibi için geliştirilmiştir.',
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2, // Profil sekmesi seçili
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Projeler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            context.go('/home');
          } else if (index == 1) {
            // Projeler sekmesi - Ana sayfa ile aynı içeriği gösterir
            context.go('/home');
          }
        },
      ),
    );
  }
} 