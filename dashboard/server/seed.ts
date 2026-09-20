import { db } from "./db";
import { trainingData, predictions, orders, trainingRuns, systemLogs } from "@shared/schema";
import { count } from "drizzle-orm";
import { generateTrainingData, mlpPredict, simulateTraining } from "./mlp-engine";
import type { PredictionInput } from "@shared/schema";

export async function seedDatabase() {
  console.log("Checking if database needs seeding...");
  
  // Check if we already have data
  const [trainingCount] = await db.select({ count: count() }).from(trainingData);
  const [predictionsCount] = await db.select({ count: count() }).from(predictions);
  
  if ((trainingCount?.count ?? 0) > 0 && (predictionsCount?.count ?? 0) > 0) {
    console.log("Database already has data, skipping seed.");
    return;
  }
  
  console.log("Seeding database with initial data...");
  
  try {
    // Generate training data
    const trainingSamples = generateTrainingData(200);
    await db.insert(trainingData).values(trainingSamples);
    console.log(`Created ${trainingSamples.length} training samples`);
    
    // Create initial training run
    const trainingResults = simulateTraining(200, 50, 32, 0.001);
    await db.insert(trainingRuns).values({
      modelVersion: "1.0.0",
      epochs: 50,
      batchSize: 32,
      learningRate: 0.001,
      trainLoss: trainingResults.trainLoss,
      valLoss: trainingResults.valLoss,
      accuracy: trainingResults.accuracy,
      samplesUsed: 200,
      status: "completed",
      completedAt: new Date(),
    });
    console.log("Created initial training run");
    
    const sampleInputs: PredictionInput[] = [
      { currentInventory: 5, dayOfWeek: 1, expectedSales: 4.5, actualSalesRate: 3.5, monthlyMultiplier: 1.0, isHoliday: false, pipelineIncoming: 0, returnsRate: 1.2 },
      { currentInventory: 25, dayOfWeek: 3, expectedSales: 3.0, actualSalesRate: 1.2, monthlyMultiplier: 0.8, isHoliday: false, pipelineIncoming: 10, returnsRate: 0.5 },
      { currentInventory: 12, dayOfWeek: 5, expectedSales: 5.0, actualSalesRate: 2.8, monthlyMultiplier: 1.1, isHoliday: false, pipelineIncoming: 5, returnsRate: 2.0 },
      { currentInventory: 8, dayOfWeek: 6, expectedSales: 4.0, actualSalesRate: 2.0, monthlyMultiplier: 1.3, isHoliday: true, pipelineIncoming: 0, returnsRate: 0.8 },
      { currentInventory: 30, dayOfWeek: 2, expectedSales: 2.5, actualSalesRate: 0.8, monthlyMultiplier: 0.7, isHoliday: false, pipelineIncoming: 20, returnsRate: 3.5 },
    ];
    
    for (const input of sampleInputs) {
      const { decision, confidence } = mlpPredict(input);
      await db.insert(predictions).values({
        inputFeatures: input,
        predictedDecision: decision,
        confidence,
        modelVersion: "1.0.0",
      });
    }
    console.log(`Created ${sampleInputs.length} sample predictions`);
    
    // Create sample orders
    const orderData = [
      { quantity: 10, status: "delivered", notes: "Monday morning order" },
      { quantity: 5, status: "confirmed", notes: "Mid-week restock" },
      { quantity: 0, status: "pending", notes: "Skipped - high inventory" },
    ];
    
    for (const order of orderData) {
      await db.insert(orders).values(order);
    }
    console.log(`Created ${orderData.length} sample orders`);
    
    // Create system logs
    const logMessages = [
      { level: "info", message: "System initialized successfully" },
      { level: "info", message: "MLP model v1.0.0 loaded and ready" },
      { level: "info", message: "Training pipeline initialized with 200 samples" },
    ];
    
    for (const log of logMessages) {
      await db.insert(systemLogs).values(log);
    }
    console.log(`Created ${logMessages.length} system logs`);
    
    console.log("Database seeding complete!");
  } catch (error) {
    console.error("Error seeding database:", error);
  }
}
