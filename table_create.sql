-- Project Members tablosu - Projeler ve kullanıcılar arasındaki ilişkiyi saklamak için
CREATE TABLE project_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_authorized BOOLEAN DEFAULT FALSE,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(project_id, user_id)
);

-- Row Level Security (RLS) ayarları
ALTER TABLE project_members ENABLE ROW LEVEL SECURITY;

-- Herkes kendi kaydını görebilir
CREATE POLICY "Kullanıcılar kendi üyeliklerini görebilir" ON project_members
  FOR SELECT
  USING (auth.uid() = user_id);

-- Proje sahibi tüm üyeleri görebilir
CREATE POLICY "Proje sahipleri tüm üyeleri görebilir" ON project_members
  FOR ALL
  USING ((SELECT owner_id FROM projects WHERE id = project_id) = auth.uid());

-- Kullanıcı ekleme yetkisi - kullanıcı kendisini ekleyebilir
CREATE POLICY "Kullanıcılar kendilerini projeye ekleyebilir" ON project_members
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Proje sahipleri üyeleri yönetebilir (silme yetkisi)
CREATE POLICY "Proje sahipleri üyeleri yönetebilir" ON project_members
  FOR DELETE
  USING ((SELECT owner_id FROM projects WHERE id = project_id) = auth.uid());

-- İndeksler
CREATE INDEX project_members_project_id_idx ON project_members(project_id);
CREATE INDEX project_members_user_id_idx ON project_members(user_id);

-- Supabase realtime özelliği için yayın ayarları
ALTER PUBLICATION supabase_realtime ADD TABLE project_members; 