import 'dart:io' if (dart.library.html) 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:insaat_takip/models/user_model.dart';
import 'package:insaat_takip/models/project_model.dart';
import 'package:insaat_takip/models/floor_model.dart';
import 'package:insaat_takip/models/element_model.dart';
import 'package:path/path.dart' as path_lib;
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  // Initializer
  static Future<void> initialize() async {
    try {
      await dotenv.load();
      
      await Supabase.initialize(
        url: 'https://xpjyapicloblvnaaieow.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwanlhcGljbG9ibHZuYWFpZW93Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUxNTU4MTAsImV4cCI6MjA2MDczMTgxMH0.rG3pjmk__SHiMWmZPin4TdEpE1-eWNyuNIvUJphG7eo',
      );
      print('Supabase bağlantısı başarılı');
    } catch (e) {
      print('Supabase bağlantı hatası: $e');
    }
  }
  
  // Auth methods
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    String? phone,
    String? profession,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
        'phone': phone,
        'profession': profession,
      },
    );
    
    // Kullanıcı kaydı başarılıysa profiles tablosuna kayıt ekle
    if (response.user != null) {
      try {
        await _client.from('profiles').upsert({
          'id': response.user!.id,
          'username': username,
          'phone': phone,
          'profession': profession,
          'created_at': DateTime.now().toIso8601String(),
        });
        print('Profil oluşturuldu: ${response.user!.id}');
      } catch (e) {
        print('Profil oluşturma hatası: $e');
      }
    }
    
    return response;
  }
  
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    // Giriş başarılıysa profil kontrolü yap
    if (response.user != null) {
      await _ensureUserProfile(response.user!.id);
    }
    
    return response;
  }
  
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
  
  User? getCurrentUser() {
    final user = _client.auth.currentUser;
    if (user != null) {
      print('Mevcut kullanıcı: ID=${user.id}, Email=${user.email}');
    } else {
      print('Oturum açmış kullanıcı bulunamadı');
    }
    return user;
  }
  
  // Profil yoksa oluştur
  Future<void> _ensureUserProfile(String userId) async {
    try {
      final exists = await _client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      
      if (exists == null) {
        final userData = _client.auth.currentUser?.userMetadata;
        final username = userData?['username'] ?? 'Kullanıcı';
        
        await _client.from('profiles').insert({
          'id': userId,
          'username': username,
          'created_at': DateTime.now().toIso8601String(),
        });
        print('Eksik profil oluşturuldu: $userId');
      }
    } catch (e) {
      print('Profil kontrolü hatası: $e');
    }
  }
  
  // User methods
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      await _ensureUserProfile(userId);
      
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      return UserModel.fromJson(response);
    } catch (e) {
      print('Profil getirme hatası: $e');
      
      // Varsayılan bir profil döndür
      return UserModel(
        id: userId,
        username: 'Kullanıcı',
      );
    }
  }
  
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _client
          .from('profiles')
          .update(user.toJson())
          .eq('id', user.id);
    } catch (e) {
      print('Profil güncelleme hatası: $e');
      rethrow;
    }
  }
  
  // Project methods
  Future<List<ProjectModel>> getUserProjects(String userId) async {
    try {
      print('------ getUserProjects BAŞLADI ------');
      print('Kullanıcı projeleri getiriliyor. Kullanıcı ID: $userId');
      
      print('1) Sahip olunan projeleri alıyorum...');
      // owner_id ile eşleşenler
      final ownerProjects = await _client
          .from('projects')
          .select()
          .eq('owner_id', userId);
      
      print('2) Sahip olunan projeler: ${ownerProjects.length}');
      
      print('3) Üye olunan projeleri alıyorum...');
      // RLS yetkilendirme sorunu olabilir, bu sorguyu ayrı alıyoruz
      final memberProjects = await _client
          .from('projects')
          .select();
          
      print('4) Toplam proje sayısı: ${memberProjects.length}');
      
      // Filtreleme yapalım
      List<Map<String, dynamic>> filteredMemberProjects = [];
      
      for (var project in memberProjects) {
        if (project['owner_id'] == userId) {
          // Sahip olunan projeleri zaten aldık, atla
          continue;
        }
        
        List<dynamic> memberIds = project['member_ids'] ?? [];
        if (memberIds.contains(userId)) {
          print('Üye olunan proje bulundu: ${project['name']} (${project['id']})');
          filteredMemberProjects.add(project);
        }
      }
      
      print('5) Üye olunan proje sayısı: ${filteredMemberProjects.length}');
      
      // Tüm projeleri birleştir
      final allProjects = [...ownerProjects, ...filteredMemberProjects];
      print('6) Toplam proje sayısı: ${allProjects.length}');
      
      // Son oluşturulana göre sırala
      allProjects.sort((a, b) {
        final dateA = DateTime.parse(a['created_at'] ?? DateTime.now().toIso8601String());
        final dateB = DateTime.parse(b['created_at'] ?? DateTime.now().toIso8601String());
        return dateB.compareTo(dateA); // Yeniden eskiye sıralama
      });
      
      List<ProjectModel> result = allProjects
          .map((project) => ProjectModel.fromJson(project))
          .toList();
          
      print('7) İşlenen proje sayısı: ${result.length}');
      print('------ getUserProjects TAMAMLANDI ------');
      
      return result;
    } catch (e) {
      print('Proje getirme hatası: $e');
      print('------ getUserProjects HATA İLE SONLANDI ------');
      return [];
    }
  }
  
  Future<ProjectModel?> getProjectById(String projectId) async {
    try {
      print('getProjectById çağrıldı: $projectId');
      
      final response = await _client
          .from('projects')
          .select()
          .eq('id', projectId)
          .single();
      
      print('Proje API yanıtı: $response');
      
      return ProjectModel.fromJson(response);
    } catch (e) {
      print('Proje detay getirme hatası: $e');
      return null;
    }
  }
  
  Future<ProjectModel> createProject(ProjectModel project) async {
    try {
      // Boş ID kontrolü
      if (project.id.isEmpty) {
        print('Yeni proje oluşturuluyor...');
      }
      
      final response = await _client
          .from('projects')
          .insert(project.toJson())
          .select()
          .single();
      
      print('Proje başarıyla oluşturuldu: ${response['id']}');
      return ProjectModel.fromJson(response);
    } catch (e) {
      print('Proje oluşturma hatası: $e');
      rethrow;
    }
  }
  
  Future<void> updateProject(ProjectModel project) async {
    await _client
        .from('projects')
        .update(project.toJson())
        .eq('id', project.id);
  }
  
  Future<void> deleteProject(String projectId) async {
    await _client
        .from('projects')
        .delete()
        .eq('id', projectId);
  }
  
  // Floor methods
  Future<List<FloorModel>> getProjectFloors(String projectId) async {
    try {
      final response = await _client
          .from('floors')
          .select()
          .eq('project_id', projectId)
          .order('created_at');
      
      return (response as List)
          .map((floor) => FloorModel.fromJson(floor))
          .toList();
    } catch (e) {
      print('Katları getirme hatası: $e');
      return [];
    }
  }
  
  Future<FloorModel> createFloor(FloorModel floor) async {
    try {
      final response = await _client
          .from('floors')
          .insert(floor.toJson())
          .select()
          .single();
      
      return FloorModel.fromJson(response);
    } catch (e) {
      print('Kat oluşturma hatası: $e');
      rethrow;
    }
  }
  
  // Element methods
  Future<List<ElementModel>> getFloorElements(String floorId) async {
    try {
      final response = await _client
          .from('elements')
          .select('*, photos(*)')
          .eq('floor_id', floorId)
          .order('created_at');
      
      return (response as List)
          .map((element) => ElementModel.fromJson(element))
          .toList();
    } catch (e) {
      print('Elemanları getirme hatası: $e');
      return [];
    }
  }
  
  Future<ElementModel> createElement(ElementModel element) async {
    try {
      final response = await _client
          .from('elements')
          .insert(element.toJson())
          .select()
          .single();
      
      return ElementModel.fromJson(response);
    } catch (e) {
      print('Eleman oluşturma hatası: $e');
      rethrow;
    }
  }
  
  // Photo methods
  Future<String?> uploadElementPhoto({
    required String path,
    required Uint8List file,
    required String contentType,
  }) async {
    try {
      await _client.storage
          .from('photos')
          .uploadBinary(path, file, fileOptions: FileOptions(contentType: contentType));
            
      // Public URL al
      final fileUrl = _client.storage
          .from('photos')
          .getPublicUrl(path);
            
      print('Dosya yüklendi: $fileUrl');
      return fileUrl;
    } catch (e) {
      print('Dosya yükleme hatası: $e');
      return null;
    }
  }
  
  Future<PhotoModel?> createElementPhoto(PhotoModel photo) async {
    try {
      final response = await _client
          .from('photos')
          .insert(photo.toJson())
          .select()
          .single();
      
      return PhotoModel.fromJson(response);
    } catch (e) {
      print('Fotoğraf oluşturma hatası: $e');
      return null;
    }
  }
  
  Future<String> uploadPhoto(String imagePath, String fileName) async {
    String fileUrl = '';
    try {
      if (kIsWeb) {
        // Web tarafında resim yükleme desteği
        final bytes = await XFile(imagePath).readAsBytes();
        final response = await _client.storage
            .from('photos')
            .uploadBinary(fileName, bytes);
            
        // Public URL al
        fileUrl = _client.storage
            .from('photos')
            .getPublicUrl(fileName);
            
        print('Web tarafında dosya yüklendi: $fileUrl');
      } else {
        // Mobil tarafında resim yükleme
        // Dart:io File sınıfını kullanarak uyumluluk sorunu oluşuyor
        // Bu nedenle mobil platformda da XFile kullanarak bytes olarak yükleyelim
        final bytes = await XFile(imagePath).readAsBytes();
        final response = await _client.storage
            .from('photos')
            .uploadBinary(fileName, bytes);
            
        // Public URL al
        fileUrl = _client.storage
            .from('photos')
            .getPublicUrl(fileName);
            
        print('Mobil tarafında dosya yüklendi: $fileUrl');
      }
      return fileUrl;
    } catch (e) {
      print('Dosya yükleme hatası: $e');
      rethrow;
    }
  }
  
  Future<PhotoModel> createPhoto(PhotoModel photo) async {
    try {
      final response = await _client
          .from('photos')
          .insert(photo.toJson())
          .select()
          .single();
      
      return PhotoModel.fromJson(response);
    } catch (e) {
      print('Fotoğraf oluşturma hatası: $e');
      rethrow;
    }
  }
  
  Future<void> updatePhotoStatus(String photoId, String status) async {
    try {
      await _client
          .from('photos')
          .update({'status': status})
          .eq('id', photoId);
    } catch (e) {
      print('Fotoğraf durumu güncelleme hatası: $e');
      rethrow;
    }
  }
  
  // Proje katılım metodları
  Future<ProjectModel> joinProject(String projectId, String userId) async {
    try {
      // Önce projeyi getir
      final project = await getProjectById(projectId);
      
      if (project == null) {
        throw Exception('Proje bulunamadı');
      }
      
      // Kullanıcı zaten projenin sahibi ise hata ver
      if (project.ownerId == userId) {
        throw Exception('Zaten bu projenin sahibisiniz');
      }
      
      // Kullanıcı zaten projede ise hata ver
      List<String> memberIds = project.memberIds ?? [];
      if (memberIds.contains(userId)) {
        throw Exception('Zaten bu projeye katılmışsınız');
      }
      
      // Kullanıcıyı üye listesine ekle
      memberIds.add(userId);
      
      // Projeyi güncelle
      final updatedProject = project.copyWith(memberIds: memberIds);
      await updateProject(updatedProject);
      
      return updatedProject;
    } catch (e) {
      print('Projeye katılma hatası: $e');
      rethrow;
    }
  }
  
  // Proje kodu ile proje bulma
  Future<ProjectModel?> findProjectByShortCode(String shortCode) async {
    try {
      print('Proje kısa kodu ile arama: $shortCode');
      
      // Tüm projeleri getir (sınırlı sayıda)
      final response = await _client
          .from('projects')
          .select()
          .limit(100);
      
      print('Toplam proje sayısı: ${response.length}');
      
      // İstemci tarafında filtreleme yap
      for (var projectData in response) {
        final projectId = projectData['id'].toString();
        print('Kontrol edilen proje ID: $projectId');
        
        // Proje ID'sinin başlangıcı kısa kodla eşleşiyor mu?
        if (projectId.toLowerCase().startsWith(shortCode.toLowerCase())) {
          print('Eşleşen proje bulundu: $projectId');
          return ProjectModel.fromJson(projectData);
        }
      }
      
      print('Eşleşen proje bulunamadı');
      return null;
    } catch (e) {
      print('Kısa kod ile proje arama hatası: $e');
      return null;
    }
  }
} 