-- ============================================================================
-- KulturLab ATPH — Skema Database Supabase
-- Simulasi Laboratorium Kultur Jaringan Tanaman (Fase F / Kelas XI SMK ATPH)
-- Jalankan script ini di Supabase Dashboard > SQL Editor
-- ============================================================================

-- 1. Tabel Utama: hasil_praktikum
CREATE TABLE IF NOT EXISTS public.hasil_praktikum (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  nama_siswa text NOT NULL CHECK (char_length(trim(nama_siswa)) > 0),
  kelas text NOT NULL CHECK (kelas IN ('XI ATPH 1', 'XI ATPH 2', 'XI ATPH 3', 'XI AT 1', 'XI AT 2')),
  misi_kode text NOT NULL CHECK (misi_kode IN ('M1-TUNAS-PISANG', 'M2-AKAR-ANGGREK', 'M3-KALUS-JATI')),
  misi_nama text NOT NULL,
  skor_tahap_1 integer NOT NULL DEFAULT 0 CHECK (skor_tahap_1 >= 0 AND skor_tahap_1 <= 25),
  skor_tahap_2 integer NOT NULL DEFAULT 0 CHECK (skor_tahap_2 >= 0 AND skor_tahap_2 <= 25),
  skor_tahap_3 integer NOT NULL DEFAULT 0 CHECK (skor_tahap_3 >= 0 AND skor_tahap_3 <= 25),
  skor_tahap_4 integer NOT NULL DEFAULT 0 CHECK (skor_tahap_4 >= 0 AND skor_tahap_4 <= 25),
  skor_total integer NOT NULL DEFAULT 0 CHECK (skor_total >= 0 AND skor_total <= 100),
  status_kultur text NOT NULL,
  catatan_diagnosis text DEFAULT '',
  detail_parameter jsonb NOT NULL DEFAULT '{}'::jsonb
);

COMMENT ON TABLE public.hasil_praktikum IS 'Menyimpan riwayat skor dan parameter praktikum simulasi kultur jaringan siswa SMK ATPH.';

-- 2. Indeks Performa untuk Query Dashboard & Filter
CREATE INDEX IF NOT EXISTS idx_hasil_praktikum_created_at
  ON public.hasil_praktikum (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_hasil_praktikum_kelas
  ON public.hasil_praktikum (kelas);

CREATE INDEX IF NOT EXISTS idx_hasil_praktikum_misi_kode
  ON public.hasil_praktikum (misi_kode);

CREATE INDEX IF NOT EXISTS idx_hasil_praktikum_nama_siswa
  ON public.hasil_praktikum (nama_siswa);

-- 3. View Rekap Statistik per Kelas
CREATE OR REPLACE VIEW public.rekap_statistik_kelas
WITH (security_invoker = true) AS
SELECT
  kelas,
  COUNT(*)::integer AS total_percobaan,
  ROUND(AVG(skor_total), 2) AS rata_rata_skor,
  MAX(skor_total)::integer AS skor_tertinggi,
  MIN(skor_total)::integer AS skor_terendah,
  COUNT(*) FILTER (WHERE status_kultur = 'Berhasil Tumbuh')::integer AS jumlah_berhasil,
  COUNT(*) FILTER (WHERE status_kultur = 'Terkontaminasi Jamur & Bakteri')::integer AS jumlah_kontaminasi,
  COUNT(*) FILTER (WHERE status_kultur = 'Pertumbuhan Terhambat & Browning')::integer AS jumlah_terhambat,
  ROUND(
    (COUNT(*) FILTER (WHERE status_kultur = 'Berhasil Tumbuh')::numeric / NULLIF(COUNT(*), 0)) * 100,
    1
  ) AS persentase_berhasil,
  MAX(created_at) AS terakhir_praktikum
FROM public.hasil_praktikum
GROUP BY kelas
ORDER BY kelas ASC;

COMMENT ON VIEW public.rekap_statistik_kelas IS 'Ringkasan statistik hasil praktikum kultur jaringan per kelas.';

-- 4. Kebijakan Row Level Security (RLS) untuk Akses Publik Anon (Aplikasi Edukasi)
ALTER TABLE public.hasil_praktikum ENABLE ROW LEVEL SECURITY;

-- Hapus policy lama jika dijalankan ulang agar idempotent
DROP POLICY IF EXISTS "Allow anon select hasil_praktikum" ON public.hasil_praktikum;
DROP POLICY IF EXISTS "Allow anon insert hasil_praktikum" ON public.hasil_praktikum;
DROP POLICY IF EXISTS "Allow anon delete hasil_praktikum" ON public.hasil_praktikum;

-- Izinkan membaca data untuk Dashboard Rekap Nilai Guru & Cek Koneksi
CREATE POLICY "Allow anon select hasil_praktikum"
  ON public.hasil_praktikum
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Izinkan siswa menyimpan hasil praktikum baru
CREATE POLICY "Allow anon insert hasil_praktikum"
  ON public.hasil_praktikum
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Izinkan fitur Reset Data dari Dashboard Guru (dilindungi PIN Guru di sisi aplikasi)
CREATE POLICY "Allow anon delete hasil_praktikum"
  ON public.hasil_praktikum
  FOR DELETE
  TO anon, authenticated
  USING (true);

-- Pastikan role anon memiliki hak akses tabel dan view
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, DELETE ON public.hasil_praktikum TO anon, authenticated;
GRANT SELECT ON public.rekap_statistik_kelas TO anon, authenticated;
