import { db } from "./db";
import {
  products, trainingData, predictions, orders, trainingRuns, systemLogs,
  type Product, type InsertProduct,
  type TrainingData, type InsertTrainingData,
  type Prediction, type InsertPrediction,
  type Order, type InsertOrder,
  type TrainingRun, type InsertTrainingRun,
  type SystemLog, type InsertSystemLog
} from "@shared/schema";
import { eq, desc, sql, count, avg, and } from "drizzle-orm";

export interface IStorage {
  // Products
  getProducts(filters?: { mlpEnabled?: boolean; isActive?: boolean }): Promise<Product[]>;
  getProductById(productId: string): Promise<Product | undefined>;
  upsertProduct(data: InsertProduct): Promise<Product>;
  updateProduct(productId: string, updates: Partial<InsertProduct>): Promise<Product | undefined>;
  getProductCount(): Promise<number>;
  getMlpEnabledProducts(): Promise<Product[]>;

  // Training Data
  createTrainingData(data: InsertTrainingData): Promise<TrainingData>;
  createManyTrainingData(data: InsertTrainingData[]): Promise<TrainingData[]>;
  getTrainingData(limit?: number): Promise<TrainingData[]>;
  getTrainingDataCount(): Promise<number>;

  // Predictions
  createPrediction(data: InsertPrediction): Promise<Prediction>;
  getPredictions(limit?: number): Promise<Prediction[]>;
  getPredictionCount(): Promise<number>;
  getAverageConfidence(): Promise<number>;

  // Orders
  createOrder(data: InsertOrder): Promise<Order>;
  getOrders(limit?: number): Promise<Order[]>;
  getOrderCount(): Promise<number>;
  updateOrderStatus(id: string, status: string): Promise<Order | undefined>;

  // Training Runs
  createTrainingRun(data: InsertTrainingRun): Promise<TrainingRun>;
  getTrainingRuns(limit?: number): Promise<TrainingRun[]>;
  updateTrainingRun(id: string, updates: Partial<TrainingRun>): Promise<TrainingRun | undefined>;
  getLatestModelVersion(): Promise<string | null>;

  // System Logs
  createLog(data: InsertSystemLog): Promise<SystemLog>;
  getLogs(limit?: number): Promise<SystemLog[]>;
}

export class DatabaseStorage implements IStorage {
  // Products
  async getProducts(filters?: { mlpEnabled?: boolean; isActive?: boolean }): Promise<Product[]> {
    const conditions = [];
    if (filters?.mlpEnabled !== undefined) {
      conditions.push(eq(products.mlpEnabled, filters.mlpEnabled));
    }
    if (filters?.isActive !== undefined) {
      conditions.push(eq(products.isActive, filters.isActive));
    }
    if (conditions.length > 0) {
      return db.select().from(products).where(and(...conditions)).orderBy(products.productName);
    }
    return db.select().from(products).orderBy(products.productName);
  }

  async getProductById(productId: string): Promise<Product | undefined> {
    const [result] = await db.select().from(products).where(eq(products.productId, productId));
    return result;
  }

  async upsertProduct(data: InsertProduct): Promise<Product> {
    const [result] = await db
      .insert(products)
      .values(data)
      .onConflictDoUpdate({
        target: products.productId,
        set: {
          productName: data.productName,
          sku: data.sku,
          category: data.category,
          trayFactor: data.trayFactor,
          shelfLifeDays: data.shelfLifeDays,
          reorderPoint: data.reorderPoint,
          reorderQuantity: data.reorderQuantity,
          deliveryDays: data.deliveryDays,
          leadTimeDays: data.leadTimeDays,
          returnDays: data.returnDays,
          isActive: data.isActive,
          mlpEnabled: data.mlpEnabled,
          updatedAt: new Date(),
        },
      })
      .returning();
    return result;
  }

  async updateProduct(productId: string, updates: Partial<InsertProduct>): Promise<Product | undefined> {
    const [result] = await db
      .update(products)
      .set({ ...updates, updatedAt: new Date() })
      .where(eq(products.productId, productId))
      .returning();
    return result;
  }

  async getProductCount(): Promise<number> {
    const [result] = await db.select({ count: count() }).from(products);
    return result?.count ?? 0;
  }

  async getMlpEnabledProducts(): Promise<Product[]> {
    return db.select().from(products)
      .where(and(eq(products.mlpEnabled, true), eq(products.isActive, true)))
      .orderBy(products.productName);
  }

  // Training Data
  async createTrainingData(data: InsertTrainingData): Promise<TrainingData> {
    const [result] = await db.insert(trainingData).values(data).returning();
    return result;
  }

  async createManyTrainingData(data: InsertTrainingData[]): Promise<TrainingData[]> {
    if (data.length === 0) return [];
    const results = await db.insert(trainingData).values(data).returning();
    return results;
  }

  async getTrainingData(limit = 1000): Promise<TrainingData[]> {
    return db.select().from(trainingData).orderBy(desc(trainingData.createdAt)).limit(limit);
  }

  async getTrainingDataCount(): Promise<number> {
    const [result] = await db.select({ count: count() }).from(trainingData);
    return result?.count ?? 0;
  }

  // Predictions
  async createPrediction(data: InsertPrediction): Promise<Prediction> {
    const [result] = await db.insert(predictions).values(data).returning();
    return result;
  }

  async getPredictions(limit = 20): Promise<Prediction[]> {
    return db.select().from(predictions).orderBy(desc(predictions.createdAt)).limit(limit);
  }

  async getPredictionCount(): Promise<number> {
    const [result] = await db.select({ count: count() }).from(predictions);
    return result?.count ?? 0;
  }

  async getAverageConfidence(): Promise<number> {
    const [result] = await db.select({ avg: avg(predictions.confidence) }).from(predictions);
    return parseFloat(result?.avg ?? "0");
  }

  // Orders
  async createOrder(data: InsertOrder): Promise<Order> {
    const [result] = await db.insert(orders).values(data).returning();
    return result;
  }

  async getOrders(limit = 20): Promise<Order[]> {
    return db.select().from(orders).orderBy(desc(orders.createdAt)).limit(limit);
  }

  async getOrderCount(): Promise<number> {
    const [result] = await db.select({ count: count() }).from(orders);
    return result?.count ?? 0;
  }

  async updateOrderStatus(id: string, status: string): Promise<Order | undefined> {
    const [result] = await db
      .update(orders)
      .set({ status, updatedAt: new Date() })
      .where(eq(orders.id, id))
      .returning();
    return result;
  }

  // Training Runs
  async createTrainingRun(data: InsertTrainingRun): Promise<TrainingRun> {
    const [result] = await db.insert(trainingRuns).values(data).returning();
    return result;
  }

  async getTrainingRuns(limit = 10): Promise<TrainingRun[]> {
    return db.select().from(trainingRuns).orderBy(desc(trainingRuns.startedAt)).limit(limit);
  }

  async updateTrainingRun(id: string, updates: Partial<TrainingRun>): Promise<TrainingRun | undefined> {
    const [result] = await db
      .update(trainingRuns)
      .set(updates)
      .where(eq(trainingRuns.id, id))
      .returning();
    return result;
  }

  async getLatestModelVersion(): Promise<string | null> {
    const [result] = await db
      .select({ modelVersion: trainingRuns.modelVersion })
      .from(trainingRuns)
      .where(eq(trainingRuns.status, "completed"))
      .orderBy(desc(trainingRuns.completedAt))
      .limit(1);
    return result?.modelVersion ?? null;
  }

  // System Logs
  async createLog(data: InsertSystemLog): Promise<SystemLog> {
    const [result] = await db.insert(systemLogs).values(data).returning();
    return result;
  }

  async getLogs(limit = 50): Promise<SystemLog[]> {
    return db.select().from(systemLogs).orderBy(desc(systemLogs.createdAt)).limit(limit);
  }
}

export const storage = new DatabaseStorage();
