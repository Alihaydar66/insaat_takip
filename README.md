# İnşaat Takip Uygulaması

İnşaat Takip, inşaat projelerinin takibi için geliştirilmiş bir mobil uygulamadır. Bu uygulama ile inşaat projelerinizi, katları ve yapı elemanlarını organize edebilir, durumlarını takip edebilir ve fotoğraflarla belgeleyebilirsiniz.

## Özellikler

- **Kullanıcı Yönetimi**: Kayıt olma, giriş yapma ve profil düzenleme işlemleri
- **Proje Yönetimi**: Yeni proje oluşturma, projeleri listeleme ve düzenleme
- **Kat ve Eleman Yönetimi**: Projelere kat ve elemanlara ekleme
- **Fotoğraf Ekleme**: Yapı elemanlarına fotoğraf ekleme ve takip etme
- **Onay/Red Mekanizması**: Eklenen fotoğrafları onaylama veya reddetme
- **Takım Çalışması**: Projelere kullanıcı davet etme (yakında)

## Teknolojiler

- **Frontend**: Flutter
- **Backend**: Supabase
- **Veritabanı**: PostgreSQL (Supabase tarafından yönetilir)
- **Depolama**: Supabase Storage

## Kurulum ve Çalıştırma

### Ön Gereksinimler

- Flutter SDK (en az 3.0.0)
- Dart SDK (en az 2.12.0)
- Android Studio / VS Code
- Supabase hesabı

### Adımlar

1. Projeyi klonlayın:
   ```
   git clone https://github.com/Alihaydar66/insaat_takip.git
   ```

2. Bağımlılıkları yükleyin:
   ```
   cd insaat_takip
   flutter pub get
   ```

3. Supabase ayarlarınızı yapın:
   - Supabase hesabı oluşturun ve yeni bir proje oluşturun
   - `.env` dosyasını proje kök dizinine oluşturun ve aşağıdaki değerleri ekleyin:
     ```
     SUPABASE_URL=YOUR_SUPABASE_URL
     SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
     ```

4. Supabase tablolarını oluşturun:
   - `profiles`: Kullanıcı profilleri
   - `projects`: Projeler
   - `floors`: Katlar
   - `elements`: Yapı elemanları
   - `photos`: Fotoğraflar

5. Uygulamayı çalıştırın:
   ```
   flutter run
   ```

## Proje Yapısı

```
lib/
  |- models/       # Veri modelleri
  |- screens/      # Uygulama ekranları
  |- services/     # Servisler (API, depolama)
  |- utils/        # Yardımcı sınıflar ve fonksiyonlar
  |- widgets/      # Yeniden kullanılabilir widget'lar
  |- main.dart     # Uygulama başlangıç noktası
```

## Lisans

Bu proje MIT lisansı altında lisanslanmıştır.

## İletişim

Sorular ve destek için: ornek@email.com
