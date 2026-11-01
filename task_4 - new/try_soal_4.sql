
/* =====================================================================
   Data visualisasi
   ===================================================================== */
 
-- total kumulatif semua produk per tanggal
SELECT s.ReportDate, s.total_sebelum, c.total_sesudah
FROM (SELECT ReportDate, SUM(SalesCumulativeSum) AS total_sebelum FROM report_arif GROUP BY ReportDate) s
JOIN (SELECT ReportDate, SUM(SalesCumulativeSum) AS total_sesudah FROM report_clean GROUP BY ReportDate) c
  ON c.ReportDate = s.ReportDate
ORDER BY s.ReportDate;
 
-- jumlah baris per tanggal
SELECT s.ReportDate, s.baris_sebelum, c.baris_sesudah
FROM (SELECT ReportDate, COUNT(*) AS baris_sebelum FROM report_arif GROUP BY ReportDate) s
JOIN (SELECT ReportDate, COUNT(*) AS baris_sesudah FROM report_clean GROUP BY ReportDate) c
  ON c.ReportDate = s.ReportDate
ORDER BY s.ReportDate;
 
-- % anomali per tanggal
WITH sesudah AS (
  SELECT ReportDate, SalesCumulativeSum AS v,
         MIN(SalesCumulativeSum) OVER (PARTITION BY ProductID, StoreID ORDER BY ReportDate
              ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING) AS min_later_value
  FROM report_clean
)
SELECT r.ReportDate,
       r.persen_anomali AS persen_anomali_sebelum,
       ROUND(100.0 * SUM(CASE WHEN s.v > s.min_later_value THEN 1 ELSE 0 END)
             / NULLIF(COUNT(s.min_later_value), 0), 2) AS persen_anomali_sesudah
FROM s1_rekap_tanggal r
JOIN sesudah s ON s.ReportDate = r.ReportDate
GROUP BY r.ReportDate, r.persen_anomali
ORDER BY r.ReportDate;
 
-- satu produk, angka raw vs angka bersih
SELECT ReportDate, raw_value, SalesCumulativeSum AS angka_bersih, status, keterangan
FROM s2f_hasil_bersih
WHERE ProductID = 6413450932 AND StoreID = 5506052
ORDER BY ReportDate;