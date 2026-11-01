-- 5a. Pareto produk: produk teratas menyumbang berapa persen penjualan
SELECT ProductID, SalesCumulativeSum AS total_penjualan,
       ROUND(100.0 * SUM(SalesCumulativeSum) OVER (ORDER BY SalesCumulativeSum DESC, ProductID)
             / SUM(SalesCumulativeSum) OVER (), 2) AS persen_kumulatif
FROM report_clean WHERE ReportDate = '2021-05-18'
ORDER BY total_penjualan DESC;
 
-- 5b. % produk tanpa penjualan sama sekali
SELECT ROUND(100.0 * AVG(CASE WHEN SalesCumulativeSum = 0 THEN 1.0 ELSE 0 END), 1) AS persen_produk_tidak_laku
FROM report_clean WHERE ReportDate = '2021-05-18';
 
-- 5c. Toko: jumlah produk dan total penjualan
SELECT StoreID, COUNT(DISTINCT ProductID) AS jumlah_produk, SUM(SalesCumulativeSum) AS total_penjualan
FROM report_clean WHERE ReportDate = '2021-05-18'
GROUP BY StoreID ORDER BY total_penjualan DESC;
 
-- 5d. % toko yang hanya membawa 1 produk
SELECT ROUND(100.0 * AVG(CASE WHEN n = 1 THEN 1.0 ELSE 0 END), 1) AS persen_toko_1_produk
FROM (SELECT StoreID, COUNT(DISTINCT ProductID) AS n FROM report_clean GROUP BY StoreID);
 
-- 5e. Seberapa cepat penjualan tercapai setelah restock (hanya angka_valid di 23 April; harus 95.4)
SELECT ROUND(100.0 * SUM(a.SalesCumulativeSum) / SUM(z.SalesCumulativeSum), 1) AS persen_laku_di_awal
FROM report_clean a
JOIN report_clean z ON z.ProductID = a.ProductID AND z.StoreID = a.StoreID
WHERE a.ReportDate = '2021-04-23' AND a.DataStatus = 'angka_valid'
  AND z.ReportDate = '2021-05-18' AND z.SalesCumulativeSum > 0;
 