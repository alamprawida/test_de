 /* #####################################################################
   LOGIKA:
   Tanpa restock, SalesCumulativeSum per (ProductID, StoreID) tidak boleh turun.
   Maka untuk setiap baris, lihat semua baris SESUDAHNYA (pasangan produk-toko yang sama):
   kalau nilai hari ini > nilai terkecil sesudahnya, nilai hari ini pasti salah -> anomali = 1.
   ##################################################################### */
 
CREATE INDEX IF NOT EXISTS ix_report ON report_arif (ProductID, StoreID, ReportDate);
 
DROP TABLE IF EXISTS s1_raw_anomali;
CREATE TABLE s1_raw_anomali AS
WITH a AS (
  SELECT ProductID, StoreID, ReportDate, SalesCumulativeSum,
         MIN(SalesCumulativeSum) OVER (
           PARTITION BY ProductID, StoreID ORDER BY ReportDate
           ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING) AS min_later_value
  FROM report_arif
)
SELECT a.ProductID, a.StoreID, a.ReportDate, a.SalesCumulativeSum,
       a.min_later_value,
       (SELECT MIN(b.ReportDate) FROM report_arif b
         WHERE b.ProductID = a.ProductID AND b.StoreID = a.StoreID
           AND b.ReportDate > a.ReportDate
           AND b.SalesCumulativeSum = a.min_later_value)            AS min_later_date,
       CASE WHEN a.min_later_value IS NULL THEN 0
            WHEN a.SalesCumulativeSum > a.min_later_value THEN 1
            ELSE 0 END                                              AS anomali
FROM a;
 
-- CEK 1.1a : jumlah baris
SELECT (SELECT COUNT(*) FROM report_arif) AS baris_raw,
       (SELECT COUNT(*) FROM s1_raw_anomali) AS baris_s1,
       (SELECT SUM(anomali) FROM s1_raw_anomali) AS total_anomali;
 
-- CEK 1.1b : lihat satu contoh produk
SELECT * FROM s1_raw_anomali
WHERE ProductID = 3704769971 AND StoreID = 14184451
ORDER BY ReportDate;
 
-- CEK 1.1c : 20 baris pertama
SELECT * FROM s1_raw_anomali WHERE anomali = 1
ORDER BY ReportDate, ProductID LIMIT 20;
 
/* ---------------------------------------------------------------------
   Rekap per tanggal: berapa % baris anomali
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS s1_rekap_tanggal;
CREATE TABLE s1_rekap_tanggal AS
SELECT ReportDate,
       COUNT(min_later_value)                                     AS bisa_dicek,
       SUM(anomali)                                               AS jumlah_anomali,
       ROUND(100.0 * SUM(anomali) / NULLIF(COUNT(min_later_value), 0), 2) AS persen_anomali
FROM s1_raw_anomali
GROUP BY ReportDate;
 
-- CEK 1.2 : lihat seluruh rekap
SELECT * FROM s1_rekap_tanggal ORDER BY ReportDate;
 
/* ---------------------------------------------------------------------
   Tentukan periode salah input: tanggal dengan persen_anomali (ambang batas = 5%)
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS s1_periode;
CREATE TABLE s1_periode AS
SELECT MIN(ReportDate) AS mulai, MAX(ReportDate) AS selesai, COUNT(*) AS jumlah_hari_kerja
FROM s1_rekap_tanggal
WHERE persen_anomali >= 5;
 
-- CEK 1.3 : cek periode salah
SELECT * FROM s1_periode;