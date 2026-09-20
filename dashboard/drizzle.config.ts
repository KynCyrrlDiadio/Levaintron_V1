import "./server/load-env";
import { defineConfig } from "drizzle-kit";

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL, ensure the database is provisioned");
}

export default defineConfig({
  out: "./migrations",
  schema: "./shared/schema.ts",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.DATABASE_URL,
  },
  tablesFilter: [
    "training_data",
    "predictions",
    "orders",
    "training_runs",
    "system_logs",
    "seasonal_sales_data",
    "returns_invoices",
    "hormuz_config",
  ],
});