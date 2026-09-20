import { Pool } from "pg";
import { drizzle } from "drizzle-orm/node-postgres";
import * as schema from "@shared/schema";

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL environment variable is not set");
}

// DEMO GUARD: this dashboard may only ever talk to the levaintron_demo database.
// Set DEMO_ALLOW_ANY_DB=1 to bypass (you almost certainly do not want to).
{
  const dbName = process.env.DATABASE_URL.split("/").pop()?.split("?")[0] ?? "";
  if (dbName !== "levaintron_demo" && process.env.DEMO_ALLOW_ANY_DB !== "1") {
    throw new Error(
      `Refusing to start: DATABASE_URL points at database "${dbName}", expected "levaintron_demo". ` +
      `Fix dashboard/.env (see .env.example).`
    );
  }
  console.log(`[demo] database: ${dbName}`);
}

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// Set session timezone to MST (America/Edmonton) for all connections
pool.on("connect", (client) => {
  client.query("SET timezone = 'America/Edmonton'");
});

export const db = drizzle(pool, { schema });
