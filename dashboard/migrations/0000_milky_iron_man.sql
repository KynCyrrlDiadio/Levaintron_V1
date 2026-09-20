CREATE TABLE "hormuz_config" (
	"id" serial PRIMARY KEY NOT NULL,
	"product_id" varchar(20) NOT NULL,
	"multiplier" real DEFAULT 1 NOT NULL,
	"updated_at" timestamp DEFAULT now(),
	CONSTRAINT "hormuz_config_product_id_unique" UNIQUE("product_id")
);
--> statement-breakpoint
CREATE TABLE "orders" (
	"id" varchar PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"quantity" integer NOT NULL,
	"prediction_id" varchar,
	"status" text DEFAULT 'pending' NOT NULL,
	"notes" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "predictions" (
	"id" varchar PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"input_features" jsonb NOT NULL,
	"predicted_decision" integer NOT NULL,
	"confidence" real NOT NULL,
	"model_version" text NOT NULL,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "products" (
	"id" serial PRIMARY KEY NOT NULL,
	"product_id" varchar(20) NOT NULL,
	"sku" varchar(30) NOT NULL,
	"product_name" varchar(200) NOT NULL,
	"category" varchar(50) DEFAULT 'bread',
	"store_id" varchar(20) DEFAULT '70012004' NOT NULL,
	"tray_factor" integer DEFAULT 9 NOT NULL,
	"shelf_life_days" integer DEFAULT 16 NOT NULL,
	"reorder_point" integer DEFAULT 20,
	"reorder_quantity" integer DEFAULT 20,
	"delivery_days" text DEFAULT 'mon,tue,thu,fri' NOT NULL,
	"lead_time_days" integer DEFAULT 3 NOT NULL,
	"return_days" text DEFAULT 'tue,fri' NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"mlp_enabled" boolean DEFAULT false,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now(),
	CONSTRAINT "products_product_id_unique" UNIQUE("product_id")
);
--> statement-breakpoint
CREATE TABLE "returns_invoices" (
	"id" serial PRIMARY KEY NOT NULL,
	"invoice_id" varchar(50) NOT NULL,
	"store_id" varchar(20) DEFAULT '70012004' NOT NULL,
	"invoice_date" date NOT NULL,
	"product_id" varchar(20) NOT NULL,
	"units_returned" integer NOT NULL,
	"reason" text,
	"processed_at" timestamp DEFAULT now(),
	"tokens_updated" integer DEFAULT 0,
	CONSTRAINT "returns_invoices_invoice_id_unique" UNIQUE("invoice_id")
);
--> statement-breakpoint
CREATE TABLE "seasonal_sales_data" (
	"id" serial PRIMARY KEY NOT NULL,
	"store_id" varchar(20) DEFAULT '70012004' NOT NULL,
	"supplier" varchar(100) DEFAULT 'Canada Bread Company',
	"category" varchar(100) NOT NULL,
	"sku" varchar(30) NOT NULL,
	"product_name" varchar(200) NOT NULL,
	"pack_size" integer,
	"forecast_period" varchar(50),
	"on_hand" integer DEFAULT 0,
	"production" integer DEFAULT 0,
	"thu_sales" integer DEFAULT 0,
	"fri_sales" integer DEFAULT 0,
	"sat_sales" integer DEFAULT 0,
	"sun_sales" integer DEFAULT 0,
	"mon_sales" integer DEFAULT 0,
	"tue_sales" integer DEFAULT 0,
	"wed_sales" integer DEFAULT 0,
	"weekly_total" integer DEFAULT 0,
	"peak_day" varchar(10),
	"notes" text,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "system_logs" (
	"id" varchar PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"level" text NOT NULL,
	"message" text NOT NULL,
	"metadata" jsonb,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "token_returns_log" (
	"id" serial PRIMARY KEY NOT NULL,
	"product_id" varchar(20) NOT NULL,
	"store_id" varchar(20) NOT NULL,
	"return_date" date NOT NULL,
	"units_returned" integer NOT NULL,
	"invoice_id" varchar(50),
	"batch_id" varchar(100),
	"arrival_date" date,
	"expiration_date" date,
	"days_on_shelf" integer,
	"reason" text,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "token_sales_log" (
	"id" serial PRIMARY KEY NOT NULL,
	"product_id" varchar(20) NOT NULL,
	"store_id" varchar(20) NOT NULL,
	"sale_date" date NOT NULL,
	"units_sold" integer NOT NULL,
	"batch_id" varchar(100),
	"arrival_date" date,
	"expiration_date" date,
	"days_on_shelf" integer,
	"source" varchar(50),
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "training_data" (
	"id" varchar PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"current_inventory" integer NOT NULL,
	"day_of_week" integer NOT NULL,
	"expected_sales" real NOT NULL,
	"actual_sales_rate" real NOT NULL,
	"monthly_multiplier" real DEFAULT 1 NOT NULL,
	"is_holiday" boolean DEFAULT false NOT NULL,
	"pipeline_incoming" integer DEFAULT 0 NOT NULL,
	"returns_rate" real DEFAULT 0 NOT NULL,
	"decision" integer NOT NULL,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "training_runs" (
	"id" varchar PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"model_version" text NOT NULL,
	"epochs" integer NOT NULL,
	"batch_size" integer NOT NULL,
	"learning_rate" real NOT NULL,
	"train_loss" real,
	"val_loss" real,
	"accuracy" real,
	"samples_used" integer NOT NULL,
	"status" text DEFAULT 'running' NOT NULL,
	"started_at" timestamp DEFAULT now(),
	"completed_at" timestamp
);
--> statement-breakpoint
ALTER TABLE "orders" ADD CONSTRAINT "orders_prediction_id_predictions_id_fk" FOREIGN KEY ("prediction_id") REFERENCES "public"."predictions"("id") ON DELETE no action ON UPDATE no action;