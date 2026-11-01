 
/* =====================================================================
   Penjualan harian
   ===================================================================== */

SELECT ProductID, StoreID, ReportDate, SalesCumulativeSum,
       LAG(SalesCumulativeSum) OVER w AS kumulatif_kemarin,
       SalesCumulativeSum - LAG(SalesCumulativeSum) OVER w AS penjualan_harian
FROM report_clean
WINDOW w AS (PARTITION BY ProductID, StoreID ORDER BY ReportDate)
ORDER BY ProductID, StoreID, ReportDate;