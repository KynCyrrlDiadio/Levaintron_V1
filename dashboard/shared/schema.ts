import { sql } from "drizzle-orm";
import { pgTable, text, varchar, integer, real, timestamp, boolean, jsonb, serial, date, numeric } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

// ============================================================
// SHARED TABLES
// These tables are used by both the dashboard and the Python
// pipeline. Schema is merged between Replit dashboard and
// Fedora production to ensure compatibility.
// ============================================================

export const products = pgTable("products", {
  id: serial("id").primaryKey(),
  productId: varchar("product_id", { length: 20 }).notNull().unique(),
  sku: varchar("sku", { length: 30 }).notNull(),
  productName: varchar("product_name", { length: 200 }).notNull(),
  category: varchar("category", { length: 50 }).default("bread"),
  storeId: varchar("store_id", { length: 20 }).notNull().default("70012004"),
  trayFactor: integer("tray_factor").notNull().default(9),
  shelfLifeDays: integer("shelf_life_days").notNull().default(16),
  reorderPoint: integer("reorder_point").default(20),
  reorderQuantity: integer("reorder_quantity").default(20),
  deliveryDays: text("delivery_days").notNull().default("mon,tue,thu,fri"),
  leadTimeDays: integer("lead_time_days").notNull().default(3),
  returnDays: text("return_days").notNull().default("tue,fri"),
  isActive: boolean("is_active").notNull().default(true),
  mlpEnabled: boolean("mlp_enabled").default(false),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// ============================================================
// DASHBOARD-MANAGED TABLES
// ============================================================

// Training data samples for the MLP
export const trainingData = pgTable("training_data", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  currentInventory: integer("current_inventory").notNull(),
  dayOfWeek: integer("day_of_week").notNull(), // 0-6
  expectedSales: real("expected_sales").notNull(), // loaves per day from forecast
  actualSalesRate: real("actual_sales_rate").notNull(), // rolling actual sales/day
  monthlyMultiplier: real("monthly_multiplier").notNull().default(1.0), // seasonal multiplier
  isHoliday: boolean("is_holiday").notNull().default(false),
  pipelineIncoming: integer("pipeline_incoming").notNull().default(0), // units in pipeline
  returnsRate: real("returns_rate").notNull().default(0), // 30-day rolling return %
  decision: integer("decision").notNull(), // 0, 5, 10, or 20
  createdAt: timestamp("created_at").defaultNow(),
});

// Predictions made by the MLP
export const predictions = pgTable("predictions", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  inputFeatures: jsonb("input_features").notNull(),
  predictedDecision: integer("predicted_decision").notNull(), // 0, 5, 10, or 20
  confidence: real("confidence").notNull(), // 0-1
  modelVersion: text("model_version").notNull(),
  createdAt: timestamp("created_at").defaultNow(),
});

// Order history (dashboard-tracked orders)
export const orders = pgTable("orders", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  quantity: integer("quantity").notNull(), // 0, 5, 10, or 20
  predictionId: varchar("prediction_id").references(() => predictions.id),
  status: text("status").notNull().default("pending"), // pending, confirmed, delivered
  notes: text("notes"),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// Model training runs
export const trainingRuns = pgTable("training_runs", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  modelVersion: text("model_version").notNull(),
  epochs: integer("epochs").notNull(),
  batchSize: integer("batch_size").notNull(),
  learningRate: real("learning_rate").notNull(),
  trainLoss: real("train_loss"),
  valLoss: real("val_loss"),
  accuracy: real("accuracy"),
  samplesUsed: integer("samples_used").notNull(),
  status: text("status").notNull().default("running"), // running, completed, failed
  startedAt: timestamp("started_at").defaultNow(),
  completedAt: timestamp("completed_at"),
});

// System logs
export const systemLogs = pgTable("system_logs", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  level: text("level").notNull(), // info, warn, error
  message: text("message").notNull(),
  metadata: jsonb("metadata"),
  createdAt: timestamp("created_at").defaultNow(),
});

// Seasonal sales data from store forecast paperwork
export const seasonalSalesData = pgTable("seasonal_sales_data", {
  id: serial("id").primaryKey(),
  storeId: varchar("store_id", { length: 20 }).notNull().default("70012004"),
  supplier: varchar("supplier", { length: 100 }).default("Canada Bread Company"),
  category: varchar("category", { length: 100 }).notNull(),
  sku: varchar("sku", { length: 30 }).notNull(),
  productName: varchar("product_name", { length: 200 }).notNull(),
  packSize: integer("pack_size"),
  forecastPeriod: varchar("forecast_period", { length: 50 }),
  onHand: integer("on_hand").default(0),
  production: integer("production").default(0),
  thuSales: integer("thu_sales").default(0),
  friSales: integer("fri_sales").default(0),
  satSales: integer("sat_sales").default(0),
  sunSales: integer("sun_sales").default(0),
  monSales: integer("mon_sales").default(0),
  tueSales: integer("tue_sales").default(0),
  wedSales: integer("wed_sales").default(0),
  weeklyTotal: integer("weekly_total").default(0),
  peakDay: varchar("peak_day", { length: 10 }),
  notes: text("notes"),
  createdAt: timestamp("created_at").defaultNow(),
});

// Returns invoices - parsed Tue/Fri invoice uploads
export const returnsInvoices = pgTable("returns_invoices", {
  id: serial("id").primaryKey(),
  invoiceId: varchar("invoice_id", { length: 50 }).notNull().unique(),
  storeId: varchar("store_id", { length: 20 }).notNull().default("70012004"),
  invoiceDate: date("invoice_date").notNull(),
  productId: varchar("product_id", { length: 20 }).notNull(),
  unitsReturned: integer("units_returned").notNull(),
  reason: text("reason"),
  processedAt: timestamp("processed_at").defaultNow(),
  tokensUpdated: integer("tokens_updated").default(0),
});

// Hormuz multiplier configuration (macro-economic dampener)
export const hormuzConfig = pgTable("hormuz_config", {
  id: serial("id").primaryKey(),
  productId: varchar("product_id", { length: 20 }).notNull().unique(),
  multiplier: real("multiplier").notNull().default(1.0),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// ============================================================
// READ-ONLY REFERENCES TO PYTHON-MANAGED TABLES
// These tables are created/managed by the Python pipeline.
// Defined here for Drizzle querying only — NOT in tablesFilter
// so Drizzle won't alter or migrate them.
// ============================================================

export const tokenSalesLog = pgTable("token_sales_log", {
  id: serial("id").primaryKey(),
  productId: varchar("product_id", { length: 20 }).notNull(),
  storeId: varchar("store_id", { length: 20 }).notNull(),
  saleDate: date("sale_date").notNull(),
  unitsSold: integer("units_sold").notNull(),
  batchId: varchar("batch_id", { length: 100 }),
  arrivalDate: date("arrival_date"),
  expirationDate: date("expiration_date"),
  daysOnShelf: integer("days_on_shelf"),
  source: varchar("source", { length: 50 }),
  createdAt: timestamp("created_at").defaultNow(),
});

export const tokenReturnsLog = pgTable("token_returns_log", {
  id: serial("id").primaryKey(),
  productId: varchar("product_id", { length: 20 }).notNull(),
  storeId: varchar("store_id", { length: 20 }).notNull(),
  returnDate: date("return_date").notNull(),
  unitsReturned: integer("units_returned").notNull(),
  invoiceId: varchar("invoice_id", { length: 50 }),
  batchId: varchar("batch_id", { length: 100 }),
  arrivalDate: date("arrival_date"),
  expirationDate: date("expiration_date"),
  daysOnShelf: integer("days_on_shelf"),
  reason: text("reason"),
  createdAt: timestamp("created_at").defaultNow(),
});

// ============================================================
// NOTE: The following tables are also managed by Python and
// already exist in your production database. They are NOT
// defined here to prevent Drizzle from altering them:
//   - product_tokens (Python: token_id PK, product_name, status_date, etc.)
//   - mlp_order_log (Python: mlp_recommendation, actual_loaves_ordered, etc.)
//   - daily_forecast, seasonal_pattern, daily_sales_log
//   - inventory_transactions, physical_counts, mlp_decisions
//   - stores, tracked_stores, store_products, snapshot_products
//   - baseline_products, store_snapshots, store_baselines, snapshot_diffs
// ============================================================

// Insert schemas
export const insertProductSchema = createInsertSchema(products).omit({ id: true, createdAt: true, updatedAt: true });
export const insertTrainingDataSchema = createInsertSchema(trainingData).omit({ id: true, createdAt: true });
export const insertPredictionSchema = createInsertSchema(predictions).omit({ id: true, createdAt: true });
export const insertOrderSchema = createInsertSchema(orders).omit({ id: true, createdAt: true, updatedAt: true });
export const insertTrainingRunSchema = createInsertSchema(trainingRuns).omit({ id: true, startedAt: true, completedAt: true });
export const insertSystemLogSchema = createInsertSchema(systemLogs).omit({ id: true, createdAt: true });
export const insertSeasonalSalesSchema = createInsertSchema(seasonalSalesData).omit({ id: true, createdAt: true });
export const insertReturnsInvoiceSchema = createInsertSchema(returnsInvoices).omit({ id: true, processedAt: true });
export const insertHormuzConfigSchema = createInsertSchema(hormuzConfig).omit({ id: true, updatedAt: true });

// Types
export type Product = typeof products.$inferSelect;
export type InsertProduct = z.infer<typeof insertProductSchema>;

export type TrainingData = typeof trainingData.$inferSelect;
export type InsertTrainingData = z.infer<typeof insertTrainingDataSchema>;

export type Prediction = typeof predictions.$inferSelect;
export type InsertPrediction = z.infer<typeof insertPredictionSchema>;

export type Order = typeof orders.$inferSelect;
export type InsertOrder = z.infer<typeof insertOrderSchema>;

export type TrainingRun = typeof trainingRuns.$inferSelect;
export type InsertTrainingRun = z.infer<typeof insertTrainingRunSchema>;

export type SystemLog = typeof systemLogs.$inferSelect;
export type InsertSystemLog = z.infer<typeof insertSystemLogSchema>;

export type SeasonalSalesData = typeof seasonalSalesData.$inferSelect;
export type InsertSeasonalSalesData = z.infer<typeof insertSeasonalSalesSchema>;

export type ReturnsInvoice = typeof returnsInvoices.$inferSelect;
export type InsertReturnsInvoice = z.infer<typeof insertReturnsInvoiceSchema>;

export type TokenSale = typeof tokenSalesLog.$inferSelect;
export type TokenReturn = typeof tokenReturnsLog.$inferSelect;

export type HormuzConfig = typeof hormuzConfig.$inferSelect;
export type InsertHormuzConfig = z.infer<typeof insertHormuzConfigSchema>;

// Input features for v8.5 prediction (8 features)
export const predictionInputSchema = z.object({
  currentInventory: z.number().min(0).max(100),
  dayOfWeek: z.number().min(0).max(6),
  expectedSales: z.number().min(0).max(50),
  actualSalesRate: z.number().min(0).max(50),
  monthlyMultiplier: z.number().min(0).max(3),
  isHoliday: z.boolean(),
  pipelineIncoming: z.number().min(0).max(100),
  returnsRate: z.number().min(0).max(100),
});

export type PredictionInput = z.infer<typeof predictionInputSchema>;

// Natural language query schema
export const nlQuerySchema = z.object({
  query: z.string().min(1).max(500),
});

export type NLQuery = z.infer<typeof nlQuerySchema>;
