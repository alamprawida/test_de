 
/* ---------------------------------------------------------------------
   LANGKAH 2.1  Tandai baris yang jatuh di dalam periode salah input
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS s2a_tandai_periode;
CREATE TABLE s2a_tandai_periode AS
SELECT r.ProductID, r.StoreID, r.ReportDate, r.SalesCumulativeSum,
       CASE WHEN r.ReportDate BETWEEN p.mulai AND p.selesai THEN 1 ELSE 0 END AS dalam_periode
FROM report_arif r CROSS JOIN s1_periode p;
 
-- CEK 2.1 : baris dalam periode vs di luar periode
SELECT dalam_periode, COUNT(*) AS jumlah_baris, MIN(ReportDate) AS dari, MAX(ReportDate) AS sampai
FROM s2a_tandai_periode GROUP BY dalam_periode;
 
/* ---------------------------------------------------------------------
   LANGKAH 2.2  Cari lonjakan nyasar di LUAR periode
   Hanya baris di luar periode yang diperiksa; nilai di dalam periode diabaikan.
   lonjakan = 1 bila nilai > nilai terkecil sesudahnya (di antara baris luar periode)
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS s2b_cek_lonjakan;
CREATE TABLE s2b_cek_lonjakan AS
WITH x AS (
  SELECT ProductID, StoreID, ReportDate, SalesCumulativeSum,
         MIN(SalesCumulativeSum) OVER (
           PARTITION BY ProductID, StoreID ORDER BY ReportDate
           ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING) AS min_later_value
  FROM s2a_tandai_periode
  WHERE dalam_periode = 0
)
SELECT *, CASE WHEN min_later_value IS NOT NULL AND SalesCumulativeSum > min_later_value
               THEN 1 ELSE 0 END AS lonjakan
FROM x;
 
-- CEK 2.2 : jumlah lonjakan dan tanggalnya
SELECT ReportDate, COUNT(*) AS jumlah_lonjakan FROM s2b_cek_lonjakan
WHERE lonjakan = 1 GROUP BY ReportDate ORDER BY ReportDate;
 
/* ---------------------------------------------------------------------
   LANGKAH 2.3  Status tiap baris raw: angka_valid atau non_valid (+ alasannya)
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS s2c_status;
CREATE TABLE s2c_status AS
SELECT t.ProductID, t.StoreID, t.ReportDate, t.SalesCumulativeSum AS raw_value,
       CASE WHEN t.dalam_periode = 1 OR l.lonjakan = 1 THEN 'non_valid' ELSE 'angka_valid' END AS status,
       CASE WHEN t.dalam_periode = 1 THEN 'dalam_periode'
            WHEN l.lonjakan = 1 THEN 'lonjakan' END AS alasan
FROM s2a_tandai_periode t
LEFT JOIN s2b_cek_lonjakan l
       ON l.ProductID = t.ProductID AND l.StoreID = t.StoreID AND l.ReportDate = t.ReportDate;
 
-- CEK 2.3 : berapa angka_valid dan non_valid
SELECT status, alasan, COUNT(*) AS jumlah FROM s2c_status GROUP BY status, alasan;
 
/* ---------------------------------------------------------------------
   LANGKAH 2.4  Kerangka lengkap: SEMUA produk-toko x SEMUA tanggal laporan
   Baris yang tidak ada di raw diberi status 'tidak_ada'
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS s2d_kerangka;
CREATE TABLE s2d_kerangka AS
WITH tgl AS (
  SELECT ReportDate, ROW_NUMBER() OVER (ORDER BY ReportDate) AS nomor
  FROM (SELECT DISTINCT ReportDate FROM report_arif)
),
pasangan AS (SELECT DISTINCT ProductID, StoreID FROM report_arif)
SELECT p.ProductID, p.StoreID, t.ReportDate, t.nomor,
       s.raw_value,
       COALESCE(s.status, 'tidak_ada') AS status
FROM pasangan p
CROSS JOIN tgl t
LEFT JOIN s2c_status s
       ON s.ProductID = p.ProductID AND s.StoreID = p.StoreID AND s.ReportDate = t.ReportDate;
 
-- CEK 2.4 : 7.500 pasangan x 24 tanggal = 180.000 baris
SELECT COUNT(*) AS baris, COUNT(DISTINCT ReportDate) AS tanggal,
       SUM(status = 'angka_valid') AS angka_valid, SUM(status = 'non_valid') AS non_valid,
       SUM(status = 'tidak_ada') AS tidak_ada
FROM s2d_kerangka;
 
/* ---------------------------------------------------------------------
   LANGKAH 2.5  Untuk tiap baris cari angka_valid terdekat di kiri & kanan
   prev_date  = tanggal angka_valid TERAKHIR sampai (dan termasuk) baris ini
   next_date  = tanggal angka_valid PERTAMA mulai (dan termasuk) baris ini
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS s2e_prev_next;
CREATE TABLE s2e_prev_next AS
WITH w AS (
  SELECT k.*,
    MAX(CASE WHEN status = 'angka_valid' THEN ReportDate END) OVER (
        PARTITION BY ProductID, StoreID ORDER BY ReportDate
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS prev_date,
    MIN(CASE WHEN status = 'angka_valid' THEN ReportDate END) OVER (
        PARTITION BY ProductID, StoreID ORDER BY ReportDate
        ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS next_date
  FROM s2d_kerangka k
)
SELECT w.ProductID, w.StoreID, w.ReportDate, w.nomor, w.raw_value, w.status,
       w.prev_date, pv.raw_value AS prev_value, pv.nomor AS prev_nomor,
       w.next_date, nv.raw_value AS next_value, nv.nomor AS next_nomor
FROM w
LEFT JOIN s2d_kerangka pv ON pv.ProductID = w.ProductID AND pv.StoreID = w.StoreID AND pv.ReportDate = w.prev_date
LEFT JOIN s2d_kerangka nv ON nv.ProductID = w.ProductID AND nv.StoreID = w.StoreID AND nv.ReportDate = w.next_date;
 
-- CEK 2.5 : lihat 1 produk (kolom prev/next menunjukkan "teman valid" tiap tanggal)
SELECT ReportDate, raw_value, status, prev_date, prev_value, next_date, next_value
FROM s2e_prev_next
WHERE ProductID = 3704769971 AND StoreID = 14184451
ORDER BY ReportDate;
 
/* ---------------------------------------------------------------------
   LANGKAH 2.6  Hitung angka bersih
   
   keterangan:
     angka_valid           = angka raw dipertahankan
     non_valid_diganti     = angka non_valid, nilainya BERUBAH
     non_valid_nilai_tetap = angka non_valid, tapi hasil perkiraan kebetulan sama
     kosong_diisi          = baris tidak ada di raw, diisi
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS s2f_hasil_bersih;
CREATE TABLE s2f_hasil_bersih AS
WITH h AS (
  SELECT ProductID, StoreID, ReportDate, raw_value, status, prev_date, next_date,
         CAST(ROUND(
           CASE
             WHEN prev_date IS NULL THEN next_value
             WHEN next_date IS NULL OR next_date = prev_date THEN prev_value
             ELSE prev_value + (next_value - prev_value) * 1.0
                  * (nomor - prev_nomor) / (next_nomor - prev_nomor)
           END) AS INTEGER) AS SalesCumulativeSum
  FROM s2e_prev_next
  WHERE prev_date IS NOT NULL OR next_date IS NOT NULL
)
SELECT ProductID, StoreID, ReportDate, SalesCumulativeSum, raw_value, status,
       CASE WHEN status = 'tidak_ada' THEN 'kosong_diisi'
            WHEN status = 'angka_valid' THEN 'angka_valid'
            WHEN raw_value = SalesCumulativeSum THEN 'non_valid_nilai_tetap'
            ELSE 'non_valid_diganti' END AS keterangan
FROM h;
 
-- CEK 2.6a : keterangan
SELECT keterangan, COUNT(*) AS jumlah FROM s2f_hasil_bersih GROUP BY keterangan;
 
-- CEK 2.6b : tidak boleh ada kumulatif yang turun
SELECT COUNT(*) AS jumlah_yang_turun FROM (
  SELECT SalesCumulativeSum - LAG(SalesCumulativeSum) OVER (
           PARTITION BY ProductID, StoreID ORDER BY ReportDate) AS selisih
  FROM s2f_hasil_bersih) WHERE selisih < 0;
 
/* ---------------------------------------------------------------------
   LANGKAH 2.7  Pasangan yang tidak bisa dipulihkan
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS s2g_tidak_bisa_dipulihkan;
CREATE TABLE s2g_tidak_bisa_dipulihkan AS
SELECT ProductID, StoreID FROM s2d_kerangka
GROUP BY ProductID, StoreID HAVING SUM(status = 'angka_valid') = 0;
 
-- CEK 2.7 : 
-- SELECT COUNT(*) AS pasangan_tidak_bisa_dipulihkan FROM s2g_tidak_bisa_dipulihkan;
 
/* final */
DROP VIEW IF EXISTS report_clean;
CREATE VIEW v_report_clean AS
SELECT ProductID, StoreID, ReportDate, SalesCumulativeSum, keterangan AS DataStatus
FROM s2f_hasil_bersih;
 
DROP TABLE IF EXISTS report_clean;
CREATE TABLE report_clean AS
SELECT ProductID, StoreID, ReportDate, SalesCumulativeSum, keterangan AS DataStatus
FROM s2f_hasil_bersih;