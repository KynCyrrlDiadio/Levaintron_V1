import type { InsertTrainingData, PredictionInput } from "@shared/schema";

/**
 * MLP Decision Engine v8.5 for Bread Ordering (Web Dashboard Simulation)
 * 
 * Simulates the trained PyTorch MLP that outputs [0, 5, 10, 20] classification
 * using v8.5 features: inventory, day, expected_sales, actual_sales, monthly_mult,
 * is_holiday, pipeline_incoming, returns_rate
 * 
 * Decision logic (matches v8.5 training data generator):
 * - ORDER 0 (cancel): days_eff > 6 AND pipeline incoming, OR high returns AND stock OK
 * - ORDER 5 (trim): days_eff > 6 AND demand < 6/day (overstock trim)
 * - ORDER 10 (normal): default for balanced conditions
 * - ORDER 20 (emergency): stock critically low (<3 days effective inventory)
 */

export function getCorrectDecision(input: PredictionInput): 0 | 5 | 10 | 20 {
  const { currentInventory, dayOfWeek, expectedSales, actualSalesRate,
          monthlyMultiplier, isHoliday, pipelineIncoming, returnsRate } = input;

  const effectiveSalesRate = Math.max(actualSalesRate, expectedSales) * monthlyMultiplier;
  if (isHoliday) {
    const holidayRate = effectiveSalesRate * 1.5;
    const daysOfInventory = holidayRate > 0 ? (currentInventory + pipelineIncoming) / holidayRate : 999;
    if (daysOfInventory < 3) return 20;
    if (daysOfInventory < 5) return 10;
  }

  const daysEff = effectiveSalesRate > 0
    ? (currentInventory + pipelineIncoming) / effectiveSalesRate
    : 999;

  if (currentInventory < 3 || daysEff < 2) {
    return 20;
  }

  if (returnsRate > 8 && daysEff > 4) {
    return 0;
  }

  if (returnsRate > 5 && daysEff > 5) {
    return 5;
  }

  if (daysEff > 6 && pipelineIncoming > 10) {
    return 0;
  }

  if (daysEff > 6 && effectiveSalesRate < 6) {
    return 5;
  }

  if (currentInventory > 45) {
    return 0;
  }

  if (daysEff < 4 || (effectiveSalesRate >= 6 && daysEff < 5)) {
    return 10;
  }

  return 5;
}

export function mlpPredict(input: PredictionInput): { decision: 0 | 5 | 10 | 20; confidence: number } {
  const decision = getCorrectDecision(input);
  
  const { currentInventory, actualSalesRate, pipelineIncoming } = input;
  
  let confidence = 0.7;
  
  if (currentInventory < 5 || currentInventory > 35) confidence += 0.15;
  if (actualSalesRate < 1 || actualSalesRate > 6) confidence += 0.1;
  if (pipelineIncoming > 20) confidence += 0.05;
  
  confidence += (Math.random() - 0.5) * 0.1;
  confidence = Math.max(0.5, Math.min(0.99, confidence));
  
  return { decision, confidence };
}

export function generateTrainingData(count: number): InsertTrainingData[] {
  const data: InsertTrainingData[] = [];
  
  for (let i = 0; i < count; i++) {
    const currentInventory = Math.floor(Math.random() * 50) + 1;
    const dayOfWeek = Math.floor(Math.random() * 7);
    const expectedSales = Math.random() * 8 + 1;
    const actualSalesRate = Math.random() * 8 + 0.5;
    const monthlyMultiplier = 0.7 + Math.random() * 0.6;
    const isHoliday = Math.random() < 0.05;
    const pipelineIncoming = Math.floor(Math.random() * 40);
    const returnsRate = Math.random() * 10;
    
    const input: PredictionInput = {
      currentInventory,
      dayOfWeek,
      expectedSales,
      actualSalesRate,
      monthlyMultiplier,
      isHoliday,
      pipelineIncoming,
      returnsRate,
    };
    
    const decision = getCorrectDecision(input);
    
    data.push({
      currentInventory,
      dayOfWeek,
      expectedSales,
      actualSalesRate,
      monthlyMultiplier,
      isHoliday,
      pipelineIncoming,
      returnsRate,
      decision,
    });
  }
  
  return data;
}

export function parseNLQuery(query: string): {
  intent: "predict" | "order" | "status" | "help" | "unknown";
  params: Partial<PredictionInput>;
  orderQuantity?: number;
} {
  const lowerQuery = query.toLowerCase();
  
  const numbers = query.match(/\d+/g)?.map(Number) || [];
  
  if (lowerQuery.includes("order")) {
    const orderMatch = lowerQuery.match(/order\s*(\d+)/);
    if (orderMatch) {
      const qty = parseInt(orderMatch[1]);
      const orderQuantity = qty <= 2 ? 0 : qty <= 7 ? 5 : qty <= 14 ? 10 : 20;
      return { intent: "order", params: {}, orderQuantity };
    }
    return { intent: "order", params: {} };
  }
  
  if (
    lowerQuery.includes("what should") ||
    lowerQuery.includes("recommend") ||
    lowerQuery.includes("predict") ||
    lowerQuery.includes("how many")
  ) {
    const params: Partial<PredictionInput> = {};
    
    const days = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
    for (let i = 0; i < days.length; i++) {
      if (lowerQuery.includes(days[i])) {
        params.dayOfWeek = i;
        break;
      }
    }
    
    const inventoryMatch = lowerQuery.match(/(\d+)\s*(loaves?|bread|units?)/);
    if (inventoryMatch) {
      params.currentInventory = parseInt(inventoryMatch[1]);
    }
    
    if (lowerQuery.includes("holiday")) params.isHoliday = true;
    
    if (lowerQuery.includes("peak") || lowerQuery.includes("busy")) {
      params.monthlyMultiplier = 1.3;
    } else if (lowerQuery.includes("slow") || lowerQuery.includes("quiet")) {
      params.monthlyMultiplier = 0.7;
    }

    if (lowerQuery.includes("high returns") || lowerQuery.includes("returns")) {
      params.returnsRate = 8;
    }
    
    return { intent: "predict", params };
  }
  
  if (lowerQuery.includes("status") || lowerQuery.includes("inventory") || lowerQuery.includes("stock")) {
    return { intent: "status", params: {} };
  }
  
  if (lowerQuery.includes("help") || lowerQuery.includes("how to")) {
    return { intent: "help", params: {} };
  }
  
  return { intent: "predict", params: {} };
}

export function simulateTraining(
  samplesCount: number,
  epochs: number = 50,
  batchSize: number = 32,
  learningRate: number = 0.001
): {
  trainLoss: number;
  valLoss: number;
  accuracy: number;
} {
  const sampleFactor = Math.min(1, samplesCount / 500);
  const baseAccuracy = 0.75 + 0.2 * sampleFactor;
  const accuracy = Math.min(0.98, baseAccuracy + (Math.random() - 0.5) * 0.05);
  const trainLoss = 0.5 * (1 - accuracy) + Math.random() * 0.1;
  const valLoss = trainLoss * (1 + Math.random() * 0.2);
  
  return {
    trainLoss: parseFloat(trainLoss.toFixed(4)),
    valLoss: parseFloat(valLoss.toFixed(4)),
    accuracy: parseFloat(accuracy.toFixed(4)),
  };
}
