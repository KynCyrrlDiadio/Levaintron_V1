import type { Express } from "express";
import { createServer, type Server } from "http";
import { storage } from "./storage";
import { predictionInputSchema, nlQuerySchema, hormuzConfig } from "@shared/schema";
import { mlpPredict, generateTrainingData, parseNLQuery, simulateTraining } from "./mlp-engine";
import { pipelineManager, getSystemHealth } from "./pipeline-manager";
import { z } from "zod";
import { eq, sql } from "drizzle-orm";
import multer from "multer";
import { execFile } from "child_process";
import path from "path";
import fs from "fs";
import { db } from "./db";

/** Get current date string in MST (America/Edmonton) as YYYY-MM-DD */
function getMSTDate(date?: Date): string {
  const d = date || new Date();
  return d.toLocaleDateString('en-CA', { timeZone: 'America/Edmonton' });
}

/** Get current day of week in MST (0=Sun, 6=Sat) */
function getMSTDayOfWeek(date?: Date): number {
  const d = date || new Date();
  const mstDateStr = d.toLocaleDateString('en-US', { timeZone: 'America/Edmonton', weekday: 'short' });
  const dayMap: Record<string, number> = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };
  return dayMap[mstDateStr] ?? d.getDay();
}

export async function registerRoutes(
  httpServer: Server,
  app: Express
): Promise<Server> {
  
  // ============================================================
  // PRODUCT CATALOG ENDPOINTS
  // ============================================================

  app.get("/api/products", async (req, res) => {
    try {
      const mlpEnabled = req.query.mlp_enabled === "true" ? true : req.query.mlp_enabled === "false" ? false : undefined;
      const isActive = req.query.is_active === "true" ? true : req.query.is_active === "false" ? false : undefined;
      const products = await storage.getProducts({ mlpEnabled, isActive });
      res.json(products);
    } catch (error) {
      console.error("Error fetching products:", error);
      res.status(500).json({ error: "Failed to fetch products" });
    }
  });

  app.get("/api/products/mlp/enabled", async (req, res) => {
    try {
      const products = await storage.getMlpEnabledProducts();
      res.json(products);
    } catch (error) {
      console.error("Error fetching MLP-enabled products:", error);
      res.status(500).json({ error: "Failed to fetch MLP-enabled products" });
    }
  });

  app.get("/api/products/:productId", async (req, res) => {
    try {
      const product = await storage.getProductById(req.params.productId);
      if (!product) {
        return res.status(404).json({ error: "Product not found" });
      }
      res.json(product);
    } catch (error) {
      console.error("Error fetching product:", error);
      res.status(500).json({ error: "Failed to fetch product" });
    }
  });

  app.patch("/api/products/:productId", async (req, res) => {
    try {
      const updateSchema = z.object({
        productName: z.string().optional(),
        category: z.string().optional(),
        trayFactor: z.number().int().min(1).optional(),
        shelfLifeDays: z.number().int().min(1).optional(),
        reorderPoint: z.number().int().min(0).optional(),
        reorderQuantity: z.number().int().min(0).optional(),
        deliveryDays: z.string().optional(),
        leadTimeDays: z.number().int().min(0).optional(),
        returnDays: z.string().optional(),
        isActive: z.boolean().optional(),
        mlpEnabled: z.boolean().optional(),
      });
      const updates = updateSchema.parse(req.body);
      const product = await storage.updateProduct(req.params.productId, updates);
      if (!product) {
        return res.status(404).json({ error: "Product not found" });
      }
      res.json(product);
    } catch (error: any) {
      console.error("Error updating product:", error);
      if (error instanceof z.ZodError) {
        res.status(400).json({ error: "Invalid update data", details: error.errors });
      } else {
        res.status(500).json({ error: "Failed to update product" });
      }
    }
  });

  // Get system stats
  app.get("/api/stats", async (req, res) => {
    try {
      const [totalPredictions, totalOrders, trainingDataCount, latestModelVersion, avgConfidence] = await Promise.all([
        storage.getPredictionCount(),
        storage.getOrderCount(),
        storage.getTrainingDataCount(),
        storage.getLatestModelVersion(),
        storage.getAverageConfidence(),
      ]);
      
      res.json({
        totalPredictions,
        totalOrders,
        trainingDataCount,
        latestModelVersion: latestModelVersion ?? "1.0.0",
        avgConfidence: avgConfidence || 0,
      });
    } catch (error) {
      console.error("Error fetching stats:", error);
      res.status(500).json({ error: "Failed to fetch stats" });
    }
  });

  // Get predictions
  app.get("/api/predictions", async (req, res) => {
    try {
      const predictions = await storage.getPredictions(20);
      res.json(predictions);
    } catch (error) {
      console.error("Error fetching predictions:", error);
      res.status(500).json({ error: "Failed to fetch predictions" });
    }
  });

  // Make a prediction
  app.post("/api/predict", async (req, res) => {
    try {
      const input = predictionInputSchema.parse(req.body);
      
      // Run MLP prediction
      const { decision, confidence } = mlpPredict(input);
      
      // Get latest model version
      const modelVersion = await storage.getLatestModelVersion() ?? "1.0.0";
      
      // Store prediction
      const prediction = await storage.createPrediction({
        inputFeatures: input,
        predictedDecision: decision,
        confidence,
        modelVersion,
      });
      
      // Log the prediction
      await storage.createLog({
        level: "info",
        message: `MLP predicted ${decision} loaves with ${(confidence * 100).toFixed(1)}% confidence`,
        metadata: { predictionId: prediction.id, input },
      });
      
      res.json(prediction);
    } catch (error) {
      console.error("Error making prediction:", error);
      if (error instanceof z.ZodError) {
        res.status(400).json({ error: "Invalid input", details: error.errors });
      } else {
        res.status(500).json({ error: "Failed to make prediction" });
      }
    }
  });

  // Natural language query
  app.post("/api/nl-query", async (req, res) => {
    try {
      const { query } = nlQuerySchema.parse(req.body);
      
      // Parse the natural language query
      const parsed = parseNLQuery(query);
      
      await storage.createLog({
        level: "info",
        message: `NL Query: "${query}" -> Intent: ${parsed.intent}`,
        metadata: { parsed },
      });
      
      switch (parsed.intent) {
        case "predict": {
          const input = {
            currentInventory: parsed.params.currentInventory ?? 15,
            dayOfWeek: parsed.params.dayOfWeek ?? getMSTDayOfWeek(),
            expectedSales: parsed.params.expectedSales ?? 4.0,
            actualSalesRate: parsed.params.actualSalesRate ?? 3.0,
            monthlyMultiplier: parsed.params.monthlyMultiplier ?? 1.0,
            isHoliday: parsed.params.isHoliday ?? false,
            pipelineIncoming: parsed.params.pipelineIncoming ?? 0,
            returnsRate: parsed.params.returnsRate ?? 1.0,
          };
          
          const { decision, confidence } = mlpPredict(input);
          const modelVersion = await storage.getLatestModelVersion() ?? "1.0.0";
          
          const prediction = await storage.createPrediction({
            inputFeatures: input,
            predictedDecision: decision,
            confidence,
            modelVersion,
          });
          
          res.json({
            type: "prediction",
            message: `Based on your query, I recommend ordering ${decision} loaves (${(confidence * 100).toFixed(0)}% confidence)`,
            prediction,
          });
          break;
        }
        
        case "order": {
          if (parsed.orderQuantity !== undefined) {
            // Create an order directly
            const order = await storage.createOrder({
              quantity: parsed.orderQuantity,
              status: "pending",
              notes: `Created via NL query: "${query}"`,
            });
            
            res.json({
              type: "order",
              message: `Order placed for ${parsed.orderQuantity} loaves`,
              order,
            });
          } else {
            res.json({
              type: "clarification",
              message: "How many loaves would you like to order? (0, 5, or 10)",
            });
          }
          break;
        }
        
        case "status": {
          const [predictions, orders, stats] = await Promise.all([
            storage.getPredictions(5),
            storage.getOrders(5),
            Promise.all([
              storage.getPredictionCount(),
              storage.getOrderCount(),
              storage.getTrainingDataCount(),
            ]),
          ]);
          
          res.json({
            type: "status",
            message: `System has made ${stats[0]} predictions and ${stats[1]} orders. Training data: ${stats[2]} samples.`,
            recentPredictions: predictions.length,
            recentOrders: orders.length,
          });
          break;
        }
        
        case "help": {
          res.json({
            type: "help",
            message: "You can ask things like: 'What should I order today?', 'Order 10 loaves for Tuesday', 'How's the system status?'",
            examples: [
              "What should I order for Monday morning?",
              "Order 5 loaves",
              "Recommend bread order for rainy day",
              "What's the current status?",
            ],
          });
          break;
        }
        
        default: {
          const input = {
            currentInventory: 15,
            dayOfWeek: getMSTDayOfWeek(),
            expectedSales: 4.0,
            actualSalesRate: 3.0,
            monthlyMultiplier: 1.0,
            isHoliday: false,
            pipelineIncoming: 0,
            returnsRate: 1.0,
          };
          
          const { decision, confidence } = mlpPredict(input);
          const modelVersion = await storage.getLatestModelVersion() ?? "1.0.0";
          
          const prediction = await storage.createPrediction({
            inputFeatures: input,
            predictedDecision: decision,
            confidence,
            modelVersion,
          });
          
          res.json({
            type: "prediction",
            message: `I recommend ordering ${decision} loaves based on current conditions (${(confidence * 100).toFixed(0)}% confidence)`,
            prediction,
          });
        }
      }
    } catch (error) {
      console.error("Error processing NL query:", error);
      if (error instanceof z.ZodError) {
        res.status(400).json({ error: "Invalid query", details: error.errors });
      } else {
        res.status(500).json({ error: "Failed to process query" });
      }
    }
  });

  // Get orders
  app.get("/api/orders", async (req, res) => {
    try {
      const orders = await storage.getOrders(20);
      res.json(orders);
    } catch (error) {
      console.error("Error fetching orders:", error);
      res.status(500).json({ error: "Failed to fetch orders" });
    }
  });

  // Create order
  app.post("/api/orders", async (req, res) => {
    try {
      const schema = z.object({
        quantity: z.number().refine(q => [0, 5, 10].includes(q), "Quantity must be 0, 5, or 10"),
        predictionId: z.string().optional(),
        notes: z.string().optional(),
      });
      
      const data = schema.parse(req.body);
      const order = await storage.createOrder({
        quantity: data.quantity,
        predictionId: data.predictionId,
        notes: data.notes,
        status: "pending",
      });
      
      await storage.createLog({
        level: "info",
        message: `Order created for ${data.quantity} loaves`,
        metadata: { orderId: order.id },
      });
      
      res.json(order);
    } catch (error) {
      console.error("Error creating order:", error);
      if (error instanceof z.ZodError) {
        res.status(400).json({ error: "Invalid order data", details: error.errors });
      } else {
        res.status(500).json({ error: "Failed to create order" });
      }
    }
  });

  // Get training runs
  app.get("/api/training-runs", async (req, res) => {
    try {
      const runs = await storage.getTrainingRuns(10);
      res.json(runs);
    } catch (error) {
      console.error("Error fetching training runs:", error);
      res.status(500).json({ error: "Failed to fetch training runs" });
    }
  });

  // Generate training data
  app.post("/api/training-data/generate", async (req, res) => {
    try {
      const schema = z.object({
        count: z.number().min(1).max(1000).default(100),
      });
      
      const { count } = schema.parse(req.body);
      const data = generateTrainingData(count);
      const created = await storage.createManyTrainingData(data);
      
      await storage.createLog({
        level: "info",
        message: `Generated ${created.length} training samples`,
        metadata: { count: created.length },
      });
      
      res.json({ 
        message: `Generated ${created.length} training samples`,
        count: created.length,
      });
    } catch (error) {
      console.error("Error generating training data:", error);
      res.status(500).json({ error: "Failed to generate training data" });
    }
  });

  // Train model
  app.post("/api/train", async (req, res) => {
    try {
      const samplesCount = await storage.getTrainingDataCount();
      
      if (samplesCount < 50) {
        return res.status(400).json({ 
          error: "Not enough training data",
          message: `Need at least 50 samples, currently have ${samplesCount}`,
        });
      }
      
      // Generate new model version
      const existingVersion = await storage.getLatestModelVersion();
      const versionParts = (existingVersion ?? "1.0.0").split(".");
      const newVersion = `${versionParts[0]}.${parseInt(versionParts[1]) + 1}.0`;
      
      // Create training run
      const epochs = 50;
      const batchSize = 32;
      const learningRate = 0.001;
      
      const run = await storage.createTrainingRun({
        modelVersion: newVersion,
        epochs,
        batchSize,
        learningRate,
        samplesUsed: samplesCount,
        status: "running",
      });
      
      await storage.createLog({
        level: "info",
        message: `Training started for model v${newVersion} with ${samplesCount} samples`,
        metadata: { runId: run.id },
      });
      
      // Simulate training (in production, this would spawn a Python process)
      const results = simulateTraining(samplesCount, epochs, batchSize, learningRate);
      
      // Update training run with results
      const completedRun = await storage.updateTrainingRun(run.id, {
        status: "completed",
        trainLoss: results.trainLoss,
        valLoss: results.valLoss,
        accuracy: results.accuracy,
        completedAt: sql`now()`,
      });
      
      await storage.createLog({
        level: "info",
        message: `Training completed for v${newVersion}: accuracy ${(results.accuracy * 100).toFixed(1)}%`,
        metadata: { runId: run.id, results },
      });
      
      res.json(completedRun);
    } catch (error) {
      console.error("Error training model:", error);
      res.status(500).json({ error: "Failed to train model" });
    }
  });

  app.get("/api/seasonal-trend", async (req, res) => {
    try {
      const { pool } = await import("./db");
      const sku = (req.query.sku as string) || "500107";
      const result = await pool.query(`
        SELECT 
          month,
          day_of_week,
          expected_daily,
          monthly_multiplier,
          confidence
        FROM seasonal_pattern
        WHERE sku = $1 AND store_id = '70012004'
        ORDER BY month, 
          CASE day_of_week 
            WHEN 'Mon' THEN 1 WHEN 'Tue' THEN 2 WHEN 'Wed' THEN 3 
            WHEN 'Thu' THEN 4 WHEN 'Fri' THEN 5 WHEN 'Sat' THEN 6 WHEN 'Sun' THEN 7 
          END
      `, [sku]);

      const monthlyAvg = await pool.query(`
        SELECT 
          month,
          ROUND(AVG(expected_daily)::numeric, 2) as avg_daily,
          monthly_multiplier as multiplier,
          confidence
        FROM seasonal_pattern
        WHERE sku = $1 AND store_id = '70012004'
        GROUP BY month, monthly_multiplier, confidence
        ORDER BY month
      `, [sku]);

      const dailyForecast = await pool.query(`
        SELECT 
          forecast_date,
          expected_sales,
          monthly_multiplier,
          day_of_week,
          confidence
        FROM daily_forecast
        WHERE sku = $1 AND store_id = '70012004'
          AND EXTRACT(YEAR FROM forecast_date) = 2025
        ORDER BY forecast_date
      `, [sku]);

      res.json({
        pattern: result.rows,
        monthlyAvg: monthlyAvg.rows,
        dailyForecast: dailyForecast.rows,
      });
    } catch (error) {
      console.error("Error fetching seasonal trend:", error);
      res.status(500).json({ error: "Failed to fetch seasonal trend data" });
    }
  });

  // ============================================================
  // PIPELINE CONTROL ENDPOINTS
  // ============================================================

  const requirePipelineAuth = (req: any, res: any, next: any) => {
    const token = process.env.PIPELINE_API_TOKEN;
    if (!token) {
      return next();
    }
    const authHeader = req.headers.authorization;
    const queryToken = req.query.token;
    if (authHeader === `Bearer ${token}` || queryToken === token) {
      return next();
    }
    return res.status(401).json({ error: "Unauthorized — invalid or missing API token" });
  };

  app.post("/api/pipeline/trigger", requirePipelineAuth, async (req: any, res: any) => {
    try {
      const schema = z.object({
        mode: z.enum(["dry_run", "live"]).default("dry_run"),
        productId: z.string().default("500107"),
      });

      const { mode, productId } = schema.parse(req.body);

      if (pipelineManager.isRunning()) {
        return res.status(409).json({ error: "Pipeline is already running" });
      }

      const run = pipelineManager.trigger({ mode, productId });

      await storage.createLog({
        level: "info",
        message: `Pipeline triggered: mode=${mode}, product=${productId}`,
        metadata: { runId: run.id },
      });

      res.json(run);
    } catch (error: any) {
      console.error("Error triggering pipeline:", error);
      res.status(500).json({ error: error.message || "Failed to trigger pipeline" });
    }
  });

  app.get("/api/pipeline/status", async (req, res) => {
    try {
      const status = pipelineManager.getStatus();
      res.json(status);
    } catch (error) {
      res.status(500).json({ error: "Failed to get pipeline status" });
    }
  });

  app.post("/api/pipeline/abort", requirePipelineAuth, async (req: any, res: any) => {
    try {
      const aborted = pipelineManager.abort();
      if (aborted) {
        await storage.createLog({
          level: "warn",
          message: "Pipeline run aborted by user",
        });
        res.json({ success: true, message: "Pipeline aborted" });
      } else {
        res.status(400).json({ error: "No running pipeline to abort" });
      }
    } catch (error) {
      res.status(500).json({ error: "Failed to abort pipeline" });
    }
  });

  app.get("/api/pipeline/history", async (req, res) => {
    try {
      const limit = parseInt(req.query.limit as string) || 20;
      const history = pipelineManager.getHistory(limit);
      res.json(history);
    } catch (error) {
      res.status(500).json({ error: "Failed to get pipeline history" });
    }
  });

  app.get("/api/pipeline/output", async (req, res) => {
    try {
      const runId = req.query.runId as string | undefined;
      const tail = parseInt(req.query.tail as string) || 100;
      const output = pipelineManager.getOutput(runId, tail);
      res.json({ lines: output });
    } catch (error) {
      res.status(500).json({ error: "Failed to get pipeline output" });
    }
  });

  app.get("/api/pipeline/orders", async (req, res) => {
    try {
      const { pool } = await import("./db");
      const limit = parseInt(req.query.limit as string) || 30;
      const result = await pool.query(`
        SELECT 
          id, delivery_date, product_id, store_id,
          current_stock, projected_stock, mlp_decision,
          mlp_confidence, mlp_method,
          created_at as decision_time,
          pipeline_incoming, returns_rate,
          adj_value, total_units, tray_factor, trays_needed,
          otto_write_success, otto_action,
          was_overridden, override_reason,
          expected_sales, actual_sales_rate, monthly_multiplier,
          reasoning, submitted, verified
        FROM mlp_order_log
        ORDER BY created_at DESC
        LIMIT $1
      `, [limit]);
      res.json(result.rows);
    } catch (error) {
      console.error("Error fetching pipeline orders:", error);
      res.status(500).json({ error: "Failed to fetch pipeline orders" });
    }
  });

  app.get("/api/system/health", async (req, res) => {
    try {
      const health = getSystemHealth();

      let gpuInfo = null;
      try {
        const { execSync } = await import("child_process");
        const gpuOutput = execSync(
          "nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits",
          { timeout: 5000 }
        ).toString().trim();

        if (gpuOutput) {
          gpuInfo = gpuOutput.split("\n").map((line: string) => {
            const [name, temp, util, memUsed, memTotal] = line.split(", ");
            return {
              name: name?.trim(),
              temperature_c: parseInt(temp),
              utilization_percent: parseInt(util),
              memory_used_mb: parseInt(memUsed),
              memory_total_mb: parseInt(memTotal),
            };
          });
        }
      } catch {
        gpuInfo = null;
      }

      let diskInfo = null;
      try {
        const { execSync } = await import("child_process");
        const dfOutput = execSync("df -h / --output=size,used,avail,pcent | tail -1", { timeout: 3000 })
          .toString().trim();
        const parts = dfOutput.split(/\s+/);
        diskInfo = {
          total: parts[0],
          used: parts[1],
          available: parts[2],
          used_percent: parts[3],
        };
      } catch {
        diskInfo = null;
      }

      res.json({
        ...health,
        gpu: gpuInfo,
        disk: diskInfo,
        pipeline: pipelineManager.getStatus(),
      });
    } catch (error) {
      res.status(500).json({ error: "Failed to get system health" });
    }
  });

  app.post("/api/returns/process", requirePipelineAuth, async (req: any, res: any) => {
    try {
      const schema = z.object({
        productId: z.string().default("500107"),
        unitsReturned: z.number().int().min(1),
        invoiceId: z.string().min(1),
        reason: z.string().optional(),
        forceDay: z.boolean().optional().default(false),
      });

      const { productId, unitsReturned, invoiceId, reason, forceDay } = schema.parse(req.body);

      const { pool } = await import("./db");

      const dayOfWeek = getMSTDayOfWeek();
      const dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
      if (!forceDay && dayOfWeek !== 2 && dayOfWeek !== 5) {
        return res.status(400).json({
          error: `Returns only processed on Tuesday and Friday. Today is ${dayNames[dayOfWeek]}.`,
          nextReturnDay: dayOfWeek < 2 ? "Tuesday" : dayOfWeek < 5 ? "Friday" : "Tuesday",
        });
      }

      const dupeCheck = await pool.query(
        "SELECT id FROM returns_invoices WHERE invoice_id = $1",
        [invoiceId]
      );
      if (dupeCheck.rows.length > 0) {
        return res.status(409).json({ error: `Invoice ${invoiceId} already processed` });
      }

      const storeId = "70012004";
      const invoiceDate = getMSTDate();

      const tokensResult = await pool.query(
        `SELECT token_id, batch_id, arrival_date, expiration_date
         FROM product_tokens
         WHERE product_id = $1 AND store_id = $2 AND status = 'in_stock'
         ORDER BY arrival_date ASC
         LIMIT $3`,
        [productId, storeId, unitsReturned]
      );

      const tokens = tokensResult.rows;
      if (tokens.length === 0) {
        return res.status(400).json({
          error: `No in_stock tokens found for product ${productId}`,
          unitsRequested: unitsReturned,
        });
      }

      let tokensUpdated = 0;
      for (const token of tokens) {
        const updateResult = await pool.query(
          `UPDATE product_tokens
           SET status = 'returned',
               consumed_date = $1,
               status_date = $1,
               updated_at = NOW(),
               notes = $2
           WHERE token_id = $3 AND status = 'in_stock'`,
          [invoiceDate, `Return invoice: ${invoiceId}`, token.token_id]
        );
        tokensUpdated += updateResult.rowCount || 0;
      }

      const returnBatches: Record<string, { batch_id: string; arrival_date: string; expiration_date: string; count: number }> = {};
      for (const token of tokens) {
        const key = `${token.batch_id}-${token.arrival_date}-${token.expiration_date}`;
        if (!returnBatches[key]) {
          returnBatches[key] = {
            batch_id: token.batch_id,
            arrival_date: token.arrival_date,
            expiration_date: token.expiration_date,
            count: 0,
          };
        }
        returnBatches[key].count += 1;
      }

      for (const batch of Object.values(returnBatches)) {
        const daysOnShelf = batch.arrival_date
          ? Math.floor((new Date(invoiceDate).getTime() - new Date(batch.arrival_date).getTime()) / 86400000)
          : null;
        await pool.query(
          `INSERT INTO token_returns_log
           (product_id, store_id, return_date, units_returned, invoice_id,
            batch_id, arrival_date, expiration_date, days_on_shelf, reason)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
          [productId, storeId, invoiceDate, batch.count, invoiceId,
           batch.batch_id, batch.arrival_date, batch.expiration_date,
           daysOnShelf, reason || null]
        );
      }

      await pool.query(
        `INSERT INTO returns_invoices
         (invoice_id, store_id, invoice_date, product_id, units_returned, reason, tokens_updated)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [invoiceId, storeId, invoiceDate, productId, unitsReturned, reason || null, tokensUpdated]
      );

      const thirtyDaysAgo = getMSTDate(new Date(Date.now() - 30 * 86400000));
      const returnedResult = await pool.query(
        `SELECT COALESCE(SUM(units_returned), 0) as total_returned
         FROM returns_invoices
         WHERE product_id = $1 AND store_id = $2 AND invoice_date >= $3`,
        [productId, storeId, thirtyDaysAgo]
      );
      // cancelled = delivery never landed; must not inflate the denominator
      const deliveredResult = await pool.query(
        `SELECT COUNT(*) as total_delivered
         FROM product_tokens
         WHERE product_id = $1 AND store_id = $2 AND arrival_date >= $3
           AND status <> 'cancelled'`,
        [productId, storeId, thirtyDaysAgo]
      );
      const totalReturned = parseInt(returnedResult.rows[0]?.total_returned) || 0;
      const totalDelivered = parseInt(deliveredResult.rows[0]?.total_delivered) || 0;
      const returnRate30d = totalDelivered > 0 ? (totalReturned / totalDelivered) * 100 : 0;

      const stockResult = await pool.query(
        `SELECT COUNT(*) as count FROM product_tokens
         WHERE product_id = $1 AND store_id = $2 AND status = 'in_stock'`,
        [productId, storeId]
      );
      const remainingStock = parseInt(stockResult.rows[0]?.count) || 0;

      await storage.createLog({
        level: "info",
        message: `Returns processed: ${tokensUpdated} units of ${productId} via invoice ${invoiceId}. Return rate: ${returnRate30d.toFixed(1)}%`,
        metadata: { invoiceId, productId, unitsReturned, tokensUpdated, returnRate30d },
      });

      res.json({
        success: true,
        productId,
        invoiceId,
        unitsRequested: unitsReturned,
        tokensUpdated,
        tokensAvailable: tokens.length,
        shortfall: Math.max(0, unitsReturned - tokens.length),
        returnRate30d: Math.round(returnRate30d * 100) / 100,
        remainingStock,
        message: `Processed ${tokensUpdated} returns for product ${productId} (FIFO oldest-first)`,
      });
    } catch (error: any) {
      console.error("Error processing returns:", error);
      if (error instanceof z.ZodError) {
        res.status(400).json({ error: "Invalid input", details: error.errors });
      } else {
        res.status(500).json({ error: error.message || "Failed to process returns" });
      }
    }
  });

  app.get("/api/returns/summary", async (req, res) => {
    try {
      const { pool } = await import("./db");
      const productId = (req.query.product_id as string) || "500107";
      const storeId = "70012004";

      const thirtyDaysAgo = getMSTDate(new Date(Date.now() - 30 * 86400000));

      const recentResult = await pool.query(
        `SELECT invoice_id, invoice_date, units_returned, reason, processed_at, tokens_updated
         FROM returns_invoices
         WHERE product_id = $1 AND store_id = $2
         ORDER BY invoice_date DESC
         LIMIT 10`,
        [productId, storeId]
      );

      const returnedResult = await pool.query(
        `SELECT COALESCE(SUM(units_returned), 0) as total_returned
         FROM returns_invoices
         WHERE product_id = $1 AND store_id = $2 AND invoice_date >= $3`,
        [productId, storeId, thirtyDaysAgo]
      );
      // cancelled = delivery never landed; must not inflate the denominator
      const deliveredResult = await pool.query(
        `SELECT COUNT(*) as total_delivered
         FROM product_tokens
         WHERE product_id = $1 AND store_id = $2 AND arrival_date >= $3
           AND status <> 'cancelled'`,
        [productId, storeId, thirtyDaysAgo]
      );
      const totalReturned = parseInt(returnedResult.rows[0]?.total_returned) || 0;
      const totalDelivered = parseInt(deliveredResult.rows[0]?.total_delivered) || 0;
      const returnRate30d = totalDelivered > 0 ? (totalReturned / totalDelivered) * 100 : 0;

      const mstDayOfWeek = getMSTDayOfWeek();
      const isReturnDay = mstDayOfWeek === 2 || mstDayOfWeek === 5;

      res.json({
        productId,
        returnRate30d: Math.round(returnRate30d * 100) / 100,
        totalReturned30d: totalReturned,
        totalDelivered30d: totalDelivered,
        isReturnDay,
        recentInvoices: recentResult.rows,
      });
    } catch (error) {
      console.error("Error fetching returns summary:", error);
      res.status(500).json({ error: "Failed to fetch returns summary" });
    }
  });

  // ============================================================
  // PDF INVOICE UPLOAD
  // ============================================================

  const upload = multer({
    dest: path.join(process.cwd(), "uploads"),
    limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
    fileFilter: (_req, file, cb) => {
      if (file.mimetype === "application/pdf") {
        cb(null, true);
      } else {
        cb(new Error("Only PDF files are accepted"));
      }
    },
  });

  // Step 1: Parse PDF — returns extracted invoice data for user review
  app.post("/api/returns/parse-pdf", requirePipelineAuth, upload.single("invoice"), async (req: any, res: any) => {
    if (!req.file) {
      return res.status(400).json({ error: "No PDF file uploaded" });
    }

    const pdfPath = req.file.path;

    // Find the Python parser script relative to project root
    const parserScript = path.resolve(process.cwd(), "..", "Application_env", "ai_orchestrator", "parse_invoice_pdf.py");

    // Try venv python first, fall back to system python3
    const pythonPaths = [
      path.resolve(process.cwd(), "..", "levaintron", "bin", "python"),
      "python3",
      "python",
    ];

    let pythonBin = "python3";
    for (const p of pythonPaths) {
      try {
        if (p.startsWith("/") && fs.existsSync(p)) {
          pythonBin = p;
          break;
        }
      } catch { /* skip */ }
    }

    execFile(pythonBin, [parserScript, pdfPath], { timeout: 30000 }, (error, stdout, stderr) => {
      if (error) {
        fs.unlink(pdfPath, () => {});
        console.error("PDF parse error:", stderr || error.message);
        return res.status(500).json({ error: `PDF parsing failed: ${stderr || error.message}` });
      }

      try {
        const result = JSON.parse(stdout);
        if (!result.success) {
          fs.unlink(pdfPath, () => {});
          return res.status(400).json({ error: result.error || "Failed to parse invoice" });
        }

        // Archive the PDF: invoices/<YYYY-MM>/<type>_<invoiceNumber>_<date>_<HHmm>.pdf
        const invoiceDate = result.date || getMSTDate();
        const yearMonth = invoiceDate.substring(0, 7);
        const archiveDir = path.resolve(process.cwd(), "..", "invoices", yearMonth);
        const now = new Date();
        const uploadTimestamp = now.toLocaleString('en-CA', { timeZone: 'America/Edmonton', hour12: false }).replace(/[^0-9]/g, '');
        const timeOnly = now.toLocaleTimeString('en-CA', { timeZone: 'America/Edmonton', hour12: false, hour: '2-digit', minute: '2-digit' }).replace(':', '');
        const sanitizedInvoice = (result.invoice_number || "unknown").replace(/[^a-zA-Z0-9_-]/g, "_");
        const archiveName = `${result.type}_${sanitizedInvoice}_${invoiceDate}_${timeOnly}.pdf`;
        const archivePath = path.join(archiveDir, archiveName);
        const logPath = path.resolve(process.cwd(), "..", "invoices", "upload_log.json");

        fs.mkdir(archiveDir, { recursive: true }, (mkdirErr) => {
          if (mkdirErr) {
            console.error("Failed to create invoice archive dir:", mkdirErr);
            fs.unlink(pdfPath, () => {});
          } else {
            fs.copyFile(pdfPath, archivePath, (copyErr) => {
              if (copyErr) {
                console.error("Failed to archive invoice PDF:", copyErr);
              } else {
                console.log(`Invoice PDF archived: ${archivePath}`);
                result.archived_path = archivePath;

                const logEntry = {
                  uploaded_at: now.toLocaleString('en-CA', { timeZone: 'America/Edmonton', hour12: false }),
                  invoice_number: result.invoice_number,
                  invoice_date: invoiceDate,
                  type: result.type,
                  total_units: result.total_units,
                  mlp_products_found: result.mlp_products_found || [],
                  non_mlp_products: result.non_mlp_products || [],
                  archived_file: archiveName,
                };
                fs.readFile(logPath, "utf-8", (_readErr, data) => {
                  const log: any[] = data ? (() => { try { return JSON.parse(data); } catch { return []; } })() : [];
                  log.push(logEntry);
                  fs.writeFile(logPath, JSON.stringify(log, null, 2), () => {});
                });
              }
              fs.unlink(pdfPath, () => {});
            });
          }
        });

        res.json(result);
      } catch (parseErr) {
        fs.unlink(pdfPath, () => {});
        console.error("JSON parse error from Python:", stdout);
        return res.status(500).json({ error: "Invalid response from PDF parser" });
      }
    });
  });

  // Step 2: Confirm & process parsed invoice products as returns
  app.post("/api/returns/process-invoice", requirePipelineAuth, async (req: any, res: any) => {
    try {
      const schema = z.object({
        invoiceNumber: z.string().min(1),
        invoiceDate: z.string().min(1),
        invoiceType: z.enum(["sales", "returns"]),
        products: z.array(z.object({
          product_id: z.string(),
          quantity: z.number().int().min(1),
          description: z.string().optional(),
        })),
        forceDay: z.boolean().optional().default(false),
      });

      const { invoiceNumber, invoiceDate, invoiceType, products, forceDay } = schema.parse(req.body);

      if (invoiceType !== "returns") {
        return res.status(400).json({ error: "Only returns/stale invoices are supported for processing. Sales invoices use the delivery token system." });
      }

      const { pool } = await import("./db");
      const storeId = "70012004";

      const dayOfWeek = getMSTDayOfWeek();
      const dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
      if (!forceDay && dayOfWeek !== 2 && dayOfWeek !== 5) {
        return res.status(400).json({
          error: `Returns only processed on Tuesday and Friday. Today is ${dayNames[dayOfWeek]}.`,
        });
      }

      const results: any[] = [];

      for (const prod of products) {
        const invoiceId = `PDF-${invoiceNumber}-${prod.product_id}`;

        // Check duplicate
        const dupeCheck = await pool.query(
          "SELECT id FROM returns_invoices WHERE invoice_id = $1",
          [invoiceId]
        );
        if (dupeCheck.rows.length > 0) {
          results.push({ product_id: prod.product_id, skipped: true, reason: `Invoice ${invoiceId} already processed` });
          continue;
        }

        // Find oldest FIFO tokens
        const tokensResult = await pool.query(
          `SELECT token_id, batch_id, arrival_date, expiration_date
           FROM product_tokens
           WHERE product_id = $1 AND store_id = $2 AND status = 'in_stock'
           ORDER BY arrival_date ASC
           LIMIT $3`,
          [prod.product_id, storeId, prod.quantity]
        );

        const tokens = tokensResult.rows;
        if (tokens.length === 0) {
          results.push({ product_id: prod.product_id, skipped: true, reason: "No in_stock tokens" });
          continue;
        }

        let tokensUpdated = 0;
        for (const token of tokens) {
          const updateResult = await pool.query(
            `UPDATE product_tokens
             SET status = 'returned',
                 consumed_date = $1,
                 status_date = $1,
                 updated_at = NOW(),
                 notes = $2
             WHERE token_id = $3 AND status = 'in_stock'`,
            [invoiceDate, `PDF Return invoice: ${invoiceId}`, token.token_id]
          );
          tokensUpdated += updateResult.rowCount ?? 0;
        }

        // Log to returns_invoices
        await pool.query(
          `INSERT INTO returns_invoices (invoice_id, store_id, invoice_date, product_id, units_returned, reason, tokens_updated)
           VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [invoiceId, storeId, invoiceDate, prod.product_id, prod.quantity, `PDF invoice ${invoiceNumber}`, tokensUpdated]
        );

        // Log to token_returns_log
        for (const token of tokens) {
          const daysOnShelf = token.arrival_date
            ? Math.floor((new Date(invoiceDate).getTime() - new Date(token.arrival_date).getTime()) / 86400000)
            : null;
          await pool.query(
            `INSERT INTO token_returns_log
             (product_id, store_id, return_date, units_returned, invoice_id, batch_id, arrival_date, expiration_date, days_on_shelf, reason)
             VALUES ($1, $2, $3, 1, $4, $5, $6, $7, $8, $9)`,
            [prod.product_id, storeId, invoiceDate, invoiceId, token.batch_id, token.arrival_date, token.expiration_date, daysOnShelf, `PDF invoice ${invoiceNumber}`]
          );
        }

        results.push({
          product_id: prod.product_id,
          description: prod.description,
          units_requested: prod.quantity,
          tokens_updated: tokensUpdated,
          tokens_available: tokens.length,
        });
      }

      res.json({
        success: true,
        invoiceNumber,
        invoiceDate,
        invoiceType,
        products: results,
        totalProcessed: results.filter(r => !r.skipped).length,
        totalSkipped: results.filter(r => r.skipped).length,
      });
    } catch (error: any) {
      console.error("Error processing invoice:", error);
      res.status(500).json({ error: error.message || "Failed to process invoice" });
    }
  });

  app.get("/api/inventory/tokens", async (req, res) => {
    try {
      const { pool } = await import("./db");
      const productId = (req.query.product_id as string) || '500107';
      const storeId = (req.query.store_id as string) || '70012004';

      const statusResult = await pool.query(`
        SELECT status, COUNT(*) as count
        FROM product_tokens
        WHERE product_id = $1 AND store_id = $2
        GROUP BY status
      `, [productId, storeId]);

      const statusCounts: Record<string, number> = {};
      for (const row of statusResult.rows) {
        statusCounts[row.status] = parseInt(row.count);
      }

      const ageResult = await pool.query(`
        SELECT 
          MIN(arrival_date) as oldest_arrival,
          MAX(arrival_date) as newest_arrival,
          COUNT(*) FILTER (WHERE expiration_date <= CURRENT_DATE + INTERVAL '3 days' AND status = 'in_stock') as expiring_soon
        FROM product_tokens
        WHERE product_id = $1 AND store_id = $2 AND status = 'in_stock'
      `, [productId, storeId]);

      const age = ageResult.rows[0] || {};

      res.json({
        product_id: productId,
        store_id: storeId,
        in_stock: statusCounts['in_stock'] || 0,
        sold: statusCounts['sold'] || 0,
        returned: statusCounts['returned'] || 0,
        expired: statusCounts['expired'] || 0,
        cancelled: statusCounts['cancelled'] || 0,
        expiring_soon: parseInt(age.expiring_soon) || 0,
        oldest_arrival: age.oldest_arrival,
        newest_arrival: age.newest_arrival,
      });
    } catch (error) {
      console.error("Error fetching token inventory:", error);
      res.status(500).json({ error: "Failed to fetch token inventory" });
    }
  });

  // ── Delivery Batch Management (Cancel Deliveries) ──────────

  // List all delivery batches for a product, grouped by arrival_date
  app.get("/api/inventory/batches", async (req, res) => {
    try {
      const { pool } = await import("./db");
      const productId = (req.query.product_id as string) || '';
      const storeId = (req.query.store_id as string) || '70012004';

      if (!productId) {
        return res.status(400).json({ error: "product_id is required" });
      }

      const result = await pool.query(`
        SELECT
          batch_id,
          arrival_date,
          expiration_date,
          status,
          COUNT(*) as token_count
        FROM product_tokens
        WHERE product_id = $1 AND store_id = $2
        GROUP BY batch_id, arrival_date, expiration_date, status
        ORDER BY arrival_date DESC, status ASC
      `, [productId, storeId]);

      // Aggregate into batches keyed by arrival_date
      const batchMap: Record<string, {
        batch_id: string;
        arrival_date: string;
        expiration_date: string;
        in_stock: number;
        sold: number;
        returned: number;
        expired: number;
        cancelled: number;
        total: number;
      }> = {};

      for (const row of result.rows) {
        const key = `${row.batch_id}-${row.arrival_date}`;
        if (!batchMap[key]) {
          batchMap[key] = {
            batch_id: row.batch_id,
            arrival_date: row.arrival_date,
            expiration_date: row.expiration_date,
            in_stock: 0,
            sold: 0,
            returned: 0,
            expired: 0,
            cancelled: 0,
            total: 0,
          };
        }
        const count = parseInt(row.token_count);
        batchMap[key][row.status as 'in_stock' | 'sold' | 'returned' | 'expired' | 'cancelled'] = count;
        batchMap[key].total += count;
      }

      // Get product name
      const nameResult = await pool.query(
        `SELECT product_name FROM products WHERE product_id = $1`,
        [productId]
      );

      res.json({
        product_id: productId,
        product_name: nameResult.rows[0]?.product_name || `SKU ${productId}`,
        batches: Object.values(batchMap),
      });
    } catch (error) {
      console.error("Error fetching delivery batches:", error);
      res.status(500).json({ error: "Failed to fetch delivery batches" });
    }
  });

  // Cancel a delivery batch — marks in_stock tokens as 'cancelled' so pipeline resync won't recreate them
  app.post("/api/inventory/batches/cancel", requirePipelineAuth, async (req: any, res: any) => {
    try {
      const { pool } = await import("./db");
      const schema = z.object({
        productId: z.string(),
        batchId: z.string(),
        arrivalDate: z.string(),
        storeId: z.string().default("70012004"),
      });
      const { productId, batchId, arrivalDate, storeId } = schema.parse(req.body);

      // The batches list serialises DATE columns as ISO timestamps
      // ("2026-09-15T06:00:00.000Z" — midnight Edmonton). Take the calendar day only so
      // the comparison below is an exact DATE match regardless of wire format.
      const arrivalDay = arrivalDate.slice(0, 10);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(arrivalDay)) {
        return res.status(400).json({ error: "arrivalDate must start with YYYY-MM-DD" });
      }

      // Mark as cancelled instead of deleting — prevents pipeline resync from recreating tokens.
      // 'cancelled' is a tombstone: readers that count delivered units exclude it,
      // dedup guards (batch / arrival-date lookups) still see it.
      const result = await pool.query(`
        UPDATE product_tokens
        SET status = 'cancelled',
            status_date = CURRENT_DATE,
            updated_at = NOW(),
            notes = COALESCE(notes || ' | ', '') || 'Cancelled via dashboard ' || CURRENT_DATE::text
        WHERE product_id = $1
          AND store_id = $2
          AND batch_id = $3
          AND arrival_date = $4::date
          AND status = 'in_stock'
      `, [productId, storeId, batchId, arrivalDay]);

      const cancelled = result.rowCount || 0;

      console.log(`[CANCEL DELIVERY] ${productId} batch=${batchId} arrival=${arrivalDate} — ${cancelled} in_stock tokens marked cancelled`);

      res.json({
        success: true,
        cancelled,
        product_id: productId,
        batch_id: batchId,
        arrival_date: arrivalDate,
      });
    } catch (error) {
      console.error("Error cancelling delivery batch:", error);
      res.status(500).json({ error: "Failed to cancel delivery batch" });
    }
  });

  // Add new delivery tokens — manually inserts per-piece in_stock tokens for a
  // delivery OTTO never captured (no pipeline sync). One token = one unit on shelf.
  // Mirrors the Python token_generator_tool: uuid token_id, expiry = arrival + shelf
  // life, status_date = today. Immediately feeds the FIFO inventory + MLP, which
  // group by arrival_date and count in_stock (batch_id is for display/audit only).
  app.post("/api/inventory/batches/add", requirePipelineAuth, async (req: any, res: any) => {
    try {
      const { pool } = await import("./db");
      const schema = z.object({
        productId: z.string().min(1),
        arrivalDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "arrivalDate must be YYYY-MM-DD"),
        quantity: z.number().int().positive().max(500),
        storeId: z.string().default("70012004"),
        batchId: z.string().optional(),
        notes: z.string().optional(),
      });
      const { productId, arrivalDate, quantity, storeId, batchId, notes } = schema.parse(req.body);

      // Reject future arrivals — this feature corrects past/present landed stock only;
      // forward inventory is the MLP's job. CURRENT_DATE uses the Edmonton (MST) session
      // timezone set in db.ts, so this is correct regardless of the node host's OS clock.
      const futureCheck = await pool.query(`SELECT ($1::date > CURRENT_DATE) AS is_future`, [arrivalDate]);
      if (futureCheck.rows[0]?.is_future) {
        return res.status(400).json({ error: "arrivalDate cannot be in the future — this corrects past/present landed stock only" });
      }

      // Product name + shelf life from products table (default 16d standard if unknown)
      const prod = await pool.query(
        `SELECT product_name, COALESCE(shelf_life_days, 16) AS shelf_life_days
         FROM products WHERE product_id = $1`,
        [productId]
      );
      const productName: string = prod.rows[0]?.product_name || `SKU ${productId}`;
      const shelfLife: number = prod.rows[0]?.shelf_life_days ?? 16;

      // Default batch id mirrors the token-generator convention but flags manual origin
      const finalBatchId = batchId && batchId.trim()
        ? batchId.trim()
        : `MANUAL-ADD-${productId}-${arrivalDate}`;

      // Single atomic multi-row insert: one in_stock token per unit via generate_series
      const result = await pool.query(
        `INSERT INTO product_tokens
           (token_id, product_id, product_name, store_id,
            arrival_date, expiration_date, status, status_date, consumed_date, batch_id, notes)
         SELECT gen_random_uuid()::text, $1, $2, $3,
                $4::date, ($4::date + ($5 || ' days')::interval)::date,
                'in_stock', CURRENT_DATE, NULL, $6, $7
         FROM generate_series(1, $8)`,
        [productId, productName, storeId, arrivalDate, shelfLife, finalBatchId, notes || null, quantity]
      );

      const added = result.rowCount || 0;

      // Compute expiry for the response (UTC date math matches the DB's plain-date add)
      const exp = new Date(`${arrivalDate}T00:00:00Z`);
      exp.setUTCDate(exp.getUTCDate() + shelfLife);
      const expirationDate = exp.toISOString().slice(0, 10);

      console.log(`[ADD DELIVERY] ${productId} arrival=${arrivalDate} qty=${quantity} batch=${finalBatchId} — ${added} in_stock tokens inserted`);

      res.json({
        success: true,
        added,
        product_id: productId,
        product_name: productName,
        store_id: storeId,
        arrival_date: arrivalDate,
        expiration_date: expirationDate,
        shelf_life_days: shelfLife,
        batch_id: finalBatchId,
      });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors.map((e) => e.message).join("; ") });
      }
      console.error("Error adding delivery tokens:", error);
      res.status(500).json({ error: "Failed to add delivery tokens" });
    }
  });

  // ============================================================
  // SALES & RETURNS TRACKER
  // ============================================================

  // Get all tracked product IDs (products with token activity)
  app.get("/api/tracker/products", async (_req, res) => {
    try {
      const { pool } = await import("./db");
      const result = await pool.query(`
        SELECT DISTINCT product_id FROM (
          SELECT product_id FROM token_sales_log
          UNION
          SELECT product_id FROM token_returns_log
          UNION
          SELECT product_id FROM product_tokens
        ) combined
        ORDER BY product_id
      `);
      // Enrich with product names from products table
      const productIds = result.rows.map((r: any) => r.product_id);
      const products = await pool.query(
        `SELECT product_id, product_name FROM products WHERE product_id = ANY($1)`,
        [productIds]
      );
      const nameMap: Record<string, string> = {};
      products.rows.forEach((r: any) => { nameMap[r.product_id] = r.product_name; });

      res.json(productIds.map((pid: string) => ({
        product_id: pid,
        product_name: nameMap[pid] || `SKU ${pid}`,
      })));
    } catch (error) {
      console.error("Error fetching tracker products:", error);
      res.status(500).json({ error: "Failed to fetch tracker products" });
    }
  });

  // Get sales log for a product (or all products)
  app.get("/api/tracker/sales", async (req, res) => {
    try {
      const { pool } = await import("./db");
      const productId = req.query.productId as string | undefined;
      const limit = parseInt(req.query.limit as string) || 100;

      let query = `
        SELECT s.*, p.product_name
        FROM token_sales_log s
        LEFT JOIN products p ON s.product_id = p.product_id
      `;
      const params: any[] = [];

      if (productId) {
        query += ` WHERE s.product_id = $1`;
        params.push(productId);
      }
      query += ` ORDER BY s.sale_date DESC, s.id DESC LIMIT $${params.length + 1}`;
      params.push(limit);

      const result = await pool.query(query, params);
      res.json(result.rows);
    } catch (error) {
      console.error("Error fetching sales log:", error);
      res.status(500).json({ error: "Failed to fetch sales log" });
    }
  });

  // Get returns log for a product (or all products)
  app.get("/api/tracker/returns", async (req, res) => {
    try {
      const { pool } = await import("./db");
      const productId = req.query.productId as string | undefined;
      const limit = parseInt(req.query.limit as string) || 100;

      let query = `
        SELECT r.*, p.product_name
        FROM token_returns_log r
        LEFT JOIN products p ON r.product_id = p.product_id
      `;
      const params: any[] = [];

      if (productId) {
        query += ` WHERE r.product_id = $1`;
        params.push(productId);
      }
      query += ` ORDER BY r.return_date DESC, r.id DESC LIMIT $${params.length + 1}`;
      params.push(limit);

      const result = await pool.query(query, params);
      res.json(result.rows);
    } catch (error) {
      console.error("Error fetching returns log:", error);
      res.status(500).json({ error: "Failed to fetch returns log" });
    }
  });

  // Get combined summary stats per product
  app.get("/api/tracker/summary", async (_req, res) => {
    try {
      const { pool } = await import("./db");
      const result = await pool.query(`
        WITH sales AS (
          SELECT product_id,
            COUNT(*) as sale_events,
            COALESCE(SUM(units_sold), 0) as total_sold,
            MIN(sale_date) as first_sale,
            MAX(sale_date) as last_sale
          FROM token_sales_log
          GROUP BY product_id
        ),
        returns AS (
          SELECT product_id,
            COUNT(*) as return_events,
            COALESCE(SUM(units_returned), 0) as total_returned,
            MIN(return_date) as first_return,
            MAX(return_date) as last_return
          FROM token_returns_log
          GROUP BY product_id
        ),
        tokens AS (
          SELECT product_id,
            COUNT(*) FILTER (WHERE status = 'in_stock') as in_stock,
            COUNT(*) FILTER (WHERE status = 'sold') as sold_tokens,
            COUNT(*) FILTER (WHERE status = 'returned') as returned_tokens,
            COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_tokens,
            COUNT(*) FILTER (WHERE status <> 'cancelled') as total_tokens
          FROM product_tokens
          GROUP BY product_id
        ),
        all_products AS (
          SELECT product_id FROM sales
          UNION SELECT product_id FROM returns
          UNION SELECT product_id FROM tokens
        )
        SELECT
          ap.product_id,
          p.product_name,
          COALESCE(s.sale_events, 0) as sale_events,
          COALESCE(s.total_sold, 0) as total_sold,
          s.first_sale, s.last_sale,
          COALESCE(r.return_events, 0) as return_events,
          COALESCE(r.total_returned, 0) as total_returned,
          r.first_return, r.last_return,
          COALESCE(t.in_stock, 0) as in_stock,
          COALESCE(t.sold_tokens, 0) as sold_tokens,
          COALESCE(t.returned_tokens, 0) as returned_tokens,
          COALESCE(t.cancelled_tokens, 0) as cancelled_tokens,
          COALESCE(t.total_tokens, 0) as total_tokens,
          CASE WHEN COALESCE(s.total_sold, 0) + COALESCE(r.total_returned, 0) > 0
            THEN ROUND(COALESCE(r.total_returned, 0)::numeric /
              (COALESCE(s.total_sold, 0) + COALESCE(r.total_returned, 0))::numeric * 100, 1)
            ELSE 0
          END as return_rate_pct
        FROM all_products ap
        LEFT JOIN sales s ON ap.product_id = s.product_id
        LEFT JOIN returns r ON ap.product_id = r.product_id
        LEFT JOIN tokens t ON ap.product_id = t.product_id
        LEFT JOIN products p ON ap.product_id = p.product_id
        ORDER BY ap.product_id
      `);
      res.json(result.rows);
    } catch (error) {
      console.error("Error fetching tracker summary:", error);
      res.status(500).json({ error: "Failed to fetch tracker summary" });
    }
  });

  // Get system logs
  app.get("/api/logs", async (req, res) => {
    try {
      const logs = await storage.getLogs(50);
      res.json(logs);
    } catch (error) {
      console.error("Error fetching logs:", error);
      res.status(500).json({ error: "Failed to fetch logs" });
    }
  });

  // ── Hormuz Multiplier Configuration ──────────────────────────

  // GET /api/hormuz — returns { global: number, products: Record<string, number> }
  app.get("/api/hormuz", async (_req, res) => {
    try {
      const rows = await db.select().from(hormuzConfig);
      let global = 0.85; // default
      const products: Record<string, number> = {};
      for (const row of rows) {
        if (row.productId === "__global__") {
          global = row.multiplier;
        } else {
          products[row.productId] = row.multiplier;
        }
      }
      res.json({ global, products });
    } catch (error) {
      console.error("Error fetching hormuz config:", error);
      res.status(500).json({ error: "Failed to fetch hormuz config" });
    }
  });

  // PUT /api/hormuz — upsert global and per-product multipliers
  app.put("/api/hormuz", async (req, res) => {
    try {
      const schema = z.object({
        global: z.number().min(0).max(3),
        products: z.record(z.string(), z.number().min(0).max(3)),
      });
      const { global: globalVal, products: productOverrides } = schema.parse(req.body);

      // Upsert global row
      await db
        .insert(hormuzConfig)
        .values({ productId: "__global__", multiplier: globalVal })
        .onConflictDoUpdate({
          target: hormuzConfig.productId,
          set: { multiplier: globalVal, updatedAt: sql`now()` },
        });

      // Upsert each per-product override
      for (const [productId, multiplier] of Object.entries(productOverrides)) {
        await db
          .insert(hormuzConfig)
          .values({ productId, multiplier })
          .onConflictDoUpdate({
            target: hormuzConfig.productId,
            set: { multiplier, updatedAt: sql`now()` },
          });
      }

      // Remove products no longer in overrides (except __global__)
      const rows = await db.select().from(hormuzConfig);
      for (const row of rows) {
        if (row.productId !== "__global__" && !(row.productId in productOverrides)) {
          await db.delete(hormuzConfig).where(eq(hormuzConfig.productId, row.productId));
        }
      }

      res.json({ success: true });
    } catch (error) {
      console.error("Error updating hormuz config:", error);
      res.status(500).json({ error: "Failed to update hormuz config" });
    }
  });

  // POST /api/inventory/fifo-projection — preview FIFO depletion under a
  // proposed Hormuz multiplier without writing to hormuz_config. Spawns the
  // canonical Python bridge so the math matches the production pipeline
  // exactly (no TS reimplementation, no drift).
  app.post("/api/inventory/fifo-projection", async (req, res) => {
    try {
      const schema = z.object({
        products: z.array(z.string()).min(1),
        hormuzGlobal: z.number().min(0).max(3).optional(),
        hormuzOverrides: z.record(z.string(), z.number().min(0).max(3)).optional(),
        includeDecisions: z.boolean().optional(),
        storeId: z.string().optional(),
      });
      const body = schema.parse(req.body);

      // Resolve venv python (demo venv lives at <repo>/levaintron)
      const projectRoot = path.resolve(process.cwd(), "..");
      const venvPython = path.resolve(projectRoot, "levaintron", "bin", "python");
      const pythonBin = fs.existsSync(venvPython) ? venvPython : "python3";

      const args = [
        "-m", "Application_env.ai_orchestrator.fifo_projection_cli",
        "--products", body.products.join(","),
        "--store-id", body.storeId || "70012004",
        "--json",
      ];
      if (body.hormuzGlobal !== undefined) {
        args.push("--hormuz-global", String(body.hormuzGlobal));
      }
      if (body.hormuzOverrides && Object.keys(body.hormuzOverrides).length > 0) {
        args.push("--hormuz-overrides", JSON.stringify(body.hormuzOverrides));
      }
      if (body.includeDecisions) {
        args.push("--include-decisions");
      }

      // Live preview must feel snappy; full-decisions modal is allowed longer.
      const timeoutMs = body.includeDecisions ? 60000 : 15000;

      execFile(pythonBin, args, {
        cwd: projectRoot,
        timeout: timeoutMs,
        maxBuffer: 8 * 1024 * 1024,
      }, (error, stdout, stderr) => {
        if (error) {
          console.error("FIFO projection failed:", stderr || error.message);
          return res.status(500).json({
            error: "Projection failed",
            detail: stderr?.toString().slice(-2000) || error.message,
          });
        }
        try {
          const payload = JSON.parse(stdout);
          res.json(payload);
        } catch (parseErr: any) {
          console.error("FIFO projection JSON parse failed:", parseErr.message);
          console.error("stdout was:", stdout.slice(0, 500));
          res.status(500).json({
            error: "Could not parse projection output",
            detail: parseErr.message,
          });
        }
      });
    } catch (error: any) {
      console.error("Error in FIFO projection endpoint:", error);
      res.status(400).json({ error: error.message || "Bad request" });
    }
  });

  // ── Weather Forecast (Open-Meteo, demo region: Calgary, AB) ────────────
  const DEMO_LAT = 51.045;
  const DEMO_LON = -114.058;
  const SNOW_CODES = new Set([56, 57, 66, 67, 71, 73, 75, 77, 85, 86]);
  const WEATHER_AWARE_PRODUCTS: Record<string, string> = {
    "121950": "Dempsters HD Original 12PK",
    "121949": "Dempsters HB Original 8PK",
    "122560": "Villaggio HB Sausage 6PK",
    "122563": "Villaggio Toscana Sausage Bun 6PK",
  };

  let weatherCache: { data: any; fetchedAt: number } | null = null;
  const WEATHER_CACHE_TTL = 3 * 60 * 60 * 1000; // 3 hours

  app.get("/api/weather", async (_req, res) => {
    try {
      if (weatherCache && Date.now() - weatherCache.fetchedAt < WEATHER_CACHE_TTL) {
        return res.json(weatherCache.data);
      }

      const url = `https://api.open-meteo.com/v1/forecast?latitude=${DEMO_LAT}&longitude=${DEMO_LON}&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,weathercode&timezone=America/Edmonton&forecast_days=14`;
      const resp = await fetch(url);
      const raw = await resp.json();
      const daily = raw.daily;

      const days = daily.time.map((date: string, i: number) => {
        const tempMax = daily.temperature_2m_max[i];
        const tempMin = daily.temperature_2m_min[i];
        const precipProb = daily.precipitation_probability_max[i];
        const precipMm = daily.precipitation_sum[i];
        const weathercode = daily.weathercode[i];

        let outdoorScore: number;
        if (SNOW_CODES.has(weathercode)) {
          outdoorScore = 0.0;
        } else {
          const avgTemp = (tempMax + tempMin) / 2;
          const tempScore = avgTemp <= 5 ? 0 : avgTemp >= 25 ? 1 : (avgTemp - 5) / 20;
          const rainFactor = 1 - precipProb / 100;
          outdoorScore = Math.max(0, Math.min(1, tempScore * rainFactor));
        }

        return {
          date,
          temp_max: tempMax,
          temp_min: tempMin,
          precip_probability: precipProb,
          precipitation_mm: precipMm,
          weathercode,
          outdoor_score: Math.round(outdoorScore * 1000) / 1000,
        };
      });

      const result = {
        location: "Calgary, AB (demo)",
        fetched_at: new Date().toISOString(),
        affected_products: WEATHER_AWARE_PRODUCTS,
        days,
      };

      weatherCache = { data: result, fetchedAt: Date.now() };
      res.json(result);
    } catch (error) {
      console.error("Weather API error:", error);
      res.status(500).json({ error: "Failed to fetch weather forecast" });
    }
  });

  return httpServer;
}
