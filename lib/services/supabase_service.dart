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
      // await dotenv.load();

      await Supabase.initialize(
        url: 'https://xpjyapicloblvnaaieow.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwanlhcGljbG9ibHZuYWFpZW93Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUxNTU4MTAsImV4cCI6MjA2MDczMTgxMH0.rG3pjmk__SHiMWmZPin4TdEpE1-eWNyuNIvUJphG7eo',
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

      final response =
          await _client.from('profiles').select().eq('id', userId).single();

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
      await _client.from('profiles').update(user.toJson()).eq('id', user.id);
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
      final ownerProjects =
          await _client.from('projects').select().eq('owner_id', userId);

      print('2) Sahip olunan projeler: ${ownerProjects.length}');

      print('3) Üye olunan projeleri alıyorum...');
      // Yeni yaklaşım: project_members tablosundan üye olunan projeleri al
      final memberProjectsResponse = await _client
          .from('project_members')
          .select('project_id')
          .eq('user_id', userId);

      // Eğer üye olunan proje yoksa boş liste döndür
      if (memberProjectsResponse == null) {
        print('Üye olunan proje bulunamadı');
        return ownerProjects.map((project) => ProjectModel.fromJson(project)).toList();
      }
      
      print('4) Üye olunan proje ID sayısı: ${memberProjectsResponse.length}');
      
      // Proje ID'lerini bir listeye al
      List<String> memberProjectIds = [];
      for (var item in memberProjectsResponse) {
        memberProjectIds.add(item['project_id']);
      }
      
      print('5) Üye olunan proje ID\'leri: $memberProjectIds');
      
      // Üye olunan projelerin detaylarını getir (boş liste ise çalışmaz)
      List<Map<String, dynamic>> memberProjects = [];
      if (memberProjectIds.isNotEmpty) {
        // IN operatörü ile birden fazla ID sorgusu
        final memberProjectsData = await _client
            .from('projects')
            .select()
            .filter('id', 'in', memberProjectIds);
            
        memberProjects = List<Map<String, dynamic>>.from(memberProjectsData);
        print('6) Üye olunan projeler yüklendi: ${memberProjects.length}');
      }

      // Tüm projeleri birleştir
      final allProjects = [...ownerProjects, ...memberProjects];
      print('7) Toplam proje sayısı: ${allProjects.length}');

      // Son oluşturulana göre sırala
      allProjects.sort((a, b) {
        final dateA =
            DateTime.parse(a['created_at'] ?? DateTime.now().toIso8601String());
        final dateB =
            DateTime.parse(b['created_at'] ?? DateTime.now().toIso8601String());
        return dateB.compareTo(dateA); // Yeniden eskiye sıralama
      });

      List<ProjectModel> result =
          allProjects.map((project) => ProjectModel.fromJson(project)).toList();

      print('8) İşlenen proje sayısı: ${result.length}');
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

      final response =
          await _client.from('projects').select().eq('id', projectId).single();

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

      // Project verilerini hazırla
      Map<String, dynamic> projectData = {
        'id': project.id,
        'name': project.name,
        'company_name': project.companyName,
        'address': project.address,
        'owner_id': project.ownerId,
        // UUID dizisi sorununu önlemek için member_ids ve authorized_member_ids null olarak gönder
        // null değerler PostgreSQL tarafında varsayılan boş array olarak işlenecek
        'created_at': project.createdAt.toIso8601String(),
      };

      print('Gönderilecek proje verisi: $projectData');

      final response = await _client
          .from('projects')
          .insert(projectData)
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
    try {
      print('Proje güncelleniyor: ${project.id}');
      print('Güncellenecek veri: ${project.toJson()}');
      
      // member_ids ve authorized_member_ids'nin array olduğundan emin ol
      final member_ids = project.memberIds ?? [];
      final authorized_member_ids = project.authorizedMemberIds ?? [];
      
      // Boş dizileri direkt SQL array formatında gönder
      await _client
          .from('projects')
          .update({
            'name': project.name,
            'company_name': project.companyName,
            'address': project.address,
            'member_ids': member_ids,
            'authorized_member_ids': authorized_member_ids,
          })
          .eq('id', project.id);
      
      print('Proje başarıyla güncellendi: ${project.id}');
    } catch (e) {
      print('Proje güncelleme hatası: $e');
      rethrow;
    }
  }

  Future<bool> deleteProject(String projectId) async {
    try {
      print('Proje siliniyor: $projectId');
      
      // 1. Önce tüm katları getir
      final floors = await getProjectFloors(projectId);
      
      // 2. Tüm katları sil - bu otomatik olarak her katın elemanlarını ve fotoğraflarını da siler
      for (var floor in floors) {
        await deleteFloor(floor.id);
      }
      
      // 3. Proje üyeliklerini sil
      await _client.from('project_members').delete().eq('project_id', projectId);
      
      // 4. Son olarak projeyi sil
    await _client.from('projects').delete().eq('id', projectId);
      
      print('Proje başarıyla silindi: $projectId');
      return true;
    } catch (e) {
      print('Proje silme hatası: $e');
      return false;
    }
  }

  // Floor methods
  Future<List<FloorModel>> getProjectFloors(String projectId) async {
    try {
      // floor_number sütunu olmadığı için sıralama yapmadan getir
      final response = await _client
          .from('floors')
          .select()
          .eq('project_id', projectId);
      
      print('Katlar veritabanından alındı: ${response.length} adet');
      print('Ham veri: $response');

      // Aldıktan sonra manuel olarak sıralama yapacağız
      final floors = (response as List).map((floor) {
        // FloorModel oluştururken floor_number varsayılan olarak 0 olacak
        FloorModel floorModel = FloorModel.fromJson(floor);
        print('Kat oluşturuluyor: ${floorModel.name}, ID: ${floorModel.id}');
        
        // İsme bakarak numarasını belirleyelim
        int floorNumber = 0;
        String name = floorModel.name.trim();
        
        // Regex ile sayıyı çıkar
        final regexNumber = RegExp(r'[-]?[0-9]+');
        final match = regexNumber.firstMatch(name);
        
        if (match != null) {
          String numberStr = match.group(0) ?? "0";
          floorNumber = int.tryParse(numberStr) ?? 0;
          print('Kat numarası bulundu: $floorNumber (${name})');
        } else {
          print('Kat numarası bulunamadı: ${name}');
        }
        
        // İsim standardizasyonu
        if (floorNumber > 0) {
          name = '$floorNumber. Kat';
        } else if (floorNumber < 0) {
          name = '-${floorNumber.abs()}. Kat';
        } else {
          name = 'Giriş Kat';
        }
        
        // floor_number ve name değerlerini güncelle
        return floorModel.copyWith(
          floorNumber: floorNumber, 
          name: name
        );
      }).toList();
      
      // Önce benzersiz kat numaralarını bul
      Map<int, FloorModel> uniqueFloors = {};
      
      for (var floor in floors) {
        // Aynı kat numarası varsa, daha yeni olanı kullan (veya bir şekilde seç)
        if (!uniqueFloors.containsKey(floor.floorNumber) || 
            floor.createdAt.isAfter(uniqueFloors[floor.floorNumber]!.createdAt)) {
          uniqueFloors[floor.floorNumber] = floor;
        }
      }
      
      // Benzersiz katları yeni bir listeye çevir
      List<FloorModel> uniqueFloorsList = uniqueFloors.values.toList();
      
      print('Benzersiz kat sayısı: ${uniqueFloorsList.length}');
      for (var floor in uniqueFloorsList) {
        print('- Kat: ${floor.name}, No: ${floor.floorNumber}');
      }
      
      // YENİ SIRALAMA GEREKSİNİMİ:
      // 1. Önce pozitif katlar büyükten küçüğe (3, 2, 1)
      // 2. Sonra negatif katlar küçükten büyüğe (-1, -2, -3)
      uniqueFloorsList.sort((a, b) {
        // Biri pozitif biri negatif ise, pozitif olan üstte
        if ((a.floorNumber > 0 && b.floorNumber < 0) || 
            (a.floorNumber < 0 && b.floorNumber > 0)) {
          return a.floorNumber > 0 ? -1 : 1;
        }
        
        // İkisi de pozitif ise, büyük olan üstte (büyükten küçüğe)
        if (a.floorNumber > 0 && b.floorNumber > 0) {
          return b.floorNumber.compareTo(a.floorNumber);
        }
        
        // İkisi de negatif ise, küçük olan üstte (-1, -2, -3 şeklinde)
        if (a.floorNumber < 0 && b.floorNumber < 0) {
          // Değişiklik yapılan yer: Büyükten küçüğe sırala (-1 en üstte, sonra -2, -3, -4...)
          return b.floorNumber.compareTo(a.floorNumber);
        }
        
        // 0 durumu için
        return 0;
      });
      
      print('Sıralanmış katlar:');
      for (var floor in uniqueFloorsList) {
        print('- Kat: ${floor.name}, No: ${floor.floorNumber}');
      }
      
      return uniqueFloorsList;
    } catch (e) {
      print('Katları getirme hatası: $e');
      return [];
    }
  }

  Future<FloorModel> createFloor(FloorModel floor) async {
    try {
      // Veritabanına gönderilecek verileri hazırla
      // floor_number sütunu olmadığı için gönderme
      final floorData = {
        'id': floor.id,
        'name': floor.name,
        'project_id': floor.projectId,
        'created_at': floor.createdAt.toIso8601String(),
        // 'floor_number' sütunu veritabanında olmadığı için göndermiyoruz
      };
      
      // Veritabanına ekle
      final response = await _client
          .from('floors')
          .insert(floorData)
          .select()
          .single();

      // Geri dönen verileri FloorModel'e dönüştür
      // floor_number sütunu olmadığı için model içinde tutarız ama DB'ye göndermeyiz
      FloorModel createdFloor = FloorModel.fromJson(response);
      
      // Kullanıcı tarafından belirtilen floor_number'ı manuel olarak ekleyelim
      // (veritabanında saklanmıyor ama uygulama içinde kullanıyoruz)
      createdFloor = createdFloor.copyWith(floorNumber: floor.floorNumber);
      
      return createdFloor;
    } catch (e) {
      print('Kat oluşturma hatası: $e');
      rethrow;
    }
  }

  // Tek kat getirme
  Future<FloorModel?> getFloorById(String floorId) async {
    try {
      final response = await _client
          .from('floors')
          .select()
          .eq('id', floorId)
          .single();
      
      return FloorModel.fromJson(response);
    } catch (e) {
      print('Kat getirme hatası: $e');
      return null;
    }
  }

  // Kat silme fonksiyonu
  Future<bool> deleteFloor(String floorId) async {
    try {
      print('Kat siliniyor: $floorId');
      
      // Önce bu kattaki tüm elemanları getir
      final elements = await getFloorElements(floorId);
      
      // Her elemanı tek tek silmeye çalış (elemanların fotoğrafları da otomatik silinir)
      for (var element in elements) {
        await deleteElement(element.id);
      }
      
      // Son olarak katı sil
      await _client.from('floors').delete().eq('id', floorId);
      print('Kat başarıyla silindi: $floorId');
      return true;
    } catch (e) {
      print('Kat silme hatası: $e');
      return false;
    }
  }

  // Kat güncelleme
  Future<void> updateFloor(FloorModel floor) async {
    try {
      print('Kat güncelleniyor: ${floor.id}');
      
      // Veritabanına gönderilecek verileri hazırla (floor_number sütunu yok)
      final floorData = {
        'name': floor.name,
        'project_id': floor.projectId,
      };
      
      await _client
          .from('floors')
          .update(floorData)
          .eq('id', floor.id);
          
      print('Kat başarıyla güncellendi: ${floor.id}');
    } catch (e) {
      print('Kat güncelleme hatası: $e');
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

  // Tek bir elementi ID'ye göre getir
  Future<ElementModel?> getElementById(String elementId) async {
    try {
      print('Element getiriliyor: $elementId');
      final response = await _client
          .from('elements')
          .select('*, photos(*)')
          .eq('id', elementId)
          .single();

      print('Element verileri alındı');
      return ElementModel.fromJson(response);
    } catch (e) {
      print('Element getirme hatası: $e');
      return null;
    }
  }
  
  // Eleman silme fonksiyonu
  Future<bool> deleteElement(String elementId) async {
    try {
      print('Element siliniyor: $elementId');
      
      // Önce elementin tüm fotoğraflarını getir
      final photos = await getElementPhotos(elementId);
      
      // Her fotoğrafı storage'dan silmeye çalış
      for (var photo in photos) {
        try {
          // Fotoğraf URL'inden dosya yolunu çıkar
          final imagePath = photo.url.split('/').last;
          await _client.storage.from('photos').remove([imagePath]);
          print('Fotoğraf storage\'dan silindi: $imagePath');
        } catch (e) {
          print('Fotoğraf storage\'dan silinemedi: $e');
          // Hata olsa bile devam et
        }
      }
      
      // Fotoğraf kayıtlarını veritabanından sil
      await _client.from('photos').delete().eq('element_id', elementId);
      
      // Son olarak elementi sil
      await _client.from('elements').delete().eq('id', elementId);
      print('Element başarıyla silindi: $elementId');
      return true;
    } catch (e) {
      print('Element silme hatası: $e');
      return false;
    }
  }

  // Bir elementin fotoğraflarını getir
  Future<List<PhotoModel>> getElementPhotos(String elementId) async {
    try {
      print('Element fotoğrafları getiriliyor: $elementId');
      final response = await _client
          .from('photos')
          .select('*')
          .eq('element_id', elementId)
          .order('uploaded_at');

      final photos = (response as List)
          .map((photo) => PhotoModel.fromJson(photo))
          .toList();
      
      print('Element fotoğrafları alındı: ${photos.length} adet');
      return photos;
    } catch (e) {
      print('Element fotoğrafları getirme hatası: $e');
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

  // Eleman güncelleme
  Future<void> updateElement(ElementModel element) async {
    try {
      print('Eleman güncelleniyor: ${element.id}');
      
      await _client
          .from('elements')
          .update(element.toJson())
          .eq('id', element.id);
          
      print('Eleman başarıyla güncellendi: ${element.id}');
    } catch (e) {
      print('Eleman güncelleme hatası: $e');
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
      print('Fotoğraf yükleniyor... Yol: $path, Boyut: ${file.length} bytes');
      
      // Mevcut kullanıcıyı al
      final user = _client.auth.currentUser;
      if (user == null) {
        print('Kullanıcı oturumu bulunamadı.');
        // Alternatif olarak anonim bir yükleme denemesi yapılabilir
      }
      
      try {
        // 'photos' bucket'a yüklemeyi dene
        await _client.storage.from('photos').uploadBinary(
          path, 
          file,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true  // Aynı isimde dosya varsa günceller
          ),
        );
        
        // Public URL oluştur
        final fileUrl = _client.storage.from('photos').getPublicUrl(path);
        print('Fotoğraf başarıyla yüklendi: $fileUrl');
        return fileUrl;
      } catch (e) {
        print('Storage hatası: $e');
        
        // RLS politikası hatası olabilir, diğer bucketları deneyelim
        // Her bucket için ayrı try-catch bloğu
        
        // element-photos bucket'ı deneyelim
        try {
          print('element-photos bucket deneniyor...');
          await _client.storage.from('element-photos').uploadBinary(
            path, 
            file,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true
            ),
          );
          
          final fileUrl = _client.storage.from('element-photos').getPublicUrl(path);
          print('element-photos bucket üzerinden yüklendi: $fileUrl');
          return fileUrl;
        } catch (alternativeError) {
          print('element-photos bucket hatası: $alternativeError');
        }
        
        // uploads bucket'ı deneyelim
        try {
          print('uploads bucket deneniyor...');
          await _client.storage.from('uploads').uploadBinary(
            path, 
            file,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true
            ),
          );
          
          final fileUrl = _client.storage.from('uploads').getPublicUrl(path);
          print('uploads bucket üzerinden yüklendi: $fileUrl');
          return fileUrl;
        } catch (uploadsError) {
          print('uploads bucket hatası: $uploadsError');
        }
        
        // public bucket'ı deneyelim (Supabase'in varsayılan public bucket'ı)
        try {
          print('public bucket deneniyor...');
          await _client.storage.from('public').uploadBinary(
            path, 
            file,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true
            ),
          );
          
          final fileUrl = _client.storage.from('public').getPublicUrl(path);
          print('public bucket üzerinden yüklendi: $fileUrl');
          return fileUrl;
        } catch (publicError) {
          print('public bucket hatası: $publicError');
        }
        
        print('Tüm bucket denemeleri başarısız oldu.');
        return null;
      }
    } catch (e) {
      print('Genel bir hata oluştu: $e');
      return null;
    }
  }

  Future<PhotoModel?> createElementPhoto(PhotoModel photo) async {
    try {
      // URL null ise bu fotoğrafı kaydetme
      if (photo.url.isEmpty) {
        print('Boş URL, veritabanına kaydetme atlanıyor');
        return null;
      }
      
      print('Fotoğraf veritabanına kaydediliyor: ${photo.url}');
      
      // Tabloya uygun JSON formatı hazırla - artık model uyumlu
      final photoData = photo.toJson();
      
      print('Fotoğraf verisi oluşturuldu: $photoData');
      print('SQL tablosuna gönderilecek veri:');
      print('- id: ${photoData['id']}');
      print('- url: ${photoData['url']}');
      print('- element_id: ${photoData['element_id']}');
      print('- status: ${photoData['status']}');
      print('- created_at: ${photoData['uploaded_at']}');
      
      // 'uploaded_at' yerine 'created_at' kullan
      photoData.remove('uploaded_at');
      photoData['created_at'] = photo.uploadedAt.toIso8601String();
      
      // local_path sütunu yoksa kaldır
      photoData.remove('local_path');
      
      final response = await _client
          .from('photos')
          .insert(photoData)
          .select()
          .single();

      print('Fotoğraf veritabanına kaydedildi, yanıt: $response');
      
      // Veritabanından gelen yanıttan PhotoModel oluştur
      final createdPhoto = PhotoModel.fromJson(response);
      
      print('Fotoğraf modeli oluşturuldu: ${createdPhoto.id}');
      print('- URL: ${createdPhoto.url}');
      print('- Element ID: ${createdPhoto.elementId}');
      print('- Onay Durumu: ${createdPhoto.approved}');
      
      return createdPhoto;
    } catch (e) {
      print('Fotoğraf veritabanı hatası: $e');
      return null;
    }
  }

  Future<String> uploadPhoto(String imagePath, String fileName) async {
    String fileUrl = '';
    try {
      if (kIsWeb) {
        // Web tarafında resim yükleme desteği
        final bytes = await XFile(imagePath).readAsBytes();
        final response =
            await _client.storage.from('photos').uploadBinary(fileName, bytes);

        // Public URL al
        fileUrl = _client.storage.from('photos').getPublicUrl(fileName);

        print('Web tarafında dosya yüklendi: $fileUrl');
      } else {
        // Mobil tarafında resim yükleme
        // Dart:io File sınıfını kullanarak uyumluluk sorunu oluşuyor
        // Bu nedenle mobil platformda da XFile kullanarak bytes olarak yükleyelim
        final bytes = await XFile(imagePath).readAsBytes();
        final response =
            await _client.storage.from('photos').uploadBinary(fileName, bytes);

        // Public URL al
        fileUrl = _client.storage.from('photos').getPublicUrl(fileName);

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
      final response =
          await _client.from('photos').insert(photo.toJson()).select().single();

      return PhotoModel.fromJson(response);
    } catch (e) {
      print('Fotoğraf oluşturma hatası: $e');
      rethrow;
    }
  }

  Future<void> updatePhotoStatus(String photoId, String status) async {
    try {
      await _client.from('photos').update({'status': status}).eq('id', photoId);
    } catch (e) {
      print('Fotoğraf durumu güncelleme hatası: $e');
      rethrow;
    }
  }

  // Proje katılım metodları
  Future<ProjectModel> joinProject(String projectId, String userId) async {
    try {
      // Proje ID'sini temizle
      String cleanProjectId = projectId.trim()
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .replaceAll("'", '')
          .trim();
      
      print('Temizlenmiş proje ID: $cleanProjectId');
      print('Katılmaya çalışan kullanıcı ID: $userId');
      
      // UUID formatını doğrula
      final RegExp uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
      if (!uuidRegex.hasMatch(cleanProjectId)) {
        print('UUID formatı geçerli değil: $cleanProjectId');
        throw Exception('Geçersiz proje ID formatı');
      }
      
      // Önce projeyi getir
      final project = await getProjectById(cleanProjectId);

      if (project == null) {
        throw Exception('Proje bulunamadı');
      }

      // Kullanıcı zaten projenin sahibi ise hata ver
      if (project.ownerId == userId) {
        throw Exception('Zaten bu projenin sahibisiniz');
      }

      // Kullanıcının projede olup olmadığını kontrol et
      final membershipCheck = await _client
          .from('project_members')
          .select()
          .eq('project_id', cleanProjectId)
          .eq('user_id', userId);
      
      print('Mevcut üyelik kontrolü: $membershipCheck');
          
      if (membershipCheck != null && membershipCheck.length > 0) {
        throw Exception('Zaten bu projeye katılmışsınız');
      }

      print('Projeye üye ekleniyor...');
      
      try {
        // Proje üyesi ilişkisi ekle
        final memberData = {
          'project_id': cleanProjectId,
          'user_id': userId,
          'is_authorized': false
        };
        
        print('Eklenecek üye verisi: $memberData');
        
          final response = await _client
            .from('project_members')
            .insert(memberData)
            .select();
            
        print('Proje üye ekleme yanıtı: $response');
        
        // Kontrol - üye eklendi mi?
        final checkMember = await _client
            .from('project_members')
            .select()
            .eq('project_id', cleanProjectId)
            .eq('user_id', userId);
        
        print('Üyelik doğrulama kontrolü: $checkMember');
          
          // Güncellenmiş projeyi getir
          final updatedProject = await getProjectById(cleanProjectId);
          if (updatedProject != null) {
            return updatedProject;
          } else {
            throw Exception('Proje güncellemesi doğrulanamadı');
          }
      } catch (updateError) {
        print('Proje üye ekleme hatası: $updateError');
        throw updateError;
      }
    } catch (e) {
      print('Projeye katılma hatası: $e');
      rethrow;
    }
  }

  // Proje kodu ile proje bulma
  Future<ProjectModel?> findProjectByShortCode(String shortCode) async {
    try {
      print('Proje kısa kodu ile arama: $shortCode');

      // Kısa kodun en az 6 karakter olmasını bekleyelim
      if (shortCode.length < 6) {
        print('Kısa kod çok kısa (min 6 karakter gerekli): $shortCode');
        return null;
      }

      // Tüm projeleri getir (sınırlı sayıda)
      final response = await _client.from('projects').select().limit(100);

      print('Toplam proje sayısı: ${response.length}');

      // İstemci tarafında filtreleme yap
      for (var projectData in response) {
        final projectId = projectData['id'].toString();
        print('Kontrol edilen proje ID: $projectId');

        // Proje ID'sinden temizlenmiş bir versiyonu oluşturalım
        String cleanProjectId = projectId
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .replaceAll("'", '')
            .trim();
        
        // Kısa kod ile karşılaştır - başlangıcı eşleşiyorsa yeterli
        if (cleanProjectId.toLowerCase().startsWith(shortCode.toLowerCase())) {
          print('Eşleşen proje bulundu: $cleanProjectId');
          
          // ProjectData'daki ID'yi temizlenmiş hale getirelim
          projectData['id'] = cleanProjectId;
          
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

  // Kullanıcının belirli bir projede yetkili olup olmadığını kontrol et
  Future<bool> isAuthorizedInProject(String projectId, String userId) async {
    try {
      final project = await getProjectById(projectId);
      
      if (project == null) {
        return false;
      }
      
      // Proje sahibi her zaman yetkilidir
      if (project.ownerId == userId) {
        return true;
      }
      
      // Yetkili üyeler - şimdi project_members tablosundan kontrol et
      final response = await _client
          .from('project_members')
          .select('is_authorized')
          .eq('project_id', projectId)
          .eq('user_id', userId)
          .maybeSingle();
      
      // Üye değilse veya yanıt yoksa
      if (response == null) {
        return false;
      }
      
      // Yetkili mi?
      return response['is_authorized'] == true;
      
    } catch (e) {
      print('Proje yetki kontrolü hatası: $e');
      return false;
    }
  }
  
  // Proje sahibi mi?
  Future<bool> isProjectOwner(String projectId, String userId) async {
    try {
      final project = await getProjectById(projectId);
      
      if (project == null) {
        return false;
      }
      
      return project.ownerId == userId;
    } catch (e) {
      print('Proje sahiplik kontrolü hatası: $e');
      return false;
    }
  }
  
  // Projenin üye listesini getir
  Future<List<Map<String, dynamic>>> getProjectMembers(String projectId) async {
    try {
      print('Proje üyeleri getiriliyor: $projectId');
      
      // Önce proje_members tablosundaki tüm kayıtları görüntüle (debug)
      final allMembers = await _client
          .from('project_members')
          .select('*');
      
      print('Tüm üyeler: $allMembers');
      
      // İlişkisel sorguyu düzeltelim - join yerine iki sorgu kullanalım
      final members = await _client
          .from('project_members')
          .select('*')
          .eq('project_id', projectId);
      
      print('Proje ID $projectId için bulunan üyeler: $members');
      
      // Her bir üye için profil bilgilerini manuel olarak getirelim
      List<Map<String, dynamic>> enrichedMembers = [];
      
      for (var member in members) {
        final userId = member['user_id'];
        
        // Profil bilgilerini getir
        try {
          final profile = await _client
              .from('profiles')
              .select('*')
              .eq('id', userId)
              .maybeSingle();
          
          // Profil bilgilerini üye verisine ekle
          if (profile != null) {
            member['profiles'] = profile;
      } else {
            member['profiles'] = {'username': 'Kullanıcı', 'profession': ''};
          }
          
          enrichedMembers.add(member);
        } catch (profileError) {
          print('Profil getirme hatası: $profileError');
          member['profiles'] = {'username': 'Kullanıcı', 'profession': ''};
          enrichedMembers.add(member);
        }
      }
      
      print('Zenginleştirilmiş üye sayısı: ${enrichedMembers.length}');
      return enrichedMembers;
    } catch (e) {
      print('Proje üyeleri getirme hatası: $e');
      return [];
    }
  }
  
  // Üyeyi yetkili/yetkisiz yap
  Future<bool> updateMemberAuthorization(String projectId, String memberId, bool authorize) async {
    try {
      print('Üye yetkilendirme işlemi başlatılıyor:');
      print('- Proje ID: $projectId');
      print('- Üye ID: $memberId'); 
      print('- Yetki Durumu: $authorize');
      
      // Doğrudan project_members tablosunda güncelleme yap
      await _client
          .from('project_members')
          .update({'is_authorized': authorize})
          .eq('project_id', projectId)
          .eq('user_id', memberId);
      
      // İşlemin doğruluğunu kontrol et
      final updatedMember = await _client
          .from('project_members')
          .select()
          .eq('project_id', projectId)
          .eq('user_id', memberId)
          .single();
      
      final bool updatedValue = updatedMember['is_authorized'] ?? false;
      
      print('Üye yetkilendirme işlemi tamamlandı:');
      print('- Güncel yetki durumu: $updatedValue');
      print('- İşlem başarılı: ${updatedValue == authorize}');
      
      // Her durumda true döndür - UI feedback'i daha önce gösteriliyor
      return true;
    } catch (e) {
      print('Üye yetkilendirme hatası: $e');
      return false;
    }
  }
  
  // Kullanıcının onaylama/reddetme yetkisi olup olmadığını kontrol et (artık dinamik)
  Future<bool> hasApprovalPermission(String projectId, String? userId) async {
    if (userId == null) return false;
    
    try {
      // Proje sahibi veya yetkili üye mi kontrol et
      return await isAuthorizedInProject(projectId, userId);
    } catch (e) {
      print('Onaylama yetkisi kontrolü hatası: $e');
      return false;
    }
  }

  // Projeden çıkma işlemi
  Future<bool> leaveProject(String projectId, String userId) async {
    try {
      print('Projeden çıkma işlemi başlatılıyor:');
      print('- Proje ID: $projectId');
      print('- Kullanıcı ID: $userId');
      
      // Kullanıcının projede olup olmadığını kontrol et
      final membershipCheck = await _client
          .from('project_members')
          .select()
          .eq('project_id', projectId)
          .eq('user_id', userId);
      
      if (membershipCheck == null || membershipCheck.isEmpty) {
        print('Kullanıcı bu projede üye değil');
        return false;
      }
      
      // Projeyi kontrol et
      final project = await getProjectById(projectId);
      if (project == null) {
        print('Proje bulunamadı');
        return false;
      }
      
      // Proje sahibi ise çıkamaz
      if (project.ownerId == userId) {
        print('Proje sahibi projeden çıkamaz');
        return false;
      }
      
      // Üyelik kaydını sil
      await _client
          .from('project_members')
          .delete()
          .eq('project_id', projectId)
          .eq('user_id', userId);
      
      print('Kullanıcı projeden başarıyla çıkarıldı');
      return true;
    } catch (e) {
      print('Projeden çıkma hatası: $e');
      return false;
    }
  }
}
