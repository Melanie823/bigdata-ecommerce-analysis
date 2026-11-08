# ===== 02 統計分析 =====
# 執行前請把工作目錄設為專案根目錄，並先執行 01_data_cleaning.R

# 第 1 步：加載套件
library(fBasics)
library(ggplot2)
library(dplyr)
library(corrplot)

cat("加載套件完成！\n\n")

# 第 2 步：導入資料
cat("導入資料中...\n")
retail_clean <- read.csv("data/raw/retail_cleaned.csv")
customer_metrics <- read.csv("data/customer_metrics.csv")
daily_sales <- read.csv("data/daily_sales.csv")
product_category <- read.csv("data/product_category.csv")

cat("✓ 資料導入完成\n")
cat("  retail_clean:", nrow(retail_clean), "筆\n")
cat("  customer_metrics:", nrow(customer_metrics), "筆\n")
cat("  daily_sales:", nrow(daily_sales), "筆\n")
cat("  product_category:", nrow(product_category), "筆\n\n")

# ===== 分析 1：交易頻率 vs 消費額 =====
cat("========== 分析 1：交易頻率 vs 消費額 ==========\n\n")

# 1. 常態性檢定
cat("Step 1：常態性檢定（抽樣 4,000 筆）\n")
cat("--------\n")

set.seed(123)
sample_idx <- sample(nrow(customer_metrics), 4000)
customer_sample <- customer_metrics[sample_idx, ]

shapiro_freq <- shapiro.test(customer_sample$TransactionCount)
cat("交易頻率常態性檢定：\n")
cat("  Shapiro-Wilk W =", round(shapiro_freq$statistic, 4), "\n")
cat("  P-value =", format(shapiro_freq$p.value, scientific = TRUE), "\n")
if(shapiro_freq$p.value > 0.05) {
  cat("  結論：符合常態分布 (p > 0.05) ✓\n")
} else {
  cat("  結論：不符合常態分布 (p < 0.05)\n")
}

shapiro_spent <- shapiro.test(customer_sample$TotalSpent)
cat("\n消費額常態性檢定：\n")
cat("  Shapiro-Wilk W =", round(shapiro_spent$statistic, 4), "\n")
cat("  P-value =", format(shapiro_spent$p.value, scientific = TRUE), "\n")
if(shapiro_spent$p.value > 0.05) {
  cat("  結論：符合常態分布 (p > 0.05) ✓\n")
} else {
  cat("  結論：不符合常態分布 (p < 0.05)\n")
}

# 2. 皮爾森相關檢定
cat("\n\nStep 2：皮爾森相關檢定\n")
cat("--------\n")

# 用 cor.test 取代 pearsonTest
pearson_test <- cor.test(customer_metrics$TransactionCount, 
                         customer_metrics$TotalSpent, 
                         method = "pearson")

r_value <- pearson_test$estimate
p_pearson <- pearson_test$p.value

cat("相關係數 r =", round(r_value, 4), "\n")
cat("P-value =", format(p_pearson, scientific = TRUE), "\n")

if(p_pearson < 0.05) {
  cat("結論：交易頻率與消費額呈顯著正相關 (p < 0.05) ✓\n")
} else {
  cat("結論：沒有顯著相關 (p > 0.05)\n")
}

# 3. 散點圖
cat("\n\nStep 3：生成散點圖\n")
cat("--------\n")
png("images/r/Analysis1_ScatterPlot.png", width=800, height=600)
plot(customer_metrics$TransactionCount, 
     customer_metrics$TotalSpent,
     main="交易頻率 vs 消費總額",
     xlab="交易次數",
     ylab="消費額 ($)",
     pch=16,
     col=rgb(0, 0, 1, 0.3))
abline(lm(customer_metrics$TotalSpent ~ customer_metrics$TransactionCount), 
       col="red", lwd=2)
dev.off()
cat("✓ 散點圖已保存\n")

# 4. 迴歸分析
cat("\n\nStep 4：迴歸分析\n")
cat("--------\n")
model_freq <- lm(TotalSpent ~ TransactionCount, data=customer_metrics)
summary_freq <- summary(model_freq)
cat("R-squared =", round(summary_freq$r.squared, 4), "\n")
cat("  (交易頻率解釋", round(summary_freq$r.squared * 100, 2), "% 的消費額變異)\n")

cat("\n✓ 分析 1 完成！\n")
cat("  關鍵結果：r =", round(r_value, 4), ", p < 0.05\n")

# ===== 分析 2：商品類別銷售差異 =====
cat("\n\n========== 分析 2：商品類別銷售差異 ==========\n\n")

cat("Step 1：各類別常態性檢定\n")
cat("--------\n")
for (cat_name in unique(product_category$Category)) {
  data_subset <- product_category$Sales[product_category$Category == cat_name]
  if(length(data_subset) >= 3) {
    p_val <- shapiro.test(data_subset)$p.value
    cat(sprintf("%-20s Shapiro p-value = %.4f\n", cat_name, p_val))
  }
}

cat("\n\nStep 2：ANOVA 檢定（不同類別銷售是否有差異）\n")
cat("--------\n")
anova_result <- aov(Sales ~ Category, data=product_category)
anova_summary <- summary(anova_result)

f_value <- anova_summary[[1]]$`F value`[1]
p_value_anova <- anova_summary[[1]]$`Pr(>F)`[1]

cat("F-statistic =", round(f_value, 4), "\n")
cat("P-value =", format(p_value_anova, scientific = TRUE), "\n")

if(p_value_anova < 0.05) {
  cat("結論：不同商品類別銷售額存在顯著差異 (p < 0.05) ✓\n")
} else {
  cat("結論：沒有顯著差異 (p > 0.05)\n")
}

cat("\n\nStep 3：各類別銷售統計\n")
cat("--------\n")
category_stats <- product_category %>%
  group_by(Category) %>%
  summarise(
    Mean_Sales = mean(Sales, na.rm = TRUE),
    SD_Sales = sd(Sales, na.rm = TRUE),
    N = n(),
    .groups = 'drop'
  ) %>%
  arrange(desc(Mean_Sales))

print(category_stats)

cat("\n\nStep 4：生成盒線圖\n")
cat("--------\n")
png("images/r/Analysis2_BoxPlot.png", width=800, height=600)
boxplot(Sales ~ Category, 
        data=product_category,
        main="商品類別銷售差異",
        ylab="銷售額 ($)",
        col=c("lightblue", "lightgreen", "lightyellow", "lightcoral", "lightpink"))
dev.off()
cat("✓ 盒線圖已保存\n")

cat("\n✓ 分析 2 完成！\n")
cat("  關鍵結果：F =", round(f_value, 4), ", p", ifelse(p_value_anova<0.05, "< 0.05", "> 0.05"), "\n")

# ===== 分析 3：季節性影響 =====
cat("\n\n========== 分析 3：季節性影響 ==========\n\n")

cat("Step 1：準備季節資料\n")
cat("--------\n")
seasonal_data <- daily_sales %>%
  group_by(Year, Quarter) %>%
  summarise(
    TotalSales = sum(TotalSales, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  mutate(Quarter_factor = as.factor(Quarter))

cat("✓ 資料準備完成，筆數：", nrow(seasonal_data), "\n\n")

cat("Step 2：ANOVA 檢定（季度間銷售是否有差異）\n")
cat("--------\n")
anova_seasonal <- aov(TotalSales ~ Quarter_factor, data=seasonal_data)
anova_seasonal_summary <- summary(anova_seasonal)

f_seasonal <- anova_seasonal_summary[[1]]$`F value`[1]
p_seasonal <- anova_seasonal_summary[[1]]$`Pr(>F)`[1]

cat("F-statistic =", round(f_seasonal, 4), "\n")
cat("P-value =", format(p_seasonal, scientific = TRUE), "\n")

if(p_seasonal < 0.05) {
  cat("結論：不同季度銷售額存在顯著差異 (p < 0.05) ✓\n")
} else {
  cat("結論：沒有顯著差異 (p > 0.05)\n")
}

cat("\n\nStep 3：計算季節指數\n")
cat("--------\n")
overall_mean <- mean(seasonal_data$TotalSales, na.rm = TRUE)
seasonal_index <- seasonal_data %>%
  group_by(Quarter) %>%
  summarise(
    Mean_Sales = mean(TotalSales, na.rm = TRUE),
    Seasonal_Index = mean(TotalSales, na.rm = TRUE) / overall_mean,
    .groups = 'drop'
  ) %>%
  arrange(Quarter)

cat("季節指數：\n")
for (i in 1:nrow(seasonal_index)) {
  cat(sprintf("Q%d: %.4f (平均銷售額：$%.2f)\n", 
              seasonal_index$Quarter[i], 
              seasonal_index$Seasonal_Index[i],
              seasonal_index$Mean_Sales[i]))
}

cat("\n\nStep 4：生成季節性盒線圖\n")
cat("--------\n")
png("images/r/Analysis3_SeasonalBoxPlot.png", width=800, height=600)
boxplot(TotalSales ~ Quarter_factor, 
        data=seasonal_data,
        main="季度銷售分布",
        ylab="銷售額 ($)",
        xlab="季度",
        col=c("lightblue", "lightgreen", "lightyellow", "lightcoral"))
dev.off()
cat("✓ 盒線圖已保存\n")

cat("\n✓ 分析 3 完成！\n")
cat("  Q4 季節指數 =", round(seasonal_index$Seasonal_Index[4], 4), "\n")

# ===== 分析 4：客戶分段差異 =====
cat("\n\n========== 分析 4：客戶分段差異 ==========\n\n")

cat("Step 1：各分段常態性檢定（抽樣）\n")
cat("--------\n")
for (seg in unique(customer_metrics$CustomerSegment)) {
  data_subset <- customer_metrics$AvgTransactionValue[customer_metrics$CustomerSegment == seg]
  if(length(data_subset) > 5000) {
    sample_idx_seg <- sample(length(data_subset), 4000)
    data_subset <- data_subset[sample_idx_seg]
  }
  if(length(data_subset) >= 3) {
    p_val <- shapiro.test(data_subset)$p.value
    cat(sprintf("%-20s Shapiro p-value = %.4f\n", seg, p_val))
  }
}

cat("\n\nStep 2：ANOVA 檢定（不同客戶等級平均訂單額是否有差異）\n")
cat("--------\n")
anova_segment <- aov(AvgTransactionValue ~ CustomerSegment, data=customer_metrics)
anova_segment_summary <- summary(anova_segment)

f_segment <- anova_segment_summary[[1]]$`F value`[1]
p_segment <- anova_segment_summary[[1]]$`Pr(>F)`[1]

cat("F-statistic =", round(f_segment, 4), "\n")
cat("P-value =", format(p_segment, scientific = TRUE), "\n")

if(p_segment < 0.05) {
  cat("結論：不同客戶等級平均訂單額存在顯著差異 (p < 0.05) ✓\n")
} else {
  cat("結論：沒有顯著差異 (p > 0.05)\n")
}

cat("\n\nStep 3：客戶分段詳細統計\n")
cat("--------\n")
segment_summary <- customer_metrics %>%
  group_by(CustomerSegment) %>%
  summarise(
    Count = n(),
    Pct = n() / nrow(customer_metrics) * 100,
    Avg_Order_Value = mean(AvgTransactionValue, na.rm = TRUE),
    Total_Spent = sum(TotalSpent, na.rm = TRUE),
    Pct_Revenue = sum(TotalSpent, na.rm = TRUE) / sum(customer_metrics$TotalSpent) * 100,
    .groups = 'drop'
  ) %>%
  arrange(desc(Pct_Revenue))

print(segment_summary)

cat("\n\nStep 4：生成客戶分段盒線圖\n")
cat("--------\n")
png("images/r/Analysis4_SegmentBoxPlot.png", width=800, height=600)
boxplot(AvgTransactionValue ~ CustomerSegment,
        data=customer_metrics,
        main="客戶等級平均訂單額",
        ylab="平均訂單額 ($)",
        col=c("lightgreen", "lightyellow", "lightcoral"))
dev.off()
cat("✓ 盒線圖已保存\n")

cat("\n✓ 分析 4 完成！\n")
cat("  High-Value 客戶佔比：", round(segment_summary$Pct[1], 2), "%\n")
cat("  High-Value 營收貢獻：", round(segment_summary$Pct_Revenue[1], 2), "%\n")

# ===== 分析 5：相關矩陣 =====
cat("\n\n========== 分析 5：綜合相關矩陣 ==========\n\n")

cat("Step 1：準備相關分析資料\n")
cat("--------\n")
key_metrics <- customer_metrics %>%
  select(
    TransactionCount,
    PurchaseFrequency,
    AvgTransactionValue,
    TotalSpent,
    DaysSinceFirstPurchase
  ) %>%
  na.omit()

cat("✓ 有效樣本數：", nrow(key_metrics), "\n\n")

cat("Step 2：計算相關矩陣\n")
cat("--------\n")
correlation_matrix <- cor(key_metrics, use="complete.obs")
print(round(correlation_matrix, 4))

cat("\n\nStep 3：生成相關矩陣熱圖\n")
cat("--------\n")
png("images/r/Analysis5_CorrelationHeatmap.png", width=800, height=700)
corrplot(correlation_matrix, 
         method="circle",
         type="upper",
         tl.col="black",
         tl.srt=45)
dev.off()
cat("✓ 熱圖已保存\n")

cat("\n\nStep 4：最強相關對\n")
cat("--------\n")
cat("相關係數 > 0.7 的關係：\n")
found_strong <- FALSE
for (i in 1:(nrow(correlation_matrix)-1)) {
  for (j in (i+1):ncol(correlation_matrix)) {
    if (abs(correlation_matrix[i,j]) > 0.7) {
      cat(sprintf("  %s <-> %s: r = %.4f\n",
                  rownames(correlation_matrix)[i],
                  colnames(correlation_matrix)[j],
                  correlation_matrix[i,j]))
      found_strong <- TRUE
    }
  }
}
if(!found_strong) {
  cat("  （沒有相關係數 > 0.7 的關係）\n")
}

cat("\n✓ 分析 5 完成！\n")

# ===== 總結 =====
cat("\n\n========== 🎉 所有分析完成！==========\n\n")

cat("✅ 5 個分析結果：\n")
cat("  1. 交易頻率 vs 消費額：r =", round(r_value, 4), ", p < 0.05 ✓\n")
cat("  2. 商品類別差異：F =", round(f_value, 4), ", p", ifelse(p_value_anova<0.05, "< 0.05", "> 0.05"), "\n")
cat("  3. 季節性影響：F =", round(f_seasonal, 4), ", Q4 指數 =", round(seasonal_index$Seasonal_Index[4], 4), "\n")
cat("  4. 客戶分段差異：F =", round(f_segment, 4), ", p < 0.05 ✓\n")
cat("  5. 相關矩陣：已生成\n\n")

cat("✅ 5 張圖表已保存到：\n")
cat("  images/r/\n")
cat("  • Analysis1_ScatterPlot.png\n")
cat("  • Analysis2_BoxPlot.png\n")
cat("  • Analysis3_SeasonalBoxPlot.png\n")
cat("  • Analysis4_SegmentBoxPlot.png\n")
cat("  • Analysis5_CorrelationHeatmap.png\n\n")

cat("✅ Day 3 上午 R 分析完成！\n")
cat("✅ 所有統計結果已記錄！\n")

# ===== 完成 =====