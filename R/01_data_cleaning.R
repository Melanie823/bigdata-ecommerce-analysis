# ===== 01 資料清理與彙總 =====
# 執行前請把工作目錄設為專案根目錄

library(readxl)
library(dplyr)
library(tidyverse)
library(lubridate)

# 原始資料請從 UCI 下載 online_retail_II.xlsx，放在 data/raw/ 資料夾
file_path <- "data/raw/online_retail_II.xlsx"

cat("讀取資料中...\n")
data_2009_2010 <- read_excel(file_path, sheet = "Year 2009-2010")
data_2010_2011 <- read_excel(file_path, sheet = "Year 2010-2011")

cat("2009-2010 工作表：", nrow(data_2009_2010), "筆\n")
cat("2010-2011 工作表：", nrow(data_2010_2011), "筆\n")

cat("\n合併資料中...\n")
retail_combined <- bind_rows(data_2009_2010, data_2010_2011)
cat("合併後：", nrow(retail_combined), "筆\n")

cat("\n原始欄位名稱：\n")
print(names(retail_combined))

# ===== 步驟 1：重命名欄位 =====
cat("\n重命名欄位...\n")
retail_combined <- retail_combined %>%
  rename(
    InvoiceNo = Invoice,           # "Invoice" → "InvoiceNo"
    CustomerID = `Customer ID`      # "Customer ID" → "CustomerID"（注意反引號）
  )

cat("修正後的欄位名稱：\n")
print(names(retail_combined))

# ===== 步驟 2：開始清洗 =====
# ===== 開始清洗 =====
cat("\n開始清洗...\n")

retail_clean <- retail_combined %>%
  # 移除缺失值
  filter(!is.na(CustomerID), !is.na(Quantity), !is.na(Price)) %>%
  
  # 移除負數和零
  filter(Quantity > 0, Price > 0) %>%
  
  # 移除異常值
  filter(Quantity < 1000, Price < 10000) %>%
  
  # 建立衍生欄位
  mutate(
    SalesAmount = Quantity * Price,
    TransactionDate = as.Date(InvoiceDate),
    Month = month(TransactionDate),
    Quarter = quarter(TransactionDate),
    Year = year(TransactionDate),
    DayOfWeek = wday(TransactionDate)
  ) %>%
  
  # 再次確認銷售額有效
  filter(SalesAmount > 0)

cat("✓ 清洗後：", nrow(retail_clean), "筆\n")
cat("✓ 缺失值數：", sum(is.na(retail_clean)), "\n")

# ===== 第一部分完成 ===== 

cat("\n\n===== 開始生成聚合資料 =====\n")

# 按日期聚合
cat("生成日度銷售聚合...\n")
daily_sales <- retail_clean %>%
  group_by(TransactionDate, Year, Quarter, Month) %>%
  summarise(
    TotalSales = sum(SalesAmount),
    TotalQuantity = sum(Quantity),
    TransactionCount = n_distinct(InvoiceNo),
    UniqueCustomers = n_distinct(CustomerID),
    UniqueProducts = n_distinct(StockCode),
    AvgOrderValue = mean(SalesAmount),
    .groups = 'drop'
  )

cat("✓ 日度聚合：", nrow(daily_sales), "筆\n")
write.csv(daily_sales, "data/daily_sales.csv", row.names = FALSE)
cat("✓ daily_sales.csv 已保存\n")

# 按商品類別聚合
cat("\n生成商品類別聚合...\n")
product_category <- retail_clean %>%
  mutate(
    Category = case_when(
      str_detect(Description, "(?i)mug|cup|plate|bowl|glass") ~ "Home & Kitchen",
      str_detect(Description, "(?i)t-shirt|shirt|dress|sweater") ~ "Clothing",
      str_detect(Description, "(?i)wall art|picture|frame|sticker") ~ "Decor",
      str_detect(Description, "(?i)toy|game|puzzle|model") ~ "Toys",
      TRUE ~ "Other"
    )
  ) %>%
  group_by(Category, Year, Quarter) %>%
  summarise(
    Sales = sum(SalesAmount),
    Quantity = sum(Quantity),
    Transactions = n(),
    Customers = n_distinct(CustomerID),
    .groups = 'drop'
  )

cat("✓ 商品類別聚合：", nrow(product_category), "筆\n")
write.csv(product_category, "data/product_category.csv", row.names = FALSE)
cat("✓ product_category.csv 已保存\n")

# 按客戶聚合
cat("\n生成客戶指標聚合...\n")
customer_metrics <- retail_clean %>%
  group_by(CustomerID) %>%
  summarise(
    TotalSpent = sum(SalesAmount),
    TransactionCount = n_distinct(InvoiceNo),
    PurchaseFrequency = n_distinct(Month),
    AvgTransactionValue = mean(SalesAmount),
    FirstPurchaseDate = min(TransactionDate),
    LastPurchaseDate = max(TransactionDate),
    DaysSinceFirstPurchase = as.numeric(max(TransactionDate) - min(TransactionDate)),
    .groups = 'drop'
  ) %>%
  mutate(
    CustomerSegment = case_when(
      TotalSpent > quantile(TotalSpent, 0.75) ~ "High-Value",
      TotalSpent > quantile(TotalSpent, 0.50) ~ "Medium-Value",
      TRUE ~ "Low-Value"
    )
  )

cat("✓ 客戶指標：", nrow(customer_metrics), "筆\n")
write.csv(customer_metrics, "data/customer_metrics.csv", row.names = FALSE)
cat("✓ customer_metrics.csv 已保存\n")

# 保存清洗後的完整資料
cat("\n保存完整清洗資料...\n")
write.csv(retail_clean, "data/raw/retail_cleaned.csv", row.names = FALSE)
cat("✓ retail_cleaned.csv 已保存\n")

# ===== 驗證 =====

cat("\n\n===== 驗證結果 =====\n")
cat("✓ retail_cleaned.csv :", nrow(retail_clean), "筆\n")
cat("✓ daily_sales.csv :", nrow(daily_sales), "筆\n")
cat("✓ product_category.csv :", nrow(product_category), "筆\n")
cat("✓ customer_metrics.csv :", nrow(customer_metrics), "筆\n")

cat("\n所有檔案已保存到：data/\n")

# 簡單統計
cat("\n\n===== 簡單統計 =====\n")
cat("資料時間範圍：", as.character(min(retail_clean$TransactionDate)), " 至 ", 
    as.character(max(retail_clean$TransactionDate)), "\n")
cat("總銷售額：$", round(sum(retail_clean$SalesAmount), 2), "\n")
cat("唯一客戶數：", n_distinct(retail_clean$CustomerID), "\n")
cat("唯一商品數：", n_distinct(retail_clean$StockCode), "\n")
cat("平均訂單額：$", round(mean(retail_clean$SalesAmount), 2), "\n")

cat("\n\n🎉 資料準備完成！\n")
cat("下一步：打開 Excel，導入 CSV 檔案到 Power Pivot\n")

# ===== 完成 =====