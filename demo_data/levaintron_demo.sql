--
-- PostgreSQL database dump
--

\restrict TUFVJ7NcgzQqKNoXsVTadYl1dy2pfJ5V6WlSeQLJeuJnGa6Vn3eHxea7nfxIqol

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.13

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: daily_forecast; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_forecast (
    id integer NOT NULL,
    sku character varying(30) NOT NULL,
    store_id character varying(20) DEFAULT '70012004'::character varying NOT NULL,
    forecast_date date NOT NULL,
    day_of_week character varying(10) NOT NULL,
    month integer NOT NULL,
    expected_sales numeric(4,1) NOT NULL,
    monthly_multiplier numeric(4,2) NOT NULL,
    dow_multiplier numeric(4,2) NOT NULL,
    confidence character varying(20) DEFAULT 'measured'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: daily_forecast_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.daily_forecast_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: daily_forecast_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.daily_forecast_id_seq OWNED BY public.daily_forecast.id;


--
-- Name: daily_sales_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_sales_log (
    id integer NOT NULL,
    store_id character varying(20) DEFAULT '70012004'::character varying NOT NULL,
    sku character varying(30) NOT NULL,
    product_name character varying(200) NOT NULL,
    sale_date date NOT NULL,
    day_of_week character varying(10) NOT NULL,
    pieces_sold integer DEFAULT 0 NOT NULL,
    month integer NOT NULL,
    year integer NOT NULL,
    notes text,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: daily_sales_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.daily_sales_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: daily_sales_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.daily_sales_log_id_seq OWNED BY public.daily_sales_log.id;


--
-- Name: hormuz_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hormuz_config (
    product_id character varying(20) NOT NULL,
    multiplier numeric NOT NULL,
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: inventory_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_transactions (
    transaction_id text NOT NULL,
    product_id text NOT NULL,
    store_id text NOT NULL,
    transaction_type text NOT NULL,
    quantity integer NOT NULL,
    transaction_date date NOT NULL,
    source text NOT NULL,
    source_reference text,
    notes text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_transaction_type CHECK ((transaction_type = ANY (ARRAY['delivery'::text, 'sale'::text, 'return'::text, 'expired'::text, 'physical_count'::text, 'adjustment'::text])))
);


--
-- Name: mlp_order_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mlp_order_log (
    id integer NOT NULL,
    product_id character varying(20) NOT NULL,
    decision_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    mlp_recommendation integer,
    mlp_confidence real,
    mlp_method character varying(50),
    actual_loaves_ordered integer,
    was_overridden boolean DEFAULT false,
    override_reason text,
    outcome character varying(30),
    order_date character varying(20),
    current_stock integer,
    sales_rate real,
    reasoning text,
    store_id character varying(50),
    projected_stock real,
    standing_order integer DEFAULT 0,
    adj_value integer DEFAULT 0,
    total_units integer DEFAULT 0,
    otto_action character varying(20),
    otto_write_success boolean,
    dow character varying(5),
    column_index integer,
    monthly_multiplier real,
    returns_rate real,
    delivery_date character varying(20),
    expected_sales real,
    actual_sales_rate real,
    pipeline_incoming integer,
    day_of_week integer,
    is_holiday boolean DEFAULT false,
    mlp_decision integer,
    tray_factor integer,
    features text,
    verified boolean
);


--
-- Name: mlp_order_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mlp_order_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mlp_order_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mlp_order_log_id_seq OWNED BY public.mlp_order_log.id;


--
-- Name: physical_counts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.physical_counts (
    count_id text NOT NULL,
    product_id text NOT NULL,
    store_id text NOT NULL,
    count_date date NOT NULL,
    quantity_counted integer NOT NULL,
    calculated_quantity integer,
    variance integer,
    count_method text,
    photo_path text,
    notes text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_count_method CHECK ((count_method = ANY (ARRAY['manual'::text, 'photo_ai'::text, 'photo_manual'::text, 'system'::text])))
);


--
-- Name: product_dow_multipliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_dow_multipliers (
    id integer NOT NULL,
    sku character varying(30) NOT NULL,
    store_id character varying(20) DEFAULT '70012004'::character varying NOT NULL,
    day_of_week integer NOT NULL,
    multiplier real DEFAULT 1.0 NOT NULL,
    confidence character varying(20) DEFAULT 'medium'::character varying,
    source character varying(20) DEFAULT 'data'::character varying,
    updated_at timestamp without time zone DEFAULT now(),
    CONSTRAINT product_dow_multipliers_day_of_week_check CHECK (((day_of_week >= 0) AND (day_of_week <= 6)))
);


--
-- Name: product_dow_multipliers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.product_dow_multipliers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: product_dow_multipliers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.product_dow_multipliers_id_seq OWNED BY public.product_dow_multipliers.id;


--
-- Name: product_monthly_multipliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_monthly_multipliers (
    id integer NOT NULL,
    sku character varying(30) NOT NULL,
    store_id character varying(20) DEFAULT '70012004'::character varying NOT NULL,
    month integer NOT NULL,
    multiplier real DEFAULT 1.0 NOT NULL,
    confidence character varying(20) DEFAULT 'medium'::character varying,
    source character varying(20) DEFAULT 'data'::character varying,
    updated_at timestamp without time zone DEFAULT now(),
    CONSTRAINT product_monthly_multipliers_month_check CHECK (((month >= 1) AND (month <= 12)))
);


--
-- Name: product_monthly_multipliers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.product_monthly_multipliers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: product_monthly_multipliers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.product_monthly_multipliers_id_seq OWNED BY public.product_monthly_multipliers.id;


--
-- Name: product_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_tokens (
    token_id text NOT NULL,
    product_id text NOT NULL,
    product_name text,
    store_id text NOT NULL,
    arrival_date date NOT NULL,
    expiration_date date NOT NULL,
    status text DEFAULT 'in_stock'::text NOT NULL,
    status_date date NOT NULL,
    consumed_date date,
    batch_id text,
    notes text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_status CHECK ((status = ANY (ARRAY['in_stock'::text, 'sold'::text, 'expired'::text, 'returned'::text])))
);


--
-- Name: product_wom_multipliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_wom_multipliers (
    id integer NOT NULL,
    sku character varying(30) NOT NULL,
    store_id character varying(20) DEFAULT '70012004'::character varying NOT NULL,
    month integer NOT NULL,
    week integer NOT NULL,
    multiplier real DEFAULT 1.0 NOT NULL,
    source character varying(20) DEFAULT 'data'::character varying,
    updated_at timestamp without time zone DEFAULT now(),
    CONSTRAINT product_wom_multipliers_month_check CHECK (((month >= 1) AND (month <= 12))),
    CONSTRAINT product_wom_multipliers_week_check CHECK (((week >= 1) AND (week <= 4)))
);


--
-- Name: product_wom_multipliers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.product_wom_multipliers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: product_wom_multipliers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.product_wom_multipliers_id_seq OWNED BY public.product_wom_multipliers.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    product_id text NOT NULL,
    product_name text NOT NULL,
    category text,
    shelf_life_days integer DEFAULT 12,
    reorder_point integer,
    reorder_quantity integer,
    tray_factor integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    sku character varying(30),
    store_id character varying(20) DEFAULT '70012004'::character varying,
    delivery_days text DEFAULT 'mon,tue,thu,fri'::text,
    lead_time_days integer DEFAULT 3,
    return_days text DEFAULT 'tue,fri'::text,
    is_active boolean DEFAULT true,
    mlp_enabled boolean DEFAULT false
);


--
-- Name: returns_invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.returns_invoices (
    id integer NOT NULL,
    invoice_id character varying(50) NOT NULL,
    store_id character varying(20) DEFAULT '70012004'::character varying NOT NULL,
    invoice_date date NOT NULL,
    product_id character varying(20) NOT NULL,
    units_returned integer NOT NULL,
    reason text,
    processed_at timestamp without time zone DEFAULT now(),
    tokens_updated integer DEFAULT 0
);


--
-- Name: returns_invoices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.returns_invoices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: returns_invoices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.returns_invoices_id_seq OWNED BY public.returns_invoices.id;


--
-- Name: sales_predictions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sales_predictions (
    prediction_id text NOT NULL,
    product_id text NOT NULL,
    store_id text NOT NULL,
    historical_date date NOT NULL,
    predicted_date date NOT NULL,
    predicted_quantity integer NOT NULL,
    confidence real DEFAULT 1.0,
    actual_quantity integer,
    variance integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: seasonal_pattern; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.seasonal_pattern (
    id integer NOT NULL,
    sku character varying(30) NOT NULL,
    store_id character varying(20) DEFAULT '70012004'::character varying NOT NULL,
    month integer NOT NULL,
    day_of_week character varying(10) NOT NULL,
    base_avg numeric(4,1) NOT NULL,
    monthly_multiplier numeric(4,2) DEFAULT 1.00 NOT NULL,
    dow_multiplier numeric(4,2) DEFAULT 1.00 NOT NULL,
    expected_daily numeric(4,1) NOT NULL,
    confidence character varying(20) DEFAULT 'measured'::character varying NOT NULL,
    data_points integer DEFAULT 0 NOT NULL,
    notes text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    CONSTRAINT seasonal_pattern_day_of_week_check CHECK (((day_of_week)::text = ANY (ARRAY[('Mon'::character varying)::text, ('Tue'::character varying)::text, ('Wed'::character varying)::text, ('Thu'::character varying)::text, ('Fri'::character varying)::text, ('Sat'::character varying)::text, ('Sun'::character varying)::text]))),
    CONSTRAINT seasonal_pattern_month_check CHECK (((month >= 1) AND (month <= 12)))
);


--
-- Name: seasonal_pattern_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.seasonal_pattern_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: seasonal_pattern_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.seasonal_pattern_id_seq OWNED BY public.seasonal_pattern.id;


--
-- Name: stores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stores (
    store_id text NOT NULL,
    store_name text NOT NULL,
    store_type text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: token_returns_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.token_returns_log (
    id integer NOT NULL,
    product_id character varying(20) NOT NULL,
    store_id character varying(20) DEFAULT '70012004'::character varying NOT NULL,
    return_date date NOT NULL,
    units_returned integer NOT NULL,
    invoice_id character varying(50),
    batch_id character varying(50),
    arrival_date date,
    expiration_date date,
    days_on_shelf integer,
    reason text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: token_returns_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.token_returns_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: token_returns_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.token_returns_log_id_seq OWNED BY public.token_returns_log.id;


--
-- Name: token_sales_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.token_sales_log (
    id integer NOT NULL,
    product_id character varying(20) NOT NULL,
    store_id character varying(20) DEFAULT '70012004'::character varying NOT NULL,
    sale_date date NOT NULL,
    units_sold integer NOT NULL,
    batch_id character varying(50),
    arrival_date date,
    expiration_date date,
    days_on_shelf integer,
    source character varying(20) DEFAULT 'shelf_life'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: token_sales_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.token_sales_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: token_sales_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.token_sales_log_id_seq OWNED BY public.token_sales_log.id;


--
-- Name: daily_forecast id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_forecast ALTER COLUMN id SET DEFAULT nextval('public.daily_forecast_id_seq'::regclass);


--
-- Name: daily_sales_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_sales_log ALTER COLUMN id SET DEFAULT nextval('public.daily_sales_log_id_seq'::regclass);


--
-- Name: mlp_order_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mlp_order_log ALTER COLUMN id SET DEFAULT nextval('public.mlp_order_log_id_seq'::regclass);


--
-- Name: product_dow_multipliers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_dow_multipliers ALTER COLUMN id SET DEFAULT nextval('public.product_dow_multipliers_id_seq'::regclass);


--
-- Name: product_monthly_multipliers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_monthly_multipliers ALTER COLUMN id SET DEFAULT nextval('public.product_monthly_multipliers_id_seq'::regclass);


--
-- Name: product_wom_multipliers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_wom_multipliers ALTER COLUMN id SET DEFAULT nextval('public.product_wom_multipliers_id_seq'::regclass);


--
-- Name: returns_invoices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.returns_invoices ALTER COLUMN id SET DEFAULT nextval('public.returns_invoices_id_seq'::regclass);


--
-- Name: seasonal_pattern id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_pattern ALTER COLUMN id SET DEFAULT nextval('public.seasonal_pattern_id_seq'::regclass);


--
-- Name: token_returns_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_returns_log ALTER COLUMN id SET DEFAULT nextval('public.token_returns_log_id_seq'::regclass);


--
-- Name: token_sales_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_sales_log ALTER COLUMN id SET DEFAULT nextval('public.token_sales_log_id_seq'::regclass);


--
-- Data for Name: daily_forecast; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.daily_forecast (id, sku, store_id, forecast_date, day_of_week, month, expected_sales, monthly_multiplier, dow_multiplier, confidence, created_at) FROM stdin;
19346	500107	70012002	2025-01-01	Wed	1	21.7	1.46	0.88	high	2026-04-03 20:28:26.428645
19347	500107	70012002	2025-01-02	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
19348	500107	70012002	2025-01-03	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
19349	500107	70012002	2025-01-04	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
19350	500107	70012002	2025-01-05	Sun	1	25.9	1.46	1.05	high	2026-04-03 20:28:26.428645
19351	500107	70012002	2025-01-06	Mon	1	24.2	1.46	0.98	high	2026-04-03 20:28:26.428645
19352	500107	70012002	2025-01-07	Tue	1	27.9	1.46	1.13	high	2026-04-03 20:28:26.428645
19353	500107	70012002	2025-01-08	Wed	1	21.7	1.46	0.88	high	2026-04-03 20:28:26.428645
19354	500107	70012002	2025-01-09	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
19355	500107	70012002	2025-01-10	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
19356	500107	70012002	2025-01-11	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
19357	500107	70012002	2025-01-12	Sun	1	25.9	1.46	1.05	high	2026-04-03 20:28:26.428645
19358	500107	70012002	2025-01-13	Mon	1	24.2	1.46	0.98	high	2026-04-03 20:28:26.428645
19359	500107	70012002	2025-01-14	Tue	1	27.9	1.46	1.13	high	2026-04-03 20:28:26.428645
19360	500107	70012002	2025-01-15	Wed	1	21.7	1.46	0.88	high	2026-04-03 20:28:26.428645
19361	500107	70012002	2025-01-16	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
19362	500107	70012002	2025-01-17	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
19363	500107	70012002	2025-01-18	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
19364	500107	70012002	2025-01-19	Sun	1	25.9	1.46	1.05	high	2026-04-03 20:28:26.428645
19365	500107	70012002	2025-01-20	Mon	1	24.2	1.46	0.98	high	2026-04-03 20:28:26.428645
19366	500107	70012002	2025-01-21	Tue	1	27.9	1.46	1.13	high	2026-04-03 20:28:26.428645
19367	500107	70012002	2025-01-22	Wed	1	21.7	1.46	0.88	high	2026-04-03 20:28:26.428645
19368	500107	70012002	2025-01-23	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
19369	500107	70012002	2025-01-24	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
19370	500107	70012002	2025-01-25	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
19371	500107	70012002	2025-01-26	Sun	1	25.9	1.46	1.05	high	2026-04-03 20:28:26.428645
19372	500107	70012002	2025-01-27	Mon	1	24.2	1.46	0.98	high	2026-04-03 20:28:26.428645
19373	500107	70012002	2025-01-28	Tue	1	27.9	1.46	1.13	high	2026-04-03 20:28:26.428645
19374	500107	70012002	2025-01-29	Wed	1	21.7	1.46	0.88	high	2026-04-03 20:28:26.428645
19375	500107	70012002	2025-01-30	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
19376	500107	70012002	2025-01-31	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
19377	500107	70012002	2025-02-01	Sat	2	16.5	1.01	0.97	high	2026-04-03 20:28:26.428645
19378	500107	70012002	2025-02-02	Sun	2	17.9	1.01	1.05	high	2026-04-03 20:28:26.428645
19379	500107	70012002	2025-02-03	Mon	2	16.7	1.01	0.98	high	2026-04-03 20:28:26.428645
19380	500107	70012002	2025-02-04	Tue	2	19.3	1.01	1.13	high	2026-04-03 20:28:26.428645
19381	500107	70012002	2025-02-05	Wed	2	15.0	1.01	0.88	high	2026-04-03 20:28:26.428645
19382	500107	70012002	2025-02-06	Thu	2	15.7	1.01	0.92	high	2026-04-03 20:28:26.428645
19383	500107	70012002	2025-02-07	Fri	2	18.1	1.01	1.06	high	2026-04-03 20:28:26.428645
19384	500107	70012002	2025-02-08	Sat	2	16.5	1.01	0.97	high	2026-04-03 20:28:26.428645
19385	500107	70012002	2025-02-09	Sun	2	17.9	1.01	1.05	high	2026-04-03 20:28:26.428645
19386	500107	70012002	2025-02-10	Mon	2	16.7	1.01	0.98	high	2026-04-03 20:28:26.428645
19387	500107	70012002	2025-02-11	Tue	2	19.3	1.01	1.13	high	2026-04-03 20:28:26.428645
19388	500107	70012002	2025-02-12	Wed	2	15.0	1.01	0.88	high	2026-04-03 20:28:26.428645
19389	500107	70012002	2025-02-13	Thu	2	15.7	1.01	0.92	high	2026-04-03 20:28:26.428645
19390	500107	70012002	2025-02-14	Fri	2	18.1	1.01	1.06	high	2026-04-03 20:28:26.428645
19391	500107	70012002	2025-02-15	Sat	2	16.5	1.01	0.97	high	2026-04-03 20:28:26.428645
19392	500107	70012002	2025-02-16	Sun	2	17.9	1.01	1.05	high	2026-04-03 20:28:26.428645
19393	500107	70012002	2025-02-17	Mon	2	16.7	1.01	0.98	high	2026-04-03 20:28:26.428645
19394	500107	70012002	2025-02-18	Tue	2	19.3	1.01	1.13	high	2026-04-03 20:28:26.428645
19395	500107	70012002	2025-02-19	Wed	2	15.0	1.01	0.88	high	2026-04-03 20:28:26.428645
19396	500107	70012002	2025-02-20	Thu	2	15.7	1.01	0.92	high	2026-04-03 20:28:26.428645
19397	500107	70012002	2025-02-21	Fri	2	18.1	1.01	1.06	high	2026-04-03 20:28:26.428645
19398	500107	70012002	2025-02-22	Sat	2	16.5	1.01	0.97	high	2026-04-03 20:28:26.428645
19399	500107	70012002	2025-02-23	Sun	2	17.9	1.01	1.05	high	2026-04-03 20:28:26.428645
19400	500107	70012002	2025-02-24	Mon	2	16.7	1.01	0.98	high	2026-04-03 20:28:26.428645
19401	500107	70012002	2025-02-25	Tue	2	19.3	1.01	1.13	high	2026-04-03 20:28:26.428645
19402	500107	70012002	2025-02-26	Wed	2	15.0	1.01	0.88	high	2026-04-03 20:28:26.428645
19403	500107	70012002	2025-02-27	Thu	2	15.7	1.01	0.92	high	2026-04-03 20:28:26.428645
19404	500107	70012002	2025-02-28	Fri	2	18.1	1.01	1.06	high	2026-04-03 20:28:26.428645
19405	500107	70012002	2025-03-01	Sat	3	11.8	0.72	0.97	high	2026-04-03 20:28:26.428645
19406	500107	70012002	2025-03-02	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
19407	500107	70012002	2025-03-03	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
19408	500107	70012002	2025-03-04	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
19409	500107	70012002	2025-03-05	Wed	3	10.7	0.72	0.88	high	2026-04-03 20:28:26.428645
19410	500107	70012002	2025-03-06	Thu	3	11.2	0.72	0.92	high	2026-04-03 20:28:26.428645
19411	500107	70012002	2025-03-07	Fri	3	12.9	0.72	1.06	high	2026-04-03 20:28:26.428645
19412	500107	70012002	2025-03-08	Sat	3	11.8	0.72	0.97	high	2026-04-03 20:28:26.428645
19413	500107	70012002	2025-03-09	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
19414	500107	70012002	2025-03-10	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
19415	500107	70012002	2025-03-11	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
19416	500107	70012002	2025-03-12	Wed	3	10.7	0.72	0.88	high	2026-04-03 20:28:26.428645
19417	500107	70012002	2025-03-13	Thu	3	11.2	0.72	0.92	high	2026-04-03 20:28:26.428645
19418	500107	70012002	2025-03-14	Fri	3	12.9	0.72	1.06	high	2026-04-03 20:28:26.428645
19419	500107	70012002	2025-03-15	Sat	3	11.8	0.72	0.97	high	2026-04-03 20:28:26.428645
19420	500107	70012002	2025-03-16	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
19421	500107	70012002	2025-03-17	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
19422	500107	70012002	2025-03-18	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
19423	500107	70012002	2025-03-19	Wed	3	10.7	0.72	0.88	high	2026-04-03 20:28:26.428645
19424	500107	70012002	2025-03-20	Thu	3	11.2	0.72	0.92	high	2026-04-03 20:28:26.428645
19425	500107	70012002	2025-03-21	Fri	3	12.9	0.72	1.06	high	2026-04-03 20:28:26.428645
19426	500107	70012002	2025-03-22	Sat	3	11.8	0.72	0.97	high	2026-04-03 20:28:26.428645
19427	500107	70012002	2025-03-23	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
19428	500107	70012002	2025-03-24	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
19429	500107	70012002	2025-03-25	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
19430	500107	70012002	2025-03-26	Wed	3	10.7	0.72	0.88	high	2026-04-03 20:28:26.428645
19431	500107	70012002	2025-03-27	Thu	3	11.2	0.72	0.92	high	2026-04-03 20:28:26.428645
19432	500107	70012002	2025-03-28	Fri	3	12.9	0.72	1.06	high	2026-04-03 20:28:26.428645
19433	500107	70012002	2025-03-29	Sat	3	11.8	0.72	0.97	high	2026-04-03 20:28:26.428645
19434	500107	70012002	2025-03-30	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
19435	500107	70012002	2025-03-31	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
19436	500107	70012002	2025-04-01	Tue	4	17.6	0.92	1.13	medium	2026-04-03 20:28:26.428645
19437	500107	70012002	2025-04-02	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
19438	500107	70012002	2025-04-03	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
19439	500107	70012002	2025-04-04	Fri	4	16.5	0.92	1.06	medium	2026-04-03 20:28:26.428645
19440	500107	70012002	2025-04-05	Sat	4	15.1	0.92	0.97	medium	2026-04-03 20:28:26.428645
19441	500107	70012002	2025-04-06	Sun	4	16.3	0.92	1.05	medium	2026-04-03 20:28:26.428645
19442	500107	70012002	2025-04-07	Mon	4	15.2	0.92	0.98	medium	2026-04-03 20:28:26.428645
19443	500107	70012002	2025-04-08	Tue	4	17.6	0.92	1.13	medium	2026-04-03 20:28:26.428645
19444	500107	70012002	2025-04-09	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
19445	500107	70012002	2025-04-10	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
19446	500107	70012002	2025-04-11	Fri	4	16.5	0.92	1.06	medium	2026-04-03 20:28:26.428645
19447	500107	70012002	2025-04-12	Sat	4	15.1	0.92	0.97	medium	2026-04-03 20:28:26.428645
19448	500107	70012002	2025-04-13	Sun	4	16.3	0.92	1.05	medium	2026-04-03 20:28:26.428645
19449	500107	70012002	2025-04-14	Mon	4	15.2	0.92	0.98	medium	2026-04-03 20:28:26.428645
19450	500107	70012002	2025-04-15	Tue	4	17.6	0.92	1.13	medium	2026-04-03 20:28:26.428645
19451	500107	70012002	2025-04-16	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
19452	500107	70012002	2025-04-17	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
19453	500107	70012002	2025-04-18	Fri	4	16.5	0.92	1.06	medium	2026-04-03 20:28:26.428645
19454	500107	70012002	2025-04-19	Sat	4	15.1	0.92	0.97	medium	2026-04-03 20:28:26.428645
19455	500107	70012002	2025-04-20	Sun	4	16.3	0.92	1.05	medium	2026-04-03 20:28:26.428645
19456	500107	70012002	2025-04-21	Mon	4	15.2	0.92	0.98	medium	2026-04-03 20:28:26.428645
19457	500107	70012002	2025-04-22	Tue	4	17.6	0.92	1.13	medium	2026-04-03 20:28:26.428645
19458	500107	70012002	2025-04-23	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
19459	500107	70012002	2025-04-24	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
19460	500107	70012002	2025-04-25	Fri	4	16.5	0.92	1.06	medium	2026-04-03 20:28:26.428645
19461	500107	70012002	2025-04-26	Sat	4	15.1	0.92	0.97	medium	2026-04-03 20:28:26.428645
19462	500107	70012002	2025-04-27	Sun	4	16.3	0.92	1.05	medium	2026-04-03 20:28:26.428645
19463	500107	70012002	2025-04-28	Mon	4	15.2	0.92	0.98	medium	2026-04-03 20:28:26.428645
19464	500107	70012002	2025-04-29	Tue	4	17.6	0.92	1.13	medium	2026-04-03 20:28:26.428645
19465	500107	70012002	2025-04-30	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
19466	500107	70012002	2025-05-01	Thu	5	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
19467	500107	70012002	2025-05-02	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19468	500107	70012002	2025-05-03	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19469	500107	70012002	2025-05-04	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19470	500107	70012002	2025-05-05	Mon	5	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
19471	500107	70012002	2025-05-06	Tue	5	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
19472	500107	70012002	2025-05-07	Wed	5	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
19473	500107	70012002	2025-05-08	Thu	5	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
19474	500107	70012002	2025-05-09	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19475	500107	70012002	2025-05-10	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19476	500107	70012002	2025-05-11	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19477	500107	70012002	2025-05-12	Mon	5	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
19478	500107	70012002	2025-05-13	Tue	5	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
19479	500107	70012002	2025-05-14	Wed	5	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
19480	500107	70012002	2025-05-15	Thu	5	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
19481	500107	70012002	2025-05-16	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19482	500107	70012002	2025-05-17	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19483	500107	70012002	2025-05-18	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19484	500107	70012002	2025-05-19	Mon	5	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
19485	500107	70012002	2025-05-20	Tue	5	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
19486	500107	70012002	2025-05-21	Wed	5	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
19487	500107	70012002	2025-05-22	Thu	5	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
19488	500107	70012002	2025-05-23	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19489	500107	70012002	2025-05-24	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19490	500107	70012002	2025-05-25	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19491	500107	70012002	2025-05-26	Mon	5	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
19492	500107	70012002	2025-05-27	Tue	5	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
19493	500107	70012002	2025-05-28	Wed	5	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
19494	500107	70012002	2025-05-29	Thu	5	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
19495	500107	70012002	2025-05-30	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19496	500107	70012002	2025-05-31	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19497	500107	70012002	2025-06-01	Sun	6	14.0	0.79	1.05	estimated	2026-04-03 20:28:26.428645
19498	500107	70012002	2025-06-02	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
19499	500107	70012002	2025-06-03	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
19500	500107	70012002	2025-06-04	Wed	6	11.7	0.79	0.88	estimated	2026-04-03 20:28:26.428645
19501	500107	70012002	2025-06-05	Thu	6	12.3	0.79	0.92	estimated	2026-04-03 20:28:26.428645
19502	500107	70012002	2025-06-06	Fri	6	14.1	0.79	1.06	estimated	2026-04-03 20:28:26.428645
19503	500107	70012002	2025-06-07	Sat	6	12.9	0.79	0.97	estimated	2026-04-03 20:28:26.428645
19504	500107	70012002	2025-06-08	Sun	6	14.0	0.79	1.05	estimated	2026-04-03 20:28:26.428645
19505	500107	70012002	2025-06-09	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
19506	500107	70012002	2025-06-10	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
19507	500107	70012002	2025-06-11	Wed	6	11.7	0.79	0.88	estimated	2026-04-03 20:28:26.428645
19508	500107	70012002	2025-06-12	Thu	6	12.3	0.79	0.92	estimated	2026-04-03 20:28:26.428645
19509	500107	70012002	2025-06-13	Fri	6	14.1	0.79	1.06	estimated	2026-04-03 20:28:26.428645
19510	500107	70012002	2025-06-14	Sat	6	12.9	0.79	0.97	estimated	2026-04-03 20:28:26.428645
19511	500107	70012002	2025-06-15	Sun	6	14.0	0.79	1.05	estimated	2026-04-03 20:28:26.428645
19512	500107	70012002	2025-06-16	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
19513	500107	70012002	2025-06-17	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
19514	500107	70012002	2025-06-18	Wed	6	11.7	0.79	0.88	estimated	2026-04-03 20:28:26.428645
19515	500107	70012002	2025-06-19	Thu	6	12.3	0.79	0.92	estimated	2026-04-03 20:28:26.428645
19516	500107	70012002	2025-06-20	Fri	6	14.1	0.79	1.06	estimated	2026-04-03 20:28:26.428645
19517	500107	70012002	2025-06-21	Sat	6	12.9	0.79	0.97	estimated	2026-04-03 20:28:26.428645
19518	500107	70012002	2025-06-22	Sun	6	14.0	0.79	1.05	estimated	2026-04-03 20:28:26.428645
19519	500107	70012002	2025-06-23	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
19520	500107	70012002	2025-06-24	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
19521	500107	70012002	2025-06-25	Wed	6	11.7	0.79	0.88	estimated	2026-04-03 20:28:26.428645
19522	500107	70012002	2025-06-26	Thu	6	12.3	0.79	0.92	estimated	2026-04-03 20:28:26.428645
19523	500107	70012002	2025-06-27	Fri	6	14.1	0.79	1.06	estimated	2026-04-03 20:28:26.428645
19524	500107	70012002	2025-06-28	Sat	6	12.9	0.79	0.97	estimated	2026-04-03 20:28:26.428645
19525	500107	70012002	2025-06-29	Sun	6	14.0	0.79	1.05	estimated	2026-04-03 20:28:26.428645
19526	500107	70012002	2025-06-30	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
19527	500107	70012002	2025-07-01	Tue	7	18.7	0.98	1.13	estimated	2026-04-03 20:28:26.428645
19528	500107	70012002	2025-07-02	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
19529	500107	70012002	2025-07-03	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
19530	500107	70012002	2025-07-04	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
19531	500107	70012002	2025-07-05	Sat	7	16.1	0.98	0.97	estimated	2026-04-03 20:28:26.428645
19532	500107	70012002	2025-07-06	Sun	7	17.4	0.98	1.05	estimated	2026-04-03 20:28:26.428645
19533	500107	70012002	2025-07-07	Mon	7	16.2	0.98	0.98	estimated	2026-04-03 20:28:26.428645
19534	500107	70012002	2025-07-08	Tue	7	18.7	0.98	1.13	estimated	2026-04-03 20:28:26.428645
19535	500107	70012002	2025-07-09	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
19536	500107	70012002	2025-07-10	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
19537	500107	70012002	2025-07-11	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
19538	500107	70012002	2025-07-12	Sat	7	16.1	0.98	0.97	estimated	2026-04-03 20:28:26.428645
19539	500107	70012002	2025-07-13	Sun	7	17.4	0.98	1.05	estimated	2026-04-03 20:28:26.428645
19540	500107	70012002	2025-07-14	Mon	7	16.2	0.98	0.98	estimated	2026-04-03 20:28:26.428645
19541	500107	70012002	2025-07-15	Tue	7	18.7	0.98	1.13	estimated	2026-04-03 20:28:26.428645
19542	500107	70012002	2025-07-16	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
19543	500107	70012002	2025-07-17	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
19544	500107	70012002	2025-07-18	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
19545	500107	70012002	2025-07-19	Sat	7	16.1	0.98	0.97	estimated	2026-04-03 20:28:26.428645
19546	500107	70012002	2025-07-20	Sun	7	17.4	0.98	1.05	estimated	2026-04-03 20:28:26.428645
19547	500107	70012002	2025-07-21	Mon	7	16.2	0.98	0.98	estimated	2026-04-03 20:28:26.428645
19548	500107	70012002	2025-07-22	Tue	7	18.7	0.98	1.13	estimated	2026-04-03 20:28:26.428645
19549	500107	70012002	2025-07-23	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
19550	500107	70012002	2025-07-24	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
19551	500107	70012002	2025-07-25	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
19552	500107	70012002	2025-07-26	Sat	7	16.1	0.98	0.97	estimated	2026-04-03 20:28:26.428645
19553	500107	70012002	2025-07-27	Sun	7	17.4	0.98	1.05	estimated	2026-04-03 20:28:26.428645
19554	500107	70012002	2025-07-28	Mon	7	16.2	0.98	0.98	estimated	2026-04-03 20:28:26.428645
19555	500107	70012002	2025-07-29	Tue	7	18.7	0.98	1.13	estimated	2026-04-03 20:28:26.428645
19556	500107	70012002	2025-07-30	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
19557	500107	70012002	2025-07-31	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
19558	500107	70012002	2025-08-01	Fri	8	18.1	1.01	1.06	estimated	2026-04-03 20:28:26.428645
19559	500107	70012002	2025-08-02	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
19560	500107	70012002	2025-08-03	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
19561	500107	70012002	2025-08-04	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
19562	500107	70012002	2025-08-05	Tue	8	19.3	1.01	1.13	estimated	2026-04-03 20:28:26.428645
19563	500107	70012002	2025-08-06	Wed	8	15.0	1.01	0.88	estimated	2026-04-03 20:28:26.428645
19564	500107	70012002	2025-08-07	Thu	8	15.7	1.01	0.92	estimated	2026-04-03 20:28:26.428645
19565	500107	70012002	2025-08-08	Fri	8	18.1	1.01	1.06	estimated	2026-04-03 20:28:26.428645
19566	500107	70012002	2025-08-09	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
19567	500107	70012002	2025-08-10	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
19568	500107	70012002	2025-08-11	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
19569	500107	70012002	2025-08-12	Tue	8	19.3	1.01	1.13	estimated	2026-04-03 20:28:26.428645
19570	500107	70012002	2025-08-13	Wed	8	15.0	1.01	0.88	estimated	2026-04-03 20:28:26.428645
19571	500107	70012002	2025-08-14	Thu	8	15.7	1.01	0.92	estimated	2026-04-03 20:28:26.428645
19572	500107	70012002	2025-08-15	Fri	8	18.1	1.01	1.06	estimated	2026-04-03 20:28:26.428645
19573	500107	70012002	2025-08-16	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
19574	500107	70012002	2025-08-17	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
19575	500107	70012002	2025-08-18	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
19576	500107	70012002	2025-08-19	Tue	8	19.3	1.01	1.13	estimated	2026-04-03 20:28:26.428645
19577	500107	70012002	2025-08-20	Wed	8	15.0	1.01	0.88	estimated	2026-04-03 20:28:26.428645
19578	500107	70012002	2025-08-21	Thu	8	15.7	1.01	0.92	estimated	2026-04-03 20:28:26.428645
19579	500107	70012002	2025-08-22	Fri	8	18.1	1.01	1.06	estimated	2026-04-03 20:28:26.428645
19580	500107	70012002	2025-08-23	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
19581	500107	70012002	2025-08-24	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
19582	500107	70012002	2025-08-25	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
19583	500107	70012002	2025-08-26	Tue	8	19.3	1.01	1.13	estimated	2026-04-03 20:28:26.428645
19584	500107	70012002	2025-08-27	Wed	8	15.0	1.01	0.88	estimated	2026-04-03 20:28:26.428645
19585	500107	70012002	2025-08-28	Thu	8	15.7	1.01	0.92	estimated	2026-04-03 20:28:26.428645
19586	500107	70012002	2025-08-29	Fri	8	18.1	1.01	1.06	estimated	2026-04-03 20:28:26.428645
19587	500107	70012002	2025-08-30	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
19588	500107	70012002	2025-08-31	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
19589	500107	70012002	2025-09-01	Mon	9	18.2	1.10	0.98	estimated	2026-04-03 20:28:26.428645
19590	500107	70012002	2025-09-02	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
19591	500107	70012002	2025-09-03	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
19592	500107	70012002	2025-09-04	Thu	9	17.1	1.10	0.92	estimated	2026-04-03 20:28:26.428645
19593	500107	70012002	2025-09-05	Fri	9	19.7	1.10	1.06	estimated	2026-04-03 20:28:26.428645
19594	500107	70012002	2025-09-06	Sat	9	18.0	1.10	0.97	estimated	2026-04-03 20:28:26.428645
19595	500107	70012002	2025-09-07	Sun	9	19.5	1.10	1.05	estimated	2026-04-03 20:28:26.428645
19596	500107	70012002	2025-09-08	Mon	9	18.2	1.10	0.98	estimated	2026-04-03 20:28:26.428645
19597	500107	70012002	2025-09-09	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
19598	500107	70012002	2025-09-10	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
19599	500107	70012002	2025-09-11	Thu	9	17.1	1.10	0.92	estimated	2026-04-03 20:28:26.428645
19600	500107	70012002	2025-09-12	Fri	9	19.7	1.10	1.06	estimated	2026-04-03 20:28:26.428645
19601	500107	70012002	2025-09-13	Sat	9	18.0	1.10	0.97	estimated	2026-04-03 20:28:26.428645
19602	500107	70012002	2025-09-14	Sun	9	19.5	1.10	1.05	estimated	2026-04-03 20:28:26.428645
19603	500107	70012002	2025-09-15	Mon	9	18.2	1.10	0.98	estimated	2026-04-03 20:28:26.428645
19604	500107	70012002	2025-09-16	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
19605	500107	70012002	2025-09-17	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
19606	500107	70012002	2025-09-18	Thu	9	17.1	1.10	0.92	estimated	2026-04-03 20:28:26.428645
19607	500107	70012002	2025-09-19	Fri	9	19.7	1.10	1.06	estimated	2026-04-03 20:28:26.428645
19608	500107	70012002	2025-09-20	Sat	9	18.0	1.10	0.97	estimated	2026-04-03 20:28:26.428645
19609	500107	70012002	2025-09-21	Sun	9	19.5	1.10	1.05	estimated	2026-04-03 20:28:26.428645
19610	500107	70012002	2025-09-22	Mon	9	18.2	1.10	0.98	estimated	2026-04-03 20:28:26.428645
19611	500107	70012002	2025-09-23	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
19612	500107	70012002	2025-09-24	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
19613	500107	70012002	2025-09-25	Thu	9	17.1	1.10	0.92	estimated	2026-04-03 20:28:26.428645
19614	500107	70012002	2025-09-26	Fri	9	19.7	1.10	1.06	estimated	2026-04-03 20:28:26.428645
19615	500107	70012002	2025-09-27	Sat	9	18.0	1.10	0.97	estimated	2026-04-03 20:28:26.428645
19616	500107	70012002	2025-09-28	Sun	9	19.5	1.10	1.05	estimated	2026-04-03 20:28:26.428645
19617	500107	70012002	2025-09-29	Mon	9	18.2	1.10	0.98	estimated	2026-04-03 20:28:26.428645
19618	500107	70012002	2025-09-30	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
19619	500107	70012002	2025-10-01	Wed	10	14.1	0.95	0.88	estimated	2026-04-03 20:28:26.428645
19620	500107	70012002	2025-10-02	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
19621	500107	70012002	2025-10-03	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
19622	500107	70012002	2025-10-04	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
19623	500107	70012002	2025-10-05	Sun	10	16.8	0.95	1.05	estimated	2026-04-03 20:28:26.428645
19624	500107	70012002	2025-10-06	Mon	10	15.7	0.95	0.98	estimated	2026-04-03 20:28:26.428645
19625	500107	70012002	2025-10-07	Tue	10	18.1	0.95	1.13	estimated	2026-04-03 20:28:26.428645
19626	500107	70012002	2025-10-08	Wed	10	14.1	0.95	0.88	estimated	2026-04-03 20:28:26.428645
19627	500107	70012002	2025-10-09	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
19628	500107	70012002	2025-10-10	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
19629	500107	70012002	2025-10-11	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
19630	500107	70012002	2025-10-12	Sun	10	16.8	0.95	1.05	estimated	2026-04-03 20:28:26.428645
19631	500107	70012002	2025-10-13	Mon	10	15.7	0.95	0.98	estimated	2026-04-03 20:28:26.428645
19632	500107	70012002	2025-10-14	Tue	10	18.1	0.95	1.13	estimated	2026-04-03 20:28:26.428645
19633	500107	70012002	2025-10-15	Wed	10	14.1	0.95	0.88	estimated	2026-04-03 20:28:26.428645
19634	500107	70012002	2025-10-16	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
19635	500107	70012002	2025-10-17	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
19636	500107	70012002	2025-10-18	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
19637	500107	70012002	2025-10-19	Sun	10	16.8	0.95	1.05	estimated	2026-04-03 20:28:26.428645
19638	500107	70012002	2025-10-20	Mon	10	15.7	0.95	0.98	estimated	2026-04-03 20:28:26.428645
19639	500107	70012002	2025-10-21	Tue	10	18.1	0.95	1.13	estimated	2026-04-03 20:28:26.428645
19640	500107	70012002	2025-10-22	Wed	10	14.1	0.95	0.88	estimated	2026-04-03 20:28:26.428645
19641	500107	70012002	2025-10-23	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
19642	500107	70012002	2025-10-24	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
19643	500107	70012002	2025-10-25	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
19644	500107	70012002	2025-10-26	Sun	10	16.8	0.95	1.05	estimated	2026-04-03 20:28:26.428645
19645	500107	70012002	2025-10-27	Mon	10	15.7	0.95	0.98	estimated	2026-04-03 20:28:26.428645
19646	500107	70012002	2025-10-28	Tue	10	18.1	0.95	1.13	estimated	2026-04-03 20:28:26.428645
19647	500107	70012002	2025-10-29	Wed	10	14.1	0.95	0.88	estimated	2026-04-03 20:28:26.428645
19648	500107	70012002	2025-10-30	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
19649	500107	70012002	2025-10-31	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
19650	500107	70012002	2025-11-01	Sat	11	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19651	500107	70012002	2025-11-02	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19652	500107	70012002	2025-11-03	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
19653	500107	70012002	2025-11-04	Tue	11	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
19654	500107	70012002	2025-11-05	Wed	11	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
19655	500107	70012002	2025-11-06	Thu	11	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
19656	500107	70012002	2025-11-07	Fri	11	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19657	500107	70012002	2025-11-08	Sat	11	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19658	500107	70012002	2025-11-09	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19659	500107	70012002	2025-11-10	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
19660	500107	70012002	2025-11-11	Tue	11	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
19661	500107	70012002	2025-11-12	Wed	11	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
19662	500107	70012002	2025-11-13	Thu	11	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
19663	500107	70012002	2025-11-14	Fri	11	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19664	500107	70012002	2025-11-15	Sat	11	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19665	500107	70012002	2025-11-16	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19666	500107	70012002	2025-11-17	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
19667	500107	70012002	2025-11-18	Tue	11	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
19668	500107	70012002	2025-11-19	Wed	11	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
19669	500107	70012002	2025-11-20	Thu	11	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
19670	500107	70012002	2025-11-21	Fri	11	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19671	500107	70012002	2025-11-22	Sat	11	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19672	500107	70012002	2025-11-23	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19673	500107	70012002	2025-11-24	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
19674	500107	70012002	2025-11-25	Tue	11	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
19675	500107	70012002	2025-11-26	Wed	11	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
19676	500107	70012002	2025-11-27	Thu	11	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
19677	500107	70012002	2025-11-28	Fri	11	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19678	500107	70012002	2025-11-29	Sat	11	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19679	500107	70012002	2025-11-30	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19680	500107	70012002	2025-12-01	Mon	12	14.7	0.89	0.98	estimated	2026-04-03 20:28:26.428645
19681	500107	70012002	2025-12-02	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
19682	500107	70012002	2025-12-03	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
19683	500107	70012002	2025-12-04	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
19684	500107	70012002	2025-12-05	Fri	12	15.9	0.89	1.06	estimated	2026-04-03 20:28:26.428645
19685	500107	70012002	2025-12-06	Sat	12	14.6	0.89	0.97	estimated	2026-04-03 20:28:26.428645
19686	500107	70012002	2025-12-07	Sun	12	15.8	0.89	1.05	estimated	2026-04-03 20:28:26.428645
19687	500107	70012002	2025-12-08	Mon	12	14.7	0.89	0.98	estimated	2026-04-03 20:28:26.428645
19688	500107	70012002	2025-12-09	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
19689	500107	70012002	2025-12-10	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
19690	500107	70012002	2025-12-11	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
19691	500107	70012002	2025-12-12	Fri	12	15.9	0.89	1.06	estimated	2026-04-03 20:28:26.428645
19692	500107	70012002	2025-12-13	Sat	12	14.6	0.89	0.97	estimated	2026-04-03 20:28:26.428645
19693	500107	70012002	2025-12-14	Sun	12	15.8	0.89	1.05	estimated	2026-04-03 20:28:26.428645
19694	500107	70012002	2025-12-15	Mon	12	14.7	0.89	0.98	estimated	2026-04-03 20:28:26.428645
19695	500107	70012002	2025-12-16	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
19696	500107	70012002	2025-12-17	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
19697	500107	70012002	2025-12-18	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
19698	500107	70012002	2025-12-19	Fri	12	15.9	0.89	1.06	estimated	2026-04-03 20:28:26.428645
19699	500107	70012002	2025-12-20	Sat	12	14.6	0.89	0.97	estimated	2026-04-03 20:28:26.428645
19700	500107	70012002	2025-12-21	Sun	12	15.8	0.89	1.05	estimated	2026-04-03 20:28:26.428645
19701	500107	70012002	2025-12-22	Mon	12	14.7	0.89	0.98	estimated	2026-04-03 20:28:26.428645
19702	500107	70012002	2025-12-23	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
19703	500107	70012002	2025-12-24	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
19704	500107	70012002	2025-12-25	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
19705	500107	70012002	2025-12-26	Fri	12	15.9	0.89	1.06	estimated	2026-04-03 20:28:26.428645
19706	500107	70012002	2025-12-27	Sat	12	14.6	0.89	0.97	estimated	2026-04-03 20:28:26.428645
19707	500107	70012002	2025-12-28	Sun	12	15.8	0.89	1.05	estimated	2026-04-03 20:28:26.428645
19708	500107	70012002	2025-12-29	Mon	12	14.7	0.89	0.98	estimated	2026-04-03 20:28:26.428645
19709	500107	70012002	2025-12-30	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
19710	500107	70012002	2025-12-31	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
19711	500107	70012002	2026-01-01	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
19712	500107	70012002	2026-01-02	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
19713	500107	70012002	2026-01-03	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
19714	500107	70012002	2026-01-04	Sun	1	25.9	1.46	1.05	high	2026-04-03 20:28:26.428645
19715	500107	70012002	2026-01-05	Mon	1	24.2	1.46	0.98	high	2026-04-03 20:28:26.428645
19716	500107	70012002	2026-01-06	Tue	1	27.9	1.46	1.13	high	2026-04-03 20:28:26.428645
19717	500107	70012002	2026-01-07	Wed	1	21.7	1.46	0.88	high	2026-04-03 20:28:26.428645
19718	500107	70012002	2026-01-08	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
19719	500107	70012002	2026-01-09	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
19720	500107	70012002	2026-01-10	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
19721	500107	70012002	2026-01-11	Sun	1	25.9	1.46	1.05	high	2026-04-03 20:28:26.428645
19722	500107	70012002	2026-01-12	Mon	1	24.2	1.46	0.98	high	2026-04-03 20:28:26.428645
19723	500107	70012002	2026-01-13	Tue	1	27.9	1.46	1.13	high	2026-04-03 20:28:26.428645
19724	500107	70012002	2026-01-14	Wed	1	21.7	1.46	0.88	high	2026-04-03 20:28:26.428645
19725	500107	70012002	2026-01-15	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
19726	500107	70012002	2026-01-16	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
19727	500107	70012002	2026-01-17	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
19728	500107	70012002	2026-01-18	Sun	1	25.9	1.46	1.05	high	2026-04-03 20:28:26.428645
19729	500107	70012002	2026-01-19	Mon	1	24.2	1.46	0.98	high	2026-04-03 20:28:26.428645
19730	500107	70012002	2026-01-20	Tue	1	27.9	1.46	1.13	high	2026-04-03 20:28:26.428645
19731	500107	70012002	2026-01-21	Wed	1	21.7	1.46	0.88	high	2026-04-03 20:28:26.428645
19732	500107	70012002	2026-01-22	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
19733	500107	70012002	2026-01-23	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
19734	500107	70012002	2026-01-24	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
19735	500107	70012002	2026-01-25	Sun	1	25.9	1.46	1.05	high	2026-04-03 20:28:26.428645
19736	500107	70012002	2026-01-26	Mon	1	24.2	1.46	0.98	high	2026-04-03 20:28:26.428645
19737	500107	70012002	2026-01-27	Tue	1	27.9	1.46	1.13	high	2026-04-03 20:28:26.428645
19738	500107	70012002	2026-01-28	Wed	1	21.7	1.46	0.88	high	2026-04-03 20:28:26.428645
19739	500107	70012002	2026-01-29	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
19740	500107	70012002	2026-01-30	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
19741	500107	70012002	2026-01-31	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
19742	500107	70012002	2026-02-01	Sun	2	17.9	1.01	1.05	high	2026-04-03 20:28:26.428645
19743	500107	70012002	2026-02-02	Mon	2	16.7	1.01	0.98	high	2026-04-03 20:28:26.428645
19744	500107	70012002	2026-02-03	Tue	2	19.3	1.01	1.13	high	2026-04-03 20:28:26.428645
19745	500107	70012002	2026-02-04	Wed	2	15.0	1.01	0.88	high	2026-04-03 20:28:26.428645
19746	500107	70012002	2026-02-05	Thu	2	15.7	1.01	0.92	high	2026-04-03 20:28:26.428645
19747	500107	70012002	2026-02-06	Fri	2	18.1	1.01	1.06	high	2026-04-03 20:28:26.428645
19748	500107	70012002	2026-02-07	Sat	2	16.5	1.01	0.97	high	2026-04-03 20:28:26.428645
19749	500107	70012002	2026-02-08	Sun	2	17.9	1.01	1.05	high	2026-04-03 20:28:26.428645
19750	500107	70012002	2026-02-09	Mon	2	16.7	1.01	0.98	high	2026-04-03 20:28:26.428645
19751	500107	70012002	2026-02-10	Tue	2	19.3	1.01	1.13	high	2026-04-03 20:28:26.428645
19752	500107	70012002	2026-02-11	Wed	2	15.0	1.01	0.88	high	2026-04-03 20:28:26.428645
19753	500107	70012002	2026-02-12	Thu	2	15.7	1.01	0.92	high	2026-04-03 20:28:26.428645
19754	500107	70012002	2026-02-13	Fri	2	18.1	1.01	1.06	high	2026-04-03 20:28:26.428645
19755	500107	70012002	2026-02-14	Sat	2	16.5	1.01	0.97	high	2026-04-03 20:28:26.428645
19756	500107	70012002	2026-02-15	Sun	2	17.9	1.01	1.05	high	2026-04-03 20:28:26.428645
19757	500107	70012002	2026-02-16	Mon	2	16.7	1.01	0.98	high	2026-04-03 20:28:26.428645
19758	500107	70012002	2026-02-17	Tue	2	19.3	1.01	1.13	high	2026-04-03 20:28:26.428645
19759	500107	70012002	2026-02-18	Wed	2	15.0	1.01	0.88	high	2026-04-03 20:28:26.428645
19760	500107	70012002	2026-02-19	Thu	2	15.7	1.01	0.92	high	2026-04-03 20:28:26.428645
19761	500107	70012002	2026-02-20	Fri	2	18.1	1.01	1.06	high	2026-04-03 20:28:26.428645
19762	500107	70012002	2026-02-21	Sat	2	16.5	1.01	0.97	high	2026-04-03 20:28:26.428645
19763	500107	70012002	2026-02-22	Sun	2	17.9	1.01	1.05	high	2026-04-03 20:28:26.428645
19764	500107	70012002	2026-02-23	Mon	2	16.7	1.01	0.98	high	2026-04-03 20:28:26.428645
19765	500107	70012002	2026-02-24	Tue	2	19.3	1.01	1.13	high	2026-04-03 20:28:26.428645
19766	500107	70012002	2026-02-25	Wed	2	15.0	1.01	0.88	high	2026-04-03 20:28:26.428645
19767	500107	70012002	2026-02-26	Thu	2	15.7	1.01	0.92	high	2026-04-03 20:28:26.428645
19768	500107	70012002	2026-02-27	Fri	2	18.1	1.01	1.06	high	2026-04-03 20:28:26.428645
19769	500107	70012002	2026-02-28	Sat	2	16.5	1.01	0.97	high	2026-04-03 20:28:26.428645
19770	500107	70012002	2026-03-01	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
19771	500107	70012002	2026-03-02	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
19772	500107	70012002	2026-03-03	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
19773	500107	70012002	2026-03-04	Wed	3	10.7	0.72	0.88	high	2026-04-03 20:28:26.428645
19774	500107	70012002	2026-03-05	Thu	3	11.2	0.72	0.92	high	2026-04-03 20:28:26.428645
19775	500107	70012002	2026-03-06	Fri	3	12.9	0.72	1.06	high	2026-04-03 20:28:26.428645
19776	500107	70012002	2026-03-07	Sat	3	11.8	0.72	0.97	high	2026-04-03 20:28:26.428645
19777	500107	70012002	2026-03-08	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
19778	500107	70012002	2026-03-09	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
19779	500107	70012002	2026-03-10	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
19780	500107	70012002	2026-03-11	Wed	3	10.7	0.72	0.88	high	2026-04-03 20:28:26.428645
19781	500107	70012002	2026-03-12	Thu	3	11.2	0.72	0.92	high	2026-04-03 20:28:26.428645
19782	500107	70012002	2026-03-13	Fri	3	12.9	0.72	1.06	high	2026-04-03 20:28:26.428645
19783	500107	70012002	2026-03-14	Sat	3	11.8	0.72	0.97	high	2026-04-03 20:28:26.428645
19784	500107	70012002	2026-03-15	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
19785	500107	70012002	2026-03-16	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
19786	500107	70012002	2026-03-17	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
19787	500107	70012002	2026-03-18	Wed	3	10.7	0.72	0.88	high	2026-04-03 20:28:26.428645
19788	500107	70012002	2026-03-19	Thu	3	11.2	0.72	0.92	high	2026-04-03 20:28:26.428645
19789	500107	70012002	2026-03-20	Fri	3	12.9	0.72	1.06	high	2026-04-03 20:28:26.428645
19790	500107	70012002	2026-03-21	Sat	3	11.8	0.72	0.97	high	2026-04-03 20:28:26.428645
19791	500107	70012002	2026-03-22	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
19792	500107	70012002	2026-03-23	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
19793	500107	70012002	2026-03-24	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
19794	500107	70012002	2026-03-25	Wed	3	10.7	0.72	0.88	high	2026-04-03 20:28:26.428645
19795	500107	70012002	2026-03-26	Thu	3	11.2	0.72	0.92	high	2026-04-03 20:28:26.428645
19796	500107	70012002	2026-03-27	Fri	3	12.9	0.72	1.06	high	2026-04-03 20:28:26.428645
19797	500107	70012002	2026-03-28	Sat	3	11.8	0.72	0.97	high	2026-04-03 20:28:26.428645
19798	500107	70012002	2026-03-29	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
19799	500107	70012002	2026-03-30	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
19800	500107	70012002	2026-03-31	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
19801	500107	70012002	2026-04-01	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
19802	500107	70012002	2026-04-02	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
19803	500107	70012002	2026-04-03	Fri	4	16.5	0.92	1.06	medium	2026-04-03 20:28:26.428645
19804	500107	70012002	2026-04-04	Sat	4	15.1	0.92	0.97	medium	2026-04-03 20:28:26.428645
19805	500107	70012002	2026-04-05	Sun	4	16.3	0.92	1.05	medium	2026-04-03 20:28:26.428645
19806	500107	70012002	2026-04-06	Mon	4	15.2	0.92	0.98	medium	2026-04-03 20:28:26.428645
19807	500107	70012002	2026-04-07	Tue	4	17.6	0.92	1.13	medium	2026-04-03 20:28:26.428645
19808	500107	70012002	2026-04-08	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
19809	500107	70012002	2026-04-09	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
19810	500107	70012002	2026-04-10	Fri	4	16.5	0.92	1.06	medium	2026-04-03 20:28:26.428645
19811	500107	70012002	2026-04-11	Sat	4	15.1	0.92	0.97	medium	2026-04-03 20:28:26.428645
19812	500107	70012002	2026-04-12	Sun	4	16.3	0.92	1.05	medium	2026-04-03 20:28:26.428645
19813	500107	70012002	2026-04-13	Mon	4	15.2	0.92	0.98	medium	2026-04-03 20:28:26.428645
19814	500107	70012002	2026-04-14	Tue	4	17.6	0.92	1.13	medium	2026-04-03 20:28:26.428645
19815	500107	70012002	2026-04-15	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
19816	500107	70012002	2026-04-16	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
19817	500107	70012002	2026-04-17	Fri	4	16.5	0.92	1.06	medium	2026-04-03 20:28:26.428645
19818	500107	70012002	2026-04-18	Sat	4	15.1	0.92	0.97	medium	2026-04-03 20:28:26.428645
19819	500107	70012002	2026-04-19	Sun	4	16.3	0.92	1.05	medium	2026-04-03 20:28:26.428645
19820	500107	70012002	2026-04-20	Mon	4	15.2	0.92	0.98	medium	2026-04-03 20:28:26.428645
19821	500107	70012002	2026-04-21	Tue	4	17.6	0.92	1.13	medium	2026-04-03 20:28:26.428645
19822	500107	70012002	2026-04-22	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
19823	500107	70012002	2026-04-23	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
19824	500107	70012002	2026-04-24	Fri	4	16.5	0.92	1.06	medium	2026-04-03 20:28:26.428645
19825	500107	70012002	2026-04-25	Sat	4	15.1	0.92	0.97	medium	2026-04-03 20:28:26.428645
19826	500107	70012002	2026-04-26	Sun	4	16.3	0.92	1.05	medium	2026-04-03 20:28:26.428645
19827	500107	70012002	2026-04-27	Mon	4	15.2	0.92	0.98	medium	2026-04-03 20:28:26.428645
19828	500107	70012002	2026-04-28	Tue	4	17.6	0.92	1.13	medium	2026-04-03 20:28:26.428645
19829	500107	70012002	2026-04-29	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
19830	500107	70012002	2026-04-30	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
19831	500107	70012002	2026-05-01	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19832	500107	70012002	2026-05-02	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19833	500107	70012002	2026-05-03	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19834	500107	70012002	2026-05-04	Mon	5	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
19835	500107	70012002	2026-05-05	Tue	5	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
19836	500107	70012002	2026-05-06	Wed	5	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
19837	500107	70012002	2026-05-07	Thu	5	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
19838	500107	70012002	2026-05-08	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19839	500107	70012002	2026-05-09	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19840	500107	70012002	2026-05-10	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19841	500107	70012002	2026-05-11	Mon	5	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
19842	500107	70012002	2026-05-12	Tue	5	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
19843	500107	70012002	2026-05-13	Wed	5	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
19844	500107	70012002	2026-05-14	Thu	5	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
19845	500107	70012002	2026-05-15	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19846	500107	70012002	2026-05-16	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19847	500107	70012002	2026-05-17	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19848	500107	70012002	2026-05-18	Mon	5	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
19849	500107	70012002	2026-05-19	Tue	5	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
19850	500107	70012002	2026-05-20	Wed	5	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
19851	500107	70012002	2026-05-21	Thu	5	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
19852	500107	70012002	2026-05-22	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19853	500107	70012002	2026-05-23	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19854	500107	70012002	2026-05-24	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19855	500107	70012002	2026-05-25	Mon	5	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
19856	500107	70012002	2026-05-26	Tue	5	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
19857	500107	70012002	2026-05-27	Wed	5	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
19858	500107	70012002	2026-05-28	Thu	5	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
19859	500107	70012002	2026-05-29	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
19860	500107	70012002	2026-05-30	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
19861	500107	70012002	2026-05-31	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
19862	500107	70012002	2026-06-01	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
19863	500107	70012002	2026-06-02	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
19864	500107	70012002	2026-06-03	Wed	6	11.7	0.79	0.88	estimated	2026-04-03 20:28:26.428645
19865	500107	70012002	2026-06-04	Thu	6	12.3	0.79	0.92	estimated	2026-04-03 20:28:26.428645
19866	500107	70012002	2026-06-05	Fri	6	14.1	0.79	1.06	estimated	2026-04-03 20:28:26.428645
19867	500107	70012002	2026-06-06	Sat	6	12.9	0.79	0.97	estimated	2026-04-03 20:28:26.428645
19868	500107	70012002	2026-06-07	Sun	6	14.0	0.79	1.05	estimated	2026-04-03 20:28:26.428645
19869	500107	70012002	2026-06-08	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
19870	500107	70012002	2026-06-09	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
19871	500107	70012002	2026-06-10	Wed	6	11.7	0.79	0.88	estimated	2026-04-03 20:28:26.428645
19872	500107	70012002	2026-06-11	Thu	6	12.3	0.79	0.92	estimated	2026-04-03 20:28:26.428645
19873	500107	70012002	2026-06-12	Fri	6	14.1	0.79	1.06	estimated	2026-04-03 20:28:26.428645
19874	500107	70012002	2026-06-13	Sat	6	12.9	0.79	0.97	estimated	2026-04-03 20:28:26.428645
19875	500107	70012002	2026-06-14	Sun	6	14.0	0.79	1.05	estimated	2026-04-03 20:28:26.428645
19876	500107	70012002	2026-06-15	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
19877	500107	70012002	2026-06-16	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
19878	500107	70012002	2026-06-17	Wed	6	11.7	0.79	0.88	estimated	2026-04-03 20:28:26.428645
19879	500107	70012002	2026-06-18	Thu	6	12.3	0.79	0.92	estimated	2026-04-03 20:28:26.428645
19880	500107	70012002	2026-06-19	Fri	6	14.1	0.79	1.06	estimated	2026-04-03 20:28:26.428645
19881	500107	70012002	2026-06-20	Sat	6	12.9	0.79	0.97	estimated	2026-04-03 20:28:26.428645
19882	500107	70012002	2026-06-21	Sun	6	14.0	0.79	1.05	estimated	2026-04-03 20:28:26.428645
19883	500107	70012002	2026-06-22	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
19884	500107	70012002	2026-06-23	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
19885	500107	70012002	2026-06-24	Wed	6	11.7	0.79	0.88	estimated	2026-04-03 20:28:26.428645
19886	500107	70012002	2026-06-25	Thu	6	12.3	0.79	0.92	estimated	2026-04-03 20:28:26.428645
19887	500107	70012002	2026-06-26	Fri	6	14.1	0.79	1.06	estimated	2026-04-03 20:28:26.428645
19888	500107	70012002	2026-06-27	Sat	6	12.9	0.79	0.97	estimated	2026-04-03 20:28:26.428645
19889	500107	70012002	2026-06-28	Sun	6	14.0	0.79	1.05	estimated	2026-04-03 20:28:26.428645
19890	500107	70012002	2026-06-29	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
19891	500107	70012002	2026-06-30	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
19892	500107	70012002	2026-07-01	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
19893	500107	70012002	2026-07-02	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
19894	500107	70012002	2026-07-03	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
19895	500107	70012002	2026-07-04	Sat	7	16.1	0.98	0.97	estimated	2026-04-03 20:28:26.428645
19896	500107	70012002	2026-07-05	Sun	7	17.4	0.98	1.05	estimated	2026-04-03 20:28:26.428645
19897	500107	70012002	2026-07-06	Mon	7	16.2	0.98	0.98	estimated	2026-04-03 20:28:26.428645
19898	500107	70012002	2026-07-07	Tue	7	18.7	0.98	1.13	estimated	2026-04-03 20:28:26.428645
19899	500107	70012002	2026-07-08	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
19900	500107	70012002	2026-07-09	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
19901	500107	70012002	2026-07-10	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
19902	500107	70012002	2026-07-11	Sat	7	16.1	0.98	0.97	estimated	2026-04-03 20:28:26.428645
19903	500107	70012002	2026-07-12	Sun	7	17.4	0.98	1.05	estimated	2026-04-03 20:28:26.428645
19904	500107	70012002	2026-07-13	Mon	7	16.2	0.98	0.98	estimated	2026-04-03 20:28:26.428645
19905	500107	70012002	2026-07-14	Tue	7	18.7	0.98	1.13	estimated	2026-04-03 20:28:26.428645
19906	500107	70012002	2026-07-15	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
19907	500107	70012002	2026-07-16	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
19908	500107	70012002	2026-07-17	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
19909	500107	70012002	2026-07-18	Sat	7	16.1	0.98	0.97	estimated	2026-04-03 20:28:26.428645
19910	500107	70012002	2026-07-19	Sun	7	17.4	0.98	1.05	estimated	2026-04-03 20:28:26.428645
19911	500107	70012002	2026-07-20	Mon	7	16.2	0.98	0.98	estimated	2026-04-03 20:28:26.428645
19912	500107	70012002	2026-07-21	Tue	7	18.7	0.98	1.13	estimated	2026-04-03 20:28:26.428645
19913	500107	70012002	2026-07-22	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
19914	500107	70012002	2026-07-23	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
19915	500107	70012002	2026-07-24	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
19916	500107	70012002	2026-07-25	Sat	7	16.1	0.98	0.97	estimated	2026-04-03 20:28:26.428645
19917	500107	70012002	2026-07-26	Sun	7	17.4	0.98	1.05	estimated	2026-04-03 20:28:26.428645
19918	500107	70012002	2026-07-27	Mon	7	16.2	0.98	0.98	estimated	2026-04-03 20:28:26.428645
19919	500107	70012002	2026-07-28	Tue	7	18.7	0.98	1.13	estimated	2026-04-03 20:28:26.428645
19920	500107	70012002	2026-07-29	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
19921	500107	70012002	2026-07-30	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
19922	500107	70012002	2026-07-31	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
19923	500107	70012002	2026-08-01	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
19924	500107	70012002	2026-08-02	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
19925	500107	70012002	2026-08-03	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
19926	500107	70012002	2026-08-04	Tue	8	19.3	1.01	1.13	estimated	2026-04-03 20:28:26.428645
19927	500107	70012002	2026-08-05	Wed	8	15.0	1.01	0.88	estimated	2026-04-03 20:28:26.428645
19928	500107	70012002	2026-08-06	Thu	8	15.7	1.01	0.92	estimated	2026-04-03 20:28:26.428645
19929	500107	70012002	2026-08-07	Fri	8	18.1	1.01	1.06	estimated	2026-04-03 20:28:26.428645
19930	500107	70012002	2026-08-08	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
19931	500107	70012002	2026-08-09	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
19932	500107	70012002	2026-08-10	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
19933	500107	70012002	2026-08-11	Tue	8	19.3	1.01	1.13	estimated	2026-04-03 20:28:26.428645
19934	500107	70012002	2026-08-12	Wed	8	15.0	1.01	0.88	estimated	2026-04-03 20:28:26.428645
19935	500107	70012002	2026-08-13	Thu	8	15.7	1.01	0.92	estimated	2026-04-03 20:28:26.428645
19936	500107	70012002	2026-08-14	Fri	8	18.1	1.01	1.06	estimated	2026-04-03 20:28:26.428645
19937	500107	70012002	2026-08-15	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
19938	500107	70012002	2026-08-16	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
19939	500107	70012002	2026-08-17	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
19940	500107	70012002	2026-08-18	Tue	8	19.3	1.01	1.13	estimated	2026-04-03 20:28:26.428645
19941	500107	70012002	2026-08-19	Wed	8	15.0	1.01	0.88	estimated	2026-04-03 20:28:26.428645
19942	500107	70012002	2026-08-20	Thu	8	15.7	1.01	0.92	estimated	2026-04-03 20:28:26.428645
19943	500107	70012002	2026-08-21	Fri	8	18.1	1.01	1.06	estimated	2026-04-03 20:28:26.428645
19944	500107	70012002	2026-08-22	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
19945	500107	70012002	2026-08-23	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
19946	500107	70012002	2026-08-24	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
19947	500107	70012002	2026-08-25	Tue	8	19.3	1.01	1.13	estimated	2026-04-03 20:28:26.428645
19948	500107	70012002	2026-08-26	Wed	8	15.0	1.01	0.88	estimated	2026-04-03 20:28:26.428645
19949	500107	70012002	2026-08-27	Thu	8	15.7	1.01	0.92	estimated	2026-04-03 20:28:26.428645
19950	500107	70012002	2026-08-28	Fri	8	18.1	1.01	1.06	estimated	2026-04-03 20:28:26.428645
19951	500107	70012002	2026-08-29	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
19952	500107	70012002	2026-08-30	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
19953	500107	70012002	2026-08-31	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
19954	500107	70012002	2026-09-01	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
19955	500107	70012002	2026-09-02	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
19956	500107	70012002	2026-09-03	Thu	9	17.1	1.10	0.92	estimated	2026-04-03 20:28:26.428645
19957	500107	70012002	2026-09-04	Fri	9	19.7	1.10	1.06	estimated	2026-04-03 20:28:26.428645
19958	500107	70012002	2026-09-05	Sat	9	18.0	1.10	0.97	estimated	2026-04-03 20:28:26.428645
19959	500107	70012002	2026-09-06	Sun	9	19.5	1.10	1.05	estimated	2026-04-03 20:28:26.428645
19960	500107	70012002	2026-09-07	Mon	9	18.2	1.10	0.98	estimated	2026-04-03 20:28:26.428645
19961	500107	70012002	2026-09-08	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
19962	500107	70012002	2026-09-09	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
19963	500107	70012002	2026-09-10	Thu	9	17.1	1.10	0.92	estimated	2026-04-03 20:28:26.428645
19964	500107	70012002	2026-09-11	Fri	9	19.7	1.10	1.06	estimated	2026-04-03 20:28:26.428645
19965	500107	70012002	2026-09-12	Sat	9	18.0	1.10	0.97	estimated	2026-04-03 20:28:26.428645
19966	500107	70012002	2026-09-13	Sun	9	19.5	1.10	1.05	estimated	2026-04-03 20:28:26.428645
19967	500107	70012002	2026-09-14	Mon	9	18.2	1.10	0.98	estimated	2026-04-03 20:28:26.428645
19968	500107	70012002	2026-09-15	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
19969	500107	70012002	2026-09-16	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
19970	500107	70012002	2026-09-17	Thu	9	17.1	1.10	0.92	estimated	2026-04-03 20:28:26.428645
19971	500107	70012002	2026-09-18	Fri	9	19.7	1.10	1.06	estimated	2026-04-03 20:28:26.428645
19972	500107	70012002	2026-09-19	Sat	9	18.0	1.10	0.97	estimated	2026-04-03 20:28:26.428645
19973	500107	70012002	2026-09-20	Sun	9	19.5	1.10	1.05	estimated	2026-04-03 20:28:26.428645
19974	500107	70012002	2026-09-21	Mon	9	18.2	1.10	0.98	estimated	2026-04-03 20:28:26.428645
19975	500107	70012002	2026-09-22	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
19976	500107	70012002	2026-09-23	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
19977	500107	70012002	2026-09-24	Thu	9	17.1	1.10	0.92	estimated	2026-04-03 20:28:26.428645
19978	500107	70012002	2026-09-25	Fri	9	19.7	1.10	1.06	estimated	2026-04-03 20:28:26.428645
19979	500107	70012002	2026-09-26	Sat	9	18.0	1.10	0.97	estimated	2026-04-03 20:28:26.428645
19980	500107	70012002	2026-09-27	Sun	9	19.5	1.10	1.05	estimated	2026-04-03 20:28:26.428645
19981	500107	70012002	2026-09-28	Mon	9	18.2	1.10	0.98	estimated	2026-04-03 20:28:26.428645
19982	500107	70012002	2026-09-29	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
19983	500107	70012002	2026-09-30	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
19984	500107	70012002	2026-10-01	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
19985	500107	70012002	2026-10-02	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
19986	500107	70012002	2026-10-03	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
19987	500107	70012002	2026-10-04	Sun	10	16.8	0.95	1.05	estimated	2026-04-03 20:28:26.428645
19988	500107	70012002	2026-10-05	Mon	10	15.7	0.95	0.98	estimated	2026-04-03 20:28:26.428645
19989	500107	70012002	2026-10-06	Tue	10	18.1	0.95	1.13	estimated	2026-04-03 20:28:26.428645
19990	500107	70012002	2026-10-07	Wed	10	14.1	0.95	0.88	estimated	2026-04-03 20:28:26.428645
19991	500107	70012002	2026-10-08	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
19992	500107	70012002	2026-10-09	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
19993	500107	70012002	2026-10-10	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
19994	500107	70012002	2026-10-11	Sun	10	16.8	0.95	1.05	estimated	2026-04-03 20:28:26.428645
19995	500107	70012002	2026-10-12	Mon	10	15.7	0.95	0.98	estimated	2026-04-03 20:28:26.428645
19996	500107	70012002	2026-10-13	Tue	10	18.1	0.95	1.13	estimated	2026-04-03 20:28:26.428645
19997	500107	70012002	2026-10-14	Wed	10	14.1	0.95	0.88	estimated	2026-04-03 20:28:26.428645
19998	500107	70012002	2026-10-15	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
19999	500107	70012002	2026-10-16	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
20000	500107	70012002	2026-10-17	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
20001	500107	70012002	2026-10-18	Sun	10	16.8	0.95	1.05	estimated	2026-04-03 20:28:26.428645
20002	500107	70012002	2026-10-19	Mon	10	15.7	0.95	0.98	estimated	2026-04-03 20:28:26.428645
20003	500107	70012002	2026-10-20	Tue	10	18.1	0.95	1.13	estimated	2026-04-03 20:28:26.428645
20004	500107	70012002	2026-10-21	Wed	10	14.1	0.95	0.88	estimated	2026-04-03 20:28:26.428645
20005	500107	70012002	2026-10-22	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
20006	500107	70012002	2026-10-23	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
20007	500107	70012002	2026-10-24	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
20008	500107	70012002	2026-10-25	Sun	10	16.8	0.95	1.05	estimated	2026-04-03 20:28:26.428645
20009	500107	70012002	2026-10-26	Mon	10	15.7	0.95	0.98	estimated	2026-04-03 20:28:26.428645
20010	500107	70012002	2026-10-27	Tue	10	18.1	0.95	1.13	estimated	2026-04-03 20:28:26.428645
20011	500107	70012002	2026-10-28	Wed	10	14.1	0.95	0.88	estimated	2026-04-03 20:28:26.428645
20012	500107	70012002	2026-10-29	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
20013	500107	70012002	2026-10-30	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
20014	500107	70012002	2026-10-31	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
20015	500107	70012002	2026-11-01	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20016	500107	70012002	2026-11-02	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20017	500107	70012002	2026-11-03	Tue	11	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
20018	500107	70012002	2026-11-04	Wed	11	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
20019	500107	70012002	2026-11-05	Thu	11	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
20020	500107	70012002	2026-11-06	Fri	11	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
20021	500107	70012002	2026-11-07	Sat	11	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
20022	500107	70012002	2026-11-08	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20023	500107	70012002	2026-11-09	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20024	500107	70012002	2026-11-10	Tue	11	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
20025	500107	70012002	2026-11-11	Wed	11	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
20026	500107	70012002	2026-11-12	Thu	11	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
20027	500107	70012002	2026-11-13	Fri	11	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
20028	500107	70012002	2026-11-14	Sat	11	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
20029	500107	70012002	2026-11-15	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20030	500107	70012002	2026-11-16	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20031	500107	70012002	2026-11-17	Tue	11	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
20032	500107	70012002	2026-11-18	Wed	11	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
20033	500107	70012002	2026-11-19	Thu	11	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
20034	500107	70012002	2026-11-20	Fri	11	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
20035	500107	70012002	2026-11-21	Sat	11	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
20036	500107	70012002	2026-11-22	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20037	500107	70012002	2026-11-23	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20038	500107	70012002	2026-11-24	Tue	11	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
20039	500107	70012002	2026-11-25	Wed	11	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
20040	500107	70012002	2026-11-26	Thu	11	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
20041	500107	70012002	2026-11-27	Fri	11	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
20042	500107	70012002	2026-11-28	Sat	11	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
20043	500107	70012002	2026-11-29	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20044	500107	70012002	2026-11-30	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20045	500107	70012002	2026-12-01	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
20046	500107	70012002	2026-12-02	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
20047	500107	70012002	2026-12-03	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
20048	500107	70012002	2026-12-04	Fri	12	15.9	0.89	1.06	estimated	2026-04-03 20:28:26.428645
20049	500107	70012002	2026-12-05	Sat	12	14.6	0.89	0.97	estimated	2026-04-03 20:28:26.428645
20050	500107	70012002	2026-12-06	Sun	12	15.8	0.89	1.05	estimated	2026-04-03 20:28:26.428645
20051	500107	70012002	2026-12-07	Mon	12	14.7	0.89	0.98	estimated	2026-04-03 20:28:26.428645
20052	500107	70012002	2026-12-08	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
20053	500107	70012002	2026-12-09	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
20054	500107	70012002	2026-12-10	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
20055	500107	70012002	2026-12-11	Fri	12	15.9	0.89	1.06	estimated	2026-04-03 20:28:26.428645
20056	500107	70012002	2026-12-12	Sat	12	14.6	0.89	0.97	estimated	2026-04-03 20:28:26.428645
20057	500107	70012002	2026-12-13	Sun	12	15.8	0.89	1.05	estimated	2026-04-03 20:28:26.428645
20058	500107	70012002	2026-12-14	Mon	12	14.7	0.89	0.98	estimated	2026-04-03 20:28:26.428645
20059	500107	70012002	2026-12-15	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
20060	500107	70012002	2026-12-16	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
20061	500107	70012002	2026-12-17	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
20062	500107	70012002	2026-12-18	Fri	12	15.9	0.89	1.06	estimated	2026-04-03 20:28:26.428645
20063	500107	70012002	2026-12-19	Sat	12	14.6	0.89	0.97	estimated	2026-04-03 20:28:26.428645
20064	500107	70012002	2026-12-20	Sun	12	15.8	0.89	1.05	estimated	2026-04-03 20:28:26.428645
20065	500107	70012002	2026-12-21	Mon	12	14.7	0.89	0.98	estimated	2026-04-03 20:28:26.428645
20066	500107	70012002	2026-12-22	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
20067	500107	70012002	2026-12-23	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
20068	500107	70012002	2026-12-24	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
20069	500107	70012002	2026-12-25	Fri	12	15.9	0.89	1.06	estimated	2026-04-03 20:28:26.428645
20070	500107	70012002	2026-12-26	Sat	12	14.6	0.89	0.97	estimated	2026-04-03 20:28:26.428645
20071	500107	70012002	2026-12-27	Sun	12	15.8	0.89	1.05	estimated	2026-04-03 20:28:26.428645
20072	500107	70012002	2026-12-28	Mon	12	14.7	0.89	0.98	estimated	2026-04-03 20:28:26.428645
20073	500107	70012002	2026-12-29	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
20074	500107	70012002	2026-12-30	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
20075	500107	70012002	2026-12-31	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
20076	500107	70012002	2027-01-01	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
20077	500107	70012002	2027-01-02	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
20078	500107	70012002	2027-01-03	Sun	1	25.9	1.46	1.05	high	2026-04-03 20:28:26.428645
20079	500107	70012002	2027-01-04	Mon	1	24.2	1.46	0.98	high	2026-04-03 20:28:26.428645
20080	500107	70012002	2027-01-05	Tue	1	27.9	1.46	1.13	high	2026-04-03 20:28:26.428645
20081	500107	70012002	2027-01-06	Wed	1	21.7	1.46	0.88	high	2026-04-03 20:28:26.428645
20082	500107	70012002	2027-01-07	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
20083	500107	70012002	2027-01-08	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
20084	500107	70012002	2027-01-09	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
20085	500107	70012002	2027-01-10	Sun	1	25.9	1.46	1.05	high	2026-04-03 20:28:26.428645
20086	500107	70012002	2027-01-11	Mon	1	24.2	1.46	0.98	high	2026-04-03 20:28:26.428645
20087	500107	70012002	2027-01-12	Tue	1	27.9	1.46	1.13	high	2026-04-03 20:28:26.428645
20088	500107	70012002	2027-01-13	Wed	1	21.7	1.46	0.88	high	2026-04-03 20:28:26.428645
20089	500107	70012002	2027-01-14	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
20090	500107	70012002	2027-01-15	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
20091	500107	70012002	2027-01-16	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
20092	500107	70012002	2027-01-17	Sun	1	25.9	1.46	1.05	high	2026-04-03 20:28:26.428645
20093	500107	70012002	2027-01-18	Mon	1	24.2	1.46	0.98	high	2026-04-03 20:28:26.428645
20094	500107	70012002	2027-01-19	Tue	1	27.9	1.46	1.13	high	2026-04-03 20:28:26.428645
20095	500107	70012002	2027-01-20	Wed	1	21.7	1.46	0.88	high	2026-04-03 20:28:26.428645
20096	500107	70012002	2027-01-21	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
20097	500107	70012002	2027-01-22	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
20098	500107	70012002	2027-01-23	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
20099	500107	70012002	2027-01-24	Sun	1	25.9	1.46	1.05	high	2026-04-03 20:28:26.428645
20100	500107	70012002	2027-01-25	Mon	1	24.2	1.46	0.98	high	2026-04-03 20:28:26.428645
20101	500107	70012002	2027-01-26	Tue	1	27.9	1.46	1.13	high	2026-04-03 20:28:26.428645
20102	500107	70012002	2027-01-27	Wed	1	21.7	1.46	0.88	high	2026-04-03 20:28:26.428645
20103	500107	70012002	2027-01-28	Thu	1	22.7	1.46	0.92	high	2026-04-03 20:28:26.428645
20104	500107	70012002	2027-01-29	Fri	1	26.1	1.46	1.06	high	2026-04-03 20:28:26.428645
20105	500107	70012002	2027-01-30	Sat	1	23.9	1.46	0.97	high	2026-04-03 20:28:26.428645
20106	500107	70012002	2027-01-31	Sun	1	25.9	1.46	1.05	high	2026-04-03 20:28:26.428645
20107	500107	70012002	2027-02-01	Mon	2	16.7	1.01	0.98	high	2026-04-03 20:28:26.428645
20108	500107	70012002	2027-02-02	Tue	2	19.3	1.01	1.13	high	2026-04-03 20:28:26.428645
20109	500107	70012002	2027-02-03	Wed	2	15.0	1.01	0.88	high	2026-04-03 20:28:26.428645
20110	500107	70012002	2027-02-04	Thu	2	15.7	1.01	0.92	high	2026-04-03 20:28:26.428645
20111	500107	70012002	2027-02-05	Fri	2	18.1	1.01	1.06	high	2026-04-03 20:28:26.428645
20112	500107	70012002	2027-02-06	Sat	2	16.5	1.01	0.97	high	2026-04-03 20:28:26.428645
20113	500107	70012002	2027-02-07	Sun	2	17.9	1.01	1.05	high	2026-04-03 20:28:26.428645
20114	500107	70012002	2027-02-08	Mon	2	16.7	1.01	0.98	high	2026-04-03 20:28:26.428645
20115	500107	70012002	2027-02-09	Tue	2	19.3	1.01	1.13	high	2026-04-03 20:28:26.428645
20116	500107	70012002	2027-02-10	Wed	2	15.0	1.01	0.88	high	2026-04-03 20:28:26.428645
20117	500107	70012002	2027-02-11	Thu	2	15.7	1.01	0.92	high	2026-04-03 20:28:26.428645
20118	500107	70012002	2027-02-12	Fri	2	18.1	1.01	1.06	high	2026-04-03 20:28:26.428645
20119	500107	70012002	2027-02-13	Sat	2	16.5	1.01	0.97	high	2026-04-03 20:28:26.428645
20120	500107	70012002	2027-02-14	Sun	2	17.9	1.01	1.05	high	2026-04-03 20:28:26.428645
20121	500107	70012002	2027-02-15	Mon	2	16.7	1.01	0.98	high	2026-04-03 20:28:26.428645
20122	500107	70012002	2027-02-16	Tue	2	19.3	1.01	1.13	high	2026-04-03 20:28:26.428645
20123	500107	70012002	2027-02-17	Wed	2	15.0	1.01	0.88	high	2026-04-03 20:28:26.428645
20124	500107	70012002	2027-02-18	Thu	2	15.7	1.01	0.92	high	2026-04-03 20:28:26.428645
20125	500107	70012002	2027-02-19	Fri	2	18.1	1.01	1.06	high	2026-04-03 20:28:26.428645
20126	500107	70012002	2027-02-20	Sat	2	16.5	1.01	0.97	high	2026-04-03 20:28:26.428645
20127	500107	70012002	2027-02-21	Sun	2	17.9	1.01	1.05	high	2026-04-03 20:28:26.428645
20128	500107	70012002	2027-02-22	Mon	2	16.7	1.01	0.98	high	2026-04-03 20:28:26.428645
20129	500107	70012002	2027-02-23	Tue	2	19.3	1.01	1.13	high	2026-04-03 20:28:26.428645
20130	500107	70012002	2027-02-24	Wed	2	15.0	1.01	0.88	high	2026-04-03 20:28:26.428645
20131	500107	70012002	2027-02-25	Thu	2	15.7	1.01	0.92	high	2026-04-03 20:28:26.428645
20132	500107	70012002	2027-02-26	Fri	2	18.1	1.01	1.06	high	2026-04-03 20:28:26.428645
20133	500107	70012002	2027-02-27	Sat	2	16.5	1.01	0.97	high	2026-04-03 20:28:26.428645
20134	500107	70012002	2027-02-28	Sun	2	17.9	1.01	1.05	high	2026-04-03 20:28:26.428645
20135	500107	70012002	2027-03-01	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
20136	500107	70012002	2027-03-02	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
20137	500107	70012002	2027-03-03	Wed	3	10.7	0.72	0.88	high	2026-04-03 20:28:26.428645
20138	500107	70012002	2027-03-04	Thu	3	11.2	0.72	0.92	high	2026-04-03 20:28:26.428645
20139	500107	70012002	2027-03-05	Fri	3	12.9	0.72	1.06	high	2026-04-03 20:28:26.428645
20140	500107	70012002	2027-03-06	Sat	3	11.8	0.72	0.97	high	2026-04-03 20:28:26.428645
20141	500107	70012002	2027-03-07	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
20142	500107	70012002	2027-03-08	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
20143	500107	70012002	2027-03-09	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
20144	500107	70012002	2027-03-10	Wed	3	10.7	0.72	0.88	high	2026-04-03 20:28:26.428645
20145	500107	70012002	2027-03-11	Thu	3	11.2	0.72	0.92	high	2026-04-03 20:28:26.428645
20146	500107	70012002	2027-03-12	Fri	3	12.9	0.72	1.06	high	2026-04-03 20:28:26.428645
20147	500107	70012002	2027-03-13	Sat	3	11.8	0.72	0.97	high	2026-04-03 20:28:26.428645
20148	500107	70012002	2027-03-14	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
20149	500107	70012002	2027-03-15	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
20150	500107	70012002	2027-03-16	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
20151	500107	70012002	2027-03-17	Wed	3	10.7	0.72	0.88	high	2026-04-03 20:28:26.428645
20152	500107	70012002	2027-03-18	Thu	3	11.2	0.72	0.92	high	2026-04-03 20:28:26.428645
20153	500107	70012002	2027-03-19	Fri	3	12.9	0.72	1.06	high	2026-04-03 20:28:26.428645
20154	500107	70012002	2027-03-20	Sat	3	11.8	0.72	0.97	high	2026-04-03 20:28:26.428645
20155	500107	70012002	2027-03-21	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
20156	500107	70012002	2027-03-22	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
20157	500107	70012002	2027-03-23	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
20158	500107	70012002	2027-03-24	Wed	3	10.7	0.72	0.88	high	2026-04-03 20:28:26.428645
20159	500107	70012002	2027-03-25	Thu	3	11.2	0.72	0.92	high	2026-04-03 20:28:26.428645
20160	500107	70012002	2027-03-26	Fri	3	12.9	0.72	1.06	high	2026-04-03 20:28:26.428645
20161	500107	70012002	2027-03-27	Sat	3	11.8	0.72	0.97	high	2026-04-03 20:28:26.428645
20162	500107	70012002	2027-03-28	Sun	3	12.8	0.72	1.05	high	2026-04-03 20:28:26.428645
20163	500107	70012002	2027-03-29	Mon	3	11.9	0.72	0.98	high	2026-04-03 20:28:26.428645
20164	500107	70012002	2027-03-30	Tue	3	13.7	0.72	1.13	high	2026-04-03 20:28:26.428645
20165	500107	70012002	2027-03-31	Wed	3	10.7	0.72	0.88	high	2026-04-03 20:28:26.428645
20166	500107	70012002	2027-04-01	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
20167	500107	70012002	2027-04-02	Fri	4	16.5	0.92	1.06	medium	2026-04-03 20:28:26.428645
20168	500107	70012002	2027-04-03	Sat	4	15.1	0.92	0.97	medium	2026-04-03 20:28:26.428645
20169	500107	70012002	2027-04-04	Sun	4	16.3	0.92	1.05	medium	2026-04-03 20:28:26.428645
20170	500107	70012002	2027-04-05	Mon	4	15.2	0.92	0.98	medium	2026-04-03 20:28:26.428645
20171	500107	70012002	2027-04-06	Tue	4	17.6	0.92	1.13	medium	2026-04-03 20:28:26.428645
20172	500107	70012002	2027-04-07	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
20173	500107	70012002	2027-04-08	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
20174	500107	70012002	2027-04-09	Fri	4	16.5	0.92	1.06	medium	2026-04-03 20:28:26.428645
20175	500107	70012002	2027-04-10	Sat	4	15.1	0.92	0.97	medium	2026-04-03 20:28:26.428645
20176	500107	70012002	2027-04-11	Sun	4	16.3	0.92	1.05	medium	2026-04-03 20:28:26.428645
20177	500107	70012002	2027-04-12	Mon	4	15.2	0.92	0.98	medium	2026-04-03 20:28:26.428645
20178	500107	70012002	2027-04-13	Tue	4	17.6	0.92	1.13	medium	2026-04-03 20:28:26.428645
20179	500107	70012002	2027-04-14	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
20180	500107	70012002	2027-04-15	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
20181	500107	70012002	2027-04-16	Fri	4	16.5	0.92	1.06	medium	2026-04-03 20:28:26.428645
20182	500107	70012002	2027-04-17	Sat	4	15.1	0.92	0.97	medium	2026-04-03 20:28:26.428645
20183	500107	70012002	2027-04-18	Sun	4	16.3	0.92	1.05	medium	2026-04-03 20:28:26.428645
20184	500107	70012002	2027-04-19	Mon	4	15.2	0.92	0.98	medium	2026-04-03 20:28:26.428645
20185	500107	70012002	2027-04-20	Tue	4	17.6	0.92	1.13	medium	2026-04-03 20:28:26.428645
20186	500107	70012002	2027-04-21	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
20187	500107	70012002	2027-04-22	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
20188	500107	70012002	2027-04-23	Fri	4	16.5	0.92	1.06	medium	2026-04-03 20:28:26.428645
20189	500107	70012002	2027-04-24	Sat	4	15.1	0.92	0.97	medium	2026-04-03 20:28:26.428645
20190	500107	70012002	2027-04-25	Sun	4	16.3	0.92	1.05	medium	2026-04-03 20:28:26.428645
20191	500107	70012002	2027-04-26	Mon	4	15.2	0.92	0.98	medium	2026-04-03 20:28:26.428645
20192	500107	70012002	2027-04-27	Tue	4	17.6	0.92	1.13	medium	2026-04-03 20:28:26.428645
20193	500107	70012002	2027-04-28	Wed	4	13.7	0.92	0.88	medium	2026-04-03 20:28:26.428645
20194	500107	70012002	2027-04-29	Thu	4	14.3	0.92	0.92	medium	2026-04-03 20:28:26.428645
20195	500107	70012002	2027-04-30	Fri	4	16.5	0.92	1.06	medium	2026-04-03 20:28:26.428645
20196	500107	70012002	2027-05-01	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
20197	500107	70012002	2027-05-02	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20198	500107	70012002	2027-05-03	Mon	5	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20199	500107	70012002	2027-05-04	Tue	5	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
20200	500107	70012002	2027-05-05	Wed	5	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
20201	500107	70012002	2027-05-06	Thu	5	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
20202	500107	70012002	2027-05-07	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
20203	500107	70012002	2027-05-08	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
20204	500107	70012002	2027-05-09	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20205	500107	70012002	2027-05-10	Mon	5	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20206	500107	70012002	2027-05-11	Tue	5	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
20207	500107	70012002	2027-05-12	Wed	5	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
20208	500107	70012002	2027-05-13	Thu	5	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
20209	500107	70012002	2027-05-14	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
20210	500107	70012002	2027-05-15	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
20211	500107	70012002	2027-05-16	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20212	500107	70012002	2027-05-17	Mon	5	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20213	500107	70012002	2027-05-18	Tue	5	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
20214	500107	70012002	2027-05-19	Wed	5	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
20215	500107	70012002	2027-05-20	Thu	5	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
20216	500107	70012002	2027-05-21	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
20217	500107	70012002	2027-05-22	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
20218	500107	70012002	2027-05-23	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20219	500107	70012002	2027-05-24	Mon	5	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20220	500107	70012002	2027-05-25	Tue	5	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
20221	500107	70012002	2027-05-26	Wed	5	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
20222	500107	70012002	2027-05-27	Thu	5	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
20223	500107	70012002	2027-05-28	Fri	5	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
20224	500107	70012002	2027-05-29	Sat	5	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
20225	500107	70012002	2027-05-30	Sun	5	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20226	500107	70012002	2027-05-31	Mon	5	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20227	500107	70012002	2027-06-01	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
20228	500107	70012002	2027-06-02	Wed	6	11.7	0.79	0.88	estimated	2026-04-03 20:28:26.428645
20229	500107	70012002	2027-06-03	Thu	6	12.3	0.79	0.92	estimated	2026-04-03 20:28:26.428645
20230	500107	70012002	2027-06-04	Fri	6	14.1	0.79	1.06	estimated	2026-04-03 20:28:26.428645
20231	500107	70012002	2027-06-05	Sat	6	12.9	0.79	0.97	estimated	2026-04-03 20:28:26.428645
20232	500107	70012002	2027-06-06	Sun	6	14.0	0.79	1.05	estimated	2026-04-03 20:28:26.428645
20233	500107	70012002	2027-06-07	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
20234	500107	70012002	2027-06-08	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
20235	500107	70012002	2027-06-09	Wed	6	11.7	0.79	0.88	estimated	2026-04-03 20:28:26.428645
20236	500107	70012002	2027-06-10	Thu	6	12.3	0.79	0.92	estimated	2026-04-03 20:28:26.428645
20237	500107	70012002	2027-06-11	Fri	6	14.1	0.79	1.06	estimated	2026-04-03 20:28:26.428645
20238	500107	70012002	2027-06-12	Sat	6	12.9	0.79	0.97	estimated	2026-04-03 20:28:26.428645
20239	500107	70012002	2027-06-13	Sun	6	14.0	0.79	1.05	estimated	2026-04-03 20:28:26.428645
20240	500107	70012002	2027-06-14	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
20241	500107	70012002	2027-06-15	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
20242	500107	70012002	2027-06-16	Wed	6	11.7	0.79	0.88	estimated	2026-04-03 20:28:26.428645
20243	500107	70012002	2027-06-17	Thu	6	12.3	0.79	0.92	estimated	2026-04-03 20:28:26.428645
20244	500107	70012002	2027-06-18	Fri	6	14.1	0.79	1.06	estimated	2026-04-03 20:28:26.428645
20245	500107	70012002	2027-06-19	Sat	6	12.9	0.79	0.97	estimated	2026-04-03 20:28:26.428645
20246	500107	70012002	2027-06-20	Sun	6	14.0	0.79	1.05	estimated	2026-04-03 20:28:26.428645
20247	500107	70012002	2027-06-21	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
20248	500107	70012002	2027-06-22	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
20249	500107	70012002	2027-06-23	Wed	6	11.7	0.79	0.88	estimated	2026-04-03 20:28:26.428645
20250	500107	70012002	2027-06-24	Thu	6	12.3	0.79	0.92	estimated	2026-04-03 20:28:26.428645
20251	500107	70012002	2027-06-25	Fri	6	14.1	0.79	1.06	estimated	2026-04-03 20:28:26.428645
20252	500107	70012002	2027-06-26	Sat	6	12.9	0.79	0.97	estimated	2026-04-03 20:28:26.428645
20253	500107	70012002	2027-06-27	Sun	6	14.0	0.79	1.05	estimated	2026-04-03 20:28:26.428645
20254	500107	70012002	2027-06-28	Mon	6	13.1	0.79	0.98	estimated	2026-04-03 20:28:26.428645
20255	500107	70012002	2027-06-29	Tue	6	15.1	0.79	1.13	estimated	2026-04-03 20:28:26.428645
20256	500107	70012002	2027-06-30	Wed	6	11.7	0.79	0.88	estimated	2026-04-03 20:28:26.428645
20257	500107	70012002	2027-07-01	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
20258	500107	70012002	2027-07-02	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
20259	500107	70012002	2027-07-03	Sat	7	16.1	0.98	0.97	estimated	2026-04-03 20:28:26.428645
20260	500107	70012002	2027-07-04	Sun	7	17.4	0.98	1.05	estimated	2026-04-03 20:28:26.428645
20261	500107	70012002	2027-07-05	Mon	7	16.2	0.98	0.98	estimated	2026-04-03 20:28:26.428645
20262	500107	70012002	2027-07-06	Tue	7	18.7	0.98	1.13	estimated	2026-04-03 20:28:26.428645
20263	500107	70012002	2027-07-07	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
20264	500107	70012002	2027-07-08	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
20265	500107	70012002	2027-07-09	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
20266	500107	70012002	2027-07-10	Sat	7	16.1	0.98	0.97	estimated	2026-04-03 20:28:26.428645
20267	500107	70012002	2027-07-11	Sun	7	17.4	0.98	1.05	estimated	2026-04-03 20:28:26.428645
20268	500107	70012002	2027-07-12	Mon	7	16.2	0.98	0.98	estimated	2026-04-03 20:28:26.428645
20269	500107	70012002	2027-07-13	Tue	7	18.7	0.98	1.13	estimated	2026-04-03 20:28:26.428645
20270	500107	70012002	2027-07-14	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
20271	500107	70012002	2027-07-15	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
20272	500107	70012002	2027-07-16	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
20273	500107	70012002	2027-07-17	Sat	7	16.1	0.98	0.97	estimated	2026-04-03 20:28:26.428645
20274	500107	70012002	2027-07-18	Sun	7	17.4	0.98	1.05	estimated	2026-04-03 20:28:26.428645
20275	500107	70012002	2027-07-19	Mon	7	16.2	0.98	0.98	estimated	2026-04-03 20:28:26.428645
20276	500107	70012002	2027-07-20	Tue	7	18.7	0.98	1.13	estimated	2026-04-03 20:28:26.428645
20277	500107	70012002	2027-07-21	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
20278	500107	70012002	2027-07-22	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
20279	500107	70012002	2027-07-23	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
20280	500107	70012002	2027-07-24	Sat	7	16.1	0.98	0.97	estimated	2026-04-03 20:28:26.428645
20281	500107	70012002	2027-07-25	Sun	7	17.4	0.98	1.05	estimated	2026-04-03 20:28:26.428645
20282	500107	70012002	2027-07-26	Mon	7	16.2	0.98	0.98	estimated	2026-04-03 20:28:26.428645
20283	500107	70012002	2027-07-27	Tue	7	18.7	0.98	1.13	estimated	2026-04-03 20:28:26.428645
20284	500107	70012002	2027-07-28	Wed	7	14.6	0.98	0.88	estimated	2026-04-03 20:28:26.428645
20285	500107	70012002	2027-07-29	Thu	7	15.2	0.98	0.92	estimated	2026-04-03 20:28:26.428645
20286	500107	70012002	2027-07-30	Fri	7	17.5	0.98	1.06	estimated	2026-04-03 20:28:26.428645
20287	500107	70012002	2027-07-31	Sat	7	16.1	0.98	0.97	estimated	2026-04-03 20:28:26.428645
20288	500107	70012002	2027-08-01	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
20289	500107	70012002	2027-08-02	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
20290	500107	70012002	2027-08-03	Tue	8	19.3	1.01	1.13	estimated	2026-04-03 20:28:26.428645
20291	500107	70012002	2027-08-04	Wed	8	15.0	1.01	0.88	estimated	2026-04-03 20:28:26.428645
20292	500107	70012002	2027-08-05	Thu	8	15.7	1.01	0.92	estimated	2026-04-03 20:28:26.428645
20293	500107	70012002	2027-08-06	Fri	8	18.1	1.01	1.06	estimated	2026-04-03 20:28:26.428645
20294	500107	70012002	2027-08-07	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
20295	500107	70012002	2027-08-08	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
20296	500107	70012002	2027-08-09	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
20297	500107	70012002	2027-08-10	Tue	8	19.3	1.01	1.13	estimated	2026-04-03 20:28:26.428645
20298	500107	70012002	2027-08-11	Wed	8	15.0	1.01	0.88	estimated	2026-04-03 20:28:26.428645
20299	500107	70012002	2027-08-12	Thu	8	15.7	1.01	0.92	estimated	2026-04-03 20:28:26.428645
20300	500107	70012002	2027-08-13	Fri	8	18.1	1.01	1.06	estimated	2026-04-03 20:28:26.428645
20301	500107	70012002	2027-08-14	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
20302	500107	70012002	2027-08-15	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
20303	500107	70012002	2027-08-16	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
20304	500107	70012002	2027-08-17	Tue	8	19.3	1.01	1.13	estimated	2026-04-03 20:28:26.428645
20305	500107	70012002	2027-08-18	Wed	8	15.0	1.01	0.88	estimated	2026-04-03 20:28:26.428645
20306	500107	70012002	2027-08-19	Thu	8	15.7	1.01	0.92	estimated	2026-04-03 20:28:26.428645
20307	500107	70012002	2027-08-20	Fri	8	18.1	1.01	1.06	estimated	2026-04-03 20:28:26.428645
20308	500107	70012002	2027-08-21	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
20309	500107	70012002	2027-08-22	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
20310	500107	70012002	2027-08-23	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
20311	500107	70012002	2027-08-24	Tue	8	19.3	1.01	1.13	estimated	2026-04-03 20:28:26.428645
20312	500107	70012002	2027-08-25	Wed	8	15.0	1.01	0.88	estimated	2026-04-03 20:28:26.428645
20313	500107	70012002	2027-08-26	Thu	8	15.7	1.01	0.92	estimated	2026-04-03 20:28:26.428645
20314	500107	70012002	2027-08-27	Fri	8	18.1	1.01	1.06	estimated	2026-04-03 20:28:26.428645
20315	500107	70012002	2027-08-28	Sat	8	16.5	1.01	0.97	estimated	2026-04-03 20:28:26.428645
20316	500107	70012002	2027-08-29	Sun	8	17.9	1.01	1.05	estimated	2026-04-03 20:28:26.428645
20317	500107	70012002	2027-08-30	Mon	8	16.7	1.01	0.98	estimated	2026-04-03 20:28:26.428645
20318	500107	70012002	2027-08-31	Tue	8	19.3	1.01	1.13	estimated	2026-04-03 20:28:26.428645
20319	500107	70012002	2027-09-01	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
20320	500107	70012002	2027-09-02	Thu	9	17.1	1.10	0.92	estimated	2026-04-03 20:28:26.428645
20321	500107	70012002	2027-09-03	Fri	9	19.7	1.10	1.06	estimated	2026-04-03 20:28:26.428645
20322	500107	70012002	2027-09-04	Sat	9	18.0	1.10	0.97	estimated	2026-04-03 20:28:26.428645
20323	500107	70012002	2027-09-05	Sun	9	19.5	1.10	1.05	estimated	2026-04-03 20:28:26.428645
20324	500107	70012002	2027-09-06	Mon	9	18.2	1.10	0.98	estimated	2026-04-03 20:28:26.428645
20325	500107	70012002	2027-09-07	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
20326	500107	70012002	2027-09-08	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
20327	500107	70012002	2027-09-09	Thu	9	17.1	1.10	0.92	estimated	2026-04-03 20:28:26.428645
20328	500107	70012002	2027-09-10	Fri	9	19.7	1.10	1.06	estimated	2026-04-03 20:28:26.428645
20329	500107	70012002	2027-09-11	Sat	9	18.0	1.10	0.97	estimated	2026-04-03 20:28:26.428645
20330	500107	70012002	2027-09-12	Sun	9	19.5	1.10	1.05	estimated	2026-04-03 20:28:26.428645
20331	500107	70012002	2027-09-13	Mon	9	18.2	1.10	0.98	estimated	2026-04-03 20:28:26.428645
20332	500107	70012002	2027-09-14	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
20333	500107	70012002	2027-09-15	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
20334	500107	70012002	2027-09-16	Thu	9	17.1	1.10	0.92	estimated	2026-04-03 20:28:26.428645
20335	500107	70012002	2027-09-17	Fri	9	19.7	1.10	1.06	estimated	2026-04-03 20:28:26.428645
20336	500107	70012002	2027-09-18	Sat	9	18.0	1.10	0.97	estimated	2026-04-03 20:28:26.428645
20337	500107	70012002	2027-09-19	Sun	9	19.5	1.10	1.05	estimated	2026-04-03 20:28:26.428645
20338	500107	70012002	2027-09-20	Mon	9	18.2	1.10	0.98	estimated	2026-04-03 20:28:26.428645
20339	500107	70012002	2027-09-21	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
20340	500107	70012002	2027-09-22	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
20341	500107	70012002	2027-09-23	Thu	9	17.1	1.10	0.92	estimated	2026-04-03 20:28:26.428645
20342	500107	70012002	2027-09-24	Fri	9	19.7	1.10	1.06	estimated	2026-04-03 20:28:26.428645
20343	500107	70012002	2027-09-25	Sat	9	18.0	1.10	0.97	estimated	2026-04-03 20:28:26.428645
20344	500107	70012002	2027-09-26	Sun	9	19.5	1.10	1.05	estimated	2026-04-03 20:28:26.428645
20345	500107	70012002	2027-09-27	Mon	9	18.2	1.10	0.98	estimated	2026-04-03 20:28:26.428645
20346	500107	70012002	2027-09-28	Tue	9	21.0	1.10	1.13	estimated	2026-04-03 20:28:26.428645
20347	500107	70012002	2027-09-29	Wed	9	16.3	1.10	0.88	estimated	2026-04-03 20:28:26.428645
20348	500107	70012002	2027-09-30	Thu	9	17.1	1.10	0.92	estimated	2026-04-03 20:28:26.428645
20349	500107	70012002	2027-10-01	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
20350	500107	70012002	2027-10-02	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
20351	500107	70012002	2027-10-03	Sun	10	16.8	0.95	1.05	estimated	2026-04-03 20:28:26.428645
20352	500107	70012002	2027-10-04	Mon	10	15.7	0.95	0.98	estimated	2026-04-03 20:28:26.428645
20353	500107	70012002	2027-10-05	Tue	10	18.1	0.95	1.13	estimated	2026-04-03 20:28:26.428645
20354	500107	70012002	2027-10-06	Wed	10	14.1	0.95	0.88	estimated	2026-04-03 20:28:26.428645
20355	500107	70012002	2027-10-07	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
20356	500107	70012002	2027-10-08	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
20357	500107	70012002	2027-10-09	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
20358	500107	70012002	2027-10-10	Sun	10	16.8	0.95	1.05	estimated	2026-04-03 20:28:26.428645
20359	500107	70012002	2027-10-11	Mon	10	15.7	0.95	0.98	estimated	2026-04-03 20:28:26.428645
20360	500107	70012002	2027-10-12	Tue	10	18.1	0.95	1.13	estimated	2026-04-03 20:28:26.428645
20361	500107	70012002	2027-10-13	Wed	10	14.1	0.95	0.88	estimated	2026-04-03 20:28:26.428645
20362	500107	70012002	2027-10-14	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
20363	500107	70012002	2027-10-15	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
20364	500107	70012002	2027-10-16	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
20365	500107	70012002	2027-10-17	Sun	10	16.8	0.95	1.05	estimated	2026-04-03 20:28:26.428645
20366	500107	70012002	2027-10-18	Mon	10	15.7	0.95	0.98	estimated	2026-04-03 20:28:26.428645
20367	500107	70012002	2027-10-19	Tue	10	18.1	0.95	1.13	estimated	2026-04-03 20:28:26.428645
20368	500107	70012002	2027-10-20	Wed	10	14.1	0.95	0.88	estimated	2026-04-03 20:28:26.428645
20369	500107	70012002	2027-10-21	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
20370	500107	70012002	2027-10-22	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
20371	500107	70012002	2027-10-23	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
20372	500107	70012002	2027-10-24	Sun	10	16.8	0.95	1.05	estimated	2026-04-03 20:28:26.428645
20373	500107	70012002	2027-10-25	Mon	10	15.7	0.95	0.98	estimated	2026-04-03 20:28:26.428645
20374	500107	70012002	2027-10-26	Tue	10	18.1	0.95	1.13	estimated	2026-04-03 20:28:26.428645
20375	500107	70012002	2027-10-27	Wed	10	14.1	0.95	0.88	estimated	2026-04-03 20:28:26.428645
20376	500107	70012002	2027-10-28	Thu	10	14.8	0.95	0.92	estimated	2026-04-03 20:28:26.428645
20377	500107	70012002	2027-10-29	Fri	10	17.0	0.95	1.06	estimated	2026-04-03 20:28:26.428645
20378	500107	70012002	2027-10-30	Sat	10	15.6	0.95	0.97	estimated	2026-04-03 20:28:26.428645
20379	500107	70012002	2027-10-31	Sun	10	16.8	0.95	1.05	estimated	2026-04-03 20:28:26.428645
20380	500107	70012002	2027-11-01	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20381	500107	70012002	2027-11-02	Tue	11	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
20382	500107	70012002	2027-11-03	Wed	11	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
20383	500107	70012002	2027-11-04	Thu	11	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
20384	500107	70012002	2027-11-05	Fri	11	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
20385	500107	70012002	2027-11-06	Sat	11	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
20386	500107	70012002	2027-11-07	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20387	500107	70012002	2027-11-08	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20388	500107	70012002	2027-11-09	Tue	11	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
20389	500107	70012002	2027-11-10	Wed	11	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
20390	500107	70012002	2027-11-11	Thu	11	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
20391	500107	70012002	2027-11-12	Fri	11	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
20392	500107	70012002	2027-11-13	Sat	11	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
20393	500107	70012002	2027-11-14	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20394	500107	70012002	2027-11-15	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20395	500107	70012002	2027-11-16	Tue	11	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
20396	500107	70012002	2027-11-17	Wed	11	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
20397	500107	70012002	2027-11-18	Thu	11	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
20398	500107	70012002	2027-11-19	Fri	11	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
20399	500107	70012002	2027-11-20	Sat	11	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
20400	500107	70012002	2027-11-21	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20401	500107	70012002	2027-11-22	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20402	500107	70012002	2027-11-23	Tue	11	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
20403	500107	70012002	2027-11-24	Wed	11	16.0	1.08	0.88	estimated	2026-04-03 20:28:26.428645
20404	500107	70012002	2027-11-25	Thu	11	16.8	1.08	0.92	estimated	2026-04-03 20:28:26.428645
20405	500107	70012002	2027-11-26	Fri	11	19.3	1.08	1.06	estimated	2026-04-03 20:28:26.428645
20406	500107	70012002	2027-11-27	Sat	11	17.7	1.08	0.97	estimated	2026-04-03 20:28:26.428645
20407	500107	70012002	2027-11-28	Sun	11	19.1	1.08	1.05	estimated	2026-04-03 20:28:26.428645
20408	500107	70012002	2027-11-29	Mon	11	17.9	1.08	0.98	estimated	2026-04-03 20:28:26.428645
20409	500107	70012002	2027-11-30	Tue	11	20.6	1.08	1.13	estimated	2026-04-03 20:28:26.428645
20410	500107	70012002	2027-12-01	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
20411	500107	70012002	2027-12-02	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
20412	500107	70012002	2027-12-03	Fri	12	15.9	0.89	1.06	estimated	2026-04-03 20:28:26.428645
20413	500107	70012002	2027-12-04	Sat	12	14.6	0.89	0.97	estimated	2026-04-03 20:28:26.428645
20414	500107	70012002	2027-12-05	Sun	12	15.8	0.89	1.05	estimated	2026-04-03 20:28:26.428645
20415	500107	70012002	2027-12-06	Mon	12	14.7	0.89	0.98	estimated	2026-04-03 20:28:26.428645
20416	500107	70012002	2027-12-07	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
20417	500107	70012002	2027-12-08	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
20418	500107	70012002	2027-12-09	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
20419	500107	70012002	2027-12-10	Fri	12	15.9	0.89	1.06	estimated	2026-04-03 20:28:26.428645
20420	500107	70012002	2027-12-11	Sat	12	14.6	0.89	0.97	estimated	2026-04-03 20:28:26.428645
20421	500107	70012002	2027-12-12	Sun	12	15.8	0.89	1.05	estimated	2026-04-03 20:28:26.428645
20422	500107	70012002	2027-12-13	Mon	12	14.7	0.89	0.98	estimated	2026-04-03 20:28:26.428645
20423	500107	70012002	2027-12-14	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
20424	500107	70012002	2027-12-15	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
20425	500107	70012002	2027-12-16	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
20426	500107	70012002	2027-12-17	Fri	12	15.9	0.89	1.06	estimated	2026-04-03 20:28:26.428645
20427	500107	70012002	2027-12-18	Sat	12	14.6	0.89	0.97	estimated	2026-04-03 20:28:26.428645
20428	500107	70012002	2027-12-19	Sun	12	15.8	0.89	1.05	estimated	2026-04-03 20:28:26.428645
20429	500107	70012002	2027-12-20	Mon	12	14.7	0.89	0.98	estimated	2026-04-03 20:28:26.428645
20430	500107	70012002	2027-12-21	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
20431	500107	70012002	2027-12-22	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
20432	500107	70012002	2027-12-23	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
20433	500107	70012002	2027-12-24	Fri	12	15.9	0.89	1.06	estimated	2026-04-03 20:28:26.428645
20434	500107	70012002	2027-12-25	Sat	12	14.6	0.89	0.97	estimated	2026-04-03 20:28:26.428645
20435	500107	70012002	2027-12-26	Sun	12	15.8	0.89	1.05	estimated	2026-04-03 20:28:26.428645
20436	500107	70012002	2027-12-27	Mon	12	14.7	0.89	0.98	estimated	2026-04-03 20:28:26.428645
20437	500107	70012002	2027-12-28	Tue	12	17.0	0.89	1.13	estimated	2026-04-03 20:28:26.428645
20438	500107	70012002	2027-12-29	Wed	12	13.2	0.89	0.88	estimated	2026-04-03 20:28:26.428645
20439	500107	70012002	2027-12-30	Thu	12	13.8	0.89	0.92	estimated	2026-04-03 20:28:26.428645
20440	500107	70012002	2027-12-31	Fri	12	15.9	0.89	1.06	estimated	2026-04-03 20:28:26.428645
1889	500107	70012004	2025-03-05	Wed	3	8.0	0.72	0.89	high	2026-03-04 16:35:31.486352
2310	500107	70012004	2026-04-30	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
2393	500107	70012004	2026-07-22	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2798	500107	70012004	2027-08-31	Tue	8	14.7	1.03	1.14	high	2026-03-04 16:35:31.486352
1826	500107	70012004	2025-01-01	Wed	1	16.7	1.50	0.89	medium	2026-03-04 16:35:31.486352
1827	500107	70012004	2025-01-02	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
1828	500107	70012004	2025-01-03	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
1829	500107	70012004	2025-01-04	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
1830	500107	70012004	2025-01-05	Sun	1	19.7	1.50	1.05	medium	2026-03-04 16:35:31.486352
1831	500107	70012004	2025-01-06	Mon	1	18.4	1.50	0.98	medium	2026-03-04 16:35:31.486352
1832	500107	70012004	2025-01-07	Tue	1	21.4	1.50	1.14	medium	2026-03-04 16:35:31.486352
1833	500107	70012004	2025-01-08	Wed	1	16.7	1.50	0.89	medium	2026-03-04 16:35:31.486352
1834	500107	70012004	2025-01-09	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
1835	500107	70012004	2025-01-10	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
1836	500107	70012004	2025-01-11	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
1837	500107	70012004	2025-01-12	Sun	1	19.7	1.50	1.05	medium	2026-03-04 16:35:31.486352
1838	500107	70012004	2025-01-13	Mon	1	18.4	1.50	0.98	medium	2026-03-04 16:35:31.486352
1839	500107	70012004	2025-01-14	Tue	1	21.4	1.50	1.14	medium	2026-03-04 16:35:31.486352
1840	500107	70012004	2025-01-15	Wed	1	16.7	1.50	0.89	medium	2026-03-04 16:35:31.486352
1841	500107	70012004	2025-01-16	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
1842	500107	70012004	2025-01-17	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
1843	500107	70012004	2025-01-18	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
1844	500107	70012004	2025-01-19	Sun	1	19.7	1.50	1.05	medium	2026-03-04 16:35:31.486352
1845	500107	70012004	2025-01-20	Mon	1	18.4	1.50	0.98	medium	2026-03-04 16:35:31.486352
1846	500107	70012004	2025-01-21	Tue	1	21.4	1.50	1.14	medium	2026-03-04 16:35:31.486352
1847	500107	70012004	2025-01-22	Wed	1	16.7	1.50	0.89	medium	2026-03-04 16:35:31.486352
1848	500107	70012004	2025-01-23	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
1849	500107	70012004	2025-01-24	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
1850	500107	70012004	2025-01-25	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
1851	500107	70012004	2025-01-26	Sun	1	19.7	1.50	1.05	medium	2026-03-04 16:35:31.486352
1852	500107	70012004	2025-01-27	Mon	1	18.4	1.50	0.98	medium	2026-03-04 16:35:31.486352
1853	500107	70012004	2025-01-28	Tue	1	21.4	1.50	1.14	medium	2026-03-04 16:35:31.486352
1854	500107	70012004	2025-01-29	Wed	1	16.7	1.50	0.89	medium	2026-03-04 16:35:31.486352
1855	500107	70012004	2025-01-30	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
1856	500107	70012004	2025-01-31	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
1857	500107	70012004	2025-02-01	Sat	2	13.8	1.15	0.96	high	2026-03-04 16:35:31.486352
1858	500107	70012004	2025-02-02	Sun	2	15.1	1.15	1.05	high	2026-03-04 16:35:31.486352
1859	500107	70012004	2025-02-03	Mon	2	14.1	1.15	0.98	high	2026-03-04 16:35:31.486352
1860	500107	70012004	2025-02-04	Tue	2	16.4	1.15	1.14	high	2026-03-04 16:35:31.486352
1861	500107	70012004	2025-02-05	Wed	2	12.8	1.15	0.89	high	2026-03-04 16:35:31.486352
1862	500107	70012004	2025-02-06	Thu	2	13.2	1.15	0.92	high	2026-03-04 16:35:31.486352
1863	500107	70012004	2025-02-07	Fri	2	15.3	1.15	1.06	high	2026-03-04 16:35:31.486352
1864	500107	70012004	2025-02-08	Sat	2	13.8	1.15	0.96	high	2026-03-04 16:35:31.486352
1865	500107	70012004	2025-02-09	Sun	2	15.1	1.15	1.05	high	2026-03-04 16:35:31.486352
1866	500107	70012004	2025-02-10	Mon	2	14.1	1.15	0.98	high	2026-03-04 16:35:31.486352
1867	500107	70012004	2025-02-11	Tue	2	16.4	1.15	1.14	high	2026-03-04 16:35:31.486352
1868	500107	70012004	2025-02-12	Wed	2	12.8	1.15	0.89	high	2026-03-04 16:35:31.486352
1869	500107	70012004	2025-02-13	Thu	2	13.2	1.15	0.92	high	2026-03-04 16:35:31.486352
1870	500107	70012004	2025-02-14	Fri	2	15.3	1.15	1.06	high	2026-03-04 16:35:31.486352
1871	500107	70012004	2025-02-15	Sat	2	13.8	1.15	0.96	high	2026-03-04 16:35:31.486352
1872	500107	70012004	2025-02-16	Sun	2	15.1	1.15	1.05	high	2026-03-04 16:35:31.486352
1873	500107	70012004	2025-02-17	Mon	2	14.1	1.15	0.98	high	2026-03-04 16:35:31.486352
1874	500107	70012004	2025-02-18	Tue	2	16.4	1.15	1.14	high	2026-03-04 16:35:31.486352
1875	500107	70012004	2025-02-19	Wed	2	12.8	1.15	0.89	high	2026-03-04 16:35:31.486352
1876	500107	70012004	2025-02-20	Thu	2	13.2	1.15	0.92	high	2026-03-04 16:35:31.486352
1877	500107	70012004	2025-02-21	Fri	2	15.3	1.15	1.06	high	2026-03-04 16:35:31.486352
1878	500107	70012004	2025-02-22	Sat	2	13.8	1.15	0.96	high	2026-03-04 16:35:31.486352
1879	500107	70012004	2025-02-23	Sun	2	15.1	1.15	1.05	high	2026-03-04 16:35:31.486352
1880	500107	70012004	2025-02-24	Mon	2	14.1	1.15	0.98	high	2026-03-04 16:35:31.486352
1881	500107	70012004	2025-02-25	Tue	2	16.4	1.15	1.14	high	2026-03-04 16:35:31.486352
1882	500107	70012004	2025-02-26	Wed	2	12.8	1.15	0.89	high	2026-03-04 16:35:31.486352
1883	500107	70012004	2025-02-27	Thu	2	13.2	1.15	0.92	high	2026-03-04 16:35:31.486352
1884	500107	70012004	2025-02-28	Fri	2	15.3	1.15	1.06	high	2026-03-04 16:35:31.486352
1885	500107	70012004	2025-03-01	Sat	3	8.6	0.72	0.96	high	2026-03-04 16:35:31.486352
1886	500107	70012004	2025-03-02	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
1887	500107	70012004	2025-03-03	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
1888	500107	70012004	2025-03-04	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
1890	500107	70012004	2025-03-06	Thu	3	8.3	0.72	0.92	high	2026-03-04 16:35:31.486352
1891	500107	70012004	2025-03-07	Fri	3	9.6	0.72	1.06	high	2026-03-04 16:35:31.486352
1892	500107	70012004	2025-03-08	Sat	3	8.6	0.72	0.96	high	2026-03-04 16:35:31.486352
1893	500107	70012004	2025-03-09	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
1894	500107	70012004	2025-03-10	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
1895	500107	70012004	2025-03-11	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
1896	500107	70012004	2025-03-12	Wed	3	8.0	0.72	0.89	high	2026-03-04 16:35:31.486352
1897	500107	70012004	2025-03-13	Thu	3	8.3	0.72	0.92	high	2026-03-04 16:35:31.486352
1898	500107	70012004	2025-03-14	Fri	3	9.6	0.72	1.06	high	2026-03-04 16:35:31.486352
1899	500107	70012004	2025-03-15	Sat	3	8.6	0.72	0.96	high	2026-03-04 16:35:31.486352
1900	500107	70012004	2025-03-16	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
1901	500107	70012004	2025-03-17	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
1902	500107	70012004	2025-03-18	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
1903	500107	70012004	2025-03-19	Wed	3	8.0	0.72	0.89	high	2026-03-04 16:35:31.486352
1904	500107	70012004	2025-03-20	Thu	3	8.3	0.72	0.92	high	2026-03-04 16:35:31.486352
1905	500107	70012004	2025-03-21	Fri	3	9.6	0.72	1.06	high	2026-03-04 16:35:31.486352
1906	500107	70012004	2025-03-22	Sat	3	8.6	0.72	0.96	high	2026-03-04 16:35:31.486352
1907	500107	70012004	2025-03-23	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
1908	500107	70012004	2025-03-24	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
1909	500107	70012004	2025-03-25	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
1910	500107	70012004	2025-03-26	Wed	3	8.0	0.72	0.89	high	2026-03-04 16:35:31.486352
1911	500107	70012004	2025-03-27	Thu	3	8.3	0.72	0.92	high	2026-03-04 16:35:31.486352
1912	500107	70012004	2025-03-28	Fri	3	9.6	0.72	1.06	high	2026-03-04 16:35:31.486352
1913	500107	70012004	2025-03-29	Sat	3	8.6	0.72	0.96	high	2026-03-04 16:35:31.486352
1914	500107	70012004	2025-03-30	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
1915	500107	70012004	2025-03-31	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
1916	500107	70012004	2025-04-01	Tue	4	14.3	1.00	1.14	estimated	2026-03-04 16:35:31.486352
1917	500107	70012004	2025-04-02	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
1918	500107	70012004	2025-04-03	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
1919	500107	70012004	2025-04-04	Fri	4	13.3	1.00	1.06	estimated	2026-03-04 16:35:31.486352
1920	500107	70012004	2025-04-05	Sat	4	12.0	1.00	0.96	estimated	2026-03-04 16:35:31.486352
1921	500107	70012004	2025-04-06	Sun	4	13.1	1.00	1.05	estimated	2026-03-04 16:35:31.486352
1922	500107	70012004	2025-04-07	Mon	4	12.3	1.00	0.98	estimated	2026-03-04 16:35:31.486352
1923	500107	70012004	2025-04-08	Tue	4	14.3	1.00	1.14	estimated	2026-03-04 16:35:31.486352
1924	500107	70012004	2025-04-09	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
1925	500107	70012004	2025-04-10	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
1926	500107	70012004	2025-04-11	Fri	4	13.3	1.00	1.06	estimated	2026-03-04 16:35:31.486352
1927	500107	70012004	2025-04-12	Sat	4	12.0	1.00	0.96	estimated	2026-03-04 16:35:31.486352
1928	500107	70012004	2025-04-13	Sun	4	13.1	1.00	1.05	estimated	2026-03-04 16:35:31.486352
1929	500107	70012004	2025-04-14	Mon	4	12.3	1.00	0.98	estimated	2026-03-04 16:35:31.486352
1930	500107	70012004	2025-04-15	Tue	4	14.3	1.00	1.14	estimated	2026-03-04 16:35:31.486352
1931	500107	70012004	2025-04-16	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
1932	500107	70012004	2025-04-17	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
1933	500107	70012004	2025-04-18	Fri	4	13.3	1.00	1.06	estimated	2026-03-04 16:35:31.486352
1934	500107	70012004	2025-04-19	Sat	4	12.0	1.00	0.96	estimated	2026-03-04 16:35:31.486352
1935	500107	70012004	2025-04-20	Sun	4	13.1	1.00	1.05	estimated	2026-03-04 16:35:31.486352
1936	500107	70012004	2025-04-21	Mon	4	12.3	1.00	0.98	estimated	2026-03-04 16:35:31.486352
1937	500107	70012004	2025-04-22	Tue	4	14.3	1.00	1.14	estimated	2026-03-04 16:35:31.486352
1938	500107	70012004	2025-04-23	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
1939	500107	70012004	2025-04-24	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
1940	500107	70012004	2025-04-25	Fri	4	13.3	1.00	1.06	estimated	2026-03-04 16:35:31.486352
1941	500107	70012004	2025-04-26	Sat	4	12.0	1.00	0.96	estimated	2026-03-04 16:35:31.486352
1942	500107	70012004	2025-04-27	Sun	4	13.1	1.00	1.05	estimated	2026-03-04 16:35:31.486352
1943	500107	70012004	2025-04-28	Mon	4	12.3	1.00	0.98	estimated	2026-03-04 16:35:31.486352
1944	500107	70012004	2025-04-29	Tue	4	14.3	1.00	1.14	estimated	2026-03-04 16:35:31.486352
1945	500107	70012004	2025-04-30	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
1946	500107	70012004	2025-05-01	Thu	5	12.7	1.10	0.92	medium	2026-03-04 16:35:31.486352
1947	500107	70012004	2025-05-02	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
1948	500107	70012004	2025-05-03	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
1949	500107	70012004	2025-05-04	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
1950	500107	70012004	2025-05-05	Mon	5	13.5	1.10	0.98	medium	2026-03-04 16:35:31.486352
1951	500107	70012004	2025-05-06	Tue	5	15.7	1.10	1.14	medium	2026-03-04 16:35:31.486352
1952	500107	70012004	2025-05-07	Wed	5	12.3	1.10	0.89	medium	2026-03-04 16:35:31.486352
1953	500107	70012004	2025-05-08	Thu	5	12.7	1.10	0.92	medium	2026-03-04 16:35:31.486352
1954	500107	70012004	2025-05-09	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
1955	500107	70012004	2025-05-10	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
1956	500107	70012004	2025-05-11	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
1957	500107	70012004	2025-05-12	Mon	5	13.5	1.10	0.98	medium	2026-03-04 16:35:31.486352
1958	500107	70012004	2025-05-13	Tue	5	15.7	1.10	1.14	medium	2026-03-04 16:35:31.486352
1959	500107	70012004	2025-05-14	Wed	5	12.3	1.10	0.89	medium	2026-03-04 16:35:31.486352
1960	500107	70012004	2025-05-15	Thu	5	12.7	1.10	0.92	medium	2026-03-04 16:35:31.486352
1961	500107	70012004	2025-05-16	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
1962	500107	70012004	2025-05-17	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
1963	500107	70012004	2025-05-18	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
1964	500107	70012004	2025-05-19	Mon	5	13.5	1.10	0.98	medium	2026-03-04 16:35:31.486352
1965	500107	70012004	2025-05-20	Tue	5	15.7	1.10	1.14	medium	2026-03-04 16:35:31.486352
1966	500107	70012004	2025-05-21	Wed	5	12.3	1.10	0.89	medium	2026-03-04 16:35:31.486352
1967	500107	70012004	2025-05-22	Thu	5	12.7	1.10	0.92	medium	2026-03-04 16:35:31.486352
1968	500107	70012004	2025-05-23	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
1969	500107	70012004	2025-05-24	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
1970	500107	70012004	2025-05-25	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
1971	500107	70012004	2025-05-26	Mon	5	13.5	1.10	0.98	medium	2026-03-04 16:35:31.486352
1972	500107	70012004	2025-05-27	Tue	5	15.7	1.10	1.14	medium	2026-03-04 16:35:31.486352
1973	500107	70012004	2025-05-28	Wed	5	12.3	1.10	0.89	medium	2026-03-04 16:35:31.486352
1974	500107	70012004	2025-05-29	Thu	5	12.7	1.10	0.92	medium	2026-03-04 16:35:31.486352
1975	500107	70012004	2025-05-30	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
1976	500107	70012004	2025-05-31	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
1977	500107	70012004	2025-06-01	Sun	6	10.4	0.79	1.05	high	2026-03-04 16:35:31.486352
1978	500107	70012004	2025-06-02	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
1979	500107	70012004	2025-06-03	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
1980	500107	70012004	2025-06-04	Wed	6	8.8	0.79	0.89	high	2026-03-04 16:35:31.486352
1981	500107	70012004	2025-06-05	Thu	6	9.1	0.79	0.92	high	2026-03-04 16:35:31.486352
1982	500107	70012004	2025-06-06	Fri	6	10.5	0.79	1.06	high	2026-03-04 16:35:31.486352
1983	500107	70012004	2025-06-07	Sat	6	9.5	0.79	0.96	high	2026-03-04 16:35:31.486352
1984	500107	70012004	2025-06-08	Sun	6	10.4	0.79	1.05	high	2026-03-04 16:35:31.486352
1985	500107	70012004	2025-06-09	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
1986	500107	70012004	2025-06-10	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
1987	500107	70012004	2025-06-11	Wed	6	8.8	0.79	0.89	high	2026-03-04 16:35:31.486352
1988	500107	70012004	2025-06-12	Thu	6	9.1	0.79	0.92	high	2026-03-04 16:35:31.486352
1989	500107	70012004	2025-06-13	Fri	6	10.5	0.79	1.06	high	2026-03-04 16:35:31.486352
1990	500107	70012004	2025-06-14	Sat	6	9.5	0.79	0.96	high	2026-03-04 16:35:31.486352
1991	500107	70012004	2025-06-15	Sun	6	10.4	0.79	1.05	high	2026-03-04 16:35:31.486352
1992	500107	70012004	2025-06-16	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
1993	500107	70012004	2025-06-17	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
1994	500107	70012004	2025-06-18	Wed	6	8.8	0.79	0.89	high	2026-03-04 16:35:31.486352
1995	500107	70012004	2025-06-19	Thu	6	9.1	0.79	0.92	high	2026-03-04 16:35:31.486352
1996	500107	70012004	2025-06-20	Fri	6	10.5	0.79	1.06	high	2026-03-04 16:35:31.486352
1997	500107	70012004	2025-06-21	Sat	6	9.5	0.79	0.96	high	2026-03-04 16:35:31.486352
1998	500107	70012004	2025-06-22	Sun	6	10.4	0.79	1.05	high	2026-03-04 16:35:31.486352
1999	500107	70012004	2025-06-23	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
2000	500107	70012004	2025-06-24	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
2001	500107	70012004	2025-06-25	Wed	6	8.8	0.79	0.89	high	2026-03-04 16:35:31.486352
2002	500107	70012004	2025-06-26	Thu	6	9.1	0.79	0.92	high	2026-03-04 16:35:31.486352
2003	500107	70012004	2025-06-27	Fri	6	10.5	0.79	1.06	high	2026-03-04 16:35:31.486352
2004	500107	70012004	2025-06-28	Sat	6	9.5	0.79	0.96	high	2026-03-04 16:35:31.486352
2005	500107	70012004	2025-06-29	Sun	6	10.4	0.79	1.05	high	2026-03-04 16:35:31.486352
2006	500107	70012004	2025-06-30	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
2007	500107	70012004	2025-07-01	Tue	7	14.1	0.99	1.14	high	2026-03-04 16:35:31.486352
2008	500107	70012004	2025-07-02	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2009	500107	70012004	2025-07-03	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2010	500107	70012004	2025-07-04	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2011	500107	70012004	2025-07-05	Sat	7	11.9	0.99	0.96	high	2026-03-04 16:35:31.486352
2012	500107	70012004	2025-07-06	Sun	7	13.0	0.99	1.05	high	2026-03-04 16:35:31.486352
2013	500107	70012004	2025-07-07	Mon	7	12.1	0.99	0.98	high	2026-03-04 16:35:31.486352
2014	500107	70012004	2025-07-08	Tue	7	14.1	0.99	1.14	high	2026-03-04 16:35:31.486352
2015	500107	70012004	2025-07-09	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2016	500107	70012004	2025-07-10	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2017	500107	70012004	2025-07-11	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2018	500107	70012004	2025-07-12	Sat	7	11.9	0.99	0.96	high	2026-03-04 16:35:31.486352
2019	500107	70012004	2025-07-13	Sun	7	13.0	0.99	1.05	high	2026-03-04 16:35:31.486352
2020	500107	70012004	2025-07-14	Mon	7	12.1	0.99	0.98	high	2026-03-04 16:35:31.486352
2021	500107	70012004	2025-07-15	Tue	7	14.1	0.99	1.14	high	2026-03-04 16:35:31.486352
2022	500107	70012004	2025-07-16	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2023	500107	70012004	2025-07-17	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2024	500107	70012004	2025-07-18	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2025	500107	70012004	2025-07-19	Sat	7	11.9	0.99	0.96	high	2026-03-04 16:35:31.486352
2026	500107	70012004	2025-07-20	Sun	7	13.0	0.99	1.05	high	2026-03-04 16:35:31.486352
2027	500107	70012004	2025-07-21	Mon	7	12.1	0.99	0.98	high	2026-03-04 16:35:31.486352
2028	500107	70012004	2025-07-22	Tue	7	14.1	0.99	1.14	high	2026-03-04 16:35:31.486352
2029	500107	70012004	2025-07-23	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2030	500107	70012004	2025-07-24	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2031	500107	70012004	2025-07-25	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2032	500107	70012004	2025-07-26	Sat	7	11.9	0.99	0.96	high	2026-03-04 16:35:31.486352
2033	500107	70012004	2025-07-27	Sun	7	13.0	0.99	1.05	high	2026-03-04 16:35:31.486352
2034	500107	70012004	2025-07-28	Mon	7	12.1	0.99	0.98	high	2026-03-04 16:35:31.486352
2035	500107	70012004	2025-07-29	Tue	7	14.1	0.99	1.14	high	2026-03-04 16:35:31.486352
2036	500107	70012004	2025-07-30	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2037	500107	70012004	2025-07-31	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2038	500107	70012004	2025-08-01	Fri	8	13.7	1.03	1.06	high	2026-03-04 16:35:31.486352
2039	500107	70012004	2025-08-02	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2040	500107	70012004	2025-08-03	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2041	500107	70012004	2025-08-04	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2042	500107	70012004	2025-08-05	Tue	8	14.7	1.03	1.14	high	2026-03-04 16:35:31.486352
2043	500107	70012004	2025-08-06	Wed	8	11.5	1.03	0.89	high	2026-03-04 16:35:31.486352
2044	500107	70012004	2025-08-07	Thu	8	11.9	1.03	0.92	high	2026-03-04 16:35:31.486352
2045	500107	70012004	2025-08-08	Fri	8	13.7	1.03	1.06	high	2026-03-04 16:35:31.486352
2046	500107	70012004	2025-08-09	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2047	500107	70012004	2025-08-10	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2048	500107	70012004	2025-08-11	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2049	500107	70012004	2025-08-12	Tue	8	14.7	1.03	1.14	high	2026-03-04 16:35:31.486352
2050	500107	70012004	2025-08-13	Wed	8	11.5	1.03	0.89	high	2026-03-04 16:35:31.486352
2051	500107	70012004	2025-08-14	Thu	8	11.9	1.03	0.92	high	2026-03-04 16:35:31.486352
2052	500107	70012004	2025-08-15	Fri	8	13.7	1.03	1.06	high	2026-03-04 16:35:31.486352
2053	500107	70012004	2025-08-16	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2054	500107	70012004	2025-08-17	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2055	500107	70012004	2025-08-18	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2056	500107	70012004	2025-08-19	Tue	8	14.7	1.03	1.14	high	2026-03-04 16:35:31.486352
2057	500107	70012004	2025-08-20	Wed	8	11.5	1.03	0.89	high	2026-03-04 16:35:31.486352
2058	500107	70012004	2025-08-21	Thu	8	11.9	1.03	0.92	high	2026-03-04 16:35:31.486352
2059	500107	70012004	2025-08-22	Fri	8	13.7	1.03	1.06	high	2026-03-04 16:35:31.486352
2060	500107	70012004	2025-08-23	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2061	500107	70012004	2025-08-24	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2062	500107	70012004	2025-08-25	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2063	500107	70012004	2025-08-26	Tue	8	14.7	1.03	1.14	high	2026-03-04 16:35:31.486352
2064	500107	70012004	2025-08-27	Wed	8	11.5	1.03	0.89	high	2026-03-04 16:35:31.486352
2065	500107	70012004	2025-08-28	Thu	8	11.9	1.03	0.92	high	2026-03-04 16:35:31.486352
2066	500107	70012004	2025-08-29	Fri	8	13.7	1.03	1.06	high	2026-03-04 16:35:31.486352
2067	500107	70012004	2025-08-30	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2068	500107	70012004	2025-08-31	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2069	500107	70012004	2025-09-01	Mon	9	13.7	1.12	0.98	high	2026-03-04 16:35:31.486352
2070	500107	70012004	2025-09-02	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2071	500107	70012004	2025-09-03	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2072	500107	70012004	2025-09-04	Thu	9	12.9	1.12	0.92	high	2026-03-04 16:35:31.486352
2073	500107	70012004	2025-09-05	Fri	9	14.9	1.12	1.06	high	2026-03-04 16:35:31.486352
2074	500107	70012004	2025-09-06	Sat	9	13.5	1.12	0.96	high	2026-03-04 16:35:31.486352
2075	500107	70012004	2025-09-07	Sun	9	14.7	1.12	1.05	high	2026-03-04 16:35:31.486352
2076	500107	70012004	2025-09-08	Mon	9	13.7	1.12	0.98	high	2026-03-04 16:35:31.486352
2077	500107	70012004	2025-09-09	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2078	500107	70012004	2025-09-10	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2079	500107	70012004	2025-09-11	Thu	9	12.9	1.12	0.92	high	2026-03-04 16:35:31.486352
2080	500107	70012004	2025-09-12	Fri	9	14.9	1.12	1.06	high	2026-03-04 16:35:31.486352
2081	500107	70012004	2025-09-13	Sat	9	13.5	1.12	0.96	high	2026-03-04 16:35:31.486352
2082	500107	70012004	2025-09-14	Sun	9	14.7	1.12	1.05	high	2026-03-04 16:35:31.486352
2083	500107	70012004	2025-09-15	Mon	9	13.7	1.12	0.98	high	2026-03-04 16:35:31.486352
2084	500107	70012004	2025-09-16	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2085	500107	70012004	2025-09-17	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2086	500107	70012004	2025-09-18	Thu	9	12.9	1.12	0.92	high	2026-03-04 16:35:31.486352
2087	500107	70012004	2025-09-19	Fri	9	14.9	1.12	1.06	high	2026-03-04 16:35:31.486352
2088	500107	70012004	2025-09-20	Sat	9	13.5	1.12	0.96	high	2026-03-04 16:35:31.486352
2089	500107	70012004	2025-09-21	Sun	9	14.7	1.12	1.05	high	2026-03-04 16:35:31.486352
2090	500107	70012004	2025-09-22	Mon	9	13.7	1.12	0.98	high	2026-03-04 16:35:31.486352
2091	500107	70012004	2025-09-23	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2092	500107	70012004	2025-09-24	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2093	500107	70012004	2025-09-25	Thu	9	12.9	1.12	0.92	high	2026-03-04 16:35:31.486352
2094	500107	70012004	2025-09-26	Fri	9	14.9	1.12	1.06	high	2026-03-04 16:35:31.486352
2095	500107	70012004	2025-09-27	Sat	9	13.5	1.12	0.96	high	2026-03-04 16:35:31.486352
2096	500107	70012004	2025-09-28	Sun	9	14.7	1.12	1.05	high	2026-03-04 16:35:31.486352
2097	500107	70012004	2025-09-29	Mon	9	13.7	1.12	0.98	high	2026-03-04 16:35:31.486352
2098	500107	70012004	2025-09-30	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2099	500107	70012004	2025-10-01	Wed	10	10.5	0.94	0.89	high	2026-03-04 16:35:31.486352
2100	500107	70012004	2025-10-02	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2101	500107	70012004	2025-10-03	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2102	500107	70012004	2025-10-04	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2103	500107	70012004	2025-10-05	Sun	10	12.4	0.94	1.05	high	2026-03-04 16:35:31.486352
2104	500107	70012004	2025-10-06	Mon	10	11.5	0.94	0.98	high	2026-03-04 16:35:31.486352
2105	500107	70012004	2025-10-07	Tue	10	13.4	0.94	1.14	high	2026-03-04 16:35:31.486352
2106	500107	70012004	2025-10-08	Wed	10	10.5	0.94	0.89	high	2026-03-04 16:35:31.486352
2107	500107	70012004	2025-10-09	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2108	500107	70012004	2025-10-10	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2109	500107	70012004	2025-10-11	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2110	500107	70012004	2025-10-12	Sun	10	12.4	0.94	1.05	high	2026-03-04 16:35:31.486352
2111	500107	70012004	2025-10-13	Mon	10	11.5	0.94	0.98	high	2026-03-04 16:35:31.486352
2112	500107	70012004	2025-10-14	Tue	10	13.4	0.94	1.14	high	2026-03-04 16:35:31.486352
2113	500107	70012004	2025-10-15	Wed	10	10.5	0.94	0.89	high	2026-03-04 16:35:31.486352
2114	500107	70012004	2025-10-16	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2115	500107	70012004	2025-10-17	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2116	500107	70012004	2025-10-18	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2117	500107	70012004	2025-10-19	Sun	10	12.4	0.94	1.05	high	2026-03-04 16:35:31.486352
2118	500107	70012004	2025-10-20	Mon	10	11.5	0.94	0.98	high	2026-03-04 16:35:31.486352
2119	500107	70012004	2025-10-21	Tue	10	13.4	0.94	1.14	high	2026-03-04 16:35:31.486352
2120	500107	70012004	2025-10-22	Wed	10	10.5	0.94	0.89	high	2026-03-04 16:35:31.486352
2121	500107	70012004	2025-10-23	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2122	500107	70012004	2025-10-24	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2123	500107	70012004	2025-10-25	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2124	500107	70012004	2025-10-26	Sun	10	12.4	0.94	1.05	high	2026-03-04 16:35:31.486352
2125	500107	70012004	2025-10-27	Mon	10	11.5	0.94	0.98	high	2026-03-04 16:35:31.486352
2126	500107	70012004	2025-10-28	Tue	10	13.4	0.94	1.14	high	2026-03-04 16:35:31.486352
2127	500107	70012004	2025-10-29	Wed	10	10.5	0.94	0.89	high	2026-03-04 16:35:31.486352
2128	500107	70012004	2025-10-30	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2129	500107	70012004	2025-10-31	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2130	500107	70012004	2025-11-01	Sat	11	12.5	1.04	0.96	high	2026-03-04 16:35:31.486352
2131	500107	70012004	2025-11-02	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2132	500107	70012004	2025-11-03	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2133	500107	70012004	2025-11-04	Tue	11	14.8	1.04	1.14	high	2026-03-04 16:35:31.486352
2134	500107	70012004	2025-11-05	Wed	11	11.6	1.04	0.89	high	2026-03-04 16:35:31.486352
2135	500107	70012004	2025-11-06	Thu	11	12.0	1.04	0.92	high	2026-03-04 16:35:31.486352
2136	500107	70012004	2025-11-07	Fri	11	13.8	1.04	1.06	high	2026-03-04 16:35:31.486352
2137	500107	70012004	2025-11-08	Sat	11	12.5	1.04	0.96	high	2026-03-04 16:35:31.486352
2138	500107	70012004	2025-11-09	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2139	500107	70012004	2025-11-10	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2140	500107	70012004	2025-11-11	Tue	11	14.8	1.04	1.14	high	2026-03-04 16:35:31.486352
2141	500107	70012004	2025-11-12	Wed	11	11.6	1.04	0.89	high	2026-03-04 16:35:31.486352
2142	500107	70012004	2025-11-13	Thu	11	12.0	1.04	0.92	high	2026-03-04 16:35:31.486352
2143	500107	70012004	2025-11-14	Fri	11	13.8	1.04	1.06	high	2026-03-04 16:35:31.486352
2144	500107	70012004	2025-11-15	Sat	11	12.5	1.04	0.96	high	2026-03-04 16:35:31.486352
2145	500107	70012004	2025-11-16	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2146	500107	70012004	2025-11-17	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2147	500107	70012004	2025-11-18	Tue	11	14.8	1.04	1.14	high	2026-03-04 16:35:31.486352
2148	500107	70012004	2025-11-19	Wed	11	11.6	1.04	0.89	high	2026-03-04 16:35:31.486352
2149	500107	70012004	2025-11-20	Thu	11	12.0	1.04	0.92	high	2026-03-04 16:35:31.486352
2150	500107	70012004	2025-11-21	Fri	11	13.8	1.04	1.06	high	2026-03-04 16:35:31.486352
2151	500107	70012004	2025-11-22	Sat	11	12.5	1.04	0.96	high	2026-03-04 16:35:31.486352
2152	500107	70012004	2025-11-23	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2153	500107	70012004	2025-11-24	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2154	500107	70012004	2025-11-25	Tue	11	14.8	1.04	1.14	high	2026-03-04 16:35:31.486352
2155	500107	70012004	2025-11-26	Wed	11	11.6	1.04	0.89	high	2026-03-04 16:35:31.486352
2156	500107	70012004	2025-11-27	Thu	11	12.0	1.04	0.92	high	2026-03-04 16:35:31.486352
2157	500107	70012004	2025-11-28	Fri	11	13.8	1.04	1.06	high	2026-03-04 16:35:31.486352
2158	500107	70012004	2025-11-29	Sat	11	12.5	1.04	0.96	high	2026-03-04 16:35:31.486352
2159	500107	70012004	2025-11-30	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2160	500107	70012004	2025-12-01	Mon	12	11.2	0.91	0.98	medium	2026-03-04 16:35:31.486352
2161	500107	70012004	2025-12-02	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2162	500107	70012004	2025-12-03	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2163	500107	70012004	2025-12-04	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2164	500107	70012004	2025-12-05	Fri	12	12.1	0.91	1.06	medium	2026-03-04 16:35:31.486352
2165	500107	70012004	2025-12-06	Sat	12	10.9	0.91	0.96	medium	2026-03-04 16:35:31.486352
2166	500107	70012004	2025-12-07	Sun	12	12.0	0.91	1.05	medium	2026-03-04 16:35:31.486352
2167	500107	70012004	2025-12-08	Mon	12	11.2	0.91	0.98	medium	2026-03-04 16:35:31.486352
2168	500107	70012004	2025-12-09	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2169	500107	70012004	2025-12-10	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2170	500107	70012004	2025-12-11	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2171	500107	70012004	2025-12-12	Fri	12	12.1	0.91	1.06	medium	2026-03-04 16:35:31.486352
2172	500107	70012004	2025-12-13	Sat	12	10.9	0.91	0.96	medium	2026-03-04 16:35:31.486352
2173	500107	70012004	2025-12-14	Sun	12	12.0	0.91	1.05	medium	2026-03-04 16:35:31.486352
2174	500107	70012004	2025-12-15	Mon	12	11.2	0.91	0.98	medium	2026-03-04 16:35:31.486352
2175	500107	70012004	2025-12-16	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2176	500107	70012004	2025-12-17	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2177	500107	70012004	2025-12-18	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2178	500107	70012004	2025-12-19	Fri	12	12.1	0.91	1.06	medium	2026-03-04 16:35:31.486352
2179	500107	70012004	2025-12-20	Sat	12	10.9	0.91	0.96	medium	2026-03-04 16:35:31.486352
2180	500107	70012004	2025-12-21	Sun	12	12.0	0.91	1.05	medium	2026-03-04 16:35:31.486352
2181	500107	70012004	2025-12-22	Mon	12	11.2	0.91	0.98	medium	2026-03-04 16:35:31.486352
2182	500107	70012004	2025-12-23	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2183	500107	70012004	2025-12-24	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2184	500107	70012004	2025-12-25	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2185	500107	70012004	2025-12-26	Fri	12	12.1	0.91	1.06	medium	2026-03-04 16:35:31.486352
2186	500107	70012004	2025-12-27	Sat	12	10.9	0.91	0.96	medium	2026-03-04 16:35:31.486352
2187	500107	70012004	2025-12-28	Sun	12	12.0	0.91	1.05	medium	2026-03-04 16:35:31.486352
2188	500107	70012004	2025-12-29	Mon	12	11.2	0.91	0.98	medium	2026-03-04 16:35:31.486352
2189	500107	70012004	2025-12-30	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2190	500107	70012004	2025-12-31	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2191	500107	70012004	2026-01-01	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
2192	500107	70012004	2026-01-02	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
2193	500107	70012004	2026-01-03	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
2194	500107	70012004	2026-01-04	Sun	1	19.7	1.50	1.05	medium	2026-03-04 16:35:31.486352
2195	500107	70012004	2026-01-05	Mon	1	18.4	1.50	0.98	medium	2026-03-04 16:35:31.486352
2196	500107	70012004	2026-01-06	Tue	1	21.4	1.50	1.14	medium	2026-03-04 16:35:31.486352
2197	500107	70012004	2026-01-07	Wed	1	16.7	1.50	0.89	medium	2026-03-04 16:35:31.486352
2198	500107	70012004	2026-01-08	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
2199	500107	70012004	2026-01-09	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
2200	500107	70012004	2026-01-10	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
2201	500107	70012004	2026-01-11	Sun	1	19.7	1.50	1.05	medium	2026-03-04 16:35:31.486352
2202	500107	70012004	2026-01-12	Mon	1	18.4	1.50	0.98	medium	2026-03-04 16:35:31.486352
2203	500107	70012004	2026-01-13	Tue	1	21.4	1.50	1.14	medium	2026-03-04 16:35:31.486352
2204	500107	70012004	2026-01-14	Wed	1	16.7	1.50	0.89	medium	2026-03-04 16:35:31.486352
2205	500107	70012004	2026-01-15	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
2206	500107	70012004	2026-01-16	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
2207	500107	70012004	2026-01-17	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
2208	500107	70012004	2026-01-18	Sun	1	19.7	1.50	1.05	medium	2026-03-04 16:35:31.486352
2209	500107	70012004	2026-01-19	Mon	1	18.4	1.50	0.98	medium	2026-03-04 16:35:31.486352
2210	500107	70012004	2026-01-20	Tue	1	21.4	1.50	1.14	medium	2026-03-04 16:35:31.486352
2211	500107	70012004	2026-01-21	Wed	1	16.7	1.50	0.89	medium	2026-03-04 16:35:31.486352
2212	500107	70012004	2026-01-22	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
2213	500107	70012004	2026-01-23	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
2214	500107	70012004	2026-01-24	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
2215	500107	70012004	2026-01-25	Sun	1	19.7	1.50	1.05	medium	2026-03-04 16:35:31.486352
2216	500107	70012004	2026-01-26	Mon	1	18.4	1.50	0.98	medium	2026-03-04 16:35:31.486352
2217	500107	70012004	2026-01-27	Tue	1	21.4	1.50	1.14	medium	2026-03-04 16:35:31.486352
2218	500107	70012004	2026-01-28	Wed	1	16.7	1.50	0.89	medium	2026-03-04 16:35:31.486352
2219	500107	70012004	2026-01-29	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
2220	500107	70012004	2026-01-30	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
2221	500107	70012004	2026-01-31	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
2222	500107	70012004	2026-02-01	Sun	2	15.1	1.15	1.05	high	2026-03-04 16:35:31.486352
2223	500107	70012004	2026-02-02	Mon	2	14.1	1.15	0.98	high	2026-03-04 16:35:31.486352
2224	500107	70012004	2026-02-03	Tue	2	16.4	1.15	1.14	high	2026-03-04 16:35:31.486352
2225	500107	70012004	2026-02-04	Wed	2	12.8	1.15	0.89	high	2026-03-04 16:35:31.486352
2226	500107	70012004	2026-02-05	Thu	2	13.2	1.15	0.92	high	2026-03-04 16:35:31.486352
2227	500107	70012004	2026-02-06	Fri	2	15.3	1.15	1.06	high	2026-03-04 16:35:31.486352
2228	500107	70012004	2026-02-07	Sat	2	13.8	1.15	0.96	high	2026-03-04 16:35:31.486352
2229	500107	70012004	2026-02-08	Sun	2	15.1	1.15	1.05	high	2026-03-04 16:35:31.486352
2230	500107	70012004	2026-02-09	Mon	2	14.1	1.15	0.98	high	2026-03-04 16:35:31.486352
2231	500107	70012004	2026-02-10	Tue	2	16.4	1.15	1.14	high	2026-03-04 16:35:31.486352
2232	500107	70012004	2026-02-11	Wed	2	12.8	1.15	0.89	high	2026-03-04 16:35:31.486352
2233	500107	70012004	2026-02-12	Thu	2	13.2	1.15	0.92	high	2026-03-04 16:35:31.486352
2234	500107	70012004	2026-02-13	Fri	2	15.3	1.15	1.06	high	2026-03-04 16:35:31.486352
2235	500107	70012004	2026-02-14	Sat	2	13.8	1.15	0.96	high	2026-03-04 16:35:31.486352
2236	500107	70012004	2026-02-15	Sun	2	15.1	1.15	1.05	high	2026-03-04 16:35:31.486352
2237	500107	70012004	2026-02-16	Mon	2	14.1	1.15	0.98	high	2026-03-04 16:35:31.486352
2238	500107	70012004	2026-02-17	Tue	2	16.4	1.15	1.14	high	2026-03-04 16:35:31.486352
2239	500107	70012004	2026-02-18	Wed	2	12.8	1.15	0.89	high	2026-03-04 16:35:31.486352
2240	500107	70012004	2026-02-19	Thu	2	13.2	1.15	0.92	high	2026-03-04 16:35:31.486352
2241	500107	70012004	2026-02-20	Fri	2	15.3	1.15	1.06	high	2026-03-04 16:35:31.486352
2242	500107	70012004	2026-02-21	Sat	2	13.8	1.15	0.96	high	2026-03-04 16:35:31.486352
2243	500107	70012004	2026-02-22	Sun	2	15.1	1.15	1.05	high	2026-03-04 16:35:31.486352
2244	500107	70012004	2026-02-23	Mon	2	14.1	1.15	0.98	high	2026-03-04 16:35:31.486352
2245	500107	70012004	2026-02-24	Tue	2	16.4	1.15	1.14	high	2026-03-04 16:35:31.486352
2246	500107	70012004	2026-02-25	Wed	2	12.8	1.15	0.89	high	2026-03-04 16:35:31.486352
2247	500107	70012004	2026-02-26	Thu	2	13.2	1.15	0.92	high	2026-03-04 16:35:31.486352
2248	500107	70012004	2026-02-27	Fri	2	15.3	1.15	1.06	high	2026-03-04 16:35:31.486352
2249	500107	70012004	2026-02-28	Sat	2	13.8	1.15	0.96	high	2026-03-04 16:35:31.486352
2250	500107	70012004	2026-03-01	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
2251	500107	70012004	2026-03-02	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
2252	500107	70012004	2026-03-03	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
2253	500107	70012004	2026-03-04	Wed	3	8.0	0.72	0.89	high	2026-03-04 16:35:31.486352
2254	500107	70012004	2026-03-05	Thu	3	8.3	0.72	0.92	high	2026-03-04 16:35:31.486352
2255	500107	70012004	2026-03-06	Fri	3	9.6	0.72	1.06	high	2026-03-04 16:35:31.486352
2256	500107	70012004	2026-03-07	Sat	3	8.6	0.72	0.96	high	2026-03-04 16:35:31.486352
2257	500107	70012004	2026-03-08	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
2258	500107	70012004	2026-03-09	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
2259	500107	70012004	2026-03-10	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
2260	500107	70012004	2026-03-11	Wed	3	8.0	0.72	0.89	high	2026-03-04 16:35:31.486352
2261	500107	70012004	2026-03-12	Thu	3	8.3	0.72	0.92	high	2026-03-04 16:35:31.486352
2262	500107	70012004	2026-03-13	Fri	3	9.6	0.72	1.06	high	2026-03-04 16:35:31.486352
2263	500107	70012004	2026-03-14	Sat	3	8.6	0.72	0.96	high	2026-03-04 16:35:31.486352
2264	500107	70012004	2026-03-15	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
2265	500107	70012004	2026-03-16	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
2266	500107	70012004	2026-03-17	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
2267	500107	70012004	2026-03-18	Wed	3	8.0	0.72	0.89	high	2026-03-04 16:35:31.486352
2268	500107	70012004	2026-03-19	Thu	3	8.3	0.72	0.92	high	2026-03-04 16:35:31.486352
2269	500107	70012004	2026-03-20	Fri	3	9.6	0.72	1.06	high	2026-03-04 16:35:31.486352
2270	500107	70012004	2026-03-21	Sat	3	8.6	0.72	0.96	high	2026-03-04 16:35:31.486352
2271	500107	70012004	2026-03-22	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
2272	500107	70012004	2026-03-23	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
2273	500107	70012004	2026-03-24	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
2274	500107	70012004	2026-03-25	Wed	3	8.0	0.72	0.89	high	2026-03-04 16:35:31.486352
2275	500107	70012004	2026-03-26	Thu	3	8.3	0.72	0.92	high	2026-03-04 16:35:31.486352
2276	500107	70012004	2026-03-27	Fri	3	9.6	0.72	1.06	high	2026-03-04 16:35:31.486352
2277	500107	70012004	2026-03-28	Sat	3	8.6	0.72	0.96	high	2026-03-04 16:35:31.486352
2278	500107	70012004	2026-03-29	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
2279	500107	70012004	2026-03-30	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
2280	500107	70012004	2026-03-31	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
2281	500107	70012004	2026-04-01	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
2282	500107	70012004	2026-04-02	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
2283	500107	70012004	2026-04-03	Fri	4	13.3	1.00	1.06	estimated	2026-03-04 16:35:31.486352
2284	500107	70012004	2026-04-04	Sat	4	12.0	1.00	0.96	estimated	2026-03-04 16:35:31.486352
2285	500107	70012004	2026-04-05	Sun	4	13.1	1.00	1.05	estimated	2026-03-04 16:35:31.486352
2286	500107	70012004	2026-04-06	Mon	4	12.3	1.00	0.98	estimated	2026-03-04 16:35:31.486352
2287	500107	70012004	2026-04-07	Tue	4	14.3	1.00	1.14	estimated	2026-03-04 16:35:31.486352
2288	500107	70012004	2026-04-08	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
2289	500107	70012004	2026-04-09	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
2290	500107	70012004	2026-04-10	Fri	4	13.3	1.00	1.06	estimated	2026-03-04 16:35:31.486352
2291	500107	70012004	2026-04-11	Sat	4	12.0	1.00	0.96	estimated	2026-03-04 16:35:31.486352
2292	500107	70012004	2026-04-12	Sun	4	13.1	1.00	1.05	estimated	2026-03-04 16:35:31.486352
2293	500107	70012004	2026-04-13	Mon	4	12.3	1.00	0.98	estimated	2026-03-04 16:35:31.486352
2294	500107	70012004	2026-04-14	Tue	4	14.3	1.00	1.14	estimated	2026-03-04 16:35:31.486352
2295	500107	70012004	2026-04-15	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
2296	500107	70012004	2026-04-16	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
2297	500107	70012004	2026-04-17	Fri	4	13.3	1.00	1.06	estimated	2026-03-04 16:35:31.486352
2298	500107	70012004	2026-04-18	Sat	4	12.0	1.00	0.96	estimated	2026-03-04 16:35:31.486352
2299	500107	70012004	2026-04-19	Sun	4	13.1	1.00	1.05	estimated	2026-03-04 16:35:31.486352
2300	500107	70012004	2026-04-20	Mon	4	12.3	1.00	0.98	estimated	2026-03-04 16:35:31.486352
2301	500107	70012004	2026-04-21	Tue	4	14.3	1.00	1.14	estimated	2026-03-04 16:35:31.486352
2302	500107	70012004	2026-04-22	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
2303	500107	70012004	2026-04-23	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
2304	500107	70012004	2026-04-24	Fri	4	13.3	1.00	1.06	estimated	2026-03-04 16:35:31.486352
2305	500107	70012004	2026-04-25	Sat	4	12.0	1.00	0.96	estimated	2026-03-04 16:35:31.486352
2306	500107	70012004	2026-04-26	Sun	4	13.1	1.00	1.05	estimated	2026-03-04 16:35:31.486352
2307	500107	70012004	2026-04-27	Mon	4	12.3	1.00	0.98	estimated	2026-03-04 16:35:31.486352
2308	500107	70012004	2026-04-28	Tue	4	14.3	1.00	1.14	estimated	2026-03-04 16:35:31.486352
2309	500107	70012004	2026-04-29	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
2311	500107	70012004	2026-05-01	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
2312	500107	70012004	2026-05-02	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
2313	500107	70012004	2026-05-03	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
2314	500107	70012004	2026-05-04	Mon	5	13.5	1.10	0.98	medium	2026-03-04 16:35:31.486352
2315	500107	70012004	2026-05-05	Tue	5	15.7	1.10	1.14	medium	2026-03-04 16:35:31.486352
2316	500107	70012004	2026-05-06	Wed	5	12.3	1.10	0.89	medium	2026-03-04 16:35:31.486352
2317	500107	70012004	2026-05-07	Thu	5	12.7	1.10	0.92	medium	2026-03-04 16:35:31.486352
2318	500107	70012004	2026-05-08	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
2319	500107	70012004	2026-05-09	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
2320	500107	70012004	2026-05-10	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
2321	500107	70012004	2026-05-11	Mon	5	13.5	1.10	0.98	medium	2026-03-04 16:35:31.486352
2322	500107	70012004	2026-05-12	Tue	5	15.7	1.10	1.14	medium	2026-03-04 16:35:31.486352
2323	500107	70012004	2026-05-13	Wed	5	12.3	1.10	0.89	medium	2026-03-04 16:35:31.486352
2324	500107	70012004	2026-05-14	Thu	5	12.7	1.10	0.92	medium	2026-03-04 16:35:31.486352
2325	500107	70012004	2026-05-15	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
2326	500107	70012004	2026-05-16	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
2327	500107	70012004	2026-05-17	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
2328	500107	70012004	2026-05-18	Mon	5	13.5	1.10	0.98	medium	2026-03-04 16:35:31.486352
2329	500107	70012004	2026-05-19	Tue	5	15.7	1.10	1.14	medium	2026-03-04 16:35:31.486352
2330	500107	70012004	2026-05-20	Wed	5	12.3	1.10	0.89	medium	2026-03-04 16:35:31.486352
2331	500107	70012004	2026-05-21	Thu	5	12.7	1.10	0.92	medium	2026-03-04 16:35:31.486352
2332	500107	70012004	2026-05-22	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
2333	500107	70012004	2026-05-23	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
2334	500107	70012004	2026-05-24	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
2335	500107	70012004	2026-05-25	Mon	5	13.5	1.10	0.98	medium	2026-03-04 16:35:31.486352
2336	500107	70012004	2026-05-26	Tue	5	15.7	1.10	1.14	medium	2026-03-04 16:35:31.486352
2337	500107	70012004	2026-05-27	Wed	5	12.3	1.10	0.89	medium	2026-03-04 16:35:31.486352
2338	500107	70012004	2026-05-28	Thu	5	12.7	1.10	0.92	medium	2026-03-04 16:35:31.486352
2339	500107	70012004	2026-05-29	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
2340	500107	70012004	2026-05-30	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
2341	500107	70012004	2026-05-31	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
2342	500107	70012004	2026-06-01	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
2343	500107	70012004	2026-06-02	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
2344	500107	70012004	2026-06-03	Wed	6	8.8	0.79	0.89	high	2026-03-04 16:35:31.486352
2345	500107	70012004	2026-06-04	Thu	6	9.1	0.79	0.92	high	2026-03-04 16:35:31.486352
2346	500107	70012004	2026-06-05	Fri	6	10.5	0.79	1.06	high	2026-03-04 16:35:31.486352
2347	500107	70012004	2026-06-06	Sat	6	9.5	0.79	0.96	high	2026-03-04 16:35:31.486352
2348	500107	70012004	2026-06-07	Sun	6	10.4	0.79	1.05	high	2026-03-04 16:35:31.486352
2349	500107	70012004	2026-06-08	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
2350	500107	70012004	2026-06-09	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
2351	500107	70012004	2026-06-10	Wed	6	8.8	0.79	0.89	high	2026-03-04 16:35:31.486352
2352	500107	70012004	2026-06-11	Thu	6	9.1	0.79	0.92	high	2026-03-04 16:35:31.486352
2353	500107	70012004	2026-06-12	Fri	6	10.5	0.79	1.06	high	2026-03-04 16:35:31.486352
2354	500107	70012004	2026-06-13	Sat	6	9.5	0.79	0.96	high	2026-03-04 16:35:31.486352
2355	500107	70012004	2026-06-14	Sun	6	10.4	0.79	1.05	high	2026-03-04 16:35:31.486352
2356	500107	70012004	2026-06-15	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
2357	500107	70012004	2026-06-16	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
2358	500107	70012004	2026-06-17	Wed	6	8.8	0.79	0.89	high	2026-03-04 16:35:31.486352
2359	500107	70012004	2026-06-18	Thu	6	9.1	0.79	0.92	high	2026-03-04 16:35:31.486352
2360	500107	70012004	2026-06-19	Fri	6	10.5	0.79	1.06	high	2026-03-04 16:35:31.486352
2361	500107	70012004	2026-06-20	Sat	6	9.5	0.79	0.96	high	2026-03-04 16:35:31.486352
2362	500107	70012004	2026-06-21	Sun	6	10.4	0.79	1.05	high	2026-03-04 16:35:31.486352
2363	500107	70012004	2026-06-22	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
2364	500107	70012004	2026-06-23	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
2365	500107	70012004	2026-06-24	Wed	6	8.8	0.79	0.89	high	2026-03-04 16:35:31.486352
2366	500107	70012004	2026-06-25	Thu	6	9.1	0.79	0.92	high	2026-03-04 16:35:31.486352
2367	500107	70012004	2026-06-26	Fri	6	10.5	0.79	1.06	high	2026-03-04 16:35:31.486352
2368	500107	70012004	2026-06-27	Sat	6	9.5	0.79	0.96	high	2026-03-04 16:35:31.486352
2369	500107	70012004	2026-06-28	Sun	6	10.4	0.79	1.05	high	2026-03-04 16:35:31.486352
2370	500107	70012004	2026-06-29	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
2371	500107	70012004	2026-06-30	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
2372	500107	70012004	2026-07-01	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2373	500107	70012004	2026-07-02	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2374	500107	70012004	2026-07-03	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2375	500107	70012004	2026-07-04	Sat	7	11.9	0.99	0.96	high	2026-03-04 16:35:31.486352
2376	500107	70012004	2026-07-05	Sun	7	13.0	0.99	1.05	high	2026-03-04 16:35:31.486352
2377	500107	70012004	2026-07-06	Mon	7	12.1	0.99	0.98	high	2026-03-04 16:35:31.486352
2378	500107	70012004	2026-07-07	Tue	7	14.1	0.99	1.14	high	2026-03-04 16:35:31.486352
2379	500107	70012004	2026-07-08	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2380	500107	70012004	2026-07-09	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2381	500107	70012004	2026-07-10	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2382	500107	70012004	2026-07-11	Sat	7	11.9	0.99	0.96	high	2026-03-04 16:35:31.486352
2383	500107	70012004	2026-07-12	Sun	7	13.0	0.99	1.05	high	2026-03-04 16:35:31.486352
2384	500107	70012004	2026-07-13	Mon	7	12.1	0.99	0.98	high	2026-03-04 16:35:31.486352
2385	500107	70012004	2026-07-14	Tue	7	14.1	0.99	1.14	high	2026-03-04 16:35:31.486352
2386	500107	70012004	2026-07-15	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2387	500107	70012004	2026-07-16	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2388	500107	70012004	2026-07-17	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2389	500107	70012004	2026-07-18	Sat	7	11.9	0.99	0.96	high	2026-03-04 16:35:31.486352
2390	500107	70012004	2026-07-19	Sun	7	13.0	0.99	1.05	high	2026-03-04 16:35:31.486352
2391	500107	70012004	2026-07-20	Mon	7	12.1	0.99	0.98	high	2026-03-04 16:35:31.486352
2392	500107	70012004	2026-07-21	Tue	7	14.1	0.99	1.14	high	2026-03-04 16:35:31.486352
2394	500107	70012004	2026-07-23	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2395	500107	70012004	2026-07-24	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2396	500107	70012004	2026-07-25	Sat	7	11.9	0.99	0.96	high	2026-03-04 16:35:31.486352
2397	500107	70012004	2026-07-26	Sun	7	13.0	0.99	1.05	high	2026-03-04 16:35:31.486352
2398	500107	70012004	2026-07-27	Mon	7	12.1	0.99	0.98	high	2026-03-04 16:35:31.486352
2399	500107	70012004	2026-07-28	Tue	7	14.1	0.99	1.14	high	2026-03-04 16:35:31.486352
2400	500107	70012004	2026-07-29	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2401	500107	70012004	2026-07-30	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2402	500107	70012004	2026-07-31	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2403	500107	70012004	2026-08-01	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2404	500107	70012004	2026-08-02	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2405	500107	70012004	2026-08-03	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2406	500107	70012004	2026-08-04	Tue	8	14.7	1.03	1.14	high	2026-03-04 16:35:31.486352
2407	500107	70012004	2026-08-05	Wed	8	11.5	1.03	0.89	high	2026-03-04 16:35:31.486352
2408	500107	70012004	2026-08-06	Thu	8	11.9	1.03	0.92	high	2026-03-04 16:35:31.486352
2409	500107	70012004	2026-08-07	Fri	8	13.7	1.03	1.06	high	2026-03-04 16:35:31.486352
2410	500107	70012004	2026-08-08	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2411	500107	70012004	2026-08-09	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2412	500107	70012004	2026-08-10	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2413	500107	70012004	2026-08-11	Tue	8	14.7	1.03	1.14	high	2026-03-04 16:35:31.486352
2414	500107	70012004	2026-08-12	Wed	8	11.5	1.03	0.89	high	2026-03-04 16:35:31.486352
2415	500107	70012004	2026-08-13	Thu	8	11.9	1.03	0.92	high	2026-03-04 16:35:31.486352
2416	500107	70012004	2026-08-14	Fri	8	13.7	1.03	1.06	high	2026-03-04 16:35:31.486352
2417	500107	70012004	2026-08-15	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2418	500107	70012004	2026-08-16	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2419	500107	70012004	2026-08-17	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2420	500107	70012004	2026-08-18	Tue	8	14.7	1.03	1.14	high	2026-03-04 16:35:31.486352
2421	500107	70012004	2026-08-19	Wed	8	11.5	1.03	0.89	high	2026-03-04 16:35:31.486352
2422	500107	70012004	2026-08-20	Thu	8	11.9	1.03	0.92	high	2026-03-04 16:35:31.486352
2423	500107	70012004	2026-08-21	Fri	8	13.7	1.03	1.06	high	2026-03-04 16:35:31.486352
2424	500107	70012004	2026-08-22	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2425	500107	70012004	2026-08-23	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2426	500107	70012004	2026-08-24	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2427	500107	70012004	2026-08-25	Tue	8	14.7	1.03	1.14	high	2026-03-04 16:35:31.486352
2428	500107	70012004	2026-08-26	Wed	8	11.5	1.03	0.89	high	2026-03-04 16:35:31.486352
2429	500107	70012004	2026-08-27	Thu	8	11.9	1.03	0.92	high	2026-03-04 16:35:31.486352
2430	500107	70012004	2026-08-28	Fri	8	13.7	1.03	1.06	high	2026-03-04 16:35:31.486352
2431	500107	70012004	2026-08-29	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2432	500107	70012004	2026-08-30	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2433	500107	70012004	2026-08-31	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2434	500107	70012004	2026-09-01	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2435	500107	70012004	2026-09-02	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2436	500107	70012004	2026-09-03	Thu	9	12.9	1.12	0.92	high	2026-03-04 16:35:31.486352
2437	500107	70012004	2026-09-04	Fri	9	14.9	1.12	1.06	high	2026-03-04 16:35:31.486352
2438	500107	70012004	2026-09-05	Sat	9	13.5	1.12	0.96	high	2026-03-04 16:35:31.486352
2439	500107	70012004	2026-09-06	Sun	9	14.7	1.12	1.05	high	2026-03-04 16:35:31.486352
2440	500107	70012004	2026-09-07	Mon	9	13.7	1.12	0.98	high	2026-03-04 16:35:31.486352
2441	500107	70012004	2026-09-08	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2442	500107	70012004	2026-09-09	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2443	500107	70012004	2026-09-10	Thu	9	12.9	1.12	0.92	high	2026-03-04 16:35:31.486352
2444	500107	70012004	2026-09-11	Fri	9	14.9	1.12	1.06	high	2026-03-04 16:35:31.486352
2445	500107	70012004	2026-09-12	Sat	9	13.5	1.12	0.96	high	2026-03-04 16:35:31.486352
2446	500107	70012004	2026-09-13	Sun	9	14.7	1.12	1.05	high	2026-03-04 16:35:31.486352
2447	500107	70012004	2026-09-14	Mon	9	13.7	1.12	0.98	high	2026-03-04 16:35:31.486352
2448	500107	70012004	2026-09-15	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2449	500107	70012004	2026-09-16	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2450	500107	70012004	2026-09-17	Thu	9	12.9	1.12	0.92	high	2026-03-04 16:35:31.486352
2451	500107	70012004	2026-09-18	Fri	9	14.9	1.12	1.06	high	2026-03-04 16:35:31.486352
2452	500107	70012004	2026-09-19	Sat	9	13.5	1.12	0.96	high	2026-03-04 16:35:31.486352
2453	500107	70012004	2026-09-20	Sun	9	14.7	1.12	1.05	high	2026-03-04 16:35:31.486352
2454	500107	70012004	2026-09-21	Mon	9	13.7	1.12	0.98	high	2026-03-04 16:35:31.486352
2455	500107	70012004	2026-09-22	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2456	500107	70012004	2026-09-23	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2457	500107	70012004	2026-09-24	Thu	9	12.9	1.12	0.92	high	2026-03-04 16:35:31.486352
2458	500107	70012004	2026-09-25	Fri	9	14.9	1.12	1.06	high	2026-03-04 16:35:31.486352
2459	500107	70012004	2026-09-26	Sat	9	13.5	1.12	0.96	high	2026-03-04 16:35:31.486352
2460	500107	70012004	2026-09-27	Sun	9	14.7	1.12	1.05	high	2026-03-04 16:35:31.486352
2461	500107	70012004	2026-09-28	Mon	9	13.7	1.12	0.98	high	2026-03-04 16:35:31.486352
2462	500107	70012004	2026-09-29	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2463	500107	70012004	2026-09-30	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2464	500107	70012004	2026-10-01	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2465	500107	70012004	2026-10-02	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2466	500107	70012004	2026-10-03	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2467	500107	70012004	2026-10-04	Sun	10	12.4	0.94	1.05	high	2026-03-04 16:35:31.486352
2468	500107	70012004	2026-10-05	Mon	10	11.5	0.94	0.98	high	2026-03-04 16:35:31.486352
2469	500107	70012004	2026-10-06	Tue	10	13.4	0.94	1.14	high	2026-03-04 16:35:31.486352
2470	500107	70012004	2026-10-07	Wed	10	10.5	0.94	0.89	high	2026-03-04 16:35:31.486352
2471	500107	70012004	2026-10-08	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2472	500107	70012004	2026-10-09	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2473	500107	70012004	2026-10-10	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2474	500107	70012004	2026-10-11	Sun	10	12.4	0.94	1.05	high	2026-03-04 16:35:31.486352
2475	500107	70012004	2026-10-12	Mon	10	11.5	0.94	0.98	high	2026-03-04 16:35:31.486352
2476	500107	70012004	2026-10-13	Tue	10	13.4	0.94	1.14	high	2026-03-04 16:35:31.486352
2477	500107	70012004	2026-10-14	Wed	10	10.5	0.94	0.89	high	2026-03-04 16:35:31.486352
2478	500107	70012004	2026-10-15	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2479	500107	70012004	2026-10-16	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2480	500107	70012004	2026-10-17	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2481	500107	70012004	2026-10-18	Sun	10	12.4	0.94	1.05	high	2026-03-04 16:35:31.486352
2482	500107	70012004	2026-10-19	Mon	10	11.5	0.94	0.98	high	2026-03-04 16:35:31.486352
2483	500107	70012004	2026-10-20	Tue	10	13.4	0.94	1.14	high	2026-03-04 16:35:31.486352
2484	500107	70012004	2026-10-21	Wed	10	10.5	0.94	0.89	high	2026-03-04 16:35:31.486352
2485	500107	70012004	2026-10-22	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2486	500107	70012004	2026-10-23	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2487	500107	70012004	2026-10-24	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2488	500107	70012004	2026-10-25	Sun	10	12.4	0.94	1.05	high	2026-03-04 16:35:31.486352
2489	500107	70012004	2026-10-26	Mon	10	11.5	0.94	0.98	high	2026-03-04 16:35:31.486352
2490	500107	70012004	2026-10-27	Tue	10	13.4	0.94	1.14	high	2026-03-04 16:35:31.486352
2491	500107	70012004	2026-10-28	Wed	10	10.5	0.94	0.89	high	2026-03-04 16:35:31.486352
2492	500107	70012004	2026-10-29	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2493	500107	70012004	2026-10-30	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2494	500107	70012004	2026-10-31	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2495	500107	70012004	2026-11-01	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2496	500107	70012004	2026-11-02	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2497	500107	70012004	2026-11-03	Tue	11	14.8	1.04	1.14	high	2026-03-04 16:35:31.486352
2498	500107	70012004	2026-11-04	Wed	11	11.6	1.04	0.89	high	2026-03-04 16:35:31.486352
2499	500107	70012004	2026-11-05	Thu	11	12.0	1.04	0.92	high	2026-03-04 16:35:31.486352
2500	500107	70012004	2026-11-06	Fri	11	13.8	1.04	1.06	high	2026-03-04 16:35:31.486352
2501	500107	70012004	2026-11-07	Sat	11	12.5	1.04	0.96	high	2026-03-04 16:35:31.486352
2502	500107	70012004	2026-11-08	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2503	500107	70012004	2026-11-09	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2504	500107	70012004	2026-11-10	Tue	11	14.8	1.04	1.14	high	2026-03-04 16:35:31.486352
2505	500107	70012004	2026-11-11	Wed	11	11.6	1.04	0.89	high	2026-03-04 16:35:31.486352
2506	500107	70012004	2026-11-12	Thu	11	12.0	1.04	0.92	high	2026-03-04 16:35:31.486352
2507	500107	70012004	2026-11-13	Fri	11	13.8	1.04	1.06	high	2026-03-04 16:35:31.486352
2508	500107	70012004	2026-11-14	Sat	11	12.5	1.04	0.96	high	2026-03-04 16:35:31.486352
2509	500107	70012004	2026-11-15	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2510	500107	70012004	2026-11-16	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2511	500107	70012004	2026-11-17	Tue	11	14.8	1.04	1.14	high	2026-03-04 16:35:31.486352
2512	500107	70012004	2026-11-18	Wed	11	11.6	1.04	0.89	high	2026-03-04 16:35:31.486352
2513	500107	70012004	2026-11-19	Thu	11	12.0	1.04	0.92	high	2026-03-04 16:35:31.486352
2514	500107	70012004	2026-11-20	Fri	11	13.8	1.04	1.06	high	2026-03-04 16:35:31.486352
2515	500107	70012004	2026-11-21	Sat	11	12.5	1.04	0.96	high	2026-03-04 16:35:31.486352
2516	500107	70012004	2026-11-22	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2517	500107	70012004	2026-11-23	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2518	500107	70012004	2026-11-24	Tue	11	14.8	1.04	1.14	high	2026-03-04 16:35:31.486352
2519	500107	70012004	2026-11-25	Wed	11	11.6	1.04	0.89	high	2026-03-04 16:35:31.486352
2520	500107	70012004	2026-11-26	Thu	11	12.0	1.04	0.92	high	2026-03-04 16:35:31.486352
2521	500107	70012004	2026-11-27	Fri	11	13.8	1.04	1.06	high	2026-03-04 16:35:31.486352
2522	500107	70012004	2026-11-28	Sat	11	12.5	1.04	0.96	high	2026-03-04 16:35:31.486352
2523	500107	70012004	2026-11-29	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2524	500107	70012004	2026-11-30	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2525	500107	70012004	2026-12-01	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2526	500107	70012004	2026-12-02	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2527	500107	70012004	2026-12-03	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2528	500107	70012004	2026-12-04	Fri	12	12.1	0.91	1.06	medium	2026-03-04 16:35:31.486352
2529	500107	70012004	2026-12-05	Sat	12	10.9	0.91	0.96	medium	2026-03-04 16:35:31.486352
2530	500107	70012004	2026-12-06	Sun	12	12.0	0.91	1.05	medium	2026-03-04 16:35:31.486352
2531	500107	70012004	2026-12-07	Mon	12	11.2	0.91	0.98	medium	2026-03-04 16:35:31.486352
2532	500107	70012004	2026-12-08	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2533	500107	70012004	2026-12-09	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2534	500107	70012004	2026-12-10	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2535	500107	70012004	2026-12-11	Fri	12	12.1	0.91	1.06	medium	2026-03-04 16:35:31.486352
2536	500107	70012004	2026-12-12	Sat	12	10.9	0.91	0.96	medium	2026-03-04 16:35:31.486352
2537	500107	70012004	2026-12-13	Sun	12	12.0	0.91	1.05	medium	2026-03-04 16:35:31.486352
2538	500107	70012004	2026-12-14	Mon	12	11.2	0.91	0.98	medium	2026-03-04 16:35:31.486352
2539	500107	70012004	2026-12-15	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2540	500107	70012004	2026-12-16	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2541	500107	70012004	2026-12-17	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2542	500107	70012004	2026-12-18	Fri	12	12.1	0.91	1.06	medium	2026-03-04 16:35:31.486352
2543	500107	70012004	2026-12-19	Sat	12	10.9	0.91	0.96	medium	2026-03-04 16:35:31.486352
2544	500107	70012004	2026-12-20	Sun	12	12.0	0.91	1.05	medium	2026-03-04 16:35:31.486352
2545	500107	70012004	2026-12-21	Mon	12	11.2	0.91	0.98	medium	2026-03-04 16:35:31.486352
2546	500107	70012004	2026-12-22	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2547	500107	70012004	2026-12-23	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2548	500107	70012004	2026-12-24	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2549	500107	70012004	2026-12-25	Fri	12	12.1	0.91	1.06	medium	2026-03-04 16:35:31.486352
2550	500107	70012004	2026-12-26	Sat	12	10.9	0.91	0.96	medium	2026-03-04 16:35:31.486352
2551	500107	70012004	2026-12-27	Sun	12	12.0	0.91	1.05	medium	2026-03-04 16:35:31.486352
2552	500107	70012004	2026-12-28	Mon	12	11.2	0.91	0.98	medium	2026-03-04 16:35:31.486352
2553	500107	70012004	2026-12-29	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2554	500107	70012004	2026-12-30	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2555	500107	70012004	2026-12-31	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2556	500107	70012004	2027-01-01	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
2557	500107	70012004	2027-01-02	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
2558	500107	70012004	2027-01-03	Sun	1	19.7	1.50	1.05	medium	2026-03-04 16:35:31.486352
2559	500107	70012004	2027-01-04	Mon	1	18.4	1.50	0.98	medium	2026-03-04 16:35:31.486352
2560	500107	70012004	2027-01-05	Tue	1	21.4	1.50	1.14	medium	2026-03-04 16:35:31.486352
2561	500107	70012004	2027-01-06	Wed	1	16.7	1.50	0.89	medium	2026-03-04 16:35:31.486352
2562	500107	70012004	2027-01-07	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
2563	500107	70012004	2027-01-08	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
2564	500107	70012004	2027-01-09	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
2565	500107	70012004	2027-01-10	Sun	1	19.7	1.50	1.05	medium	2026-03-04 16:35:31.486352
2566	500107	70012004	2027-01-11	Mon	1	18.4	1.50	0.98	medium	2026-03-04 16:35:31.486352
2567	500107	70012004	2027-01-12	Tue	1	21.4	1.50	1.14	medium	2026-03-04 16:35:31.486352
2568	500107	70012004	2027-01-13	Wed	1	16.7	1.50	0.89	medium	2026-03-04 16:35:31.486352
2569	500107	70012004	2027-01-14	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
2570	500107	70012004	2027-01-15	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
2571	500107	70012004	2027-01-16	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
2572	500107	70012004	2027-01-17	Sun	1	19.7	1.50	1.05	medium	2026-03-04 16:35:31.486352
2573	500107	70012004	2027-01-18	Mon	1	18.4	1.50	0.98	medium	2026-03-04 16:35:31.486352
2574	500107	70012004	2027-01-19	Tue	1	21.4	1.50	1.14	medium	2026-03-04 16:35:31.486352
2575	500107	70012004	2027-01-20	Wed	1	16.7	1.50	0.89	medium	2026-03-04 16:35:31.486352
2576	500107	70012004	2027-01-21	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
2577	500107	70012004	2027-01-22	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
2578	500107	70012004	2027-01-23	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
2579	500107	70012004	2027-01-24	Sun	1	19.7	1.50	1.05	medium	2026-03-04 16:35:31.486352
2580	500107	70012004	2027-01-25	Mon	1	18.4	1.50	0.98	medium	2026-03-04 16:35:31.486352
2581	500107	70012004	2027-01-26	Tue	1	21.4	1.50	1.14	medium	2026-03-04 16:35:31.486352
2582	500107	70012004	2027-01-27	Wed	1	16.7	1.50	0.89	medium	2026-03-04 16:35:31.486352
2583	500107	70012004	2027-01-28	Thu	1	17.3	1.50	0.92	medium	2026-03-04 16:35:31.486352
2584	500107	70012004	2027-01-29	Fri	1	19.9	1.50	1.06	medium	2026-03-04 16:35:31.486352
2585	500107	70012004	2027-01-30	Sat	1	18.0	1.50	0.96	medium	2026-03-04 16:35:31.486352
2586	500107	70012004	2027-01-31	Sun	1	19.7	1.50	1.05	medium	2026-03-04 16:35:31.486352
2587	500107	70012004	2027-02-01	Mon	2	14.1	1.15	0.98	high	2026-03-04 16:35:31.486352
2588	500107	70012004	2027-02-02	Tue	2	16.4	1.15	1.14	high	2026-03-04 16:35:31.486352
2589	500107	70012004	2027-02-03	Wed	2	12.8	1.15	0.89	high	2026-03-04 16:35:31.486352
2590	500107	70012004	2027-02-04	Thu	2	13.2	1.15	0.92	high	2026-03-04 16:35:31.486352
2591	500107	70012004	2027-02-05	Fri	2	15.3	1.15	1.06	high	2026-03-04 16:35:31.486352
2592	500107	70012004	2027-02-06	Sat	2	13.8	1.15	0.96	high	2026-03-04 16:35:31.486352
2593	500107	70012004	2027-02-07	Sun	2	15.1	1.15	1.05	high	2026-03-04 16:35:31.486352
2594	500107	70012004	2027-02-08	Mon	2	14.1	1.15	0.98	high	2026-03-04 16:35:31.486352
2595	500107	70012004	2027-02-09	Tue	2	16.4	1.15	1.14	high	2026-03-04 16:35:31.486352
2596	500107	70012004	2027-02-10	Wed	2	12.8	1.15	0.89	high	2026-03-04 16:35:31.486352
2597	500107	70012004	2027-02-11	Thu	2	13.2	1.15	0.92	high	2026-03-04 16:35:31.486352
2598	500107	70012004	2027-02-12	Fri	2	15.3	1.15	1.06	high	2026-03-04 16:35:31.486352
2599	500107	70012004	2027-02-13	Sat	2	13.8	1.15	0.96	high	2026-03-04 16:35:31.486352
2600	500107	70012004	2027-02-14	Sun	2	15.1	1.15	1.05	high	2026-03-04 16:35:31.486352
2601	500107	70012004	2027-02-15	Mon	2	14.1	1.15	0.98	high	2026-03-04 16:35:31.486352
2602	500107	70012004	2027-02-16	Tue	2	16.4	1.15	1.14	high	2026-03-04 16:35:31.486352
2603	500107	70012004	2027-02-17	Wed	2	12.8	1.15	0.89	high	2026-03-04 16:35:31.486352
2604	500107	70012004	2027-02-18	Thu	2	13.2	1.15	0.92	high	2026-03-04 16:35:31.486352
2605	500107	70012004	2027-02-19	Fri	2	15.3	1.15	1.06	high	2026-03-04 16:35:31.486352
2606	500107	70012004	2027-02-20	Sat	2	13.8	1.15	0.96	high	2026-03-04 16:35:31.486352
2607	500107	70012004	2027-02-21	Sun	2	15.1	1.15	1.05	high	2026-03-04 16:35:31.486352
2608	500107	70012004	2027-02-22	Mon	2	14.1	1.15	0.98	high	2026-03-04 16:35:31.486352
2609	500107	70012004	2027-02-23	Tue	2	16.4	1.15	1.14	high	2026-03-04 16:35:31.486352
2610	500107	70012004	2027-02-24	Wed	2	12.8	1.15	0.89	high	2026-03-04 16:35:31.486352
2611	500107	70012004	2027-02-25	Thu	2	13.2	1.15	0.92	high	2026-03-04 16:35:31.486352
2612	500107	70012004	2027-02-26	Fri	2	15.3	1.15	1.06	high	2026-03-04 16:35:31.486352
2613	500107	70012004	2027-02-27	Sat	2	13.8	1.15	0.96	high	2026-03-04 16:35:31.486352
2614	500107	70012004	2027-02-28	Sun	2	15.1	1.15	1.05	high	2026-03-04 16:35:31.486352
2615	500107	70012004	2027-03-01	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
2616	500107	70012004	2027-03-02	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
2617	500107	70012004	2027-03-03	Wed	3	8.0	0.72	0.89	high	2026-03-04 16:35:31.486352
2618	500107	70012004	2027-03-04	Thu	3	8.3	0.72	0.92	high	2026-03-04 16:35:31.486352
2619	500107	70012004	2027-03-05	Fri	3	9.6	0.72	1.06	high	2026-03-04 16:35:31.486352
2620	500107	70012004	2027-03-06	Sat	3	8.6	0.72	0.96	high	2026-03-04 16:35:31.486352
2621	500107	70012004	2027-03-07	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
2622	500107	70012004	2027-03-08	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
2623	500107	70012004	2027-03-09	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
2624	500107	70012004	2027-03-10	Wed	3	8.0	0.72	0.89	high	2026-03-04 16:35:31.486352
2625	500107	70012004	2027-03-11	Thu	3	8.3	0.72	0.92	high	2026-03-04 16:35:31.486352
2626	500107	70012004	2027-03-12	Fri	3	9.6	0.72	1.06	high	2026-03-04 16:35:31.486352
2627	500107	70012004	2027-03-13	Sat	3	8.6	0.72	0.96	high	2026-03-04 16:35:31.486352
2628	500107	70012004	2027-03-14	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
2629	500107	70012004	2027-03-15	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
2630	500107	70012004	2027-03-16	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
2631	500107	70012004	2027-03-17	Wed	3	8.0	0.72	0.89	high	2026-03-04 16:35:31.486352
2632	500107	70012004	2027-03-18	Thu	3	8.3	0.72	0.92	high	2026-03-04 16:35:31.486352
2633	500107	70012004	2027-03-19	Fri	3	9.6	0.72	1.06	high	2026-03-04 16:35:31.486352
2634	500107	70012004	2027-03-20	Sat	3	8.6	0.72	0.96	high	2026-03-04 16:35:31.486352
2635	500107	70012004	2027-03-21	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
2636	500107	70012004	2027-03-22	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
2637	500107	70012004	2027-03-23	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
2638	500107	70012004	2027-03-24	Wed	3	8.0	0.72	0.89	high	2026-03-04 16:35:31.486352
2639	500107	70012004	2027-03-25	Thu	3	8.3	0.72	0.92	high	2026-03-04 16:35:31.486352
2640	500107	70012004	2027-03-26	Fri	3	9.6	0.72	1.06	high	2026-03-04 16:35:31.486352
2641	500107	70012004	2027-03-27	Sat	3	8.6	0.72	0.96	high	2026-03-04 16:35:31.486352
2642	500107	70012004	2027-03-28	Sun	3	9.5	0.72	1.05	high	2026-03-04 16:35:31.486352
2643	500107	70012004	2027-03-29	Mon	3	8.8	0.72	0.98	high	2026-03-04 16:35:31.486352
2644	500107	70012004	2027-03-30	Tue	3	10.3	0.72	1.14	high	2026-03-04 16:35:31.486352
2645	500107	70012004	2027-03-31	Wed	3	8.0	0.72	0.89	high	2026-03-04 16:35:31.486352
2646	500107	70012004	2027-04-01	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
2647	500107	70012004	2027-04-02	Fri	4	13.3	1.00	1.06	estimated	2026-03-04 16:35:31.486352
2648	500107	70012004	2027-04-03	Sat	4	12.0	1.00	0.96	estimated	2026-03-04 16:35:31.486352
2649	500107	70012004	2027-04-04	Sun	4	13.1	1.00	1.05	estimated	2026-03-04 16:35:31.486352
2650	500107	70012004	2027-04-05	Mon	4	12.3	1.00	0.98	estimated	2026-03-04 16:35:31.486352
2651	500107	70012004	2027-04-06	Tue	4	14.3	1.00	1.14	estimated	2026-03-04 16:35:31.486352
2652	500107	70012004	2027-04-07	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
2653	500107	70012004	2027-04-08	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
2654	500107	70012004	2027-04-09	Fri	4	13.3	1.00	1.06	estimated	2026-03-04 16:35:31.486352
2655	500107	70012004	2027-04-10	Sat	4	12.0	1.00	0.96	estimated	2026-03-04 16:35:31.486352
2656	500107	70012004	2027-04-11	Sun	4	13.1	1.00	1.05	estimated	2026-03-04 16:35:31.486352
2657	500107	70012004	2027-04-12	Mon	4	12.3	1.00	0.98	estimated	2026-03-04 16:35:31.486352
2658	500107	70012004	2027-04-13	Tue	4	14.3	1.00	1.14	estimated	2026-03-04 16:35:31.486352
2659	500107	70012004	2027-04-14	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
2660	500107	70012004	2027-04-15	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
2661	500107	70012004	2027-04-16	Fri	4	13.3	1.00	1.06	estimated	2026-03-04 16:35:31.486352
2662	500107	70012004	2027-04-17	Sat	4	12.0	1.00	0.96	estimated	2026-03-04 16:35:31.486352
2663	500107	70012004	2027-04-18	Sun	4	13.1	1.00	1.05	estimated	2026-03-04 16:35:31.486352
2664	500107	70012004	2027-04-19	Mon	4	12.3	1.00	0.98	estimated	2026-03-04 16:35:31.486352
2665	500107	70012004	2027-04-20	Tue	4	14.3	1.00	1.14	estimated	2026-03-04 16:35:31.486352
2666	500107	70012004	2027-04-21	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
2667	500107	70012004	2027-04-22	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
2668	500107	70012004	2027-04-23	Fri	4	13.3	1.00	1.06	estimated	2026-03-04 16:35:31.486352
2669	500107	70012004	2027-04-24	Sat	4	12.0	1.00	0.96	estimated	2026-03-04 16:35:31.486352
2670	500107	70012004	2027-04-25	Sun	4	13.1	1.00	1.05	estimated	2026-03-04 16:35:31.486352
2671	500107	70012004	2027-04-26	Mon	4	12.3	1.00	0.98	estimated	2026-03-04 16:35:31.486352
2672	500107	70012004	2027-04-27	Tue	4	14.3	1.00	1.14	estimated	2026-03-04 16:35:31.486352
2673	500107	70012004	2027-04-28	Wed	4	11.1	1.00	0.89	estimated	2026-03-04 16:35:31.486352
2674	500107	70012004	2027-04-29	Thu	4	11.5	1.00	0.92	estimated	2026-03-04 16:35:31.486352
2675	500107	70012004	2027-04-30	Fri	4	13.3	1.00	1.06	estimated	2026-03-04 16:35:31.486352
2676	500107	70012004	2027-05-01	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
2677	500107	70012004	2027-05-02	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
2678	500107	70012004	2027-05-03	Mon	5	13.5	1.10	0.98	medium	2026-03-04 16:35:31.486352
2679	500107	70012004	2027-05-04	Tue	5	15.7	1.10	1.14	medium	2026-03-04 16:35:31.486352
2680	500107	70012004	2027-05-05	Wed	5	12.3	1.10	0.89	medium	2026-03-04 16:35:31.486352
2681	500107	70012004	2027-05-06	Thu	5	12.7	1.10	0.92	medium	2026-03-04 16:35:31.486352
2682	500107	70012004	2027-05-07	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
2683	500107	70012004	2027-05-08	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
2684	500107	70012004	2027-05-09	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
2685	500107	70012004	2027-05-10	Mon	5	13.5	1.10	0.98	medium	2026-03-04 16:35:31.486352
2686	500107	70012004	2027-05-11	Tue	5	15.7	1.10	1.14	medium	2026-03-04 16:35:31.486352
2687	500107	70012004	2027-05-12	Wed	5	12.3	1.10	0.89	medium	2026-03-04 16:35:31.486352
2688	500107	70012004	2027-05-13	Thu	5	12.7	1.10	0.92	medium	2026-03-04 16:35:31.486352
2689	500107	70012004	2027-05-14	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
2690	500107	70012004	2027-05-15	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
2691	500107	70012004	2027-05-16	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
2692	500107	70012004	2027-05-17	Mon	5	13.5	1.10	0.98	medium	2026-03-04 16:35:31.486352
2693	500107	70012004	2027-05-18	Tue	5	15.7	1.10	1.14	medium	2026-03-04 16:35:31.486352
2694	500107	70012004	2027-05-19	Wed	5	12.3	1.10	0.89	medium	2026-03-04 16:35:31.486352
2695	500107	70012004	2027-05-20	Thu	5	12.7	1.10	0.92	medium	2026-03-04 16:35:31.486352
2696	500107	70012004	2027-05-21	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
2697	500107	70012004	2027-05-22	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
2698	500107	70012004	2027-05-23	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
2699	500107	70012004	2027-05-24	Mon	5	13.5	1.10	0.98	medium	2026-03-04 16:35:31.486352
2700	500107	70012004	2027-05-25	Tue	5	15.7	1.10	1.14	medium	2026-03-04 16:35:31.486352
2701	500107	70012004	2027-05-26	Wed	5	12.3	1.10	0.89	medium	2026-03-04 16:35:31.486352
2702	500107	70012004	2027-05-27	Thu	5	12.7	1.10	0.92	medium	2026-03-04 16:35:31.486352
2703	500107	70012004	2027-05-28	Fri	5	14.6	1.10	1.06	medium	2026-03-04 16:35:31.486352
2704	500107	70012004	2027-05-29	Sat	5	13.2	1.10	0.96	medium	2026-03-04 16:35:31.486352
2705	500107	70012004	2027-05-30	Sun	5	14.5	1.10	1.05	medium	2026-03-04 16:35:31.486352
2706	500107	70012004	2027-05-31	Mon	5	13.5	1.10	0.98	medium	2026-03-04 16:35:31.486352
2707	500107	70012004	2027-06-01	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
2708	500107	70012004	2027-06-02	Wed	6	8.8	0.79	0.89	high	2026-03-04 16:35:31.486352
2709	500107	70012004	2027-06-03	Thu	6	9.1	0.79	0.92	high	2026-03-04 16:35:31.486352
2710	500107	70012004	2027-06-04	Fri	6	10.5	0.79	1.06	high	2026-03-04 16:35:31.486352
2711	500107	70012004	2027-06-05	Sat	6	9.5	0.79	0.96	high	2026-03-04 16:35:31.486352
2712	500107	70012004	2027-06-06	Sun	6	10.4	0.79	1.05	high	2026-03-04 16:35:31.486352
2713	500107	70012004	2027-06-07	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
2714	500107	70012004	2027-06-08	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
2715	500107	70012004	2027-06-09	Wed	6	8.8	0.79	0.89	high	2026-03-04 16:35:31.486352
2716	500107	70012004	2027-06-10	Thu	6	9.1	0.79	0.92	high	2026-03-04 16:35:31.486352
2717	500107	70012004	2027-06-11	Fri	6	10.5	0.79	1.06	high	2026-03-04 16:35:31.486352
2718	500107	70012004	2027-06-12	Sat	6	9.5	0.79	0.96	high	2026-03-04 16:35:31.486352
2719	500107	70012004	2027-06-13	Sun	6	10.4	0.79	1.05	high	2026-03-04 16:35:31.486352
2720	500107	70012004	2027-06-14	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
2721	500107	70012004	2027-06-15	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
2722	500107	70012004	2027-06-16	Wed	6	8.8	0.79	0.89	high	2026-03-04 16:35:31.486352
2723	500107	70012004	2027-06-17	Thu	6	9.1	0.79	0.92	high	2026-03-04 16:35:31.486352
2724	500107	70012004	2027-06-18	Fri	6	10.5	0.79	1.06	high	2026-03-04 16:35:31.486352
2725	500107	70012004	2027-06-19	Sat	6	9.5	0.79	0.96	high	2026-03-04 16:35:31.486352
2726	500107	70012004	2027-06-20	Sun	6	10.4	0.79	1.05	high	2026-03-04 16:35:31.486352
2727	500107	70012004	2027-06-21	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
2728	500107	70012004	2027-06-22	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
2729	500107	70012004	2027-06-23	Wed	6	8.8	0.79	0.89	high	2026-03-04 16:35:31.486352
2730	500107	70012004	2027-06-24	Thu	6	9.1	0.79	0.92	high	2026-03-04 16:35:31.486352
2731	500107	70012004	2027-06-25	Fri	6	10.5	0.79	1.06	high	2026-03-04 16:35:31.486352
2732	500107	70012004	2027-06-26	Sat	6	9.5	0.79	0.96	high	2026-03-04 16:35:31.486352
2733	500107	70012004	2027-06-27	Sun	6	10.4	0.79	1.05	high	2026-03-04 16:35:31.486352
2734	500107	70012004	2027-06-28	Mon	6	9.7	0.79	0.98	high	2026-03-04 16:35:31.486352
2735	500107	70012004	2027-06-29	Tue	6	11.3	0.79	1.14	high	2026-03-04 16:35:31.486352
2736	500107	70012004	2027-06-30	Wed	6	8.8	0.79	0.89	high	2026-03-04 16:35:31.486352
2737	500107	70012004	2027-07-01	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2738	500107	70012004	2027-07-02	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2739	500107	70012004	2027-07-03	Sat	7	11.9	0.99	0.96	high	2026-03-04 16:35:31.486352
2740	500107	70012004	2027-07-04	Sun	7	13.0	0.99	1.05	high	2026-03-04 16:35:31.486352
2741	500107	70012004	2027-07-05	Mon	7	12.1	0.99	0.98	high	2026-03-04 16:35:31.486352
2742	500107	70012004	2027-07-06	Tue	7	14.1	0.99	1.14	high	2026-03-04 16:35:31.486352
2743	500107	70012004	2027-07-07	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2744	500107	70012004	2027-07-08	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2745	500107	70012004	2027-07-09	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2746	500107	70012004	2027-07-10	Sat	7	11.9	0.99	0.96	high	2026-03-04 16:35:31.486352
2747	500107	70012004	2027-07-11	Sun	7	13.0	0.99	1.05	high	2026-03-04 16:35:31.486352
2748	500107	70012004	2027-07-12	Mon	7	12.1	0.99	0.98	high	2026-03-04 16:35:31.486352
2749	500107	70012004	2027-07-13	Tue	7	14.1	0.99	1.14	high	2026-03-04 16:35:31.486352
2750	500107	70012004	2027-07-14	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2751	500107	70012004	2027-07-15	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2752	500107	70012004	2027-07-16	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2753	500107	70012004	2027-07-17	Sat	7	11.9	0.99	0.96	high	2026-03-04 16:35:31.486352
2754	500107	70012004	2027-07-18	Sun	7	13.0	0.99	1.05	high	2026-03-04 16:35:31.486352
2755	500107	70012004	2027-07-19	Mon	7	12.1	0.99	0.98	high	2026-03-04 16:35:31.486352
2756	500107	70012004	2027-07-20	Tue	7	14.1	0.99	1.14	high	2026-03-04 16:35:31.486352
2757	500107	70012004	2027-07-21	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2758	500107	70012004	2027-07-22	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2759	500107	70012004	2027-07-23	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2760	500107	70012004	2027-07-24	Sat	7	11.9	0.99	0.96	high	2026-03-04 16:35:31.486352
2761	500107	70012004	2027-07-25	Sun	7	13.0	0.99	1.05	high	2026-03-04 16:35:31.486352
2762	500107	70012004	2027-07-26	Mon	7	12.1	0.99	0.98	high	2026-03-04 16:35:31.486352
2763	500107	70012004	2027-07-27	Tue	7	14.1	0.99	1.14	high	2026-03-04 16:35:31.486352
2764	500107	70012004	2027-07-28	Wed	7	11.0	0.99	0.89	high	2026-03-04 16:35:31.486352
2765	500107	70012004	2027-07-29	Thu	7	11.4	0.99	0.92	high	2026-03-04 16:35:31.486352
2766	500107	70012004	2027-07-30	Fri	7	13.1	0.99	1.06	high	2026-03-04 16:35:31.486352
2767	500107	70012004	2027-07-31	Sat	7	11.9	0.99	0.96	high	2026-03-04 16:35:31.486352
2768	500107	70012004	2027-08-01	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2769	500107	70012004	2027-08-02	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2770	500107	70012004	2027-08-03	Tue	8	14.7	1.03	1.14	high	2026-03-04 16:35:31.486352
2771	500107	70012004	2027-08-04	Wed	8	11.5	1.03	0.89	high	2026-03-04 16:35:31.486352
2772	500107	70012004	2027-08-05	Thu	8	11.9	1.03	0.92	high	2026-03-04 16:35:31.486352
2773	500107	70012004	2027-08-06	Fri	8	13.7	1.03	1.06	high	2026-03-04 16:35:31.486352
2774	500107	70012004	2027-08-07	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2775	500107	70012004	2027-08-08	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2776	500107	70012004	2027-08-09	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2777	500107	70012004	2027-08-10	Tue	8	14.7	1.03	1.14	high	2026-03-04 16:35:31.486352
2778	500107	70012004	2027-08-11	Wed	8	11.5	1.03	0.89	high	2026-03-04 16:35:31.486352
2779	500107	70012004	2027-08-12	Thu	8	11.9	1.03	0.92	high	2026-03-04 16:35:31.486352
2780	500107	70012004	2027-08-13	Fri	8	13.7	1.03	1.06	high	2026-03-04 16:35:31.486352
2781	500107	70012004	2027-08-14	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2782	500107	70012004	2027-08-15	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2783	500107	70012004	2027-08-16	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2784	500107	70012004	2027-08-17	Tue	8	14.7	1.03	1.14	high	2026-03-04 16:35:31.486352
2785	500107	70012004	2027-08-18	Wed	8	11.5	1.03	0.89	high	2026-03-04 16:35:31.486352
2786	500107	70012004	2027-08-19	Thu	8	11.9	1.03	0.92	high	2026-03-04 16:35:31.486352
2787	500107	70012004	2027-08-20	Fri	8	13.7	1.03	1.06	high	2026-03-04 16:35:31.486352
2788	500107	70012004	2027-08-21	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2789	500107	70012004	2027-08-22	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2790	500107	70012004	2027-08-23	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2791	500107	70012004	2027-08-24	Tue	8	14.7	1.03	1.14	high	2026-03-04 16:35:31.486352
2792	500107	70012004	2027-08-25	Wed	8	11.5	1.03	0.89	high	2026-03-04 16:35:31.486352
2793	500107	70012004	2027-08-26	Thu	8	11.9	1.03	0.92	high	2026-03-04 16:35:31.486352
2794	500107	70012004	2027-08-27	Fri	8	13.7	1.03	1.06	high	2026-03-04 16:35:31.486352
2795	500107	70012004	2027-08-28	Sat	8	12.4	1.03	0.96	high	2026-03-04 16:35:31.486352
2796	500107	70012004	2027-08-29	Sun	8	13.5	1.03	1.05	high	2026-03-04 16:35:31.486352
2797	500107	70012004	2027-08-30	Mon	8	12.6	1.03	0.98	high	2026-03-04 16:35:31.486352
2799	500107	70012004	2027-09-01	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2800	500107	70012004	2027-09-02	Thu	9	12.9	1.12	0.92	high	2026-03-04 16:35:31.486352
2801	500107	70012004	2027-09-03	Fri	9	14.9	1.12	1.06	high	2026-03-04 16:35:31.486352
2802	500107	70012004	2027-09-04	Sat	9	13.5	1.12	0.96	high	2026-03-04 16:35:31.486352
2803	500107	70012004	2027-09-05	Sun	9	14.7	1.12	1.05	high	2026-03-04 16:35:31.486352
2804	500107	70012004	2027-09-06	Mon	9	13.7	1.12	0.98	high	2026-03-04 16:35:31.486352
2805	500107	70012004	2027-09-07	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2806	500107	70012004	2027-09-08	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2807	500107	70012004	2027-09-09	Thu	9	12.9	1.12	0.92	high	2026-03-04 16:35:31.486352
2808	500107	70012004	2027-09-10	Fri	9	14.9	1.12	1.06	high	2026-03-04 16:35:31.486352
2809	500107	70012004	2027-09-11	Sat	9	13.5	1.12	0.96	high	2026-03-04 16:35:31.486352
2810	500107	70012004	2027-09-12	Sun	9	14.7	1.12	1.05	high	2026-03-04 16:35:31.486352
2811	500107	70012004	2027-09-13	Mon	9	13.7	1.12	0.98	high	2026-03-04 16:35:31.486352
2812	500107	70012004	2027-09-14	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2813	500107	70012004	2027-09-15	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2814	500107	70012004	2027-09-16	Thu	9	12.9	1.12	0.92	high	2026-03-04 16:35:31.486352
2815	500107	70012004	2027-09-17	Fri	9	14.9	1.12	1.06	high	2026-03-04 16:35:31.486352
2816	500107	70012004	2027-09-18	Sat	9	13.5	1.12	0.96	high	2026-03-04 16:35:31.486352
2817	500107	70012004	2027-09-19	Sun	9	14.7	1.12	1.05	high	2026-03-04 16:35:31.486352
2818	500107	70012004	2027-09-20	Mon	9	13.7	1.12	0.98	high	2026-03-04 16:35:31.486352
2819	500107	70012004	2027-09-21	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2820	500107	70012004	2027-09-22	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2821	500107	70012004	2027-09-23	Thu	9	12.9	1.12	0.92	high	2026-03-04 16:35:31.486352
2822	500107	70012004	2027-09-24	Fri	9	14.9	1.12	1.06	high	2026-03-04 16:35:31.486352
2823	500107	70012004	2027-09-25	Sat	9	13.5	1.12	0.96	high	2026-03-04 16:35:31.486352
2824	500107	70012004	2027-09-26	Sun	9	14.7	1.12	1.05	high	2026-03-04 16:35:31.486352
2825	500107	70012004	2027-09-27	Mon	9	13.7	1.12	0.98	high	2026-03-04 16:35:31.486352
2826	500107	70012004	2027-09-28	Tue	9	16.0	1.12	1.14	high	2026-03-04 16:35:31.486352
2827	500107	70012004	2027-09-29	Wed	9	12.5	1.12	0.89	high	2026-03-04 16:35:31.486352
2828	500107	70012004	2027-09-30	Thu	9	12.9	1.12	0.92	high	2026-03-04 16:35:31.486352
2829	500107	70012004	2027-10-01	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2830	500107	70012004	2027-10-02	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2831	500107	70012004	2027-10-03	Sun	10	12.4	0.94	1.05	high	2026-03-04 16:35:31.486352
2832	500107	70012004	2027-10-04	Mon	10	11.5	0.94	0.98	high	2026-03-04 16:35:31.486352
2833	500107	70012004	2027-10-05	Tue	10	13.4	0.94	1.14	high	2026-03-04 16:35:31.486352
2834	500107	70012004	2027-10-06	Wed	10	10.5	0.94	0.89	high	2026-03-04 16:35:31.486352
2835	500107	70012004	2027-10-07	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2836	500107	70012004	2027-10-08	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2837	500107	70012004	2027-10-09	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2838	500107	70012004	2027-10-10	Sun	10	12.4	0.94	1.05	high	2026-03-04 16:35:31.486352
2839	500107	70012004	2027-10-11	Mon	10	11.5	0.94	0.98	high	2026-03-04 16:35:31.486352
2840	500107	70012004	2027-10-12	Tue	10	13.4	0.94	1.14	high	2026-03-04 16:35:31.486352
2841	500107	70012004	2027-10-13	Wed	10	10.5	0.94	0.89	high	2026-03-04 16:35:31.486352
2842	500107	70012004	2027-10-14	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2843	500107	70012004	2027-10-15	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2844	500107	70012004	2027-10-16	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2845	500107	70012004	2027-10-17	Sun	10	12.4	0.94	1.05	high	2026-03-04 16:35:31.486352
2846	500107	70012004	2027-10-18	Mon	10	11.5	0.94	0.98	high	2026-03-04 16:35:31.486352
2847	500107	70012004	2027-10-19	Tue	10	13.4	0.94	1.14	high	2026-03-04 16:35:31.486352
2848	500107	70012004	2027-10-20	Wed	10	10.5	0.94	0.89	high	2026-03-04 16:35:31.486352
2849	500107	70012004	2027-10-21	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2850	500107	70012004	2027-10-22	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2851	500107	70012004	2027-10-23	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2852	500107	70012004	2027-10-24	Sun	10	12.4	0.94	1.05	high	2026-03-04 16:35:31.486352
2853	500107	70012004	2027-10-25	Mon	10	11.5	0.94	0.98	high	2026-03-04 16:35:31.486352
2854	500107	70012004	2027-10-26	Tue	10	13.4	0.94	1.14	high	2026-03-04 16:35:31.486352
2855	500107	70012004	2027-10-27	Wed	10	10.5	0.94	0.89	high	2026-03-04 16:35:31.486352
2856	500107	70012004	2027-10-28	Thu	10	10.8	0.94	0.92	high	2026-03-04 16:35:31.486352
2857	500107	70012004	2027-10-29	Fri	10	12.5	0.94	1.06	high	2026-03-04 16:35:31.486352
2858	500107	70012004	2027-10-30	Sat	10	11.3	0.94	0.96	high	2026-03-04 16:35:31.486352
2859	500107	70012004	2027-10-31	Sun	10	12.4	0.94	1.05	high	2026-03-04 16:35:31.486352
2860	500107	70012004	2027-11-01	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2861	500107	70012004	2027-11-02	Tue	11	14.8	1.04	1.14	high	2026-03-04 16:35:31.486352
2862	500107	70012004	2027-11-03	Wed	11	11.6	1.04	0.89	high	2026-03-04 16:35:31.486352
2863	500107	70012004	2027-11-04	Thu	11	12.0	1.04	0.92	high	2026-03-04 16:35:31.486352
2864	500107	70012004	2027-11-05	Fri	11	13.8	1.04	1.06	high	2026-03-04 16:35:31.486352
2865	500107	70012004	2027-11-06	Sat	11	12.5	1.04	0.96	high	2026-03-04 16:35:31.486352
2866	500107	70012004	2027-11-07	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2867	500107	70012004	2027-11-08	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2868	500107	70012004	2027-11-09	Tue	11	14.8	1.04	1.14	high	2026-03-04 16:35:31.486352
2869	500107	70012004	2027-11-10	Wed	11	11.6	1.04	0.89	high	2026-03-04 16:35:31.486352
2870	500107	70012004	2027-11-11	Thu	11	12.0	1.04	0.92	high	2026-03-04 16:35:31.486352
2871	500107	70012004	2027-11-12	Fri	11	13.8	1.04	1.06	high	2026-03-04 16:35:31.486352
2872	500107	70012004	2027-11-13	Sat	11	12.5	1.04	0.96	high	2026-03-04 16:35:31.486352
2873	500107	70012004	2027-11-14	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2874	500107	70012004	2027-11-15	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2875	500107	70012004	2027-11-16	Tue	11	14.8	1.04	1.14	high	2026-03-04 16:35:31.486352
2876	500107	70012004	2027-11-17	Wed	11	11.6	1.04	0.89	high	2026-03-04 16:35:31.486352
2877	500107	70012004	2027-11-18	Thu	11	12.0	1.04	0.92	high	2026-03-04 16:35:31.486352
2878	500107	70012004	2027-11-19	Fri	11	13.8	1.04	1.06	high	2026-03-04 16:35:31.486352
2879	500107	70012004	2027-11-20	Sat	11	12.5	1.04	0.96	high	2026-03-04 16:35:31.486352
2880	500107	70012004	2027-11-21	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2881	500107	70012004	2027-11-22	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2882	500107	70012004	2027-11-23	Tue	11	14.8	1.04	1.14	high	2026-03-04 16:35:31.486352
2883	500107	70012004	2027-11-24	Wed	11	11.6	1.04	0.89	high	2026-03-04 16:35:31.486352
2884	500107	70012004	2027-11-25	Thu	11	12.0	1.04	0.92	high	2026-03-04 16:35:31.486352
2885	500107	70012004	2027-11-26	Fri	11	13.8	1.04	1.06	high	2026-03-04 16:35:31.486352
2886	500107	70012004	2027-11-27	Sat	11	12.5	1.04	0.96	high	2026-03-04 16:35:31.486352
2887	500107	70012004	2027-11-28	Sun	11	13.7	1.04	1.05	high	2026-03-04 16:35:31.486352
2888	500107	70012004	2027-11-29	Mon	11	12.8	1.04	0.98	high	2026-03-04 16:35:31.486352
2889	500107	70012004	2027-11-30	Tue	11	14.8	1.04	1.14	high	2026-03-04 16:35:31.486352
2890	500107	70012004	2027-12-01	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2891	500107	70012004	2027-12-02	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2892	500107	70012004	2027-12-03	Fri	12	12.1	0.91	1.06	medium	2026-03-04 16:35:31.486352
2893	500107	70012004	2027-12-04	Sat	12	10.9	0.91	0.96	medium	2026-03-04 16:35:31.486352
2894	500107	70012004	2027-12-05	Sun	12	12.0	0.91	1.05	medium	2026-03-04 16:35:31.486352
2895	500107	70012004	2027-12-06	Mon	12	11.2	0.91	0.98	medium	2026-03-04 16:35:31.486352
2896	500107	70012004	2027-12-07	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2897	500107	70012004	2027-12-08	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2898	500107	70012004	2027-12-09	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2899	500107	70012004	2027-12-10	Fri	12	12.1	0.91	1.06	medium	2026-03-04 16:35:31.486352
2900	500107	70012004	2027-12-11	Sat	12	10.9	0.91	0.96	medium	2026-03-04 16:35:31.486352
2901	500107	70012004	2027-12-12	Sun	12	12.0	0.91	1.05	medium	2026-03-04 16:35:31.486352
2902	500107	70012004	2027-12-13	Mon	12	11.2	0.91	0.98	medium	2026-03-04 16:35:31.486352
2903	500107	70012004	2027-12-14	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2904	500107	70012004	2027-12-15	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2905	500107	70012004	2027-12-16	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2906	500107	70012004	2027-12-17	Fri	12	12.1	0.91	1.06	medium	2026-03-04 16:35:31.486352
2907	500107	70012004	2027-12-18	Sat	12	10.9	0.91	0.96	medium	2026-03-04 16:35:31.486352
2908	500107	70012004	2027-12-19	Sun	12	12.0	0.91	1.05	medium	2026-03-04 16:35:31.486352
2909	500107	70012004	2027-12-20	Mon	12	11.2	0.91	0.98	medium	2026-03-04 16:35:31.486352
2910	500107	70012004	2027-12-21	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2911	500107	70012004	2027-12-22	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2912	500107	70012004	2027-12-23	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2913	500107	70012004	2027-12-24	Fri	12	12.1	0.91	1.06	medium	2026-03-04 16:35:31.486352
2914	500107	70012004	2027-12-25	Sat	12	10.9	0.91	0.96	medium	2026-03-04 16:35:31.486352
2915	500107	70012004	2027-12-26	Sun	12	12.0	0.91	1.05	medium	2026-03-04 16:35:31.486352
2916	500107	70012004	2027-12-27	Mon	12	11.2	0.91	0.98	medium	2026-03-04 16:35:31.486352
2917	500107	70012004	2027-12-28	Tue	12	13.0	0.91	1.14	medium	2026-03-04 16:35:31.486352
2918	500107	70012004	2027-12-29	Wed	12	10.1	0.91	0.89	medium	2026-03-04 16:35:31.486352
2919	500107	70012004	2027-12-30	Thu	12	10.5	0.91	0.92	medium	2026-03-04 16:35:31.486352
2920	500107	70012004	2027-12-31	Fri	12	12.1	0.91	1.06	medium	2026-03-04 16:35:31.486352
\.


--
-- Data for Name: daily_sales_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.daily_sales_log (id, store_id, sku, product_name, sale_date, day_of_week, pieces_sold, month, year, notes, created_at) FROM stdin;
164	70012004	500107	Demo_500g_Rye_Bread	2025-05-22	Thu	12	5	2025	\N	2026-03-04 14:14:17.799302
165	70012004	500107	Demo_500g_Rye_Bread	2025-05-23	Fri	14	5	2025	\N	2026-03-04 14:36:08.619709
166	70012004	500107	Demo_500g_Rye_Bread	2025-05-24	Sat	13	5	2025	\N	2026-03-04 14:36:19.259632
167	70012004	500107	Demo_500g_Rye_Bread	2025-05-25	Sun	15	5	2025	\N	2026-03-04 14:36:23.699709
168	70012004	500107	Demo_500g_Rye_Bread	2025-05-26	Mon	13	5	2025	\N	2026-03-04 14:36:27.747421
169	70012004	500107	Demo_500g_Rye_Bread	2025-05-27	Tue	17	5	2025	\N	2026-03-04 14:36:34.755499
170	70012004	500107	Demo_500g_Rye_Bread	2025-05-28	Wed	12	5	2025	\N	2026-03-04 14:36:39.491425
171	70012004	500107	Demo_500g_Rye_Bread	2025-06-03	Tue	12	6	2025	\N	2026-03-04 14:39:00.170831
172	70012004	500107	Demo_500g_Rye_Bread	2025-06-04	Wed	9	6	2025	\N	2026-03-04 14:40:37.586577
173	70012004	500107	Demo_500g_Rye_Bread	2025-06-05	Thu	9	6	2025	\N	2026-03-04 14:40:39.68242
174	70012004	500107	Demo_500g_Rye_Bread	2025-06-06	Fri	9	6	2025	\N	2026-03-04 14:40:42.418682
175	70012004	500107	Demo_500g_Rye_Bread	2025-06-07	Sat	10	6	2025	\N	2026-03-04 14:40:45.034539
176	70012004	500107	Demo_500g_Rye_Bread	2025-06-08	Sun	9	6	2025	\N	2026-03-04 14:40:47.47437
177	70012004	500107	Demo_500g_Rye_Bread	2025-06-09	Mon	8	6	2025	\N	2026-03-04 14:41:01.80242
180	70012004	500107	Demo_500g_Rye_Bread	2025-06-10	Tue	10	6	2025	\N	2026-03-04 14:45:29.921831
181	70012004	500107	Demo_500g_Rye_Bread	2025-06-11	Wed	7	6	2025	\N	2026-03-04 14:45:32.857669
182	70012004	500107	Demo_500g_Rye_Bread	2025-06-12	Thu	8	6	2025	\N	2026-03-04 14:45:35.377645
183	70012004	500107	Demo_500g_Rye_Bread	2025-06-13	Fri	9	6	2025	\N	2026-03-04 14:45:47.257705
184	70012004	500107	Demo_500g_Rye_Bread	2025-06-14	Sat	9	6	2025	\N	2026-03-04 14:45:59.17765
185	70012004	500107	Demo_500g_Rye_Bread	2025-06-15	Sun	10	6	2025	\N	2026-03-04 14:47:28.226146
186	70012004	500107	Demo_500g_Rye_Bread	2025-06-16	Mon	9	6	2025	\N	2026-03-04 14:47:31.521369
187	70012004	500107	Demo_500g_Rye_Bread	2025-06-17	Tue	12	6	2025	\N	2026-03-04 14:47:34.473213
188	70012004	500107	Demo_500g_Rye_Bread	2025-06-18	Wed	8	6	2025	\N	2026-03-04 14:47:38.089223
189	70012004	500107	Demo_500g_Rye_Bread	2025-06-19	Thu	9	6	2025	\N	2026-03-04 14:47:45.289485
190	70012004	500107	Demo_500g_Rye_Bread	2025-06-24	Tue	15	6	2025	\N	2026-03-04 14:50:59.160564
191	70012004	500107	Demo_500g_Rye_Bread	2025-06-25	Wed	11	6	2025	\N	2026-03-04 14:51:02.112774
192	70012004	500107	Demo_500g_Rye_Bread	2025-06-26	Thu	10	6	2025	\N	2026-03-04 14:51:04.33677
193	70012004	500107	Demo_500g_Rye_Bread	2025-06-27	Fri	12	6	2025	\N	2026-03-04 14:51:08.072778
194	70012004	500107	Demo_500g_Rye_Bread	2025-06-28	Sat	9	6	2025	\N	2026-03-04 14:51:18.331912
195	70012004	500107	Demo_500g_Rye_Bread	2025-06-29	Sun	11	6	2025	\N	2026-03-04 14:51:24.840505
196	70012004	500107	Demo_500g_Rye_Bread	2025-06-30	Mon	12	6	2025	\N	2026-03-04 14:51:30.440748
197	70012004	500107	Demo_500g_Rye_Bread	2025-07-01	Tue	15	7	2025	\N	2026-03-04 14:51:36.928761
198	70012004	500107	Demo_500g_Rye_Bread	2025-07-02	Wed	12	7	2025	\N	2026-03-04 14:53:31.080278
199	70012004	500107	Demo_500g_Rye_Bread	2025-07-03	Thu	10	7	2025	\N	2026-03-04 14:53:39.04019
200	70012004	500107	Demo_500g_Rye_Bread	2025-07-04	Fri	15	7	2025	\N	2026-03-04 14:53:45.136413
201	70012004	500107	Demo_500g_Rye_Bread	2025-07-05	Sat	8	7	2025	\N	2026-03-04 14:53:51.648266
202	70012004	500107	Demo_500g_Rye_Bread	2025-07-06	Sun	9	7	2025	\N	2026-03-04 14:53:56.144288
203	70012004	500107	Demo_500g_Rye_Bread	2025-07-07	Mon	12	7	2025	\N	2026-03-04 14:54:06.97643
205	70012004	500107	Demo_500g_Rye_Bread	2025-07-08	Tue	13	7	2025	\N	2026-03-04 14:55:48.87165
206	70012004	500107	Demo_500g_Rye_Bread	2025-07-09	Wed	11	7	2025	\N	2026-03-04 14:55:51.760057
207	70012004	500107	Demo_500g_Rye_Bread	2025-07-10	Thu	17	7	2025	\N	2026-03-04 14:55:55.808106
208	70012004	500107	Demo_500g_Rye_Bread	2025-07-11	Fri	20	7	2025	\N	2026-03-04 14:55:59.159629
209	70012004	500107	Demo_500g_Rye_Bread	2025-07-12	Sat	18	7	2025	\N	2026-03-04 14:56:02.079847
210	70012004	500107	Demo_500g_Rye_Bread	2025-07-13	Sun	20	7	2025	\N	2026-03-04 14:56:15.75226
211	70012004	500107	Demo_500g_Rye_Bread	2025-07-17	Thu	10	7	2025	\N	2026-03-04 14:59:11.119172
212	70012004	500107	Demo_500g_Rye_Bread	2025-07-18	Fri	11	7	2025	\N	2026-03-04 14:59:13.767082
213	70012004	500107	Demo_500g_Rye_Bread	2025-07-19	Sat	11	7	2025	\N	2026-03-04 14:59:14.526946
214	70012004	500107	Demo_500g_Rye_Bread	2025-07-20	Sun	11	7	2025	\N	2026-03-04 14:59:21.694959
215	70012004	500107	Demo_500g_Rye_Bread	2025-07-21	Mon	11	7	2025	\N	2026-03-04 14:59:25.839348
216	70012004	500107	Demo_500g_Rye_Bread	2025-07-22	Tue	14	7	2025	\N	2026-03-04 14:59:31.679107
217	70012004	500107	Demo_500g_Rye_Bread	2025-07-23	Wed	9	7	2025	\N	2026-03-04 14:59:38.447038
218	70012004	500107	Demo_500g_Rye_Bread	2025-07-24	Thu	8	7	2025	\N	2026-03-04 15:01:40.718777
219	70012004	500107	Demo_500g_Rye_Bread	2025-07-25	Fri	11	7	2025	\N	2026-03-04 15:01:46.958449
220	70012004	500107	Demo_500g_Rye_Bread	2025-07-26	Sat	9	7	2025	\N	2026-03-04 15:01:50.73487
221	70012004	500107	Demo_500g_Rye_Bread	2025-07-27	Sun	11	7	2025	\N	2026-03-04 15:01:54.262832
222	70012004	500107	Demo_500g_Rye_Bread	2025-07-28	Mon	11	7	2025	\N	2026-03-04 15:01:59.8386
227	70012004	500107	Demo_500g_Rye_Bread	2025-07-29	Tue	13	7	2025	\N	2026-03-04 15:04:26.462306
228	70012004	500107	Demo_500g_Rye_Bread	2025-07-30	Wed	9	7	2025	\N	2026-03-04 15:04:31.870158
229	70012004	500107	Demo_500g_Rye_Bread	2025-07-31	Thu	17	7	2025	\N	2026-03-04 15:04:43.454323
230	70012004	500107	Demo_500g_Rye_Bread	2025-08-01	Fri	20	8	2025	\N	2026-03-04 15:04:50.126432
231	70012004	500107	Demo_500g_Rye_Bread	2025-08-02	Sat	16	8	2025	\N	2026-03-04 15:06:57.542202
232	70012004	500107	Demo_500g_Rye_Bread	2025-08-03	Sun	19	8	2025	\N	2026-03-04 15:07:05.709946
233	70012004	500107	Demo_500g_Rye_Bread	2025-08-04	Mon	18	8	2025	\N	2026-03-04 15:07:12.493798
234	70012004	500107	Demo_500g_Rye_Bread	2025-08-05	Tue	20	8	2025	\N	2026-03-04 15:08:05.493812
235	70012004	500107	Demo_500g_Rye_Bread	2025-08-06	Wed	15	8	2025	\N	2026-03-04 15:08:08.573583
236	70012004	500107	Demo_500g_Rye_Bread	2025-08-07	Thu	10	8	2025	\N	2026-03-04 15:08:21.365495
237	70012004	500107	Demo_500g_Rye_Bread	2025-08-08	Fri	11	8	2025	\N	2026-03-04 15:08:33.789337
238	70012004	500107	Demo_500g_Rye_Bread	2025-08-09	Sat	9	8	2025	\N	2026-03-04 15:08:40.557464
239	70012004	500107	Demo_500g_Rye_Bread	2025-08-10	Sun	10	8	2025	\N	2026-03-04 15:08:45.685648
240	70012004	500107	Demo_500g_Rye_Bread	2025-08-11	Mon	9	8	2025	\N	2026-03-04 15:09:02.933929
242	70012004	500107	Demo_500g_Rye_Bread	2025-08-12	Tue	11	8	2025	\N	2026-03-04 15:10:46.397254
243	70012004	500107	Demo_500g_Rye_Bread	2025-08-13	Wed	7	8	2025	\N	2026-03-04 15:10:48.941122
244	70012004	500107	Demo_500g_Rye_Bread	2025-08-14	Thu	9	8	2025	\N	2026-03-04 15:10:50.557322
245	70012004	500107	Demo_500g_Rye_Bread	2025-08-15	Fri	11	8	2025	\N	2026-03-04 15:10:59.677008
246	70012004	500107	Demo_500g_Rye_Bread	2025-08-16	Sat	9	8	2025	\N	2026-03-04 15:11:07.205532
247	70012004	500107	Demo_500g_Rye_Bread	2025-08-17	Sun	10	8	2025	\N	2026-03-04 15:11:12.973051
248	70012004	500107	Demo_500g_Rye_Bread	2025-08-18	Mon	13	8	2025	\N	2026-03-04 15:12:51.500652
249	70012004	500107	Demo_500g_Rye_Bread	2025-08-19	Tue	17	8	2025	\N	2026-03-04 15:12:55.956979
250	70012004	500107	Demo_500g_Rye_Bread	2025-08-20	Wed	13	8	2025	\N	2026-03-04 15:12:59.51653
251	70012004	500107	Demo_500g_Rye_Bread	2025-08-21	Thu	13	8	2025	\N	2026-03-04 15:13:04.420677
252	70012004	500107	Demo_500g_Rye_Bread	2025-08-22	Fri	14	8	2025	\N	2026-03-04 15:13:08.70888
253	70012004	500107	Demo_500g_Rye_Bread	2025-08-23	Sat	12	8	2025	\N	2026-03-04 15:13:17.676749
254	70012004	500107	Demo_500g_Rye_Bread	2025-08-24	Sun	12	8	2025	\N	2026-03-04 15:13:24.340677
255	70012004	500107	Demo_500g_Rye_Bread	2025-09-01	Mon	12	9	2025	\N	2026-03-04 15:14:13.556717
256	70012004	500107	Demo_500g_Rye_Bread	2025-09-02	Tue	15	9	2025	\N	2026-03-04 15:14:38.07689
257	70012004	500107	Demo_500g_Rye_Bread	2025-09-03	Wed	13	9	2025	\N	2026-03-04 15:14:42.572218
258	70012004	500107	Demo_500g_Rye_Bread	2025-09-04	Thu	12	9	2025	\N	2026-03-04 15:14:46.476667
259	70012004	500107	Demo_500g_Rye_Bread	2025-09-05	Fri	12	9	2025	\N	2026-03-04 15:14:52.99639
260	70012004	500107	Demo_500g_Rye_Bread	2025-09-06	Sat	11	9	2025	\N	2026-03-04 15:15:00.180392
261	70012004	500107	Demo_500g_Rye_Bread	2025-09-07	Sun	10	9	2025	\N	2026-03-04 15:15:04.500451
262	70012004	500107	Demo_500g_Rye_Bread	2025-09-16	Tue	22	9	2025	\N	2026-03-04 15:16:14.476176
263	70012004	500107	Demo_500g_Rye_Bread	2025-09-17	Wed	19	9	2025	\N	2026-03-04 15:16:17.780429
265	70012004	500107	Demo_500g_Rye_Bread	2025-09-18	Thu	13	9	2025	\N	2026-03-04 15:16:42.396202
266	70012004	500107	Demo_500g_Rye_Bread	2025-09-19	Fri	15	9	2025	\N	2026-03-04 15:16:46.692013
267	70012004	500107	Demo_500g_Rye_Bread	2025-09-20	Sat	13	9	2025	\N	2026-03-04 15:16:55.644336
268	70012004	500107	Demo_500g_Rye_Bread	2025-09-21	Sun	13	9	2025	\N	2026-03-04 15:17:01.507965
269	70012004	500107	Demo_500g_Rye_Bread	2025-09-22	Mon	14	9	2025	\N	2026-03-04 15:17:09.179996
270	70012004	500107	Demo_500g_Rye_Bread	2025-09-30	Tue	12	9	2025	\N	2026-03-04 15:18:17.364124
271	70012004	500107	Demo_500g_Rye_Bread	2025-10-01	Wed	10	10	2025	\N	2026-03-04 15:18:21.259991
272	70012004	500107	Demo_500g_Rye_Bread	2025-10-02	Thu	11	10	2025	\N	2026-03-04 15:18:30.331692
273	70012004	500107	Demo_500g_Rye_Bread	2025-10-03	Fri	12	10	2025	\N	2026-03-04 15:18:33.899576
274	70012004	500107	Demo_500g_Rye_Bread	2025-10-04	Sat	12	10	2025	\N	2026-03-04 15:18:37.819978
275	70012004	500107	Demo_500g_Rye_Bread	2025-10-05	Sun	11	10	2025	\N	2026-03-04 15:18:42.771716
276	70012004	500107	Demo_500g_Rye_Bread	2025-10-06	Mon	12	10	2025	\N	2026-03-04 15:18:49.595848
277	70012004	500107	Demo_500g_Rye_Bread	2025-10-07	Tue	11	10	2025	\N	2026-03-04 15:20:40.435489
278	70012004	500107	Demo_500g_Rye_Bread	2025-10-08	Wed	10	10	2025	\N	2026-03-04 15:20:43.659379
279	70012004	500107	Demo_500g_Rye_Bread	2025-10-09	Thu	11	10	2025	\N	2026-03-04 15:20:48.131465
280	70012004	500107	Demo_500g_Rye_Bread	2025-10-10	Fri	12	10	2025	\N	2026-03-04 15:20:54.227232
281	70012004	500107	Demo_500g_Rye_Bread	2025-10-11	Sat	12	10	2025	\N	2026-03-04 15:20:59.371599
282	70012004	500107	Demo_500g_Rye_Bread	2025-10-12	Sun	12	10	2025	\N	2026-03-04 15:21:05.987542
283	70012004	500107	Demo_500g_Rye_Bread	2025-10-28	Tue	14	10	2025	\N	2026-03-04 15:22:05.827129
284	70012004	500107	Demo_500g_Rye_Bread	2025-10-29	Wed	12	10	2025	\N	2026-03-04 15:22:11.043283
285	70012004	500107	Demo_500g_Rye_Bread	2025-10-30	Thu	13	10	2025	\N	2026-03-04 15:22:13.811001
286	70012004	500107	Demo_500g_Rye_Bread	2025-10-31	Fri	14	10	2025	\N	2026-03-04 15:22:17.091388
287	70012004	500107	Demo_500g_Rye_Bread	2025-11-01	Sat	13	11	2025	\N	2026-03-04 15:22:33.123323
288	70012004	500107	Demo_500g_Rye_Bread	2025-11-02	Sun	14	11	2025	\N	2026-03-04 15:22:42.819008
289	70012004	500107	Demo_500g_Rye_Bread	2025-11-03	Mon	13	11	2025	\N	2026-03-04 15:22:50.322884
290	70012004	500107	Demo_500g_Rye_Bread	2025-11-06	Thu	10	11	2025	\N	2026-03-04 15:24:24.746756
291	70012004	500107	Demo_500g_Rye_Bread	2025-11-07	Fri	13	11	2025	\N	2026-03-04 15:24:30.482677
292	70012004	500107	Demo_500g_Rye_Bread	2025-11-08	Sat	11	11	2025	\N	2026-03-04 15:24:34.066619
293	70012004	500107	Demo_500g_Rye_Bread	2025-11-09	Sun	12	11	2025	\N	2026-03-04 15:24:40.834694
297	70012004	500107	Demo_500g_Rye_Bread	2025-12-03	Wed	11	12	2025	\N	2026-03-04 15:25:34.170429
298	70012004	500107	Demo_500g_Rye_Bread	2025-12-04	Thu	10	12	2025	\N	2026-03-04 15:26:46.050264
299	70012004	500107	Demo_500g_Rye_Bread	2025-12-05	Fri	12	12	2025	\N	2026-03-04 15:26:49.378216
300	70012004	500107	Demo_500g_Rye_Bread	2025-12-06	Sat	11	12	2025	\N	2026-03-04 15:26:53.914314
301	70012004	500107	Demo_500g_Rye_Bread	2025-12-07	Sun	13	12	2025	\N	2026-03-04 15:26:58.498272
302	70012004	500107	Demo_500g_Rye_Bread	2025-12-08	Mon	11	12	2025	\N	2026-03-04 15:27:05.034321
303	70012004	500107	Demo_500g_Rye_Bread	2025-12-09	Tue	12	12	2025	\N	2026-03-04 15:27:12.546258
304	70012004	500107	Demo_500g_Rye_Bread	2026-01-23	Fri	19	1	2026	\N	2026-03-04 15:28:03.289982
305	70012004	500107	Demo_500g_Rye_Bread	2026-01-24	Sat	18	1	2026	\N	2026-03-04 15:29:41.145952
306	70012004	500107	Demo_500g_Rye_Bread	2026-01-25	Sun	21	1	2026	\N	2026-03-04 15:29:53.129779
307	70012004	500107	Demo_500g_Rye_Bread	2026-01-26	Mon	19	1	2026	\N	2026-03-04 15:29:59.353995
308	70012004	500107	Demo_500g_Rye_Bread	2026-01-27	Tue	22	1	2026	\N	2026-03-04 15:30:04.817731
309	70012004	500107	Demo_500g_Rye_Bread	2026-01-28	Wed	16	1	2026	\N	2026-03-04 15:30:09.481664
310	70012004	500107	Demo_500g_Rye_Bread	2026-01-29	Thu	18	1	2026	\N	2026-03-04 15:30:15.881702
311	70012004	500107	Demo_500g_Rye_Bread	2026-01-30	Fri	18	1	2026	\N	2026-03-04 15:31:27.129691
312	70012004	500107	Demo_500g_Rye_Bread	2026-01-31	Sat	18	1	2026	\N	2026-03-04 15:31:31.105343
313	70012004	500107	Demo_500g_Rye_Bread	2026-02-01	Sun	20	2	2026	\N	2026-03-04 15:31:37.93778
314	70012004	500107	Demo_500g_Rye_Bread	2026-02-02	Mon	19	2	2026	\N	2026-03-04 15:31:53.857398
315	70012004	500107	Demo_500g_Rye_Bread	2026-02-03	Tue	21	2	2026	\N	2026-03-04 15:31:58.257421
316	70012004	500107	Demo_500g_Rye_Bread	2026-02-04	Wed	16	2	2026	\N	2026-03-04 15:32:03.266072
317	70012004	500107	Demo_500g_Rye_Bread	2026-02-05	Thu	15	2	2026	\N	2026-03-04 15:32:08.481871
318	70012004	500107	Demo_500g_Rye_Bread	2026-02-06	Fri	20	2	2026	\N	2026-03-04 15:32:50.433189
319	70012004	500107	Demo_500g_Rye_Bread	2026-02-07	Sat	20	2	2026	\N	2026-03-04 15:32:53.665078
320	70012004	500107	Demo_500g_Rye_Bread	2026-02-08	Sun	23	2	2026	\N	2026-03-04 15:33:05.025185
321	70012004	500107	Demo_500g_Rye_Bread	2026-02-09	Mon	21	2	2026	\N	2026-03-04 15:33:10.641176
322	70012004	500107	Demo_500g_Rye_Bread	2026-02-10	Tue	23	2	2026	\N	2026-03-04 15:33:15.297038
323	70012004	500107	Demo_500g_Rye_Bread	2026-02-11	Wed	17	2	2026	\N	2026-03-04 15:33:24.329555
324	70012004	500107	Demo_500g_Rye_Bread	2026-02-12	Thu	9	2	2026	\N	2026-03-04 15:33:30.673413
325	70012004	500107	Demo_500g_Rye_Bread	2026-02-13	Fri	9	2	2026	\N	2026-03-04 15:34:32.600815
326	70012004	500107	Demo_500g_Rye_Bread	2026-02-14	Sat	9	2	2026	\N	2026-03-04 15:34:36.897
327	70012004	500107	Demo_500g_Rye_Bread	2026-02-15	Sun	10	2	2026	\N	2026-03-04 15:34:52.585327
328	70012004	500107	Demo_500g_Rye_Bread	2026-02-16	Mon	9	2	2026	\N	2026-03-04 15:35:04.840818
329	70012004	500107	Demo_500g_Rye_Bread	2026-02-17	Tue	10	2	2026	\N	2026-03-04 15:35:09.896838
330	70012004	500107	Demo_500g_Rye_Bread	2026-02-18	Wed	8	2	2026	\N	2026-03-04 15:35:15.448879
331	70012004	500107	Demo_500g_Rye_Bread	2026-02-26	Thu	8	2	2026	\N	2026-03-04 15:36:30.936525
332	70012004	500107	Demo_500g_Rye_Bread	2026-02-27	Fri	8	2	2026	\N	2026-03-04 15:36:42.560601
333	70012004	500107	Demo_500g_Rye_Bread	2026-02-28	Sat	8	2	2026	\N	2026-03-04 15:36:48.833182
295	70012004	500107	Demo_500g_Rye_Bread	2025-11-11	Tue	11	11	2025	\N	2026-03-04 15:24:58.018666
296	70012004	500107	Demo_500g_Rye_Bread	2025-11-12	Wed	9	11	2025	\N	2026-03-04 15:25:01.698579
1104	70012004	500107	Demo_500g_Rye_Bread	2025-09-23	Tue	15	9	2025	\N	2026-03-28 00:08:53.018779
1105	70012004	500107	Demo_500g_Rye_Bread	2025-09-24	Wed	13	9	2025	\N	2026-03-28 00:11:43.562173
1106	70012004	500107	Demo_500g_Rye_Bread	2025-09-25	Thu	14	9	2025	\N	2026-03-28 00:11:47.45028
1107	70012004	500107	Demo_500g_Rye_Bread	2025-09-26	Fri	16	9	2025	\N	2026-03-28 00:11:51.954365
1108	70012004	500107	Demo_500g_Rye_Bread	2025-09-27	Sat	14	9	2025	\N	2026-03-28 00:11:57.442213
1109	70012004	500107	Demo_500g_Rye_Bread	2025-09-28	Sun	15	9	2025	\N	2026-03-28 00:12:14.338229
294	70012004	500107	Demo_500g_Rye_Bread	2025-11-10	Mon	9	11	2025	\N	2026-03-04 15:24:53.954906
1113	70012004	500107	Demo_500g_Rye_Bread	2025-11-13	Thu	16	11	2025	\N	2026-03-28 00:17:13.473334
1114	70012004	500107	Demo_500g_Rye_Bread	2025-11-14	Fri	17	11	2025	\N	2026-03-28 00:17:16.601456
1115	70012004	500107	Demo_500g_Rye_Bread	2025-11-15	Sat	16	11	2025	\N	2026-03-28 00:17:23.14574
1116	70012004	500107	Demo_500g_Rye_Bread	2025-11-16	Sun	18	11	2025	\N	2026-03-28 00:17:33.217487
1117	70012004	500107	Demo_500g_Rye_Bread	2026-03-01	Sun	10	3	2026	\N	2026-03-28 00:18:18.161248
1118	70012004	500107	Demo_500g_Rye_Bread	2026-03-02	Mon	9	3	2026	\N	2026-03-28 00:22:29.512605
1119	70012004	500107	Demo_500g_Rye_Bread	2026-03-03	Tue	9	3	2026	\N	2026-03-28 00:22:38.976529
1120	70012004	500107	Demo_500g_Rye_Bread	2026-03-04	Wed	8	3	2026	\N	2026-03-28 00:22:51.28875
1121	70012004	500107	Demo_500g_Rye_Bread	2026-03-12	Thu	7	3	2026	\N	2026-03-28 00:24:16.600003
1122	70012004	500107	Demo_500g_Rye_Bread	2026-03-13	Fri	6	3	2026	\N	2026-03-28 00:24:19.704074
1123	70012004	500107	Demo_500g_Rye_Bread	2026-03-14	Sat	7	3	2026	\N	2026-03-28 00:24:23.888266
1124	70012004	500107	Demo_500g_Rye_Bread	2026-03-15	Sun	7	3	2026	\N	2026-03-28 00:24:30.720046
1125	70012004	500107	Demo_500g_Rye_Bread	2026-03-16	Mon	7	3	2026	\N	2026-03-28 00:24:35.543992
1126	70012004	500107	Demo_500g_Rye_Bread	2026-03-17	Tue	8	3	2026	\N	2026-03-28 00:24:44.000093
1127	70012004	500107	Demo_500g_Rye_Bread	2026-03-18	Wed	6	3	2026	\N	2026-03-28 00:24:50.920089
1128	70012004	500107	Demo_500g_Rye_Bread	2026-03-19	Thu	12	3	2026	\N	2026-03-28 00:25:53.696521
1129	70012004	500107	Demo_500g_Rye_Bread	2026-03-20	Fri	10	3	2026	\N	2026-03-28 00:25:59.807857
1130	70012004	500107	Demo_500g_Rye_Bread	2026-03-21	Sat	11	3	2026	\N	2026-03-28 00:26:04.559555
1131	70012004	500107	Demo_500g_Rye_Bread	2026-03-22	Sun	12	3	2026	\N	2026-03-28 00:26:09.047868
1132	70012004	500107	Demo_500g_Rye_Bread	2026-03-23	Mon	11	3	2026	\N	2026-03-28 00:26:13.455708
1133	70012004	500107	Demo_500g_Rye_Bread	2026-03-24	Tue	12	3	2026	\N	2026-03-28 00:26:17.105073
1134	70012004	500107	Demo_500g_Rye_Bread	2026-03-25	Wed	10	3	2026	\N	2026-03-28 00:26:27.535662
17858	70012002	500107	Demo_500g_Rye_Bread	2025-01-01	Wed	22	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17859	70012002	500107	Demo_500g_Rye_Bread	2025-01-02	Thu	23	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17860	70012002	500107	Demo_500g_Rye_Bread	2025-01-03	Fri	26	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17861	70012002	500107	Demo_500g_Rye_Bread	2025-01-04	Sat	24	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17862	70012002	500107	Demo_500g_Rye_Bread	2025-01-05	Sun	26	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17863	70012002	500107	Demo_500g_Rye_Bread	2025-01-06	Mon	24	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17864	70012002	500107	Demo_500g_Rye_Bread	2025-01-07	Tue	28	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17865	70012002	500107	Demo_500g_Rye_Bread	2025-01-08	Wed	22	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17866	70012002	500107	Demo_500g_Rye_Bread	2025-01-09	Thu	23	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17867	70012002	500107	Demo_500g_Rye_Bread	2025-01-10	Fri	26	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17868	70012002	500107	Demo_500g_Rye_Bread	2025-01-11	Sat	24	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17869	70012002	500107	Demo_500g_Rye_Bread	2025-01-12	Sun	26	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17870	70012002	500107	Demo_500g_Rye_Bread	2025-01-13	Mon	24	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17871	70012002	500107	Demo_500g_Rye_Bread	2025-01-14	Tue	28	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17872	70012002	500107	Demo_500g_Rye_Bread	2025-01-15	Wed	22	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17873	70012002	500107	Demo_500g_Rye_Bread	2025-01-16	Thu	23	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17874	70012002	500107	Demo_500g_Rye_Bread	2025-01-17	Fri	26	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17875	70012002	500107	Demo_500g_Rye_Bread	2025-01-18	Sat	24	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17876	70012002	500107	Demo_500g_Rye_Bread	2025-01-19	Sun	26	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17877	70012002	500107	Demo_500g_Rye_Bread	2025-01-20	Mon	24	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17878	70012002	500107	Demo_500g_Rye_Bread	2025-01-21	Tue	28	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17879	70012002	500107	Demo_500g_Rye_Bread	2025-01-22	Wed	22	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17880	70012002	500107	Demo_500g_Rye_Bread	2025-01-23	Thu	23	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17881	70012002	500107	Demo_500g_Rye_Bread	2025-01-24	Fri	26	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17882	70012002	500107	Demo_500g_Rye_Bread	2025-01-25	Sat	24	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17883	70012002	500107	Demo_500g_Rye_Bread	2025-01-26	Sun	26	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17884	70012002	500107	Demo_500g_Rye_Bread	2025-01-27	Mon	24	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17885	70012002	500107	Demo_500g_Rye_Bread	2025-01-28	Tue	28	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17886	70012002	500107	Demo_500g_Rye_Bread	2025-01-29	Wed	22	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17887	70012002	500107	Demo_500g_Rye_Bread	2025-01-30	Thu	23	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17888	70012002	500107	Demo_500g_Rye_Bread	2025-01-31	Fri	26	1	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17889	70012002	500107	Demo_500g_Rye_Bread	2025-02-01	Sat	24	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17890	70012002	500107	Demo_500g_Rye_Bread	2025-02-02	Sun	26	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17891	70012002	500107	Demo_500g_Rye_Bread	2025-02-03	Mon	24	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17892	70012002	500107	Demo_500g_Rye_Bread	2025-02-04	Tue	28	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17893	70012002	500107	Demo_500g_Rye_Bread	2025-02-05	Wed	22	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17894	70012002	500107	Demo_500g_Rye_Bread	2025-02-06	Thu	23	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17895	70012002	500107	Demo_500g_Rye_Bread	2025-02-07	Fri	26	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17896	70012002	500107	Demo_500g_Rye_Bread	2025-02-08	Sat	20	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17897	70012002	500107	Demo_500g_Rye_Bread	2025-02-09	Sun	22	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17898	70012002	500107	Demo_500g_Rye_Bread	2025-02-10	Mon	21	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17899	70012002	500107	Demo_500g_Rye_Bread	2025-02-11	Tue	24	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17900	70012002	500107	Demo_500g_Rye_Bread	2025-02-12	Wed	19	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17901	70012002	500107	Demo_500g_Rye_Bread	2025-02-13	Thu	19	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17902	70012002	500107	Demo_500g_Rye_Bread	2025-02-14	Fri	22	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17903	70012002	500107	Demo_500g_Rye_Bread	2025-02-15	Sat	12	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17904	70012002	500107	Demo_500g_Rye_Bread	2025-02-16	Sun	13	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17905	70012002	500107	Demo_500g_Rye_Bread	2025-02-17	Mon	12	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17906	70012002	500107	Demo_500g_Rye_Bread	2025-02-18	Tue	14	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17907	70012002	500107	Demo_500g_Rye_Bread	2025-02-19	Wed	11	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17908	70012002	500107	Demo_500g_Rye_Bread	2025-02-20	Thu	11	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17909	70012002	500107	Demo_500g_Rye_Bread	2025-02-21	Fri	13	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17910	70012002	500107	Demo_500g_Rye_Bread	2025-02-22	Sat	10	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17911	70012002	500107	Demo_500g_Rye_Bread	2025-02-23	Sun	11	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17912	70012002	500107	Demo_500g_Rye_Bread	2025-02-24	Mon	10	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17913	70012002	500107	Demo_500g_Rye_Bread	2025-02-25	Tue	12	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17914	70012002	500107	Demo_500g_Rye_Bread	2025-02-26	Wed	9	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17915	70012002	500107	Demo_500g_Rye_Bread	2025-02-27	Thu	10	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17916	70012002	500107	Demo_500g_Rye_Bread	2025-02-28	Fri	11	2	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17917	70012002	500107	Demo_500g_Rye_Bread	2025-03-01	Sat	11	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17918	70012002	500107	Demo_500g_Rye_Bread	2025-03-02	Sun	13	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17919	70012002	500107	Demo_500g_Rye_Bread	2025-03-03	Mon	12	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17920	70012002	500107	Demo_500g_Rye_Bread	2025-03-04	Tue	14	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17921	70012002	500107	Demo_500g_Rye_Bread	2025-03-05	Wed	11	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17922	70012002	500107	Demo_500g_Rye_Bread	2025-03-06	Thu	11	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17923	70012002	500107	Demo_500g_Rye_Bread	2025-03-07	Fri	13	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17924	70012002	500107	Demo_500g_Rye_Bread	2025-03-08	Sat	8	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17925	70012002	500107	Demo_500g_Rye_Bread	2025-03-09	Sun	9	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17926	70012002	500107	Demo_500g_Rye_Bread	2025-03-10	Mon	9	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17927	70012002	500107	Demo_500g_Rye_Bread	2025-03-11	Tue	10	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17928	70012002	500107	Demo_500g_Rye_Bread	2025-03-12	Wed	8	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17929	70012002	500107	Demo_500g_Rye_Bread	2025-03-13	Thu	8	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17930	70012002	500107	Demo_500g_Rye_Bread	2025-03-14	Fri	9	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17931	70012002	500107	Demo_500g_Rye_Bread	2025-03-15	Sat	11	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17932	70012002	500107	Demo_500g_Rye_Bread	2025-03-16	Sun	12	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17933	70012002	500107	Demo_500g_Rye_Bread	2025-03-17	Mon	11	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17934	70012002	500107	Demo_500g_Rye_Bread	2025-03-18	Tue	13	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17935	70012002	500107	Demo_500g_Rye_Bread	2025-03-19	Wed	10	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17936	70012002	500107	Demo_500g_Rye_Bread	2025-03-20	Thu	11	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17937	70012002	500107	Demo_500g_Rye_Bread	2025-03-21	Fri	12	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17938	70012002	500107	Demo_500g_Rye_Bread	2025-03-22	Sat	14	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17939	70012002	500107	Demo_500g_Rye_Bread	2025-03-23	Sun	16	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17940	70012002	500107	Demo_500g_Rye_Bread	2025-03-24	Mon	15	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17941	70012002	500107	Demo_500g_Rye_Bread	2025-03-25	Tue	17	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17942	70012002	500107	Demo_500g_Rye_Bread	2025-03-26	Wed	13	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17943	70012002	500107	Demo_500g_Rye_Bread	2025-03-27	Thu	14	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17944	70012002	500107	Demo_500g_Rye_Bread	2025-03-28	Fri	16	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17945	70012002	500107	Demo_500g_Rye_Bread	2025-03-29	Sat	14	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17946	70012002	500107	Demo_500g_Rye_Bread	2025-03-30	Sun	16	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17947	70012002	500107	Demo_500g_Rye_Bread	2025-03-31	Mon	15	3	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17948	70012002	500107	Demo_500g_Rye_Bread	2025-04-01	Tue	22	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17949	70012002	500107	Demo_500g_Rye_Bread	2025-04-02	Wed	17	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17950	70012002	500107	Demo_500g_Rye_Bread	2025-04-03	Thu	18	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17951	70012002	500107	Demo_500g_Rye_Bread	2025-04-04	Fri	20	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17952	70012002	500107	Demo_500g_Rye_Bread	2025-04-05	Sat	18	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17953	70012002	500107	Demo_500g_Rye_Bread	2025-04-06	Sun	20	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17954	70012002	500107	Demo_500g_Rye_Bread	2025-04-07	Mon	19	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17955	70012002	500107	Demo_500g_Rye_Bread	2025-04-08	Tue	17	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17956	70012002	500107	Demo_500g_Rye_Bread	2025-04-09	Wed	14	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17957	70012002	500107	Demo_500g_Rye_Bread	2025-04-10	Thu	14	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17958	70012002	500107	Demo_500g_Rye_Bread	2025-04-11	Fri	16	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17959	70012002	500107	Demo_500g_Rye_Bread	2025-04-12	Sat	15	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17960	70012002	500107	Demo_500g_Rye_Bread	2025-04-13	Sun	16	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17961	70012002	500107	Demo_500g_Rye_Bread	2025-04-14	Mon	15	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17962	70012002	500107	Demo_500g_Rye_Bread	2025-04-15	Tue	15	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17963	70012002	500107	Demo_500g_Rye_Bread	2025-04-16	Wed	12	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17964	70012002	500107	Demo_500g_Rye_Bread	2025-04-17	Thu	12	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17965	70012002	500107	Demo_500g_Rye_Bread	2025-04-18	Fri	14	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17966	70012002	500107	Demo_500g_Rye_Bread	2025-04-19	Sat	13	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17967	70012002	500107	Demo_500g_Rye_Bread	2025-04-20	Sun	14	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17968	70012002	500107	Demo_500g_Rye_Bread	2025-04-21	Mon	13	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17969	70012002	500107	Demo_500g_Rye_Bread	2025-04-22	Tue	17	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17970	70012002	500107	Demo_500g_Rye_Bread	2025-04-23	Wed	13	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17971	70012002	500107	Demo_500g_Rye_Bread	2025-04-24	Thu	14	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17972	70012002	500107	Demo_500g_Rye_Bread	2025-04-25	Fri	16	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17973	70012002	500107	Demo_500g_Rye_Bread	2025-04-26	Sat	14	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17974	70012002	500107	Demo_500g_Rye_Bread	2025-04-27	Sun	16	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17975	70012002	500107	Demo_500g_Rye_Bread	2025-04-28	Mon	15	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17976	70012002	500107	Demo_500g_Rye_Bread	2025-04-29	Tue	17	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17977	70012002	500107	Demo_500g_Rye_Bread	2025-04-30	Wed	13	4	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17978	70012002	500107	Demo_500g_Rye_Bread	2025-05-01	Thu	17	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17979	70012002	500107	Demo_500g_Rye_Bread	2025-05-02	Fri	19	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17980	70012002	500107	Demo_500g_Rye_Bread	2025-05-03	Sat	18	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17981	70012002	500107	Demo_500g_Rye_Bread	2025-05-04	Sun	19	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17982	70012002	500107	Demo_500g_Rye_Bread	2025-05-05	Mon	18	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17983	70012002	500107	Demo_500g_Rye_Bread	2025-05-06	Tue	21	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17984	70012002	500107	Demo_500g_Rye_Bread	2025-05-07	Wed	16	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17985	70012002	500107	Demo_500g_Rye_Bread	2025-05-08	Thu	17	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17986	70012002	500107	Demo_500g_Rye_Bread	2025-05-09	Fri	19	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17987	70012002	500107	Demo_500g_Rye_Bread	2025-05-10	Sat	18	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17988	70012002	500107	Demo_500g_Rye_Bread	2025-05-11	Sun	19	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17989	70012002	500107	Demo_500g_Rye_Bread	2025-05-12	Mon	18	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17990	70012002	500107	Demo_500g_Rye_Bread	2025-05-13	Tue	21	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17991	70012002	500107	Demo_500g_Rye_Bread	2025-05-14	Wed	16	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17992	70012002	500107	Demo_500g_Rye_Bread	2025-05-15	Thu	17	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17993	70012002	500107	Demo_500g_Rye_Bread	2025-05-16	Fri	19	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17994	70012002	500107	Demo_500g_Rye_Bread	2025-05-17	Sat	18	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17995	70012002	500107	Demo_500g_Rye_Bread	2025-05-18	Sun	19	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17996	70012002	500107	Demo_500g_Rye_Bread	2025-05-19	Mon	18	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17997	70012002	500107	Demo_500g_Rye_Bread	2025-05-20	Tue	21	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17998	70012002	500107	Demo_500g_Rye_Bread	2025-05-21	Wed	16	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
17999	70012002	500107	Demo_500g_Rye_Bread	2025-05-22	Thu	17	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18000	70012002	500107	Demo_500g_Rye_Bread	2025-05-23	Fri	19	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18001	70012002	500107	Demo_500g_Rye_Bread	2025-05-24	Sat	18	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18002	70012002	500107	Demo_500g_Rye_Bread	2025-05-25	Sun	19	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18003	70012002	500107	Demo_500g_Rye_Bread	2025-05-26	Mon	18	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18004	70012002	500107	Demo_500g_Rye_Bread	2025-05-27	Tue	21	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18005	70012002	500107	Demo_500g_Rye_Bread	2025-05-28	Wed	16	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18006	70012002	500107	Demo_500g_Rye_Bread	2025-05-29	Thu	17	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18007	70012002	500107	Demo_500g_Rye_Bread	2025-05-30	Fri	19	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18008	70012002	500107	Demo_500g_Rye_Bread	2025-05-31	Sat	18	5	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18009	70012002	500107	Demo_500g_Rye_Bread	2025-06-01	Sun	14	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18010	70012002	500107	Demo_500g_Rye_Bread	2025-06-02	Mon	13	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18011	70012002	500107	Demo_500g_Rye_Bread	2025-06-03	Tue	15	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18012	70012002	500107	Demo_500g_Rye_Bread	2025-06-04	Wed	12	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18013	70012002	500107	Demo_500g_Rye_Bread	2025-06-05	Thu	12	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18014	70012002	500107	Demo_500g_Rye_Bread	2025-06-06	Fri	14	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18015	70012002	500107	Demo_500g_Rye_Bread	2025-06-07	Sat	12	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18016	70012002	500107	Demo_500g_Rye_Bread	2025-06-08	Sun	12	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18017	70012002	500107	Demo_500g_Rye_Bread	2025-06-09	Mon	11	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18018	70012002	500107	Demo_500g_Rye_Bread	2025-06-10	Tue	13	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18019	70012002	500107	Demo_500g_Rye_Bread	2025-06-11	Wed	10	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18020	70012002	500107	Demo_500g_Rye_Bread	2025-06-12	Thu	11	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18021	70012002	500107	Demo_500g_Rye_Bread	2025-06-13	Fri	12	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18022	70012002	500107	Demo_500g_Rye_Bread	2025-06-14	Sat	11	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18023	70012002	500107	Demo_500g_Rye_Bread	2025-06-15	Sun	13	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18024	70012002	500107	Demo_500g_Rye_Bread	2025-06-16	Mon	12	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18025	70012002	500107	Demo_500g_Rye_Bread	2025-06-17	Tue	15	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18026	70012002	500107	Demo_500g_Rye_Bread	2025-06-18	Wed	11	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18027	70012002	500107	Demo_500g_Rye_Bread	2025-06-19	Thu	12	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18028	70012002	500107	Demo_500g_Rye_Bread	2025-06-20	Fri	13	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18029	70012002	500107	Demo_500g_Rye_Bread	2025-06-21	Sat	12	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18030	70012002	500107	Demo_500g_Rye_Bread	2025-06-22	Sun	16	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18031	70012002	500107	Demo_500g_Rye_Bread	2025-06-23	Mon	15	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18032	70012002	500107	Demo_500g_Rye_Bread	2025-06-24	Tue	17	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18033	70012002	500107	Demo_500g_Rye_Bread	2025-06-25	Wed	14	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18034	70012002	500107	Demo_500g_Rye_Bread	2025-06-26	Thu	14	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18035	70012002	500107	Demo_500g_Rye_Bread	2025-06-27	Fri	16	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18036	70012002	500107	Demo_500g_Rye_Bread	2025-06-28	Sat	15	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18037	70012002	500107	Demo_500g_Rye_Bread	2025-06-29	Sun	16	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18038	70012002	500107	Demo_500g_Rye_Bread	2025-06-30	Mon	15	6	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18039	70012002	500107	Demo_500g_Rye_Bread	2025-07-01	Tue	18	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18040	70012002	500107	Demo_500g_Rye_Bread	2025-07-02	Wed	14	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18041	70012002	500107	Demo_500g_Rye_Bread	2025-07-03	Thu	14	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18042	70012002	500107	Demo_500g_Rye_Bread	2025-07-04	Fri	16	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18043	70012002	500107	Demo_500g_Rye_Bread	2025-07-05	Sat	15	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18044	70012002	500107	Demo_500g_Rye_Bread	2025-07-06	Sun	16	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18045	70012002	500107	Demo_500g_Rye_Bread	2025-07-07	Mon	15	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18046	70012002	500107	Demo_500g_Rye_Bread	2025-07-08	Tue	25	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18047	70012002	500107	Demo_500g_Rye_Bread	2025-07-09	Wed	20	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18048	70012002	500107	Demo_500g_Rye_Bread	2025-07-10	Thu	20	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18049	70012002	500107	Demo_500g_Rye_Bread	2025-07-11	Fri	23	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18050	70012002	500107	Demo_500g_Rye_Bread	2025-07-12	Sat	21	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18051	70012002	500107	Demo_500g_Rye_Bread	2025-07-13	Sun	23	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18052	70012002	500107	Demo_500g_Rye_Bread	2025-07-14	Mon	22	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18053	70012002	500107	Demo_500g_Rye_Bread	2025-07-15	Tue	16	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18054	70012002	500107	Demo_500g_Rye_Bread	2025-07-16	Wed	13	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18055	70012002	500107	Demo_500g_Rye_Bread	2025-07-17	Thu	13	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18056	70012002	500107	Demo_500g_Rye_Bread	2025-07-18	Fri	15	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18057	70012002	500107	Demo_500g_Rye_Bread	2025-07-19	Sat	14	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18058	70012002	500107	Demo_500g_Rye_Bread	2025-07-20	Sun	15	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18059	70012002	500107	Demo_500g_Rye_Bread	2025-07-21	Mon	14	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18060	70012002	500107	Demo_500g_Rye_Bread	2025-07-22	Tue	17	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18061	70012002	500107	Demo_500g_Rye_Bread	2025-07-23	Wed	13	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18062	70012002	500107	Demo_500g_Rye_Bread	2025-07-24	Thu	14	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18063	70012002	500107	Demo_500g_Rye_Bread	2025-07-25	Fri	16	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18064	70012002	500107	Demo_500g_Rye_Bread	2025-07-26	Sat	14	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18065	70012002	500107	Demo_500g_Rye_Bread	2025-07-27	Sun	16	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18066	70012002	500107	Demo_500g_Rye_Bread	2025-07-28	Mon	15	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18067	70012002	500107	Demo_500g_Rye_Bread	2025-07-29	Tue	17	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18068	70012002	500107	Demo_500g_Rye_Bread	2025-07-30	Wed	13	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18069	70012002	500107	Demo_500g_Rye_Bread	2025-07-31	Thu	14	7	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18070	70012002	500107	Demo_500g_Rye_Bread	2025-08-01	Fri	24	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18071	70012002	500107	Demo_500g_Rye_Bread	2025-08-02	Sat	22	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18072	70012002	500107	Demo_500g_Rye_Bread	2025-08-03	Sun	24	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18073	70012002	500107	Demo_500g_Rye_Bread	2025-08-04	Mon	22	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18074	70012002	500107	Demo_500g_Rye_Bread	2025-08-05	Tue	26	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18075	70012002	500107	Demo_500g_Rye_Bread	2025-08-06	Wed	20	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18076	70012002	500107	Demo_500g_Rye_Bread	2025-08-07	Thu	21	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18077	70012002	500107	Demo_500g_Rye_Bread	2025-08-08	Fri	13	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18078	70012002	500107	Demo_500g_Rye_Bread	2025-08-09	Sat	12	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18079	70012002	500107	Demo_500g_Rye_Bread	2025-08-10	Sun	13	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18080	70012002	500107	Demo_500g_Rye_Bread	2025-08-11	Mon	12	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18081	70012002	500107	Demo_500g_Rye_Bread	2025-08-12	Tue	14	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18082	70012002	500107	Demo_500g_Rye_Bread	2025-08-13	Wed	11	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18083	70012002	500107	Demo_500g_Rye_Bread	2025-08-14	Thu	11	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18084	70012002	500107	Demo_500g_Rye_Bread	2025-08-15	Fri	17	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18085	70012002	500107	Demo_500g_Rye_Bread	2025-08-16	Sat	16	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18086	70012002	500107	Demo_500g_Rye_Bread	2025-08-17	Sun	17	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18087	70012002	500107	Demo_500g_Rye_Bread	2025-08-18	Mon	16	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18088	70012002	500107	Demo_500g_Rye_Bread	2025-08-19	Tue	19	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18089	70012002	500107	Demo_500g_Rye_Bread	2025-08-20	Wed	15	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18090	70012002	500107	Demo_500g_Rye_Bread	2025-08-21	Thu	15	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18091	70012002	500107	Demo_500g_Rye_Bread	2025-08-22	Fri	18	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18092	70012002	500107	Demo_500g_Rye_Bread	2025-08-23	Sat	16	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18093	70012002	500107	Demo_500g_Rye_Bread	2025-08-24	Sun	18	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18094	70012002	500107	Demo_500g_Rye_Bread	2025-08-25	Mon	17	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18095	70012002	500107	Demo_500g_Rye_Bread	2025-08-26	Tue	19	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18096	70012002	500107	Demo_500g_Rye_Bread	2025-08-27	Wed	15	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18097	70012002	500107	Demo_500g_Rye_Bread	2025-08-28	Thu	16	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18098	70012002	500107	Demo_500g_Rye_Bread	2025-08-29	Fri	18	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18099	70012002	500107	Demo_500g_Rye_Bread	2025-08-30	Sat	16	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18100	70012002	500107	Demo_500g_Rye_Bread	2025-08-31	Sun	18	8	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18101	70012002	500107	Demo_500g_Rye_Bread	2025-09-01	Mon	16	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18102	70012002	500107	Demo_500g_Rye_Bread	2025-09-02	Tue	18	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18103	70012002	500107	Demo_500g_Rye_Bread	2025-09-03	Wed	14	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18104	70012002	500107	Demo_500g_Rye_Bread	2025-09-04	Thu	15	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18105	70012002	500107	Demo_500g_Rye_Bread	2025-09-05	Fri	17	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18106	70012002	500107	Demo_500g_Rye_Bread	2025-09-06	Sat	16	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18107	70012002	500107	Demo_500g_Rye_Bread	2025-09-07	Sun	17	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18108	70012002	500107	Demo_500g_Rye_Bread	2025-09-08	Mon	18	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18109	70012002	500107	Demo_500g_Rye_Bread	2025-09-09	Tue	21	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18110	70012002	500107	Demo_500g_Rye_Bread	2025-09-10	Wed	17	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18111	70012002	500107	Demo_500g_Rye_Bread	2025-09-11	Thu	17	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18112	70012002	500107	Demo_500g_Rye_Bread	2025-09-12	Fri	20	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18113	70012002	500107	Demo_500g_Rye_Bread	2025-09-13	Sat	18	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18114	70012002	500107	Demo_500g_Rye_Bread	2025-09-14	Sun	20	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18115	70012002	500107	Demo_500g_Rye_Bread	2025-09-15	Mon	21	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18116	70012002	500107	Demo_500g_Rye_Bread	2025-09-16	Tue	24	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18117	70012002	500107	Demo_500g_Rye_Bread	2025-09-17	Wed	19	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18118	70012002	500107	Demo_500g_Rye_Bread	2025-09-18	Thu	19	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18119	70012002	500107	Demo_500g_Rye_Bread	2025-09-19	Fri	22	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18120	70012002	500107	Demo_500g_Rye_Bread	2025-09-20	Sat	20	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18121	70012002	500107	Demo_500g_Rye_Bread	2025-09-21	Sun	22	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18122	70012002	500107	Demo_500g_Rye_Bread	2025-09-22	Mon	18	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18123	70012002	500107	Demo_500g_Rye_Bread	2025-09-23	Tue	21	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18124	70012002	500107	Demo_500g_Rye_Bread	2025-09-24	Wed	17	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18125	70012002	500107	Demo_500g_Rye_Bread	2025-09-25	Thu	17	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18126	70012002	500107	Demo_500g_Rye_Bread	2025-09-26	Fri	20	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18127	70012002	500107	Demo_500g_Rye_Bread	2025-09-27	Sat	18	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18128	70012002	500107	Demo_500g_Rye_Bread	2025-09-28	Sun	20	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18129	70012002	500107	Demo_500g_Rye_Bread	2025-09-29	Mon	18	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18130	70012002	500107	Demo_500g_Rye_Bread	2025-09-30	Tue	21	9	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18131	70012002	500107	Demo_500g_Rye_Bread	2025-10-01	Wed	13	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18132	70012002	500107	Demo_500g_Rye_Bread	2025-10-02	Thu	14	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18133	70012002	500107	Demo_500g_Rye_Bread	2025-10-03	Fri	16	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18134	70012002	500107	Demo_500g_Rye_Bread	2025-10-04	Sat	14	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18135	70012002	500107	Demo_500g_Rye_Bread	2025-10-05	Sun	16	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18136	70012002	500107	Demo_500g_Rye_Bread	2025-10-06	Mon	15	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18137	70012002	500107	Demo_500g_Rye_Bread	2025-10-07	Tue	17	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18138	70012002	500107	Demo_500g_Rye_Bread	2025-10-08	Wed	13	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18139	70012002	500107	Demo_500g_Rye_Bread	2025-10-09	Thu	14	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18140	70012002	500107	Demo_500g_Rye_Bread	2025-10-10	Fri	16	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18141	70012002	500107	Demo_500g_Rye_Bread	2025-10-11	Sat	15	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18142	70012002	500107	Demo_500g_Rye_Bread	2025-10-12	Sun	16	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18143	70012002	500107	Demo_500g_Rye_Bread	2025-10-13	Mon	15	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18144	70012002	500107	Demo_500g_Rye_Bread	2025-10-14	Tue	17	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18145	70012002	500107	Demo_500g_Rye_Bread	2025-10-15	Wed	14	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18146	70012002	500107	Demo_500g_Rye_Bread	2025-10-16	Thu	14	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18147	70012002	500107	Demo_500g_Rye_Bread	2025-10-17	Fri	17	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18148	70012002	500107	Demo_500g_Rye_Bread	2025-10-18	Sat	15	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18149	70012002	500107	Demo_500g_Rye_Bread	2025-10-19	Sun	16	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18150	70012002	500107	Demo_500g_Rye_Bread	2025-10-20	Mon	15	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18151	70012002	500107	Demo_500g_Rye_Bread	2025-10-21	Tue	18	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18152	70012002	500107	Demo_500g_Rye_Bread	2025-10-22	Wed	16	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18153	70012002	500107	Demo_500g_Rye_Bread	2025-10-23	Thu	16	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18154	70012002	500107	Demo_500g_Rye_Bread	2025-10-24	Fri	19	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18155	70012002	500107	Demo_500g_Rye_Bread	2025-10-25	Sat	17	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18156	70012002	500107	Demo_500g_Rye_Bread	2025-10-26	Sun	18	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18157	70012002	500107	Demo_500g_Rye_Bread	2025-10-27	Mon	17	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18158	70012002	500107	Demo_500g_Rye_Bread	2025-10-28	Tue	20	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18159	70012002	500107	Demo_500g_Rye_Bread	2025-10-29	Wed	16	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18160	70012002	500107	Demo_500g_Rye_Bread	2025-10-30	Thu	16	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18161	70012002	500107	Demo_500g_Rye_Bread	2025-10-31	Fri	19	10	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18162	70012002	500107	Demo_500g_Rye_Bread	2025-11-01	Sat	16	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18163	70012002	500107	Demo_500g_Rye_Bread	2025-11-02	Sun	18	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18164	70012002	500107	Demo_500g_Rye_Bread	2025-11-03	Mon	16	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18165	70012002	500107	Demo_500g_Rye_Bread	2025-11-04	Tue	19	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18166	70012002	500107	Demo_500g_Rye_Bread	2025-11-05	Wed	15	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18167	70012002	500107	Demo_500g_Rye_Bread	2025-11-06	Thu	15	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18168	70012002	500107	Demo_500g_Rye_Bread	2025-11-07	Fri	18	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18169	70012002	500107	Demo_500g_Rye_Bread	2025-11-08	Sat	15	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18170	70012002	500107	Demo_500g_Rye_Bread	2025-11-09	Sun	17	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18171	70012002	500107	Demo_500g_Rye_Bread	2025-11-10	Mon	16	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18172	70012002	500107	Demo_500g_Rye_Bread	2025-11-11	Tue	18	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18173	70012002	500107	Demo_500g_Rye_Bread	2025-11-12	Wed	14	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18174	70012002	500107	Demo_500g_Rye_Bread	2025-11-13	Thu	15	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18175	70012002	500107	Demo_500g_Rye_Bread	2025-11-14	Fri	17	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18176	70012002	500107	Demo_500g_Rye_Bread	2025-11-15	Sat	22	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18177	70012002	500107	Demo_500g_Rye_Bread	2025-11-16	Sun	24	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18178	70012002	500107	Demo_500g_Rye_Bread	2025-11-17	Mon	22	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18179	70012002	500107	Demo_500g_Rye_Bread	2025-11-18	Tue	26	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18180	70012002	500107	Demo_500g_Rye_Bread	2025-11-19	Wed	20	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18181	70012002	500107	Demo_500g_Rye_Bread	2025-11-20	Thu	21	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18182	70012002	500107	Demo_500g_Rye_Bread	2025-11-21	Fri	24	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18183	70012002	500107	Demo_500g_Rye_Bread	2025-11-22	Sat	17	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18184	70012002	500107	Demo_500g_Rye_Bread	2025-11-23	Sun	18	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18185	70012002	500107	Demo_500g_Rye_Bread	2025-11-24	Mon	17	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18186	70012002	500107	Demo_500g_Rye_Bread	2025-11-25	Tue	20	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18187	70012002	500107	Demo_500g_Rye_Bread	2025-11-26	Wed	15	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18188	70012002	500107	Demo_500g_Rye_Bread	2025-11-27	Thu	16	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18189	70012002	500107	Demo_500g_Rye_Bread	2025-11-28	Fri	18	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18190	70012002	500107	Demo_500g_Rye_Bread	2025-11-29	Sat	17	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18191	70012002	500107	Demo_500g_Rye_Bread	2025-11-30	Sun	18	11	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18192	70012002	500107	Demo_500g_Rye_Bread	2025-12-01	Mon	15	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18193	70012002	500107	Demo_500g_Rye_Bread	2025-12-02	Tue	17	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18194	70012002	500107	Demo_500g_Rye_Bread	2025-12-03	Wed	13	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18195	70012002	500107	Demo_500g_Rye_Bread	2025-12-04	Thu	14	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18196	70012002	500107	Demo_500g_Rye_Bread	2025-12-05	Fri	16	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18197	70012002	500107	Demo_500g_Rye_Bread	2025-12-06	Sat	15	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18198	70012002	500107	Demo_500g_Rye_Bread	2025-12-07	Sun	16	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18199	70012002	500107	Demo_500g_Rye_Bread	2025-12-08	Mon	15	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18200	70012002	500107	Demo_500g_Rye_Bread	2025-12-09	Tue	17	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18201	70012002	500107	Demo_500g_Rye_Bread	2025-12-10	Wed	13	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18202	70012002	500107	Demo_500g_Rye_Bread	2025-12-11	Thu	14	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18203	70012002	500107	Demo_500g_Rye_Bread	2025-12-12	Fri	16	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18204	70012002	500107	Demo_500g_Rye_Bread	2025-12-13	Sat	15	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18205	70012002	500107	Demo_500g_Rye_Bread	2025-12-14	Sun	16	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18206	70012002	500107	Demo_500g_Rye_Bread	2025-12-15	Mon	15	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18207	70012002	500107	Demo_500g_Rye_Bread	2025-12-16	Tue	17	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18208	70012002	500107	Demo_500g_Rye_Bread	2025-12-17	Wed	13	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18209	70012002	500107	Demo_500g_Rye_Bread	2025-12-18	Thu	14	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18210	70012002	500107	Demo_500g_Rye_Bread	2025-12-19	Fri	16	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18211	70012002	500107	Demo_500g_Rye_Bread	2025-12-20	Sat	15	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18212	70012002	500107	Demo_500g_Rye_Bread	2025-12-21	Sun	16	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18213	70012002	500107	Demo_500g_Rye_Bread	2025-12-22	Mon	15	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18214	70012002	500107	Demo_500g_Rye_Bread	2025-12-23	Tue	17	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18215	70012002	500107	Demo_500g_Rye_Bread	2025-12-24	Wed	13	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18216	70012002	500107	Demo_500g_Rye_Bread	2025-12-25	Thu	14	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18217	70012002	500107	Demo_500g_Rye_Bread	2025-12-26	Fri	16	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18218	70012002	500107	Demo_500g_Rye_Bread	2025-12-27	Sat	15	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18219	70012002	500107	Demo_500g_Rye_Bread	2025-12-28	Sun	16	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18220	70012002	500107	Demo_500g_Rye_Bread	2025-12-29	Mon	15	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18221	70012002	500107	Demo_500g_Rye_Bread	2025-12-30	Tue	17	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18222	70012002	500107	Demo_500g_Rye_Bread	2025-12-31	Wed	13	12	2025	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18223	70012002	500107	Demo_500g_Rye_Bread	2026-01-01	Thu	23	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18224	70012002	500107	Demo_500g_Rye_Bread	2026-01-02	Fri	26	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18225	70012002	500107	Demo_500g_Rye_Bread	2026-01-03	Sat	24	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18226	70012002	500107	Demo_500g_Rye_Bread	2026-01-04	Sun	26	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18227	70012002	500107	Demo_500g_Rye_Bread	2026-01-05	Mon	24	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18228	70012002	500107	Demo_500g_Rye_Bread	2026-01-06	Tue	28	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18229	70012002	500107	Demo_500g_Rye_Bread	2026-01-07	Wed	22	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18230	70012002	500107	Demo_500g_Rye_Bread	2026-01-08	Thu	23	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18231	70012002	500107	Demo_500g_Rye_Bread	2026-01-09	Fri	26	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18232	70012002	500107	Demo_500g_Rye_Bread	2026-01-10	Sat	24	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18233	70012002	500107	Demo_500g_Rye_Bread	2026-01-11	Sun	26	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18234	70012002	500107	Demo_500g_Rye_Bread	2026-01-12	Mon	24	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18235	70012002	500107	Demo_500g_Rye_Bread	2026-01-13	Tue	28	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18236	70012002	500107	Demo_500g_Rye_Bread	2026-01-14	Wed	22	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18237	70012002	500107	Demo_500g_Rye_Bread	2026-01-15	Thu	23	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18238	70012002	500107	Demo_500g_Rye_Bread	2026-01-16	Fri	26	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18239	70012002	500107	Demo_500g_Rye_Bread	2026-01-17	Sat	24	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18240	70012002	500107	Demo_500g_Rye_Bread	2026-01-18	Sun	26	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18241	70012002	500107	Demo_500g_Rye_Bread	2026-01-19	Mon	24	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18242	70012002	500107	Demo_500g_Rye_Bread	2026-01-20	Tue	28	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18243	70012002	500107	Demo_500g_Rye_Bread	2026-01-21	Wed	22	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18244	70012002	500107	Demo_500g_Rye_Bread	2026-01-22	Thu	23	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18245	70012002	500107	Demo_500g_Rye_Bread	2026-01-23	Fri	26	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18246	70012002	500107	Demo_500g_Rye_Bread	2026-01-24	Sat	24	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18247	70012002	500107	Demo_500g_Rye_Bread	2026-01-25	Sun	26	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18248	70012002	500107	Demo_500g_Rye_Bread	2026-01-26	Mon	24	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18249	70012002	500107	Demo_500g_Rye_Bread	2026-01-27	Tue	28	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18250	70012002	500107	Demo_500g_Rye_Bread	2026-01-28	Wed	22	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18251	70012002	500107	Demo_500g_Rye_Bread	2026-01-29	Thu	23	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18252	70012002	500107	Demo_500g_Rye_Bread	2026-01-30	Fri	26	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18253	70012002	500107	Demo_500g_Rye_Bread	2026-01-31	Sat	24	1	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18254	70012002	500107	Demo_500g_Rye_Bread	2026-02-01	Sun	26	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18255	70012002	500107	Demo_500g_Rye_Bread	2026-02-02	Mon	24	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18256	70012002	500107	Demo_500g_Rye_Bread	2026-02-03	Tue	28	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18257	70012002	500107	Demo_500g_Rye_Bread	2026-02-04	Wed	22	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18258	70012002	500107	Demo_500g_Rye_Bread	2026-02-05	Thu	23	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18259	70012002	500107	Demo_500g_Rye_Bread	2026-02-06	Fri	26	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18260	70012002	500107	Demo_500g_Rye_Bread	2026-02-07	Sat	24	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18261	70012002	500107	Demo_500g_Rye_Bread	2026-02-08	Sun	22	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18262	70012002	500107	Demo_500g_Rye_Bread	2026-02-09	Mon	21	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18263	70012002	500107	Demo_500g_Rye_Bread	2026-02-10	Tue	24	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18264	70012002	500107	Demo_500g_Rye_Bread	2026-02-11	Wed	19	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18265	70012002	500107	Demo_500g_Rye_Bread	2026-02-12	Thu	19	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18266	70012002	500107	Demo_500g_Rye_Bread	2026-02-13	Fri	22	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18267	70012002	500107	Demo_500g_Rye_Bread	2026-02-14	Sat	20	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18268	70012002	500107	Demo_500g_Rye_Bread	2026-02-15	Sun	13	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18269	70012002	500107	Demo_500g_Rye_Bread	2026-02-16	Mon	12	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18270	70012002	500107	Demo_500g_Rye_Bread	2026-02-17	Tue	14	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18271	70012002	500107	Demo_500g_Rye_Bread	2026-02-18	Wed	11	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18272	70012002	500107	Demo_500g_Rye_Bread	2026-02-19	Thu	11	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18273	70012002	500107	Demo_500g_Rye_Bread	2026-02-20	Fri	13	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18274	70012002	500107	Demo_500g_Rye_Bread	2026-02-21	Sat	12	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18275	70012002	500107	Demo_500g_Rye_Bread	2026-02-22	Sun	11	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18276	70012002	500107	Demo_500g_Rye_Bread	2026-02-23	Mon	10	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18277	70012002	500107	Demo_500g_Rye_Bread	2026-02-24	Tue	12	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18278	70012002	500107	Demo_500g_Rye_Bread	2026-02-25	Wed	9	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18279	70012002	500107	Demo_500g_Rye_Bread	2026-02-26	Thu	10	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18280	70012002	500107	Demo_500g_Rye_Bread	2026-02-27	Fri	11	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18281	70012002	500107	Demo_500g_Rye_Bread	2026-02-28	Sat	10	2	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18282	70012002	500107	Demo_500g_Rye_Bread	2026-03-01	Sun	13	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18283	70012002	500107	Demo_500g_Rye_Bread	2026-03-02	Mon	12	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18284	70012002	500107	Demo_500g_Rye_Bread	2026-03-03	Tue	14	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18285	70012002	500107	Demo_500g_Rye_Bread	2026-03-04	Wed	11	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18286	70012002	500107	Demo_500g_Rye_Bread	2026-03-05	Thu	11	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18287	70012002	500107	Demo_500g_Rye_Bread	2026-03-06	Fri	13	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18288	70012002	500107	Demo_500g_Rye_Bread	2026-03-07	Sat	11	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18289	70012002	500107	Demo_500g_Rye_Bread	2026-03-08	Sun	9	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18290	70012002	500107	Demo_500g_Rye_Bread	2026-03-09	Mon	9	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18291	70012002	500107	Demo_500g_Rye_Bread	2026-03-10	Tue	10	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18292	70012002	500107	Demo_500g_Rye_Bread	2026-03-11	Wed	8	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18293	70012002	500107	Demo_500g_Rye_Bread	2026-03-12	Thu	8	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18294	70012002	500107	Demo_500g_Rye_Bread	2026-03-13	Fri	9	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18295	70012002	500107	Demo_500g_Rye_Bread	2026-03-14	Sat	8	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18296	70012002	500107	Demo_500g_Rye_Bread	2026-03-15	Sun	12	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18297	70012002	500107	Demo_500g_Rye_Bread	2026-03-16	Mon	11	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18298	70012002	500107	Demo_500g_Rye_Bread	2026-03-17	Tue	13	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18299	70012002	500107	Demo_500g_Rye_Bread	2026-03-18	Wed	10	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18300	70012002	500107	Demo_500g_Rye_Bread	2026-03-19	Thu	11	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18301	70012002	500107	Demo_500g_Rye_Bread	2026-03-20	Fri	12	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18302	70012002	500107	Demo_500g_Rye_Bread	2026-03-21	Sat	11	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18303	70012002	500107	Demo_500g_Rye_Bread	2026-03-22	Sun	16	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18304	70012002	500107	Demo_500g_Rye_Bread	2026-03-23	Mon	15	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18305	70012002	500107	Demo_500g_Rye_Bread	2026-03-24	Tue	17	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18306	70012002	500107	Demo_500g_Rye_Bread	2026-03-25	Wed	13	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18307	70012002	500107	Demo_500g_Rye_Bread	2026-03-26	Thu	14	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18308	70012002	500107	Demo_500g_Rye_Bread	2026-03-27	Fri	16	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18309	70012002	500107	Demo_500g_Rye_Bread	2026-03-28	Sat	14	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18310	70012002	500107	Demo_500g_Rye_Bread	2026-03-29	Sun	16	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18311	70012002	500107	Demo_500g_Rye_Bread	2026-03-30	Mon	15	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18312	70012002	500107	Demo_500g_Rye_Bread	2026-03-31	Tue	17	3	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18313	70012002	500107	Demo_500g_Rye_Bread	2026-04-01	Wed	17	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18314	70012002	500107	Demo_500g_Rye_Bread	2026-04-02	Thu	18	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18315	70012002	500107	Demo_500g_Rye_Bread	2026-04-03	Fri	20	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18316	70012002	500107	Demo_500g_Rye_Bread	2026-04-04	Sat	18	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18317	70012002	500107	Demo_500g_Rye_Bread	2026-04-05	Sun	20	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18318	70012002	500107	Demo_500g_Rye_Bread	2026-04-06	Mon	19	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18319	70012002	500107	Demo_500g_Rye_Bread	2026-04-07	Tue	22	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18320	70012002	500107	Demo_500g_Rye_Bread	2026-04-08	Wed	14	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18321	70012002	500107	Demo_500g_Rye_Bread	2026-04-09	Thu	14	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18322	70012002	500107	Demo_500g_Rye_Bread	2026-04-10	Fri	16	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18323	70012002	500107	Demo_500g_Rye_Bread	2026-04-11	Sat	15	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18324	70012002	500107	Demo_500g_Rye_Bread	2026-04-12	Sun	16	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18325	70012002	500107	Demo_500g_Rye_Bread	2026-04-13	Mon	15	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18326	70012002	500107	Demo_500g_Rye_Bread	2026-04-14	Tue	17	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18327	70012002	500107	Demo_500g_Rye_Bread	2026-04-15	Wed	12	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18328	70012002	500107	Demo_500g_Rye_Bread	2026-04-16	Thu	12	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18329	70012002	500107	Demo_500g_Rye_Bread	2026-04-17	Fri	14	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18330	70012002	500107	Demo_500g_Rye_Bread	2026-04-18	Sat	13	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18331	70012002	500107	Demo_500g_Rye_Bread	2026-04-19	Sun	14	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18332	70012002	500107	Demo_500g_Rye_Bread	2026-04-20	Mon	13	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18333	70012002	500107	Demo_500g_Rye_Bread	2026-04-21	Tue	15	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18334	70012002	500107	Demo_500g_Rye_Bread	2026-04-22	Wed	13	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18335	70012002	500107	Demo_500g_Rye_Bread	2026-04-23	Thu	14	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18336	70012002	500107	Demo_500g_Rye_Bread	2026-04-24	Fri	16	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18337	70012002	500107	Demo_500g_Rye_Bread	2026-04-25	Sat	14	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18338	70012002	500107	Demo_500g_Rye_Bread	2026-04-26	Sun	16	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18339	70012002	500107	Demo_500g_Rye_Bread	2026-04-27	Mon	15	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18340	70012002	500107	Demo_500g_Rye_Bread	2026-04-28	Tue	17	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18341	70012002	500107	Demo_500g_Rye_Bread	2026-04-29	Wed	13	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18342	70012002	500107	Demo_500g_Rye_Bread	2026-04-30	Thu	14	4	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18343	70012002	500107	Demo_500g_Rye_Bread	2026-05-01	Fri	19	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18344	70012002	500107	Demo_500g_Rye_Bread	2026-05-02	Sat	18	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18345	70012002	500107	Demo_500g_Rye_Bread	2026-05-03	Sun	19	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18346	70012002	500107	Demo_500g_Rye_Bread	2026-05-04	Mon	18	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18347	70012002	500107	Demo_500g_Rye_Bread	2026-05-05	Tue	21	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18348	70012002	500107	Demo_500g_Rye_Bread	2026-05-06	Wed	16	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18349	70012002	500107	Demo_500g_Rye_Bread	2026-05-07	Thu	17	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18350	70012002	500107	Demo_500g_Rye_Bread	2026-05-08	Fri	19	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18351	70012002	500107	Demo_500g_Rye_Bread	2026-05-09	Sat	18	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18352	70012002	500107	Demo_500g_Rye_Bread	2026-05-10	Sun	19	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18353	70012002	500107	Demo_500g_Rye_Bread	2026-05-11	Mon	18	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18354	70012002	500107	Demo_500g_Rye_Bread	2026-05-12	Tue	21	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18355	70012002	500107	Demo_500g_Rye_Bread	2026-05-13	Wed	16	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18356	70012002	500107	Demo_500g_Rye_Bread	2026-05-14	Thu	17	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18357	70012002	500107	Demo_500g_Rye_Bread	2026-05-15	Fri	19	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18358	70012002	500107	Demo_500g_Rye_Bread	2026-05-16	Sat	18	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18359	70012002	500107	Demo_500g_Rye_Bread	2026-05-17	Sun	19	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18360	70012002	500107	Demo_500g_Rye_Bread	2026-05-18	Mon	18	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18361	70012002	500107	Demo_500g_Rye_Bread	2026-05-19	Tue	21	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18362	70012002	500107	Demo_500g_Rye_Bread	2026-05-20	Wed	16	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18363	70012002	500107	Demo_500g_Rye_Bread	2026-05-21	Thu	17	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18364	70012002	500107	Demo_500g_Rye_Bread	2026-05-22	Fri	19	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18365	70012002	500107	Demo_500g_Rye_Bread	2026-05-23	Sat	18	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18366	70012002	500107	Demo_500g_Rye_Bread	2026-05-24	Sun	19	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18367	70012002	500107	Demo_500g_Rye_Bread	2026-05-25	Mon	18	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18368	70012002	500107	Demo_500g_Rye_Bread	2026-05-26	Tue	21	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18369	70012002	500107	Demo_500g_Rye_Bread	2026-05-27	Wed	16	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18370	70012002	500107	Demo_500g_Rye_Bread	2026-05-28	Thu	17	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18371	70012002	500107	Demo_500g_Rye_Bread	2026-05-29	Fri	19	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18372	70012002	500107	Demo_500g_Rye_Bread	2026-05-30	Sat	18	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18373	70012002	500107	Demo_500g_Rye_Bread	2026-05-31	Sun	19	5	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18374	70012002	500107	Demo_500g_Rye_Bread	2026-06-01	Mon	13	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18375	70012002	500107	Demo_500g_Rye_Bread	2026-06-02	Tue	15	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18376	70012002	500107	Demo_500g_Rye_Bread	2026-06-03	Wed	12	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18377	70012002	500107	Demo_500g_Rye_Bread	2026-06-04	Thu	12	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18378	70012002	500107	Demo_500g_Rye_Bread	2026-06-05	Fri	14	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18379	70012002	500107	Demo_500g_Rye_Bread	2026-06-06	Sat	12	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18380	70012002	500107	Demo_500g_Rye_Bread	2026-06-07	Sun	14	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18381	70012002	500107	Demo_500g_Rye_Bread	2026-06-08	Mon	11	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18382	70012002	500107	Demo_500g_Rye_Bread	2026-06-09	Tue	13	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18383	70012002	500107	Demo_500g_Rye_Bread	2026-06-10	Wed	10	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18384	70012002	500107	Demo_500g_Rye_Bread	2026-06-11	Thu	11	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18385	70012002	500107	Demo_500g_Rye_Bread	2026-06-12	Fri	12	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18386	70012002	500107	Demo_500g_Rye_Bread	2026-06-13	Sat	11	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18387	70012002	500107	Demo_500g_Rye_Bread	2026-06-14	Sun	12	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18388	70012002	500107	Demo_500g_Rye_Bread	2026-06-15	Mon	12	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18389	70012002	500107	Demo_500g_Rye_Bread	2026-06-16	Tue	15	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18390	70012002	500107	Demo_500g_Rye_Bread	2026-06-17	Wed	11	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18391	70012002	500107	Demo_500g_Rye_Bread	2026-06-18	Thu	12	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18392	70012002	500107	Demo_500g_Rye_Bread	2026-06-19	Fri	13	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18393	70012002	500107	Demo_500g_Rye_Bread	2026-06-20	Sat	12	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18394	70012002	500107	Demo_500g_Rye_Bread	2026-06-21	Sun	13	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18395	70012002	500107	Demo_500g_Rye_Bread	2026-06-22	Mon	15	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18396	70012002	500107	Demo_500g_Rye_Bread	2026-06-23	Tue	17	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18397	70012002	500107	Demo_500g_Rye_Bread	2026-06-24	Wed	14	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18398	70012002	500107	Demo_500g_Rye_Bread	2026-06-25	Thu	14	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18399	70012002	500107	Demo_500g_Rye_Bread	2026-06-26	Fri	16	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18400	70012002	500107	Demo_500g_Rye_Bread	2026-06-27	Sat	15	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18401	70012002	500107	Demo_500g_Rye_Bread	2026-06-28	Sun	16	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18402	70012002	500107	Demo_500g_Rye_Bread	2026-06-29	Mon	15	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18403	70012002	500107	Demo_500g_Rye_Bread	2026-06-30	Tue	17	6	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18404	70012002	500107	Demo_500g_Rye_Bread	2026-07-01	Wed	14	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18405	70012002	500107	Demo_500g_Rye_Bread	2026-07-02	Thu	14	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18406	70012002	500107	Demo_500g_Rye_Bread	2026-07-03	Fri	16	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18407	70012002	500107	Demo_500g_Rye_Bread	2026-07-04	Sat	15	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18408	70012002	500107	Demo_500g_Rye_Bread	2026-07-05	Sun	16	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18409	70012002	500107	Demo_500g_Rye_Bread	2026-07-06	Mon	15	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18410	70012002	500107	Demo_500g_Rye_Bread	2026-07-07	Tue	18	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18411	70012002	500107	Demo_500g_Rye_Bread	2026-07-08	Wed	20	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18412	70012002	500107	Demo_500g_Rye_Bread	2026-07-09	Thu	20	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18413	70012002	500107	Demo_500g_Rye_Bread	2026-07-10	Fri	23	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18414	70012002	500107	Demo_500g_Rye_Bread	2026-07-11	Sat	21	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18415	70012002	500107	Demo_500g_Rye_Bread	2026-07-12	Sun	23	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18416	70012002	500107	Demo_500g_Rye_Bread	2026-07-13	Mon	22	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18417	70012002	500107	Demo_500g_Rye_Bread	2026-07-14	Tue	25	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18418	70012002	500107	Demo_500g_Rye_Bread	2026-07-15	Wed	13	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18419	70012002	500107	Demo_500g_Rye_Bread	2026-07-16	Thu	13	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18420	70012002	500107	Demo_500g_Rye_Bread	2026-07-17	Fri	15	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18421	70012002	500107	Demo_500g_Rye_Bread	2026-07-18	Sat	14	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18422	70012002	500107	Demo_500g_Rye_Bread	2026-07-19	Sun	15	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18423	70012002	500107	Demo_500g_Rye_Bread	2026-07-20	Mon	14	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18424	70012002	500107	Demo_500g_Rye_Bread	2026-07-21	Tue	16	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18425	70012002	500107	Demo_500g_Rye_Bread	2026-07-22	Wed	13	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18426	70012002	500107	Demo_500g_Rye_Bread	2026-07-23	Thu	14	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18427	70012002	500107	Demo_500g_Rye_Bread	2026-07-24	Fri	16	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18428	70012002	500107	Demo_500g_Rye_Bread	2026-07-25	Sat	14	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18429	70012002	500107	Demo_500g_Rye_Bread	2026-07-26	Sun	16	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18430	70012002	500107	Demo_500g_Rye_Bread	2026-07-27	Mon	15	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18431	70012002	500107	Demo_500g_Rye_Bread	2026-07-28	Tue	17	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18432	70012002	500107	Demo_500g_Rye_Bread	2026-07-29	Wed	13	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18433	70012002	500107	Demo_500g_Rye_Bread	2026-07-30	Thu	14	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18434	70012002	500107	Demo_500g_Rye_Bread	2026-07-31	Fri	16	7	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18435	70012002	500107	Demo_500g_Rye_Bread	2026-08-01	Sat	22	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18436	70012002	500107	Demo_500g_Rye_Bread	2026-08-02	Sun	24	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18437	70012002	500107	Demo_500g_Rye_Bread	2026-08-03	Mon	22	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18438	70012002	500107	Demo_500g_Rye_Bread	2026-08-04	Tue	26	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18439	70012002	500107	Demo_500g_Rye_Bread	2026-08-05	Wed	20	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18440	70012002	500107	Demo_500g_Rye_Bread	2026-08-06	Thu	21	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18441	70012002	500107	Demo_500g_Rye_Bread	2026-08-07	Fri	24	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18442	70012002	500107	Demo_500g_Rye_Bread	2026-08-08	Sat	12	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18443	70012002	500107	Demo_500g_Rye_Bread	2026-08-09	Sun	13	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18444	70012002	500107	Demo_500g_Rye_Bread	2026-08-10	Mon	12	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18445	70012002	500107	Demo_500g_Rye_Bread	2026-08-11	Tue	14	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18446	70012002	500107	Demo_500g_Rye_Bread	2026-08-12	Wed	11	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18447	70012002	500107	Demo_500g_Rye_Bread	2026-08-13	Thu	11	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18448	70012002	500107	Demo_500g_Rye_Bread	2026-08-14	Fri	13	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18449	70012002	500107	Demo_500g_Rye_Bread	2026-08-15	Sat	16	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18450	70012002	500107	Demo_500g_Rye_Bread	2026-08-16	Sun	17	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18451	70012002	500107	Demo_500g_Rye_Bread	2026-08-17	Mon	16	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18452	70012002	500107	Demo_500g_Rye_Bread	2026-08-18	Tue	19	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18453	70012002	500107	Demo_500g_Rye_Bread	2026-08-19	Wed	15	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18454	70012002	500107	Demo_500g_Rye_Bread	2026-08-20	Thu	15	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18455	70012002	500107	Demo_500g_Rye_Bread	2026-08-21	Fri	17	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18456	70012002	500107	Demo_500g_Rye_Bread	2026-08-22	Sat	16	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18457	70012002	500107	Demo_500g_Rye_Bread	2026-08-23	Sun	18	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18458	70012002	500107	Demo_500g_Rye_Bread	2026-08-24	Mon	17	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18459	70012002	500107	Demo_500g_Rye_Bread	2026-08-25	Tue	19	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18460	70012002	500107	Demo_500g_Rye_Bread	2026-08-26	Wed	15	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18461	70012002	500107	Demo_500g_Rye_Bread	2026-08-27	Thu	16	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18462	70012002	500107	Demo_500g_Rye_Bread	2026-08-28	Fri	18	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18463	70012002	500107	Demo_500g_Rye_Bread	2026-08-29	Sat	16	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18464	70012002	500107	Demo_500g_Rye_Bread	2026-08-30	Sun	18	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18465	70012002	500107	Demo_500g_Rye_Bread	2026-08-31	Mon	17	8	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18466	70012002	500107	Demo_500g_Rye_Bread	2026-09-01	Tue	18	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18467	70012002	500107	Demo_500g_Rye_Bread	2026-09-02	Wed	14	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18468	70012002	500107	Demo_500g_Rye_Bread	2026-09-03	Thu	15	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18469	70012002	500107	Demo_500g_Rye_Bread	2026-09-04	Fri	17	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18470	70012002	500107	Demo_500g_Rye_Bread	2026-09-05	Sat	16	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18471	70012002	500107	Demo_500g_Rye_Bread	2026-09-06	Sun	17	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18472	70012002	500107	Demo_500g_Rye_Bread	2026-09-07	Mon	16	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18473	70012002	500107	Demo_500g_Rye_Bread	2026-09-08	Tue	21	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18474	70012002	500107	Demo_500g_Rye_Bread	2026-09-09	Wed	17	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18475	70012002	500107	Demo_500g_Rye_Bread	2026-09-10	Thu	17	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18476	70012002	500107	Demo_500g_Rye_Bread	2026-09-11	Fri	20	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18477	70012002	500107	Demo_500g_Rye_Bread	2026-09-12	Sat	18	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18478	70012002	500107	Demo_500g_Rye_Bread	2026-09-13	Sun	20	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18479	70012002	500107	Demo_500g_Rye_Bread	2026-09-14	Mon	18	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18480	70012002	500107	Demo_500g_Rye_Bread	2026-09-15	Tue	24	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18481	70012002	500107	Demo_500g_Rye_Bread	2026-09-16	Wed	19	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18482	70012002	500107	Demo_500g_Rye_Bread	2026-09-17	Thu	19	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18483	70012002	500107	Demo_500g_Rye_Bread	2026-09-18	Fri	22	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18484	70012002	500107	Demo_500g_Rye_Bread	2026-09-19	Sat	20	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18485	70012002	500107	Demo_500g_Rye_Bread	2026-09-20	Sun	22	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18486	70012002	500107	Demo_500g_Rye_Bread	2026-09-21	Mon	21	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18487	70012002	500107	Demo_500g_Rye_Bread	2026-09-22	Tue	21	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18488	70012002	500107	Demo_500g_Rye_Bread	2026-09-23	Wed	17	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18489	70012002	500107	Demo_500g_Rye_Bread	2026-09-24	Thu	17	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18490	70012002	500107	Demo_500g_Rye_Bread	2026-09-25	Fri	20	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18491	70012002	500107	Demo_500g_Rye_Bread	2026-09-26	Sat	18	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18492	70012002	500107	Demo_500g_Rye_Bread	2026-09-27	Sun	20	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18493	70012002	500107	Demo_500g_Rye_Bread	2026-09-28	Mon	18	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18494	70012002	500107	Demo_500g_Rye_Bread	2026-09-29	Tue	21	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18495	70012002	500107	Demo_500g_Rye_Bread	2026-09-30	Wed	17	9	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18496	70012002	500107	Demo_500g_Rye_Bread	2026-10-01	Thu	14	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18497	70012002	500107	Demo_500g_Rye_Bread	2026-10-02	Fri	16	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18498	70012002	500107	Demo_500g_Rye_Bread	2026-10-03	Sat	14	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18499	70012002	500107	Demo_500g_Rye_Bread	2026-10-04	Sun	16	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18500	70012002	500107	Demo_500g_Rye_Bread	2026-10-05	Mon	15	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18501	70012002	500107	Demo_500g_Rye_Bread	2026-10-06	Tue	17	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18502	70012002	500107	Demo_500g_Rye_Bread	2026-10-07	Wed	13	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18503	70012002	500107	Demo_500g_Rye_Bread	2026-10-08	Thu	14	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18504	70012002	500107	Demo_500g_Rye_Bread	2026-10-09	Fri	16	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18505	70012002	500107	Demo_500g_Rye_Bread	2026-10-10	Sat	15	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18506	70012002	500107	Demo_500g_Rye_Bread	2026-10-11	Sun	16	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18507	70012002	500107	Demo_500g_Rye_Bread	2026-10-12	Mon	15	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18508	70012002	500107	Demo_500g_Rye_Bread	2026-10-13	Tue	17	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18509	70012002	500107	Demo_500g_Rye_Bread	2026-10-14	Wed	13	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18510	70012002	500107	Demo_500g_Rye_Bread	2026-10-15	Thu	14	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18511	70012002	500107	Demo_500g_Rye_Bread	2026-10-16	Fri	17	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18512	70012002	500107	Demo_500g_Rye_Bread	2026-10-17	Sat	15	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18513	70012002	500107	Demo_500g_Rye_Bread	2026-10-18	Sun	16	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18514	70012002	500107	Demo_500g_Rye_Bread	2026-10-19	Mon	15	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18515	70012002	500107	Demo_500g_Rye_Bread	2026-10-20	Tue	18	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18516	70012002	500107	Demo_500g_Rye_Bread	2026-10-21	Wed	14	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18517	70012002	500107	Demo_500g_Rye_Bread	2026-10-22	Thu	16	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18518	70012002	500107	Demo_500g_Rye_Bread	2026-10-23	Fri	19	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18519	70012002	500107	Demo_500g_Rye_Bread	2026-10-24	Sat	17	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18520	70012002	500107	Demo_500g_Rye_Bread	2026-10-25	Sun	18	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18521	70012002	500107	Demo_500g_Rye_Bread	2026-10-26	Mon	17	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18522	70012002	500107	Demo_500g_Rye_Bread	2026-10-27	Tue	20	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18523	70012002	500107	Demo_500g_Rye_Bread	2026-10-28	Wed	16	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18524	70012002	500107	Demo_500g_Rye_Bread	2026-10-29	Thu	16	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18525	70012002	500107	Demo_500g_Rye_Bread	2026-10-30	Fri	19	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18526	70012002	500107	Demo_500g_Rye_Bread	2026-10-31	Sat	17	10	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18527	70012002	500107	Demo_500g_Rye_Bread	2026-11-01	Sun	18	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18528	70012002	500107	Demo_500g_Rye_Bread	2026-11-02	Mon	16	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18529	70012002	500107	Demo_500g_Rye_Bread	2026-11-03	Tue	19	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18530	70012002	500107	Demo_500g_Rye_Bread	2026-11-04	Wed	15	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18531	70012002	500107	Demo_500g_Rye_Bread	2026-11-05	Thu	15	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18532	70012002	500107	Demo_500g_Rye_Bread	2026-11-06	Fri	18	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18533	70012002	500107	Demo_500g_Rye_Bread	2026-11-07	Sat	16	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18534	70012002	500107	Demo_500g_Rye_Bread	2026-11-08	Sun	17	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18535	70012002	500107	Demo_500g_Rye_Bread	2026-11-09	Mon	16	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18536	70012002	500107	Demo_500g_Rye_Bread	2026-11-10	Tue	18	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18537	70012002	500107	Demo_500g_Rye_Bread	2026-11-11	Wed	14	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18538	70012002	500107	Demo_500g_Rye_Bread	2026-11-12	Thu	15	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18539	70012002	500107	Demo_500g_Rye_Bread	2026-11-13	Fri	17	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18540	70012002	500107	Demo_500g_Rye_Bread	2026-11-14	Sat	15	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18541	70012002	500107	Demo_500g_Rye_Bread	2026-11-15	Sun	24	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18542	70012002	500107	Demo_500g_Rye_Bread	2026-11-16	Mon	22	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18543	70012002	500107	Demo_500g_Rye_Bread	2026-11-17	Tue	26	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18544	70012002	500107	Demo_500g_Rye_Bread	2026-11-18	Wed	20	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18545	70012002	500107	Demo_500g_Rye_Bread	2026-11-19	Thu	21	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18546	70012002	500107	Demo_500g_Rye_Bread	2026-11-20	Fri	24	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18547	70012002	500107	Demo_500g_Rye_Bread	2026-11-21	Sat	22	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18548	70012002	500107	Demo_500g_Rye_Bread	2026-11-22	Sun	18	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18549	70012002	500107	Demo_500g_Rye_Bread	2026-11-23	Mon	17	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18550	70012002	500107	Demo_500g_Rye_Bread	2026-11-24	Tue	20	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18551	70012002	500107	Demo_500g_Rye_Bread	2026-11-25	Wed	15	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18552	70012002	500107	Demo_500g_Rye_Bread	2026-11-26	Thu	16	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18553	70012002	500107	Demo_500g_Rye_Bread	2026-11-27	Fri	18	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18554	70012002	500107	Demo_500g_Rye_Bread	2026-11-28	Sat	17	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18555	70012002	500107	Demo_500g_Rye_Bread	2026-11-29	Sun	18	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18556	70012002	500107	Demo_500g_Rye_Bread	2026-11-30	Mon	17	11	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18557	70012002	500107	Demo_500g_Rye_Bread	2026-12-01	Tue	17	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18558	70012002	500107	Demo_500g_Rye_Bread	2026-12-02	Wed	13	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18559	70012002	500107	Demo_500g_Rye_Bread	2026-12-03	Thu	14	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18560	70012002	500107	Demo_500g_Rye_Bread	2026-12-04	Fri	16	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18561	70012002	500107	Demo_500g_Rye_Bread	2026-12-05	Sat	15	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18562	70012002	500107	Demo_500g_Rye_Bread	2026-12-06	Sun	16	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18563	70012002	500107	Demo_500g_Rye_Bread	2026-12-07	Mon	15	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18564	70012002	500107	Demo_500g_Rye_Bread	2026-12-08	Tue	17	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18565	70012002	500107	Demo_500g_Rye_Bread	2026-12-09	Wed	13	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18566	70012002	500107	Demo_500g_Rye_Bread	2026-12-10	Thu	14	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18567	70012002	500107	Demo_500g_Rye_Bread	2026-12-11	Fri	16	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18568	70012002	500107	Demo_500g_Rye_Bread	2026-12-12	Sat	15	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18569	70012002	500107	Demo_500g_Rye_Bread	2026-12-13	Sun	16	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18570	70012002	500107	Demo_500g_Rye_Bread	2026-12-14	Mon	15	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18571	70012002	500107	Demo_500g_Rye_Bread	2026-12-15	Tue	17	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18572	70012002	500107	Demo_500g_Rye_Bread	2026-12-16	Wed	13	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18573	70012002	500107	Demo_500g_Rye_Bread	2026-12-17	Thu	14	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18574	70012002	500107	Demo_500g_Rye_Bread	2026-12-18	Fri	16	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18575	70012002	500107	Demo_500g_Rye_Bread	2026-12-19	Sat	15	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18576	70012002	500107	Demo_500g_Rye_Bread	2026-12-20	Sun	16	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18577	70012002	500107	Demo_500g_Rye_Bread	2026-12-21	Mon	15	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18578	70012002	500107	Demo_500g_Rye_Bread	2026-12-22	Tue	17	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18579	70012002	500107	Demo_500g_Rye_Bread	2026-12-23	Wed	13	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18580	70012002	500107	Demo_500g_Rye_Bread	2026-12-24	Thu	14	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18581	70012002	500107	Demo_500g_Rye_Bread	2026-12-25	Fri	16	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18582	70012002	500107	Demo_500g_Rye_Bread	2026-12-26	Sat	15	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18583	70012002	500107	Demo_500g_Rye_Bread	2026-12-27	Sun	16	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18584	70012002	500107	Demo_500g_Rye_Bread	2026-12-28	Mon	15	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18585	70012002	500107	Demo_500g_Rye_Bread	2026-12-29	Tue	17	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18586	70012002	500107	Demo_500g_Rye_Bread	2026-12-30	Wed	13	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18587	70012002	500107	Demo_500g_Rye_Bread	2026-12-31	Thu	14	12	2026	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18588	70012002	500107	Demo_500g_Rye_Bread	2027-01-01	Fri	26	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18589	70012002	500107	Demo_500g_Rye_Bread	2027-01-02	Sat	24	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18590	70012002	500107	Demo_500g_Rye_Bread	2027-01-03	Sun	26	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18591	70012002	500107	Demo_500g_Rye_Bread	2027-01-04	Mon	24	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18592	70012002	500107	Demo_500g_Rye_Bread	2027-01-05	Tue	28	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18593	70012002	500107	Demo_500g_Rye_Bread	2027-01-06	Wed	22	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18594	70012002	500107	Demo_500g_Rye_Bread	2027-01-07	Thu	23	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18595	70012002	500107	Demo_500g_Rye_Bread	2027-01-08	Fri	26	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18596	70012002	500107	Demo_500g_Rye_Bread	2027-01-09	Sat	24	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18597	70012002	500107	Demo_500g_Rye_Bread	2027-01-10	Sun	26	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18598	70012002	500107	Demo_500g_Rye_Bread	2027-01-11	Mon	24	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18599	70012002	500107	Demo_500g_Rye_Bread	2027-01-12	Tue	28	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18600	70012002	500107	Demo_500g_Rye_Bread	2027-01-13	Wed	22	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18601	70012002	500107	Demo_500g_Rye_Bread	2027-01-14	Thu	23	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18602	70012002	500107	Demo_500g_Rye_Bread	2027-01-15	Fri	26	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18603	70012002	500107	Demo_500g_Rye_Bread	2027-01-16	Sat	24	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18604	70012002	500107	Demo_500g_Rye_Bread	2027-01-17	Sun	26	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18605	70012002	500107	Demo_500g_Rye_Bread	2027-01-18	Mon	24	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18606	70012002	500107	Demo_500g_Rye_Bread	2027-01-19	Tue	28	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18607	70012002	500107	Demo_500g_Rye_Bread	2027-01-20	Wed	22	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18608	70012002	500107	Demo_500g_Rye_Bread	2027-01-21	Thu	23	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18609	70012002	500107	Demo_500g_Rye_Bread	2027-01-22	Fri	26	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18610	70012002	500107	Demo_500g_Rye_Bread	2027-01-23	Sat	24	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18611	70012002	500107	Demo_500g_Rye_Bread	2027-01-24	Sun	26	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18612	70012002	500107	Demo_500g_Rye_Bread	2027-01-25	Mon	24	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18613	70012002	500107	Demo_500g_Rye_Bread	2027-01-26	Tue	28	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18614	70012002	500107	Demo_500g_Rye_Bread	2027-01-27	Wed	22	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18615	70012002	500107	Demo_500g_Rye_Bread	2027-01-28	Thu	23	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18616	70012002	500107	Demo_500g_Rye_Bread	2027-01-29	Fri	26	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18617	70012002	500107	Demo_500g_Rye_Bread	2027-01-30	Sat	24	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18618	70012002	500107	Demo_500g_Rye_Bread	2027-01-31	Sun	26	1	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18619	70012002	500107	Demo_500g_Rye_Bread	2027-02-01	Mon	24	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18620	70012002	500107	Demo_500g_Rye_Bread	2027-02-02	Tue	28	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18621	70012002	500107	Demo_500g_Rye_Bread	2027-02-03	Wed	22	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18622	70012002	500107	Demo_500g_Rye_Bread	2027-02-04	Thu	23	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18623	70012002	500107	Demo_500g_Rye_Bread	2027-02-05	Fri	26	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18624	70012002	500107	Demo_500g_Rye_Bread	2027-02-06	Sat	24	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18625	70012002	500107	Demo_500g_Rye_Bread	2027-02-07	Sun	26	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18626	70012002	500107	Demo_500g_Rye_Bread	2027-02-08	Mon	21	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18627	70012002	500107	Demo_500g_Rye_Bread	2027-02-09	Tue	24	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18628	70012002	500107	Demo_500g_Rye_Bread	2027-02-10	Wed	19	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18629	70012002	500107	Demo_500g_Rye_Bread	2027-02-11	Thu	19	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18630	70012002	500107	Demo_500g_Rye_Bread	2027-02-12	Fri	22	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18631	70012002	500107	Demo_500g_Rye_Bread	2027-02-13	Sat	20	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18632	70012002	500107	Demo_500g_Rye_Bread	2027-02-14	Sun	22	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18633	70012002	500107	Demo_500g_Rye_Bread	2027-02-15	Mon	12	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18634	70012002	500107	Demo_500g_Rye_Bread	2027-02-16	Tue	14	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18635	70012002	500107	Demo_500g_Rye_Bread	2027-02-17	Wed	11	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18636	70012002	500107	Demo_500g_Rye_Bread	2027-02-18	Thu	11	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18637	70012002	500107	Demo_500g_Rye_Bread	2027-02-19	Fri	13	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18638	70012002	500107	Demo_500g_Rye_Bread	2027-02-20	Sat	12	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18639	70012002	500107	Demo_500g_Rye_Bread	2027-02-21	Sun	13	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18640	70012002	500107	Demo_500g_Rye_Bread	2027-02-22	Mon	10	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18641	70012002	500107	Demo_500g_Rye_Bread	2027-02-23	Tue	12	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18642	70012002	500107	Demo_500g_Rye_Bread	2027-02-24	Wed	9	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18643	70012002	500107	Demo_500g_Rye_Bread	2027-02-25	Thu	10	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18644	70012002	500107	Demo_500g_Rye_Bread	2027-02-26	Fri	11	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18645	70012002	500107	Demo_500g_Rye_Bread	2027-02-27	Sat	10	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18646	70012002	500107	Demo_500g_Rye_Bread	2027-02-28	Sun	11	2	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18647	70012002	500107	Demo_500g_Rye_Bread	2027-03-01	Mon	12	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18648	70012002	500107	Demo_500g_Rye_Bread	2027-03-02	Tue	14	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18649	70012002	500107	Demo_500g_Rye_Bread	2027-03-03	Wed	11	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18650	70012002	500107	Demo_500g_Rye_Bread	2027-03-04	Thu	11	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18651	70012002	500107	Demo_500g_Rye_Bread	2027-03-05	Fri	13	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18652	70012002	500107	Demo_500g_Rye_Bread	2027-03-06	Sat	11	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18653	70012002	500107	Demo_500g_Rye_Bread	2027-03-07	Sun	13	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18654	70012002	500107	Demo_500g_Rye_Bread	2027-03-08	Mon	9	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18655	70012002	500107	Demo_500g_Rye_Bread	2027-03-09	Tue	10	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18656	70012002	500107	Demo_500g_Rye_Bread	2027-03-10	Wed	8	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18657	70012002	500107	Demo_500g_Rye_Bread	2027-03-11	Thu	8	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18658	70012002	500107	Demo_500g_Rye_Bread	2027-03-12	Fri	9	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18659	70012002	500107	Demo_500g_Rye_Bread	2027-03-13	Sat	8	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18660	70012002	500107	Demo_500g_Rye_Bread	2027-03-14	Sun	9	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18661	70012002	500107	Demo_500g_Rye_Bread	2027-03-15	Mon	11	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18662	70012002	500107	Demo_500g_Rye_Bread	2027-03-16	Tue	13	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18663	70012002	500107	Demo_500g_Rye_Bread	2027-03-17	Wed	10	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18664	70012002	500107	Demo_500g_Rye_Bread	2027-03-18	Thu	11	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18665	70012002	500107	Demo_500g_Rye_Bread	2027-03-19	Fri	12	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18666	70012002	500107	Demo_500g_Rye_Bread	2027-03-20	Sat	11	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18667	70012002	500107	Demo_500g_Rye_Bread	2027-03-21	Sun	12	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18668	70012002	500107	Demo_500g_Rye_Bread	2027-03-22	Mon	15	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18669	70012002	500107	Demo_500g_Rye_Bread	2027-03-23	Tue	17	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18670	70012002	500107	Demo_500g_Rye_Bread	2027-03-24	Wed	13	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18671	70012002	500107	Demo_500g_Rye_Bread	2027-03-25	Thu	14	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18672	70012002	500107	Demo_500g_Rye_Bread	2027-03-26	Fri	16	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18673	70012002	500107	Demo_500g_Rye_Bread	2027-03-27	Sat	14	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18674	70012002	500107	Demo_500g_Rye_Bread	2027-03-28	Sun	16	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18675	70012002	500107	Demo_500g_Rye_Bread	2027-03-29	Mon	15	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18676	70012002	500107	Demo_500g_Rye_Bread	2027-03-30	Tue	17	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18677	70012002	500107	Demo_500g_Rye_Bread	2027-03-31	Wed	13	3	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18678	70012002	500107	Demo_500g_Rye_Bread	2027-04-01	Thu	18	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18679	70012002	500107	Demo_500g_Rye_Bread	2027-04-02	Fri	20	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18680	70012002	500107	Demo_500g_Rye_Bread	2027-04-03	Sat	18	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18681	70012002	500107	Demo_500g_Rye_Bread	2027-04-04	Sun	20	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18682	70012002	500107	Demo_500g_Rye_Bread	2027-04-05	Mon	19	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18683	70012002	500107	Demo_500g_Rye_Bread	2027-04-06	Tue	22	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18684	70012002	500107	Demo_500g_Rye_Bread	2027-04-07	Wed	17	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18685	70012002	500107	Demo_500g_Rye_Bread	2027-04-08	Thu	14	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18686	70012002	500107	Demo_500g_Rye_Bread	2027-04-09	Fri	16	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18687	70012002	500107	Demo_500g_Rye_Bread	2027-04-10	Sat	15	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18688	70012002	500107	Demo_500g_Rye_Bread	2027-04-11	Sun	16	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18689	70012002	500107	Demo_500g_Rye_Bread	2027-04-12	Mon	15	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18690	70012002	500107	Demo_500g_Rye_Bread	2027-04-13	Tue	17	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18691	70012002	500107	Demo_500g_Rye_Bread	2027-04-14	Wed	14	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18692	70012002	500107	Demo_500g_Rye_Bread	2027-04-15	Thu	12	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18693	70012002	500107	Demo_500g_Rye_Bread	2027-04-16	Fri	14	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18694	70012002	500107	Demo_500g_Rye_Bread	2027-04-17	Sat	13	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18695	70012002	500107	Demo_500g_Rye_Bread	2027-04-18	Sun	14	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18696	70012002	500107	Demo_500g_Rye_Bread	2027-04-19	Mon	13	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18697	70012002	500107	Demo_500g_Rye_Bread	2027-04-20	Tue	15	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18698	70012002	500107	Demo_500g_Rye_Bread	2027-04-21	Wed	12	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18699	70012002	500107	Demo_500g_Rye_Bread	2027-04-22	Thu	14	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18700	70012002	500107	Demo_500g_Rye_Bread	2027-04-23	Fri	16	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18701	70012002	500107	Demo_500g_Rye_Bread	2027-04-24	Sat	14	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18702	70012002	500107	Demo_500g_Rye_Bread	2027-04-25	Sun	16	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18703	70012002	500107	Demo_500g_Rye_Bread	2027-04-26	Mon	15	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18704	70012002	500107	Demo_500g_Rye_Bread	2027-04-27	Tue	17	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18705	70012002	500107	Demo_500g_Rye_Bread	2027-04-28	Wed	13	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18706	70012002	500107	Demo_500g_Rye_Bread	2027-04-29	Thu	14	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18707	70012002	500107	Demo_500g_Rye_Bread	2027-04-30	Fri	16	4	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18708	70012002	500107	Demo_500g_Rye_Bread	2027-05-01	Sat	18	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18709	70012002	500107	Demo_500g_Rye_Bread	2027-05-02	Sun	19	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18710	70012002	500107	Demo_500g_Rye_Bread	2027-05-03	Mon	18	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18711	70012002	500107	Demo_500g_Rye_Bread	2027-05-04	Tue	21	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18712	70012002	500107	Demo_500g_Rye_Bread	2027-05-05	Wed	16	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18713	70012002	500107	Demo_500g_Rye_Bread	2027-05-06	Thu	17	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18714	70012002	500107	Demo_500g_Rye_Bread	2027-05-07	Fri	19	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18715	70012002	500107	Demo_500g_Rye_Bread	2027-05-08	Sat	18	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18716	70012002	500107	Demo_500g_Rye_Bread	2027-05-09	Sun	19	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18717	70012002	500107	Demo_500g_Rye_Bread	2027-05-10	Mon	18	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18718	70012002	500107	Demo_500g_Rye_Bread	2027-05-11	Tue	21	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18719	70012002	500107	Demo_500g_Rye_Bread	2027-05-12	Wed	16	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18720	70012002	500107	Demo_500g_Rye_Bread	2027-05-13	Thu	17	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18721	70012002	500107	Demo_500g_Rye_Bread	2027-05-14	Fri	19	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18722	70012002	500107	Demo_500g_Rye_Bread	2027-05-15	Sat	18	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18723	70012002	500107	Demo_500g_Rye_Bread	2027-05-16	Sun	19	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18724	70012002	500107	Demo_500g_Rye_Bread	2027-05-17	Mon	18	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18725	70012002	500107	Demo_500g_Rye_Bread	2027-05-18	Tue	21	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18726	70012002	500107	Demo_500g_Rye_Bread	2027-05-19	Wed	16	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18727	70012002	500107	Demo_500g_Rye_Bread	2027-05-20	Thu	17	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18728	70012002	500107	Demo_500g_Rye_Bread	2027-05-21	Fri	19	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18729	70012002	500107	Demo_500g_Rye_Bread	2027-05-22	Sat	18	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18730	70012002	500107	Demo_500g_Rye_Bread	2027-05-23	Sun	19	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18731	70012002	500107	Demo_500g_Rye_Bread	2027-05-24	Mon	18	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18732	70012002	500107	Demo_500g_Rye_Bread	2027-05-25	Tue	21	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18733	70012002	500107	Demo_500g_Rye_Bread	2027-05-26	Wed	16	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18734	70012002	500107	Demo_500g_Rye_Bread	2027-05-27	Thu	17	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18735	70012002	500107	Demo_500g_Rye_Bread	2027-05-28	Fri	19	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18736	70012002	500107	Demo_500g_Rye_Bread	2027-05-29	Sat	18	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18737	70012002	500107	Demo_500g_Rye_Bread	2027-05-30	Sun	19	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18738	70012002	500107	Demo_500g_Rye_Bread	2027-05-31	Mon	18	5	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18739	70012002	500107	Demo_500g_Rye_Bread	2027-06-01	Tue	15	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18740	70012002	500107	Demo_500g_Rye_Bread	2027-06-02	Wed	12	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18741	70012002	500107	Demo_500g_Rye_Bread	2027-06-03	Thu	12	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18742	70012002	500107	Demo_500g_Rye_Bread	2027-06-04	Fri	14	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18743	70012002	500107	Demo_500g_Rye_Bread	2027-06-05	Sat	12	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18744	70012002	500107	Demo_500g_Rye_Bread	2027-06-06	Sun	14	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18745	70012002	500107	Demo_500g_Rye_Bread	2027-06-07	Mon	13	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18746	70012002	500107	Demo_500g_Rye_Bread	2027-06-08	Tue	13	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18747	70012002	500107	Demo_500g_Rye_Bread	2027-06-09	Wed	10	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18748	70012002	500107	Demo_500g_Rye_Bread	2027-06-10	Thu	11	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18749	70012002	500107	Demo_500g_Rye_Bread	2027-06-11	Fri	12	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18750	70012002	500107	Demo_500g_Rye_Bread	2027-06-12	Sat	11	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18751	70012002	500107	Demo_500g_Rye_Bread	2027-06-13	Sun	12	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18752	70012002	500107	Demo_500g_Rye_Bread	2027-06-14	Mon	11	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18753	70012002	500107	Demo_500g_Rye_Bread	2027-06-15	Tue	15	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18754	70012002	500107	Demo_500g_Rye_Bread	2027-06-16	Wed	11	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18755	70012002	500107	Demo_500g_Rye_Bread	2027-06-17	Thu	12	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18756	70012002	500107	Demo_500g_Rye_Bread	2027-06-18	Fri	13	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18757	70012002	500107	Demo_500g_Rye_Bread	2027-06-19	Sat	12	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18758	70012002	500107	Demo_500g_Rye_Bread	2027-06-20	Sun	13	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18759	70012002	500107	Demo_500g_Rye_Bread	2027-06-21	Mon	12	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18760	70012002	500107	Demo_500g_Rye_Bread	2027-06-22	Tue	17	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18761	70012002	500107	Demo_500g_Rye_Bread	2027-06-23	Wed	14	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18762	70012002	500107	Demo_500g_Rye_Bread	2027-06-24	Thu	14	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18763	70012002	500107	Demo_500g_Rye_Bread	2027-06-25	Fri	16	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18764	70012002	500107	Demo_500g_Rye_Bread	2027-06-26	Sat	15	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18765	70012002	500107	Demo_500g_Rye_Bread	2027-06-27	Sun	16	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18766	70012002	500107	Demo_500g_Rye_Bread	2027-06-28	Mon	15	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18767	70012002	500107	Demo_500g_Rye_Bread	2027-06-29	Tue	17	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18768	70012002	500107	Demo_500g_Rye_Bread	2027-06-30	Wed	14	6	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18769	70012002	500107	Demo_500g_Rye_Bread	2027-07-01	Thu	14	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18770	70012002	500107	Demo_500g_Rye_Bread	2027-07-02	Fri	16	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18771	70012002	500107	Demo_500g_Rye_Bread	2027-07-03	Sat	15	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18772	70012002	500107	Demo_500g_Rye_Bread	2027-07-04	Sun	16	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18773	70012002	500107	Demo_500g_Rye_Bread	2027-07-05	Mon	15	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18774	70012002	500107	Demo_500g_Rye_Bread	2027-07-06	Tue	18	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18775	70012002	500107	Demo_500g_Rye_Bread	2027-07-07	Wed	14	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18776	70012002	500107	Demo_500g_Rye_Bread	2027-07-08	Thu	20	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18777	70012002	500107	Demo_500g_Rye_Bread	2027-07-09	Fri	23	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18778	70012002	500107	Demo_500g_Rye_Bread	2027-07-10	Sat	21	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18779	70012002	500107	Demo_500g_Rye_Bread	2027-07-11	Sun	23	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18780	70012002	500107	Demo_500g_Rye_Bread	2027-07-12	Mon	22	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18781	70012002	500107	Demo_500g_Rye_Bread	2027-07-13	Tue	25	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18782	70012002	500107	Demo_500g_Rye_Bread	2027-07-14	Wed	20	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18783	70012002	500107	Demo_500g_Rye_Bread	2027-07-15	Thu	13	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18784	70012002	500107	Demo_500g_Rye_Bread	2027-07-16	Fri	15	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18785	70012002	500107	Demo_500g_Rye_Bread	2027-07-17	Sat	14	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18786	70012002	500107	Demo_500g_Rye_Bread	2027-07-18	Sun	15	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18787	70012002	500107	Demo_500g_Rye_Bread	2027-07-19	Mon	14	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18788	70012002	500107	Demo_500g_Rye_Bread	2027-07-20	Tue	16	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18789	70012002	500107	Demo_500g_Rye_Bread	2027-07-21	Wed	13	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18790	70012002	500107	Demo_500g_Rye_Bread	2027-07-22	Thu	14	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18791	70012002	500107	Demo_500g_Rye_Bread	2027-07-23	Fri	16	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18792	70012002	500107	Demo_500g_Rye_Bread	2027-07-24	Sat	14	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18793	70012002	500107	Demo_500g_Rye_Bread	2027-07-25	Sun	16	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18794	70012002	500107	Demo_500g_Rye_Bread	2027-07-26	Mon	15	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18795	70012002	500107	Demo_500g_Rye_Bread	2027-07-27	Tue	17	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18796	70012002	500107	Demo_500g_Rye_Bread	2027-07-28	Wed	13	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18797	70012002	500107	Demo_500g_Rye_Bread	2027-07-29	Thu	14	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18798	70012002	500107	Demo_500g_Rye_Bread	2027-07-30	Fri	16	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18799	70012002	500107	Demo_500g_Rye_Bread	2027-07-31	Sat	14	7	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18800	70012002	500107	Demo_500g_Rye_Bread	2027-08-01	Sun	24	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18801	70012002	500107	Demo_500g_Rye_Bread	2027-08-02	Mon	22	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18802	70012002	500107	Demo_500g_Rye_Bread	2027-08-03	Tue	26	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18803	70012002	500107	Demo_500g_Rye_Bread	2027-08-04	Wed	20	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18804	70012002	500107	Demo_500g_Rye_Bread	2027-08-05	Thu	21	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18805	70012002	500107	Demo_500g_Rye_Bread	2027-08-06	Fri	24	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18806	70012002	500107	Demo_500g_Rye_Bread	2027-08-07	Sat	22	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18807	70012002	500107	Demo_500g_Rye_Bread	2027-08-08	Sun	13	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18808	70012002	500107	Demo_500g_Rye_Bread	2027-08-09	Mon	12	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18809	70012002	500107	Demo_500g_Rye_Bread	2027-08-10	Tue	14	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18810	70012002	500107	Demo_500g_Rye_Bread	2027-08-11	Wed	11	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18811	70012002	500107	Demo_500g_Rye_Bread	2027-08-12	Thu	11	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18812	70012002	500107	Demo_500g_Rye_Bread	2027-08-13	Fri	13	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18813	70012002	500107	Demo_500g_Rye_Bread	2027-08-14	Sat	12	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18814	70012002	500107	Demo_500g_Rye_Bread	2027-08-15	Sun	17	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18815	70012002	500107	Demo_500g_Rye_Bread	2027-08-16	Mon	16	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18816	70012002	500107	Demo_500g_Rye_Bread	2027-08-17	Tue	19	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18817	70012002	500107	Demo_500g_Rye_Bread	2027-08-18	Wed	15	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18818	70012002	500107	Demo_500g_Rye_Bread	2027-08-19	Thu	15	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18819	70012002	500107	Demo_500g_Rye_Bread	2027-08-20	Fri	17	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18820	70012002	500107	Demo_500g_Rye_Bread	2027-08-21	Sat	16	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18821	70012002	500107	Demo_500g_Rye_Bread	2027-08-22	Sun	18	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18822	70012002	500107	Demo_500g_Rye_Bread	2027-08-23	Mon	17	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18823	70012002	500107	Demo_500g_Rye_Bread	2027-08-24	Tue	19	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18824	70012002	500107	Demo_500g_Rye_Bread	2027-08-25	Wed	15	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18825	70012002	500107	Demo_500g_Rye_Bread	2027-08-26	Thu	16	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18826	70012002	500107	Demo_500g_Rye_Bread	2027-08-27	Fri	18	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18827	70012002	500107	Demo_500g_Rye_Bread	2027-08-28	Sat	16	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18828	70012002	500107	Demo_500g_Rye_Bread	2027-08-29	Sun	18	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18829	70012002	500107	Demo_500g_Rye_Bread	2027-08-30	Mon	17	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18830	70012002	500107	Demo_500g_Rye_Bread	2027-08-31	Tue	19	8	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18831	70012002	500107	Demo_500g_Rye_Bread	2027-09-01	Wed	14	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18832	70012002	500107	Demo_500g_Rye_Bread	2027-09-02	Thu	15	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18833	70012002	500107	Demo_500g_Rye_Bread	2027-09-03	Fri	17	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18834	70012002	500107	Demo_500g_Rye_Bread	2027-09-04	Sat	16	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18835	70012002	500107	Demo_500g_Rye_Bread	2027-09-05	Sun	17	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18836	70012002	500107	Demo_500g_Rye_Bread	2027-09-06	Mon	16	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18837	70012002	500107	Demo_500g_Rye_Bread	2027-09-07	Tue	18	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18838	70012002	500107	Demo_500g_Rye_Bread	2027-09-08	Wed	17	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18839	70012002	500107	Demo_500g_Rye_Bread	2027-09-09	Thu	17	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18840	70012002	500107	Demo_500g_Rye_Bread	2027-09-10	Fri	20	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18841	70012002	500107	Demo_500g_Rye_Bread	2027-09-11	Sat	18	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18842	70012002	500107	Demo_500g_Rye_Bread	2027-09-12	Sun	20	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18843	70012002	500107	Demo_500g_Rye_Bread	2027-09-13	Mon	18	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18844	70012002	500107	Demo_500g_Rye_Bread	2027-09-14	Tue	21	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18845	70012002	500107	Demo_500g_Rye_Bread	2027-09-15	Wed	19	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18846	70012002	500107	Demo_500g_Rye_Bread	2027-09-16	Thu	19	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18847	70012002	500107	Demo_500g_Rye_Bread	2027-09-17	Fri	22	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18848	70012002	500107	Demo_500g_Rye_Bread	2027-09-18	Sat	20	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18849	70012002	500107	Demo_500g_Rye_Bread	2027-09-19	Sun	22	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18850	70012002	500107	Demo_500g_Rye_Bread	2027-09-20	Mon	21	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18851	70012002	500107	Demo_500g_Rye_Bread	2027-09-21	Tue	24	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18852	70012002	500107	Demo_500g_Rye_Bread	2027-09-22	Wed	17	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18853	70012002	500107	Demo_500g_Rye_Bread	2027-09-23	Thu	17	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18854	70012002	500107	Demo_500g_Rye_Bread	2027-09-24	Fri	20	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18855	70012002	500107	Demo_500g_Rye_Bread	2027-09-25	Sat	18	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18856	70012002	500107	Demo_500g_Rye_Bread	2027-09-26	Sun	20	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18857	70012002	500107	Demo_500g_Rye_Bread	2027-09-27	Mon	18	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18858	70012002	500107	Demo_500g_Rye_Bread	2027-09-28	Tue	21	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18859	70012002	500107	Demo_500g_Rye_Bread	2027-09-29	Wed	17	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18860	70012002	500107	Demo_500g_Rye_Bread	2027-09-30	Thu	17	9	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18861	70012002	500107	Demo_500g_Rye_Bread	2027-10-01	Fri	16	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18862	70012002	500107	Demo_500g_Rye_Bread	2027-10-02	Sat	14	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18863	70012002	500107	Demo_500g_Rye_Bread	2027-10-03	Sun	16	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18864	70012002	500107	Demo_500g_Rye_Bread	2027-10-04	Mon	15	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18865	70012002	500107	Demo_500g_Rye_Bread	2027-10-05	Tue	17	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18866	70012002	500107	Demo_500g_Rye_Bread	2027-10-06	Wed	13	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18867	70012002	500107	Demo_500g_Rye_Bread	2027-10-07	Thu	14	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18868	70012002	500107	Demo_500g_Rye_Bread	2027-10-08	Fri	16	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18869	70012002	500107	Demo_500g_Rye_Bread	2027-10-09	Sat	15	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18870	70012002	500107	Demo_500g_Rye_Bread	2027-10-10	Sun	16	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18871	70012002	500107	Demo_500g_Rye_Bread	2027-10-11	Mon	15	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18872	70012002	500107	Demo_500g_Rye_Bread	2027-10-12	Tue	17	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18873	70012002	500107	Demo_500g_Rye_Bread	2027-10-13	Wed	13	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18874	70012002	500107	Demo_500g_Rye_Bread	2027-10-14	Thu	14	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18875	70012002	500107	Demo_500g_Rye_Bread	2027-10-15	Fri	17	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18876	70012002	500107	Demo_500g_Rye_Bread	2027-10-16	Sat	15	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18877	70012002	500107	Demo_500g_Rye_Bread	2027-10-17	Sun	16	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18878	70012002	500107	Demo_500g_Rye_Bread	2027-10-18	Mon	15	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18879	70012002	500107	Demo_500g_Rye_Bread	2027-10-19	Tue	18	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18880	70012002	500107	Demo_500g_Rye_Bread	2027-10-20	Wed	14	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18881	70012002	500107	Demo_500g_Rye_Bread	2027-10-21	Thu	14	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18882	70012002	500107	Demo_500g_Rye_Bread	2027-10-22	Fri	19	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18883	70012002	500107	Demo_500g_Rye_Bread	2027-10-23	Sat	17	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18884	70012002	500107	Demo_500g_Rye_Bread	2027-10-24	Sun	18	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18885	70012002	500107	Demo_500g_Rye_Bread	2027-10-25	Mon	17	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18886	70012002	500107	Demo_500g_Rye_Bread	2027-10-26	Tue	20	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18887	70012002	500107	Demo_500g_Rye_Bread	2027-10-27	Wed	16	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18888	70012002	500107	Demo_500g_Rye_Bread	2027-10-28	Thu	16	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18889	70012002	500107	Demo_500g_Rye_Bread	2027-10-29	Fri	19	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18890	70012002	500107	Demo_500g_Rye_Bread	2027-10-30	Sat	17	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18891	70012002	500107	Demo_500g_Rye_Bread	2027-10-31	Sun	18	10	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18892	70012002	500107	Demo_500g_Rye_Bread	2027-11-01	Mon	16	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18893	70012002	500107	Demo_500g_Rye_Bread	2027-11-02	Tue	19	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18894	70012002	500107	Demo_500g_Rye_Bread	2027-11-03	Wed	15	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18895	70012002	500107	Demo_500g_Rye_Bread	2027-11-04	Thu	15	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18896	70012002	500107	Demo_500g_Rye_Bread	2027-11-05	Fri	18	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18897	70012002	500107	Demo_500g_Rye_Bread	2027-11-06	Sat	16	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18898	70012002	500107	Demo_500g_Rye_Bread	2027-11-07	Sun	18	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18899	70012002	500107	Demo_500g_Rye_Bread	2027-11-08	Mon	16	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18900	70012002	500107	Demo_500g_Rye_Bread	2027-11-09	Tue	18	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18901	70012002	500107	Demo_500g_Rye_Bread	2027-11-10	Wed	14	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18902	70012002	500107	Demo_500g_Rye_Bread	2027-11-11	Thu	15	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18903	70012002	500107	Demo_500g_Rye_Bread	2027-11-12	Fri	17	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18904	70012002	500107	Demo_500g_Rye_Bread	2027-11-13	Sat	15	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18905	70012002	500107	Demo_500g_Rye_Bread	2027-11-14	Sun	17	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18906	70012002	500107	Demo_500g_Rye_Bread	2027-11-15	Mon	22	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18907	70012002	500107	Demo_500g_Rye_Bread	2027-11-16	Tue	26	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18908	70012002	500107	Demo_500g_Rye_Bread	2027-11-17	Wed	20	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18909	70012002	500107	Demo_500g_Rye_Bread	2027-11-18	Thu	21	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18910	70012002	500107	Demo_500g_Rye_Bread	2027-11-19	Fri	24	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18911	70012002	500107	Demo_500g_Rye_Bread	2027-11-20	Sat	22	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18912	70012002	500107	Demo_500g_Rye_Bread	2027-11-21	Sun	24	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18913	70012002	500107	Demo_500g_Rye_Bread	2027-11-22	Mon	17	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18914	70012002	500107	Demo_500g_Rye_Bread	2027-11-23	Tue	20	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18915	70012002	500107	Demo_500g_Rye_Bread	2027-11-24	Wed	15	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18916	70012002	500107	Demo_500g_Rye_Bread	2027-11-25	Thu	16	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18917	70012002	500107	Demo_500g_Rye_Bread	2027-11-26	Fri	18	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18918	70012002	500107	Demo_500g_Rye_Bread	2027-11-27	Sat	17	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18919	70012002	500107	Demo_500g_Rye_Bread	2027-11-28	Sun	18	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18920	70012002	500107	Demo_500g_Rye_Bread	2027-11-29	Mon	17	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18921	70012002	500107	Demo_500g_Rye_Bread	2027-11-30	Tue	20	11	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18922	70012002	500107	Demo_500g_Rye_Bread	2027-12-01	Wed	13	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18923	70012002	500107	Demo_500g_Rye_Bread	2027-12-02	Thu	14	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18924	70012002	500107	Demo_500g_Rye_Bread	2027-12-03	Fri	16	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18925	70012002	500107	Demo_500g_Rye_Bread	2027-12-04	Sat	15	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18926	70012002	500107	Demo_500g_Rye_Bread	2027-12-05	Sun	16	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18927	70012002	500107	Demo_500g_Rye_Bread	2027-12-06	Mon	15	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18928	70012002	500107	Demo_500g_Rye_Bread	2027-12-07	Tue	17	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18929	70012002	500107	Demo_500g_Rye_Bread	2027-12-08	Wed	13	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18930	70012002	500107	Demo_500g_Rye_Bread	2027-12-09	Thu	14	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18931	70012002	500107	Demo_500g_Rye_Bread	2027-12-10	Fri	16	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18932	70012002	500107	Demo_500g_Rye_Bread	2027-12-11	Sat	15	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18933	70012002	500107	Demo_500g_Rye_Bread	2027-12-12	Sun	16	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18934	70012002	500107	Demo_500g_Rye_Bread	2027-12-13	Mon	15	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18935	70012002	500107	Demo_500g_Rye_Bread	2027-12-14	Tue	17	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18936	70012002	500107	Demo_500g_Rye_Bread	2027-12-15	Wed	13	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18937	70012002	500107	Demo_500g_Rye_Bread	2027-12-16	Thu	14	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18938	70012002	500107	Demo_500g_Rye_Bread	2027-12-17	Fri	16	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18939	70012002	500107	Demo_500g_Rye_Bread	2027-12-18	Sat	15	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18940	70012002	500107	Demo_500g_Rye_Bread	2027-12-19	Sun	16	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18941	70012002	500107	Demo_500g_Rye_Bread	2027-12-20	Mon	15	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18942	70012002	500107	Demo_500g_Rye_Bread	2027-12-21	Tue	17	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18943	70012002	500107	Demo_500g_Rye_Bread	2027-12-22	Wed	13	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18944	70012002	500107	Demo_500g_Rye_Bread	2027-12-23	Thu	14	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18945	70012002	500107	Demo_500g_Rye_Bread	2027-12-24	Fri	16	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18946	70012002	500107	Demo_500g_Rye_Bread	2027-12-25	Sat	15	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18947	70012002	500107	Demo_500g_Rye_Bread	2027-12-26	Sun	16	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18948	70012002	500107	Demo_500g_Rye_Bread	2027-12-27	Mon	15	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18949	70012002	500107	Demo_500g_Rye_Bread	2027-12-28	Tue	17	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18950	70012002	500107	Demo_500g_Rye_Bread	2027-12-29	Wed	13	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18951	70012002	500107	Demo_500g_Rye_Bread	2027-12-30	Thu	14	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
18952	70012002	500107	Demo_500g_Rye_Bread	2027-12-31	Fri	16	12	2027	synthetic:demo_store_shape+invoice_volume	2026-04-03 20:49:34.718545
\.


--
-- Data for Name: hormuz_config; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.hormuz_config (product_id, multiplier, updated_at) FROM stdin;
__global__	0.85	2026-08-02 17:40:06.200489
500107	1.0	2026-08-02 17:40:06.200489
\.


--
-- Data for Name: inventory_transactions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.inventory_transactions (transaction_id, product_id, store_id, transaction_type, quantity, transaction_date, source, source_reference, notes, created_at) FROM stdin;
\.


--
-- Data for Name: mlp_order_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.mlp_order_log (id, product_id, decision_time, mlp_recommendation, mlp_confidence, mlp_method, actual_loaves_ordered, was_overridden, override_reason, outcome, order_date, current_stock, sales_rate, reasoning, store_id, projected_stock, standing_order, adj_value, total_units, otto_action, otto_write_success, dow, column_index, monthly_multiplier, returns_rate, delivery_date, expected_sales, actual_sales_rate, pipeline_incoming, day_of_week, is_holiday, mlp_decision, tray_factor, features, verified) FROM stdin;
154	500107	2026-03-05 21:55:37.975096	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	68	\N	Stock: 68 units | (5.4 days effective) | Sales: 12.7/day | -> ORDER 18 (18 loaves) | [100% confidence]	70012004	68.1	0	18	18	\N	\N	Thu	44	1.11	0	2026-03-12	12.65	0	0	3	f	18	10	[0.85, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
155	500107	2026-03-05 21:55:37.989671	\N	0.9976	mlp_v9_500107	\N	f	\N	\N	\N	57	\N	Stock: 57 units | (3.8 days effective) | Sales: 14.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	57.6	0	27	27	\N	\N	Fri	45	1.11	0	2026-03-13	14.92	0	0	4	f	27	10	[0.7125, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
156	500107	2026-03-05 21:55:38.003578	\N	0.9261	mlp_v9_500107	\N	f	\N	\N	\N	45	\N	Stock: 45 units | (3.1 days effective) | Sales: 14.3/day | -> ORDER 27 (27 loaves) | [93% confidence]	70012004	45.5	0	27	27	\N	\N	Mon	41	1.11	0	2026-03-16	14.35	0	0	0	f	27	10	[0.5625, 0.0, 0.574, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
157	500107	2026-03-05 21:55:38.017403	\N	0.9997	mlp_v9_500107	\N	f	\N	\N	\N	33	\N	Stock: 33 units | (2.0 days effective) | Sales: 16.6/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	33.2	0	36	36	\N	\N	Tue	42	1.11	0	2026-03-17	16.62	0	0	1	f	36	10	[0.4125, 0.16666666666666666, 0.6648000000000001, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
158	500107	2026-03-05 21:55:38.031508	\N	0.508	mlp_v9_500107	\N	f	\N	\N	\N	87	\N	Stock: 87 units | (6.9 days effective) | Sales: 12.7/day | -> No order needed | [51% confidence]	70012004	87.5	0	0	0	\N	\N	Thu	44	1.11	0	2026-03-19	12.65	0	0	3	f	0	10	[1.0875, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
159	500107	2026-03-05 21:55:38.046023	\N	0.9901	mlp_v9_500107	\N	f	\N	\N	\N	43	\N	Stock: 43 units | (2.9 days effective) | Sales: 14.9/day | -> ORDER 36 (36 loaves) | [99% confidence]	70012004	43.1	0	36	36	\N	\N	Fri	45	1.11	0	2026-03-20	14.92	0	0	4	f	36	10	[0.5375, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
160	500107	2026-03-05 21:57:36.153214	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	68	\N	Stock: 68 units | (5.4 days effective) | Sales: 12.7/day | -> ORDER 18 (18 loaves) | [100% confidence]	70012004	68.1	0	18	18	failed	\N	Thu	44	1.11	0	2026-03-12	12.65	0	0	3	f	18	10	[0.85, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
161	500107	2026-03-05 21:57:36.17553	\N	0.9976	mlp_v9_500107	\N	f	\N	\N	\N	57	\N	Stock: 57 units | (3.8 days effective) | Sales: 14.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	57.6	0	27	27	failed	\N	Fri	45	1.11	0	2026-03-13	14.92	0	0	4	f	27	10	[0.7125, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
162	500107	2026-03-05 21:57:36.189513	\N	0.9261	mlp_v9_500107	\N	f	\N	\N	\N	45	\N	Stock: 45 units | (3.1 days effective) | Sales: 14.3/day | -> ORDER 27 (27 loaves) | [93% confidence]	70012004	45.5	0	27	27	failed	\N	Mon	41	1.11	0	2026-03-16	14.35	0	0	0	f	27	10	[0.5625, 0.0, 0.574, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
163	500107	2026-03-05 21:57:36.203379	\N	0.9997	mlp_v9_500107	\N	f	\N	\N	\N	33	\N	Stock: 33 units | (2.0 days effective) | Sales: 16.6/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	33.2	0	36	36	failed	\N	Tue	42	1.11	0	2026-03-17	16.62	0	0	1	f	36	10	[0.4125, 0.16666666666666666, 0.6648000000000001, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
164	500107	2026-03-05 21:57:36.217137	\N	0.508	mlp_v9_500107	\N	f	\N	\N	\N	87	\N	Stock: 87 units | (6.9 days effective) | Sales: 12.7/day | -> No order needed | [51% confidence]	70012004	87.5	0	0	0	skipped	\N	Thu	44	1.11	0	2026-03-19	12.65	0	0	3	f	0	10	[1.0875, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
165	500107	2026-03-05 21:57:36.231431	\N	0.9901	mlp_v9_500107	\N	f	\N	\N	\N	43	\N	Stock: 43 units | (2.9 days effective) | Sales: 14.9/day | -> ORDER 36 (36 loaves) | [99% confidence]	70012004	43.1	0	36	36	failed	\N	Fri	45	1.11	0	2026-03-20	14.92	0	0	4	f	36	10	[0.5375, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
166	500107	2026-03-05 22:04:17.098679	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	68	\N	Stock: 68 units | (5.4 days effective) | Sales: 12.7/day | -> ORDER 18 (18 loaves) | [100% confidence]	70012004	68.1	0	18	18	failed	\N	Thu	44	1.11	0	2026-03-12	12.65	0	0	3	f	18	10	[0.85, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
167	500107	2026-03-05 22:04:17.123081	\N	0.9976	mlp_v9_500107	\N	f	\N	\N	\N	57	\N	Stock: 57 units | (3.8 days effective) | Sales: 14.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	57.6	0	27	27	failed	\N	Fri	45	1.11	0	2026-03-13	14.92	0	0	4	f	27	10	[0.7125, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
168	500107	2026-03-05 22:04:17.138334	\N	0.9261	mlp_v9_500107	\N	f	\N	\N	\N	45	\N	Stock: 45 units | (3.1 days effective) | Sales: 14.3/day | -> ORDER 27 (27 loaves) | [93% confidence]	70012004	45.5	0	27	27	written	\N	Mon	41	1.11	0	2026-03-16	14.35	0	0	0	f	27	10	[0.5625, 0.0, 0.574, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
169	500107	2026-03-05 22:04:17.153711	\N	0.9997	mlp_v9_500107	\N	f	\N	\N	\N	33	\N	Stock: 33 units | (2.0 days effective) | Sales: 16.6/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	33.2	0	36	36	written	\N	Tue	42	1.11	0	2026-03-17	16.62	0	0	1	f	36	10	[0.4125, 0.16666666666666666, 0.6648000000000001, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
170	500107	2026-03-05 22:04:17.167906	\N	0.508	mlp_v9_500107	\N	f	\N	\N	\N	87	\N	Stock: 87 units | (6.9 days effective) | Sales: 12.7/day | -> No order needed | [51% confidence]	70012004	87.5	0	0	0	skipped	\N	Thu	44	1.11	0	2026-03-19	12.65	0	0	3	f	0	10	[1.0875, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
171	500107	2026-03-05 22:04:17.182448	\N	0.9901	mlp_v9_500107	\N	f	\N	\N	\N	43	\N	Stock: 43 units | (2.9 days effective) | Sales: 14.9/day | -> ORDER 36 (36 loaves) | [99% confidence]	70012004	43.1	0	36	36	written	\N	Fri	45	1.11	0	2026-03-20	14.92	0	0	4	f	36	10	[0.5375, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
172	500107	2026-03-05 22:16:07.071354	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	68	\N	Stock: 68 units | (5.4 days effective) | Sales: 12.7/day | -> ORDER 18 (18 loaves) | [100% confidence]	70012004	68.1	0	18	18	submitted	\N	Thu	44	1.11	0	2026-03-12	12.65	0	0	3	f	18	10	[0.85, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
173	500107	2026-03-05 22:16:07.086302	\N	0.9976	mlp_v9_500107	\N	f	\N	\N	\N	57	\N	Stock: 57 units | (3.8 days effective) | Sales: 14.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	57.6	0	27	27	submitted	\N	Fri	45	1.11	0	2026-03-13	14.92	0	0	4	f	27	10	[0.7125, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
174	500107	2026-03-05 22:16:07.10023	\N	0.9261	mlp_v9_500107	\N	f	\N	\N	\N	45	\N	Stock: 45 units | (3.1 days effective) | Sales: 14.3/day | -> ORDER 27 (27 loaves) | [93% confidence]	70012004	45.5	0	27	27	submitted	\N	Mon	41	1.11	0	2026-03-16	14.35	0	0	0	f	27	10	[0.5625, 0.0, 0.574, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
175	500107	2026-03-05 22:16:07.115139	\N	0.9997	mlp_v9_500107	\N	f	\N	\N	\N	33	\N	Stock: 33 units | (2.0 days effective) | Sales: 16.6/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	33.2	0	36	36	submitted	\N	Tue	42	1.11	0	2026-03-17	16.62	0	0	1	f	36	10	[0.4125, 0.16666666666666666, 0.6648000000000001, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
176	500107	2026-03-05 22:16:07.130425	\N	0.508	mlp_v9_500107	\N	f	\N	\N	\N	87	\N	Stock: 87 units | (6.9 days effective) | Sales: 12.7/day | -> No order needed | [51% confidence]	70012004	87.5	0	0	0	skipped	\N	Thu	44	1.11	0	2026-03-19	12.65	0	0	3	f	0	10	[1.0875, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
177	500107	2026-03-05 22:16:07.144505	\N	0.9901	mlp_v9_500107	\N	f	\N	\N	\N	43	\N	Stock: 43 units | (2.9 days effective) | Sales: 14.9/day | -> ORDER 36 (36 loaves) | [99% confidence]	70012004	43.1	0	36	36	submitted	\N	Fri	45	1.11	0	2026-03-20	14.92	0	0	4	f	36	10	[0.5375, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
178	500107	2026-03-05 22:36:00.750916	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	77	\N	Stock: 77 units | (6.1 days effective) | Sales: 12.7/day | -> ORDER 18 (18 loaves) | [100% confidence]	70012004	77.1	0	18	18	submitted	\N	Thu	36	1.11	0	2026-03-12	12.65	0	0	3	f	18	10	[0.9625, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
179	500107	2026-03-05 22:36:00.773475	\N	0.9976	mlp_v9_500107	\N	f	\N	\N	\N	66	\N	Stock: 66 units | (4.4 days effective) | Sales: 14.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	66.6	0	27	27	submitted	\N	Fri	37	1.11	0	2026-03-13	14.92	0	0	4	f	27	10	[0.825, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
180	500107	2026-03-05 22:36:00.787333	\N	0.9881	mlp_v9_500107	\N	f	\N	\N	\N	54	\N	Stock: 54 units | (3.8 days effective) | Sales: 14.3/day | -> ORDER 27 (27 loaves) | [99% confidence]	70012004	54.5	0	27	27	submitted	\N	Mon	41	1.11	0	2026-03-16	14.35	0	0	0	f	27	10	[0.675, 0.0, 0.574, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
181	500107	2026-03-05 22:36:00.801661	\N	0.9973	mlp_v9_500107	\N	f	\N	\N	\N	42	\N	Stock: 42 units | (2.5 days effective) | Sales: 16.6/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	42.2	0	36	36	submitted	\N	Tue	42	1.11	0	2026-03-17	16.62	0	0	1	f	36	10	[0.525, 0.16666666666666666, 0.6648000000000001, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
182	500107	2026-03-05 22:36:00.815831	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	96	\N	Stock: 96 units | (7.6 days effective) | Sales: 12.7/day | -> No order needed | [100% confidence]	70012004	96.5	0	0	0	skipped	\N	Thu	44	1.11	0	2026-03-19	12.65	0	0	3	f	0	10	[1.2, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
183	500107	2026-03-05 22:36:00.829525	\N	0.997	mlp_v9_500107	\N	f	\N	\N	\N	52	\N	Stock: 52 units | (3.5 days effective) | Sales: 14.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	52.1	0	27	27	submitted	\N	Fri	45	1.11	0	2026-03-20	14.92	0	0	4	f	27	10	[0.65, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
192	500107	2026-03-05 22:49:45.72093	\N	1	mlp_v9_500107	\N	t	Dangerously low stock 0 - max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 12.7/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	failed	\N	Thu	36	1.11	0	2026-03-12	12.65	0	0	3	f	36	10	[0.0, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
193	500107	2026-03-05 22:49:45.743518	\N	1	mlp_v9_500107	\N	t	Dangerously low stock 0 - max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 14.9/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	failed	\N	Fri	37	1.11	0	2026-03-13	14.92	0	0	4	f	36	10	[0.0, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
194	500107	2026-03-05 22:49:45.757978	\N	1	mlp_v9_500107	\N	t	Dangerously low stock 0 - max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 14.3/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	failed	\N	Mon	41	1.11	0	2026-03-16	14.35	0	0	0	f	36	10	[0.0, 0.0, 0.574, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
195	500107	2026-03-05 22:49:45.771851	\N	1	mlp_v9_500107	\N	t	Dangerously low stock 0 - max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 16.6/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	failed	\N	Tue	42	1.11	0	2026-03-17	16.62	0	0	1	f	36	10	[0.0, 0.16666666666666666, 0.6648000000000001, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
196	500107	2026-03-05 22:49:45.78754	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	39	\N	Stock: 39 units | (3.1 days effective) | Sales: 12.7/day | -> ORDER 18 (18 loaves) | [100% confidence]	70012004	39.5	0	18	18	failed	\N	Thu	44	1.11	0	2026-03-19	12.65	0	0	3	f	18	10	[0.4875, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
197	500107	2026-03-05 22:49:45.802067	\N	0.9784	mlp_v9_500107	\N	f	\N	\N	\N	13	\N	Stock: 13 units | (0.9 days effective) | Sales: 14.9/day | -> ORDER 36 (36 loaves) | [98% confidence]	70012004	13.1	0	36	36	failed	\N	Fri	45	1.11	0	2026-03-20	14.92	0	0	4	f	36	10	[0.1625, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
206	500107	2026-03-05 23:00:53.116222	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	77	\N	Stock: 77 units | (6.1 days effective) | Sales: 12.7/day | -> ORDER 18 (18 loaves) | [100% confidence]	70012004	77.1	0	18	18	written	\N	Thu	36	1.11	0	2026-03-12	12.65	0	0	3	f	18	10	[0.9625, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
207	500107	2026-03-05 23:00:53.130365	\N	0.9976	mlp_v9_500107	\N	f	\N	\N	\N	66	\N	Stock: 66 units | (4.4 days effective) | Sales: 14.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	66.6	0	27	27	written	\N	Fri	37	1.11	0	2026-03-13	14.92	0	0	4	f	27	10	[0.825, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
208	500107	2026-03-05 23:00:53.144867	\N	0.9881	mlp_v9_500107	\N	f	\N	\N	\N	54	\N	Stock: 54 units | (3.8 days effective) | Sales: 14.3/day | -> ORDER 27 (27 loaves) | [99% confidence]	70012004	54.5	0	27	27	written	\N	Mon	41	1.11	0	2026-03-16	14.35	0	0	0	f	27	10	[0.675, 0.0, 0.574, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
209	500107	2026-03-05 23:00:53.159066	\N	0.9973	mlp_v9_500107	\N	f	\N	\N	\N	42	\N	Stock: 42 units | (2.5 days effective) | Sales: 16.6/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	42.2	0	36	36	written	\N	Tue	42	1.11	0	2026-03-17	16.62	0	0	1	f	36	10	[0.525, 0.16666666666666666, 0.6648000000000001, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
210	500107	2026-03-05 23:00:53.173526	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	96	\N	Stock: 96 units | (7.6 days effective) | Sales: 12.7/day | -> No order needed | [100% confidence]	70012004	96.5	0	0	0	skipped	\N	Thu	44	1.11	0	2026-03-19	12.65	0	0	3	f	0	10	[1.2, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
211	500107	2026-03-05 23:00:53.187862	\N	0.997	mlp_v9_500107	\N	f	\N	\N	\N	52	\N	Stock: 52 units | (3.5 days effective) | Sales: 14.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	52.1	0	27	27	written	\N	Fri	45	1.11	0	2026-03-20	14.92	0	0	4	f	27	10	[0.65, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
220	500107	2026-03-05 23:07:03.72625	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	32	\N	Stock: 32 units | (2.5 days effective) | Sales: 12.7/day | -> ORDER 18 (18 loaves) | [100% confidence]	70012004	32.1	0	18	18	written	\N	Thu	36	1.11	0	2026-03-12	12.65	0	0	3	f	18	10	[0.4, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
221	500107	2026-03-05 23:07:03.740784	\N	0.994	mlp_v9_500107	\N	f	\N	\N	\N	21	\N	Stock: 21 units | (1.4 days effective) | Sales: 14.9/day | -> ORDER 36 (36 loaves) | [99% confidence]	70012004	21.6	0	36	36	written	\N	Fri	37	1.11	0	2026-03-13	14.92	0	0	4	f	36	10	[0.2625, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
222	500107	2026-03-05 23:07:03.755432	\N	0.9872	mlp_v9_500107	\N	f	\N	\N	\N	18	\N	Stock: 18 units | (1.3 days effective) | Sales: 14.3/day | -> ORDER 27 (27 loaves) | [99% confidence]	70012004	18.5	0	27	27	written	\N	Mon	41	1.11	0	2026-03-16	14.35	0	0	0	f	27	10	[0.225, 0.0, 0.574, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
223	500107	2026-03-05 23:07:03.769851	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	6	\N	Stock: 6 units | (0.4 days effective) | Sales: 16.6/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	6.2	0	36	36	written	\N	Tue	42	1.11	0	2026-03-17	16.62	0	0	1	f	36	10	[0.075, 0.16666666666666666, 0.6648000000000001, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
224	500107	2026-03-05 23:07:03.78402	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	60	\N	Stock: 60 units | (4.7 days effective) | Sales: 12.7/day | -> ORDER 18 (18 loaves) | [100% confidence]	70012004	60.5	0	18	18	written	\N	Thu	44	1.11	0	2026-03-19	12.65	0	0	3	f	18	10	[0.75, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
308	500107	2026-07-08 12:15:21.037432	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	38	\N	Stock: 38 units | (3.8 days effective) | Sales: 9.9/day | -> ORDER 18 (18 loaves) | [100% confidence]	70012004	38.7	0	18	18	\N	\N	Thu	44	0.99	0	2026-07-16	9.9	1.29	0	3	f	18	10	[0.475, 0.5, 0.396, 0.0516, 0.99, 0.0, 0.0, 0.0]	\N
225	500107	2026-03-05 23:07:03.798244	\N	0.9961	mlp_v9_500107	\N	f	\N	\N	\N	34	\N	Stock: 34 units | (2.3 days effective) | Sales: 14.9/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	34.1	0	36	36	written	\N	Fri	45	1.11	0	2026-03-20	14.92	0	0	4	f	36	10	[0.425, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
234	500107	2026-03-05 23:15:13.041053	\N	0.6529	mlp_v9_500107	\N	f	\N	\N	\N	86	\N	Stock: 86 units | (6.8 days effective) | Sales: 12.7/day | -> ORDER 18 (18 loaves) | [65% confidence]	70012004	86.1	0	18	18	submitted	\N	Thu	36	1.11	0	2026-03-12	12.65	0	0	3	f	18	10	[1.075, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	t
235	500107	2026-03-05 23:15:13.063926	\N	0.991	mlp_v9_500107	\N	t	Effective stock 75 > 70 - trimming to ORDER 18	\N	\N	75	\N	Stock: 75 units | (5.0 days effective) | Sales: 14.9/day | -> ORDER 18 (18 loaves) | [99% confidence]	70012004	75.6	0	18	18	submitted	\N	Fri	37	1.11	0	2026-03-13	14.92	0	0	4	f	18	10	[0.9375, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	t
236	500107	2026-03-05 23:15:13.077733	\N	0.9881	mlp_v9_500107	\N	f	\N	\N	\N	54	\N	Stock: 54 units | (3.8 days effective) | Sales: 14.3/day | -> ORDER 27 (27 loaves) | [99% confidence]	70012004	54.5	0	27	27	submitted	\N	Mon	41	1.11	0	2026-03-16	14.35	0	0	0	f	27	10	[0.675, 0.0, 0.574, 0.0, 1.11, 0.0, 0.0, 0.0]	t
237	500107	2026-03-05 23:15:13.091467	\N	0.9973	mlp_v9_500107	\N	f	\N	\N	\N	42	\N	Stock: 42 units | (2.5 days effective) | Sales: 16.6/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	42.2	0	36	36	submitted	\N	Tue	42	1.11	0	2026-03-17	16.62	0	0	1	f	36	10	[0.525, 0.16666666666666666, 0.6648000000000001, 0.0, 1.11, 0.0, 0.0, 0.0]	t
238	500107	2026-03-05 23:15:13.105678	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	96	\N	Stock: 96 units | (7.6 days effective) | Sales: 12.7/day | -> No order needed | [100% confidence]	70012004	96.5	0	0	0	skipped	\N	Thu	44	1.11	0	2026-03-19	12.65	0	0	3	f	0	10	[1.2, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
239	500107	2026-03-05 23:15:13.119932	\N	0.997	mlp_v9_500107	\N	f	\N	\N	\N	52	\N	Stock: 52 units | (3.5 days effective) | Sales: 14.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	52.1	0	27	27	submitted	\N	Fri	45	1.11	0	2026-03-20	14.92	0	0	4	f	27	10	[0.65, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	t
248	500107	2026-03-05 23:24:11.657572	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	68	\N	Stock: 68 units | (5.4 days effective) | Sales: 12.7/day | -> ORDER 18 (18 loaves) | [100% confidence]	70012004	68.1	0	18	18	submitted	\N	Thu	36	1.11	0	2026-03-12	12.65	0	0	3	f	18	10	[0.85, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	t
249	500107	2026-03-05 23:24:11.680516	\N	0.9976	mlp_v9_500107	\N	f	\N	\N	\N	57	\N	Stock: 57 units | (3.8 days effective) | Sales: 14.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	57.6	0	27	27	submitted	\N	Fri	37	1.11	0	2026-03-13	14.92	0	0	4	f	27	10	[0.7125, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	t
250	500107	2026-03-05 23:24:11.695126	\N	0.9261	mlp_v9_500107	\N	f	\N	\N	\N	45	\N	Stock: 45 units | (3.1 days effective) | Sales: 14.3/day | -> ORDER 27 (27 loaves) | [93% confidence]	70012004	45.5	0	27	27	submitted	\N	Mon	41	1.11	0	2026-03-16	14.35	0	0	0	f	27	10	[0.5625, 0.0, 0.574, 0.0, 1.11, 0.0, 0.0, 0.0]	t
251	500107	2026-03-05 23:24:11.709431	\N	0.9997	mlp_v9_500107	\N	f	\N	\N	\N	33	\N	Stock: 33 units | (2.0 days effective) | Sales: 16.6/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	33.2	0	36	36	submitted	\N	Tue	42	1.11	0	2026-03-17	16.62	0	0	1	f	36	10	[0.4125, 0.16666666666666666, 0.6648000000000001, 0.0, 1.11, 0.0, 0.0, 0.0]	t
252	500107	2026-03-05 23:24:11.723577	\N	0.508	mlp_v9_500107	\N	f	\N	\N	\N	87	\N	Stock: 87 units | (6.9 days effective) | Sales: 12.7/day | -> No order needed | [51% confidence]	70012004	87.5	0	0	0	skipped	\N	Thu	44	1.11	0	2026-03-19	12.65	0	0	3	f	0	10	[1.0875, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
253	500107	2026-03-05 23:24:11.737566	\N	0.9901	mlp_v9_500107	\N	f	\N	\N	\N	43	\N	Stock: 43 units | (2.9 days effective) | Sales: 14.9/day | -> ORDER 36 (36 loaves) | [99% confidence]	70012004	43.1	0	36	36	submitted	\N	Fri	45	1.11	0	2026-03-20	14.92	0	0	4	f	36	10	[0.5375, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	t
262	500107	2026-03-05 23:32:15.205996	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	77	\N	Stock: 77 units | (6.1 days effective) | Sales: 12.7/day | -> ORDER 18 (18 loaves) | [100% confidence]	70012004	77.1	0	18	18	submitted	\N	Thu	36	1.11	0	2026-03-12	12.65	0	0	3	f	18	10	[0.9625, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	t
263	500107	2026-03-05 23:32:15.229328	\N	0.9976	mlp_v9_500107	\N	f	\N	\N	\N	66	\N	Stock: 66 units | (4.4 days effective) | Sales: 14.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	66.6	0	27	27	submitted	\N	Fri	37	1.11	0	2026-03-13	14.92	0	0	4	f	27	10	[0.825, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	t
264	500107	2026-03-05 23:32:15.243782	\N	0.9881	mlp_v9_500107	\N	f	\N	\N	\N	54	\N	Stock: 54 units | (3.8 days effective) | Sales: 14.3/day | -> ORDER 27 (27 loaves) | [99% confidence]	70012004	54.5	0	27	27	submitted	\N	Mon	41	1.11	0	2026-03-16	14.35	0	0	0	f	27	10	[0.675, 0.0, 0.574, 0.0, 1.11, 0.0, 0.0, 0.0]	t
265	500107	2026-03-05 23:32:15.258532	\N	0.9973	mlp_v9_500107	\N	f	\N	\N	\N	42	\N	Stock: 42 units | (2.5 days effective) | Sales: 16.6/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	42.2	0	36	36	submitted	\N	Tue	42	1.11	0	2026-03-17	16.62	0	0	1	f	36	10	[0.525, 0.16666666666666666, 0.6648000000000001, 0.0, 1.11, 0.0, 0.0, 0.0]	t
266	500107	2026-03-05 23:32:15.273065	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	96	\N	Stock: 96 units | (7.6 days effective) | Sales: 12.7/day | -> No order needed | [100% confidence]	70012004	96.5	0	0	0	skipped	\N	Thu	44	1.11	0	2026-03-19	12.65	0	0	3	f	0	10	[1.2, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
267	500107	2026-03-05 23:32:15.286563	\N	0.997	mlp_v9_500107	\N	f	\N	\N	\N	52	\N	Stock: 52 units | (3.5 days effective) | Sales: 14.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	52.1	0	27	27	submitted	\N	Fri	45	1.11	0	2026-03-20	14.92	0	0	4	f	27	10	[0.65, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	t
272	500107	2026-03-11 23:24:45.274262	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	118	\N	Stock: 118 units | (9.3 days effective) | Sales: 12.7/day | -> No order needed | [100% confidence]	70012004	118.5	0	0	0	\N	\N	Thu	44	1.11	0	2026-03-19	12.65	0	0	3	f	0	10	[1.475, 0.5, 0.506, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
273	500107	2026-03-11 23:24:45.288617	\N	0.5314	mlp_v9_500107	\N	f	\N	\N	\N	87	\N	Stock: 87 units | (5.8 days effective) | Sales: 14.9/day | -> No order needed | [53% confidence]	70012004	87.6	0	0	0	\N	\N	Fri	45	1.11	0	2026-03-20	14.92	0	0	4	f	0	10	[1.0875, 0.6666666666666666, 0.5968, 0.0, 1.11, 0.0, 0.0, 0.0]	\N
284	500107	2026-03-25 20:22:27.427302	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - emergency order	\N	\N	0	\N	Stock: 0 units | + 99 in pipeline | (8.1 days effective) | Sales: 12.2/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	0	0	27	27	written	\N	Thu	44	1.07	0	2026-04-02	12.19	4.5	99	3	f	27	10	[0.0, 0.5, 0.4876, 0.18, 1.07, 0.0, 0.66, 0.0]	\N
285	500107	2026-03-25 20:22:27.457298	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - emergency order	\N	\N	0	\N	Stock: 0 units | + 99 in pipeline | (6.9 days effective) | Sales: 14.4/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	0	0	27	27	written	\N	Fri	45	1.07	0	2026-04-03	14.38	4.5	99	4	f	27	10	[0.0, 0.6666666666666666, 0.5752, 0.18, 1.07, 0.0, 0.66, 0.0]	\N
309	500107	2026-07-08 12:15:21.060607	\N	0.938	mlp_v9_500107	\N	f	\N	\N	\N	34	\N	Stock: 34 units | (3.0 days effective) | Sales: 11.4/day | -> ORDER 27 (27 loaves) | [94% confidence]	70012004	34.7	0	27	27	\N	\N	Fri	45	0.99	0	2026-07-17	11.41	1.29	0	4	f	27	10	[0.425, 0.6666666666666666, 0.45640000000000003, 0.0516, 0.99, 0.0, 0.0, 0.0]	\N
372	500107	2026-07-15 21:13:38.488706	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 10.4/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	\N	\N	Thu	44	0.99	0	2026-07-23	10.36	1.29	0	3	f	36	10	[0.0, 0.5, 0.4144, 0.0516, 0.99, 0.0, 0.0, 0.0]	\N
373	500107	2026-07-15 21:13:38.501148	\N	0.9996	mlp_v9_500107	\N	t	Low coverage 1.0 days - floor at ORDER 18	\N	\N	12	\N	Stock: 12 units | (1.0 days effective) | Sales: 11.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	12.5	0	27	27	\N	\N	Fri	45	0.99	0	2026-07-24	11.94	1.29	0	4	f	27	10	[0.15, 0.6666666666666666, 0.47759999999999997, 0.0516, 0.99, 0.0, 0.0, 0.0]	\N
382	500107	2026-07-15 21:25:02.637702	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 10.4/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	\N	\N	Thu	44	0.99	0	2026-07-23	10.36	1.29	0	3	f	36	10	[0.0, 0.5, 0.4144, 0.0516, 0.99, 0.0, 0.0, 0.0]	\N
383	500107	2026-07-15 21:25:02.657956	\N	0.9996	mlp_v9_500107	\N	t	Low coverage 1.0 days - floor at ORDER 18	\N	\N	12	\N	Stock: 12 units | (1.0 days effective) | Sales: 11.9/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	12.5	0	27	27	\N	\N	Fri	45	0.99	0	2026-07-24	11.94	1.29	0	4	f	27	10	[0.15, 0.6666666666666666, 0.47759999999999997, 0.0516, 0.99, 0.0, 0.0, 0.0]	\N
384	500107	2026-08-02 17:19:47.525837	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 10.7/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	\N	\N	Tue	42	1.03	0	2026-08-11	10.71	0	0	1	f	36	10	[0.0, 0.16666666666666666, 0.42840000000000006, 0.0, 1.03, 0.0, 0.0, 0.0]	\N
385	500107	2026-08-02 17:19:47.54712	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 8.7/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	\N	\N	Thu	44	1.03	0	2026-08-13	8.65	0	0	3	f	36	10	[0.0, 0.5, 0.34600000000000003, 0.0, 1.03, 0.0, 0.0, 0.0]	\N
386	500107	2026-08-02 17:19:47.559552	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 10.0/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	\N	\N	Fri	45	1.03	0	2026-08-14	9.96	0	0	4	f	36	10	[0.0, 0.6666666666666666, 0.39840000000000003, 0.0, 1.03, 0.0, 0.0, 0.0]	\N
387	500107	2026-08-02 17:34:58.646787	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 10.7/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Tue	42	1.03	0	2026-08-11	10.71	0	0	1	f	36	10	[0.0, 0.16666666666666666, 0.42840000000000006, 0.0, 1.03, 0.0, 0.0, 0.0]	t
388	500107	2026-08-02 17:34:58.668113	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 8.7/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Thu	44	1.03	0	2026-08-13	8.65	0	0	3	f	36	10	[0.0, 0.5, 0.34600000000000003, 0.0, 1.03, 0.0, 0.0, 0.0]	t
389	500107	2026-08-02 17:34:58.679655	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 10.0/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Fri	45	1.03	0	2026-08-14	9.96	0	0	4	f	36	10	[0.0, 0.6666666666666666, 0.39840000000000003, 0.0, 1.03, 0.0, 0.0, 0.0]	t
390	500107	2026-08-02 17:43:18.487856	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 10.7/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Tue	34	1.03	0	2026-08-11	10.71	0	0	1	f	36	10	[0.0, 0.16666666666666666, 0.42840000000000006, 0.0, 1.03, 0.0, 0.0, 0.0]	t
391	500107	2026-08-02 17:43:18.509348	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 8.7/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Thu	36	1.03	0	2026-08-13	8.65	0	0	3	f	36	10	[0.0, 0.5, 0.34600000000000003, 0.0, 1.03, 0.0, 0.0, 0.0]	t
392	500107	2026-08-02 17:43:18.521619	\N	1	mlp_v9_500107	\N	t	Critical stock 4 - forcing max order	\N	\N	4	\N	Stock: 4 units | (0.4 days effective) | Sales: 10.0/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	4.4	0	36	36	submitted	\N	Fri	37	1.03	0	2026-08-14	9.96	0	0	4	f	36	10	[0.05, 0.6666666666666666, 0.39840000000000003, 0.0, 1.03, 0.0, 0.0, 0.0]	t
393	500107	2026-08-02 17:43:18.534823	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 12.1/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Mon	41	1.03	0	2026-08-17	12.11	0	0	0	f	36	10	[0.0, 0.0, 0.4844, 0.0, 1.03, 0.0, 0.0, 0.0]	t
394	500107	2026-08-02 17:43:18.547545	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 14.1/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Tue	42	1.03	0	2026-08-18	14.09	0	0	1	f	36	10	[0.0, 0.16666666666666666, 0.5636, 0.0, 1.03, 0.0, 0.0, 0.0]	t
395	500107	2026-08-02 17:43:18.560285	\N	1	mlp_v9_500107	\N	f	\N	\N	\N	28	\N	Stock: 28 units | (2.5 days effective) | Sales: 11.4/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	28.7	0	27	27	submitted	\N	Thu	44	1.03	0	2026-08-20	11.37	0	0	3	f	27	10	[0.35, 0.5, 0.4548, 0.0, 1.03, 0.0, 0.0, 0.0]	t
396	500107	2026-08-02 17:43:18.572486	\N	0.9995	mlp_v9_500107	\N	t	Low coverage 1.0 days - floor at ORDER 18	\N	\N	13	\N	Stock: 13 units | (1.0 days effective) | Sales: 13.1/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	13.2	0	27	27	submitted	\N	Fri	45	1.03	0	2026-08-21	13.1	0	0	4	f	27	10	[0.1625, 0.6666666666666666, 0.524, 0.0, 1.03, 0.0, 0.0, 0.0]	t
397	500107	2026-08-02 18:06:27.0433	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 10.7/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Tue	34	1.03	0	2026-08-11	10.71	0	0	1	f	36	10	[0.0, 0.16666666666666666, 0.42840000000000006, 0.0, 1.03, 0.0, 0.0, 0.0]	t
398	500107	2026-08-02 18:06:27.064603	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 8.7/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Thu	36	1.03	0	2026-08-13	8.65	0	0	3	f	36	10	[0.0, 0.5, 0.34600000000000003, 0.0, 1.03, 0.0, 0.0, 0.0]	t
399	500107	2026-08-02 18:06:27.07722	\N	1	mlp_v9_500107	\N	t	Critical stock 3 - forcing max order	\N	\N	3	\N	Stock: 3 units | (0.3 days effective) | Sales: 10.0/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	3.4	0	36	36	submitted	\N	Fri	37	1.03	0	2026-08-14	9.96	0	0	4	f	36	10	[0.0375, 0.6666666666666666, 0.39840000000000003, 0.0, 1.03, 0.0, 0.0, 0.0]	t
400	500107	2026-08-02 18:06:27.088978	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 12.1/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Mon	41	1.03	0	2026-08-17	12.11	0	0	0	f	36	10	[0.0, 0.0, 0.4844, 0.0, 1.03, 0.0, 0.0, 0.0]	t
401	500107	2026-08-02 18:06:27.100475	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 14.1/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Tue	42	1.03	0	2026-08-18	14.09	0	0	1	f	36	10	[0.0, 0.16666666666666666, 0.5636, 0.0, 1.03, 0.0, 0.0, 0.0]	t
402	500107	2026-08-02 18:06:27.112131	\N	0.9999	mlp_v9_500107	\N	f	\N	\N	\N	27	\N	Stock: 27 units | (2.4 days effective) | Sales: 11.4/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	27.7	0	27	27	submitted	\N	Thu	44	1.03	0	2026-08-20	11.37	0	0	3	f	27	10	[0.3375, 0.5, 0.4548, 0.0, 1.03, 0.0, 0.0, 0.0]	t
403	500107	2026-08-02 18:06:27.1236	\N	0.9995	mlp_v9_500107	\N	t	Low coverage 0.9 days - floor at ORDER 18	\N	\N	12	\N	Stock: 12 units | (0.9 days effective) | Sales: 13.1/day | -> ORDER 27 (27 loaves) | [100% confidence]	70012004	12.2	0	27	27	submitted	\N	Fri	45	1.03	0	2026-08-21	13.1	0	0	4	f	27	10	[0.15, 0.6666666666666666, 0.524, 0.0, 1.03, 0.0, 0.0, 0.0]	t
404	500107	2026-08-02 18:09:14.895916	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 12.1/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Mon	33	1.03	0	2026-08-17	12.11	0	0	0	f	36	10	[0.0, 0.0, 0.4844, 0.0, 1.03, 0.0, 0.0, 0.0]	t
405	500107	2026-08-02 18:09:14.916661	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 14.1/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Tue	34	1.03	0	2026-08-18	14.09	0	0	1	f	36	10	[0.0, 0.16666666666666666, 0.5636, 0.0, 1.03, 0.0, 0.0, 0.0]	t
406	500107	2026-08-02 18:09:14.928211	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 11.4/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Thu	36	1.03	0	2026-08-20	11.37	0	0	3	f	36	10	[0.0, 0.5, 0.4548, 0.0, 1.03, 0.0, 0.0, 0.0]	t
407	500107	2026-08-02 18:09:14.939842	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 13.1/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Fri	37	1.03	0	2026-08-21	13.1	0	0	4	f	36	10	[0.0, 0.6666666666666666, 0.524, 0.0, 1.03, 0.0, 0.0, 0.0]	t
408	500107	2026-08-02 18:09:14.951792	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 12.5/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Mon	41	1.03	0	2026-08-24	12.49	0	0	0	f	36	10	[0.0, 0.0, 0.4996, 0.0, 1.03, 0.0, 0.0, 0.0]	t
409	500107	2026-08-02 18:09:14.96359	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 14.5/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Tue	42	1.03	0	2026-08-25	14.53	0	0	1	f	36	10	[0.0, 0.16666666666666666, 0.5811999999999999, 0.0, 1.03, 0.0, 0.0, 0.0]	t
410	500107	2026-08-02 18:09:14.975851	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 11.7/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Thu	44	1.03	0	2026-08-27	11.73	0	0	3	f	36	10	[0.0, 0.5, 0.4692, 0.0, 1.03, 0.0, 0.0, 0.0]	t
411	500107	2026-08-02 18:09:14.987135	\N	1	mlp_v9_500107	\N	t	Critical stock 0 - forcing max order	\N	\N	0	\N	Stock: 0 units | (0.0 days effective) | Sales: 13.5/day | -> ORDER 36 (36 loaves) | [100% confidence]	70012004	0	0	36	36	submitted	\N	Fri	45	1.03	0	2026-08-28	13.51	0	0	4	f	36	10	[0.0, 0.6666666666666666, 0.5404, 0.0, 1.03, 0.0, 0.0, 0.0]	t
\.


--
-- Data for Name: physical_counts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.physical_counts (count_id, product_id, store_id, count_date, quantity_counted, calculated_quantity, variance, count_method, photo_path, notes, created_at) FROM stdin;
\.


--
-- Data for Name: product_dow_multipliers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_dow_multipliers (id, sku, store_id, day_of_week, multiplier, confidence, source, updated_at) FROM stdin;
29	500107	70012004	0	0.98	high	data	2026-04-01 14:41:44.341454
30	500107	70012004	1	1.14	high	data	2026-04-01 14:41:44.341454
31	500107	70012004	2	0.89	high	data	2026-04-01 14:41:44.341454
32	500107	70012004	3	0.92	high	data	2026-04-01 14:41:44.341454
33	500107	70012004	4	1.06	high	data	2026-04-01 14:41:44.341454
34	500107	70012004	5	0.96	high	data	2026-04-01 14:41:44.341454
35	500107	70012004	6	1.05	high	data	2026-04-01 14:41:44.341454
\.


--
-- Data for Name: product_monthly_multipliers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_monthly_multipliers (id, sku, store_id, month, multiplier, confidence, source, updated_at) FROM stdin;
49	500107	70012004	1	1.5	low	data	2026-04-01 14:41:44.341454
50	500107	70012004	2	1.15	high	data	2026-04-01 14:41:44.341454
51	500107	70012004	3	0.72	high	data	2026-04-01 14:41:44.341454
52	500107	70012004	4	0.91	estimated	interp	2026-04-01 14:41:44.341454
53	500107	70012004	5	1.1	low	data	2026-04-01 14:41:44.341454
54	500107	70012004	6	0.79	high	data	2026-04-01 14:41:44.341454
55	500107	70012004	7	0.99	high	data	2026-04-01 14:41:44.341454
56	500107	70012004	8	1.03	high	data	2026-04-01 14:41:44.341454
57	500107	70012004	9	1.12	high	data	2026-04-01 14:41:44.341454
58	500107	70012004	10	0.94	medium	data	2026-04-01 14:41:44.341454
59	500107	70012004	11	1.04	medium	data	2026-04-01 14:41:44.341454
60	500107	70012004	12	0.91	low	data	2026-04-01 14:41:44.341454
\.


--
-- Data for Name: product_tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_tokens (token_id, product_id, product_name, store_id, arrival_date, expiration_date, status, status_date, consumed_date, batch_id, notes, created_at, updated_at) FROM stdin;
e1c335ad-e62b-415e-843b-57411b4ce0fa	500107	Demo_500g_Rye_Bread	70012004	2026-07-29	2026-08-10	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-02-500107	\N	2026-03-05 23:30:41.863899	2026-03-25 20:22:03
ca6977f3-0bae-4774-bb0f-3a269c266d4e	500107	Demo_500g_Rye_Bread	70012004	2026-07-29	2026-08-10	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-02-500107	\N	2026-03-05 23:30:41.863899	2026-03-25 20:22:03
2c59b68d-6af4-489c-9901-27482fbedf2d	500107	Demo_500g_Rye_Bread	70012004	2026-07-29	2026-08-10	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-02-500107	\N	2026-03-05 23:30:41.863899	2026-03-25 20:22:03
ec7e98e1-8788-44ca-bd4c-a2a3bbd721f0	500107	Demo_500g_Rye_Bread	70012004	2026-07-29	2026-08-10	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-02-500107	\N	2026-03-05 23:30:41.863899	2026-03-25 20:22:03
e1c13ce0-8cf6-46d3-a66a-d34df95c720d	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
798930ec-8c07-43a5-9663-8daa37f93355	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
85a1ccb4-6350-4754-a856-46706e961da6	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
1519b540-491b-4d9b-a915-31b12a906489	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
0ec670bf-f2f8-4dcb-8836-f20c40b03eb8	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
ebfb623e-b0da-4b3f-8e40-f7c48798d654	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
8936b36b-435c-432b-be63-aaf65c3a8093	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
7750c5a9-eda8-4e5b-8665-22a54ae0bb46	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
348c844b-f645-47ff-9d95-8e21824cbe0a	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
27d9a730-9f6f-4c91-84fc-c3d880995118	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
c06a579f-fd5b-47b4-b2d8-57355ffbd95e	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
c6833025-d767-4dd2-8113-1bf8899ea761	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
cd1e4f1c-6598-4f90-b14c-b31840b25126	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
94994e7b-3d7b-43ba-85dc-40c535b3cb6f	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
37e94fe1-9958-4a3f-aa30-e434f4614bc7	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
8d11f0a6-cd09-4275-bad6-5f1691dcfc30	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
8c56cc21-d41b-4f50-9bfc-79013f8c1edf	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
c4a9eb8c-8864-4c8f-9f0c-80394c6a5f77	500107	Demo_500g_Rye_Bread	70012004	2026-07-30	2026-08-11	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-03-500107	\N	2026-03-05 23:30:41.875637	2026-03-25 20:22:03
bb76b73c-3cba-42f8-9a37-01b91ac96378	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
3226bd03-d77e-41ee-bded-9c67bc22a9be	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
548c2b57-7c88-42a6-9701-902a9e22ae82	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
fb6699f2-96e5-4e1d-8cc4-64d9a5afdf1f	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
01afc6ac-d7c9-455e-bb84-76c4b8143b42	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
67db7829-6caa-4467-abdf-2971934630b1	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
5317b70f-9136-4c11-92b1-99f4245301db	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
0a2b3253-b97e-4680-82ab-1c17e6469d06	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
029abd85-e2a5-4389-9f68-f6570d542f99	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
3417e8f1-720a-4a79-a86e-c7662bb42c82	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
6bd7b070-dedc-4ce2-8762-a22ffa5d14b9	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
75a3d692-0dda-43df-89ed-62d5d5d55c00	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
58e76309-ecdc-43a1-b686-ffa6800173ea	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
57d36264-f43d-45b7-bf86-8c56bb83bf33	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
ef768daf-fe80-4f7f-ba8a-66ff861e9a2d	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
5f2aca6e-fde8-4110-a832-d742ae5d10a3	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
c3a58fe7-9420-4563-8548-dba4ff3f7746	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
64b81ae7-f601-469f-af56-85a07e41504b	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
15e33988-9860-4934-a28a-fd06f3b48d8c	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
41b4869c-5013-49fb-abfc-d504b749c50b	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
e5958509-ed5b-4049-b5e4-5a8c89cd0237	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
b89fdb12-115f-4d2e-a076-05f6f891ef28	500107	Demo_500g_Rye_Bread	70012004	2026-07-29	2026-08-10	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-02-500107	\N	2026-03-05 23:30:41.863899	2026-03-25 20:22:03
305ee16f-c7a8-4727-aef5-559c628f8464	500107	Demo_500g_Rye_Bread	70012004	2026-07-29	2026-08-10	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-02-500107	\N	2026-03-05 23:30:41.863899	2026-03-25 20:22:03
24582ad9-38b3-4419-a044-372297c68069	500107	Demo_500g_Rye_Bread	70012004	2026-07-29	2026-08-10	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-02-500107	\N	2026-03-05 23:30:41.863899	2026-03-25 20:22:03
3ec17032-7435-4ef7-bca5-6789314fba2a	500107	Demo_500g_Rye_Bread	70012004	2026-07-29	2026-08-10	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-02-500107	\N	2026-03-05 23:30:41.863899	2026-03-25 20:22:03
3405d3d8-8a0c-4667-baaf-848a88483009	500107	Demo_500g_Rye_Bread	70012004	2026-07-29	2026-08-10	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-02-500107	\N	2026-03-05 23:30:41.863899	2026-03-25 20:22:03
95147d61-d370-4359-b62f-768aaeaf142b	500107	Demo_500g_Rye_Bread	70012004	2026-08-01	2026-08-13	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-09-500107	\N	2026-03-11 23:24:44.94343	2026-03-25 20:22:03
bc423cab-1812-42f3-a2b1-f471c4c2e66e	500107	Demo_500g_Rye_Bread	70012004	2026-08-01	2026-08-13	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-09-500107	\N	2026-03-11 23:24:44.94343	2026-03-25 20:22:03
79560fcd-2566-4aa2-a76a-90cf5627d1dc	500107	Demo_500g_Rye_Bread	70012004	2026-08-01	2026-08-13	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-09-500107	\N	2026-03-11 23:24:44.94343	2026-03-25 20:22:03
2ffd418e-16cd-4b45-ab7d-a951f7d4dbb4	500107	Demo_500g_Rye_Bread	70012004	2026-08-01	2026-08-13	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-09-500107	\N	2026-03-11 23:24:44.94343	2026-03-25 20:22:03
e385fa28-c16a-432c-bee4-5f88729aa2d1	500107	Demo_500g_Rye_Bread	70012004	2026-08-01	2026-08-13	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-09-500107	\N	2026-03-11 23:24:44.94343	2026-03-25 20:22:03
c5d269ca-7f8e-4604-b38b-78f6e62a7db8	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
4bf7bc3b-3b73-49f7-bc07-95166a3785c2	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
c1933908-8d44-4fa1-b6b0-582181762804	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
3425ea2b-19fe-4861-87b5-c6e205546614	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
6893f319-4b07-4a06-b8cd-d594736fdc63	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
a62f76da-1908-4f79-8943-25de160d62ae	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
f7e4d44d-6564-45d6-92ea-a67baaa4962c	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
e7fa7586-47d7-4bb8-a4f5-9190d99c7201	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
d00833ff-b2cc-4d0d-9273-bfb16fd44648	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
0b517a31-9c2d-4431-9c17-ad6f114ef967	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
ee6dbc74-e36c-40a7-839c-256cde8f868a	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
c9206d20-1ce5-40b1-84d3-d777a0d1baaa	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
81729d39-14e3-4e72-ab24-767974d6cf3e	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
657cb572-be1d-455b-ac1c-10124f52e6d6	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
46f5aded-d528-420c-84d7-6dc370f17fb9	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
fc2b69ba-7816-4d48-bb86-0589add0eeec	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
2954b9c4-a08b-49d5-90a8-78553dd11617	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
970dc2e3-0643-48b8-87d1-2cdc90bdfa03	500107	Demo_500g_Rye_Bread	70012004	2026-08-02	2026-08-14	in_stock	2026-07-08	\N	OTTO-DELIVERED-2026-03-10-500107	\N	2026-03-11 23:24:44.971232	2026-07-08 12:12:43
98b22687-682c-45cb-8fae-219855668bd5	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
31b9c36e-866e-4d8c-a4cb-8784c32a71a5	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
aa132aae-94af-4132-80e6-0dcb57132dc7	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
1fdf7b2c-436a-4f19-9a0a-7d2a52f72fd0	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
8e8d3123-027a-435d-a134-203290b345c0	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
e60a5990-de08-45b7-9d05-a6c1c13d31fd	500107	Demo_500g_Rye_Bread	70012004	2026-07-31	2026-08-12	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-05-500107	\N	2026-03-05 23:30:41.888294	2026-03-25 20:22:03
ad80b55b-516e-43c3-89bf-28a5eff4582c	500107	Demo_500g_Rye_Bread	70012004	2026-08-01	2026-08-13	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-09-500107	\N	2026-03-11 23:24:44.94343	2026-03-25 20:22:03
6a401e4f-0fbf-4367-a7df-18e82df1694e	500107	Demo_500g_Rye_Bread	70012004	2026-08-01	2026-08-13	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-09-500107	\N	2026-03-11 23:24:44.94343	2026-03-25 20:22:03
8683a55c-87a6-48f3-b39a-5e29b8e47653	500107	Demo_500g_Rye_Bread	70012004	2026-08-01	2026-08-13	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-09-500107	\N	2026-03-11 23:24:44.94343	2026-03-25 20:22:03
cae56c6c-c114-4075-af94-f37a20da77b9	500107	Demo_500g_Rye_Bread	70012004	2026-08-01	2026-08-13	in_stock	2026-03-25	\N	OTTO-DELIVERED-2026-03-09-500107	\N	2026-03-11 23:24:44.94343	2026-03-25 20:22:03
\.


--
-- Data for Name: product_wom_multipliers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_wom_multipliers (id, sku, store_id, month, week, multiplier, source, updated_at) FROM stdin;
481	500107	70012002	1	1	1	flat	2026-04-03 20:49:34.982242
482	500107	70012002	1	2	1	flat	2026-04-03 20:49:34.982242
483	500107	70012002	1	3	1	flat	2026-04-03 20:49:34.982242
484	500107	70012002	1	4	1	flat	2026-04-03 20:49:34.982242
489	500107	70012002	3	1	1	flat	2026-04-03 20:49:34.982242
497	500107	70012002	5	1	1	flat	2026-04-03 20:49:34.982242
498	500107	70012002	5	2	1	flat	2026-04-03 20:49:34.982242
499	500107	70012002	5	3	1	flat	2026-04-03 20:49:34.982242
500	500107	70012002	5	4	1	flat	2026-04-03 20:49:34.982242
514	500107	70012002	9	2	1	flat	2026-04-03 20:49:34.982242
519	500107	70012002	10	3	1	flat	2026-04-03 20:49:34.982242
524	500107	70012002	11	4	1	flat	2026-04-03 20:49:34.982242
525	500107	70012002	12	1	1	flat	2026-04-03 20:49:34.982242
526	500107	70012002	12	2	1	flat	2026-04-03 20:49:34.982242
527	500107	70012002	12	3	1	flat	2026-04-03 20:49:34.982242
528	500107	70012002	12	4	1	flat	2026-04-03 20:49:34.982242
485	500107	70012002	2	1	1.3	demo_store_transfer	2026-04-03 20:49:34.982242
486	500107	70012002	2	2	1.1	demo_store_transfer	2026-04-03 20:49:34.982242
487	500107	70012002	2	3	0.64	demo_store_transfer	2026-04-03 20:49:34.982242
488	500107	70012002	2	4	0.55	demo_store_transfer	2026-04-03 20:49:34.982242
490	500107	70012002	3	2	0.74	demo_store_transfer	2026-04-03 20:49:34.982242
491	500107	70012002	3	3	0.97	demo_store_transfer	2026-04-03 20:49:34.982242
193	500107	70012004	1	1	1	flat	2026-04-01 14:41:44.341454
194	500107	70012004	1	2	1	flat	2026-04-01 14:41:44.341454
195	500107	70012004	1	3	1	flat	2026-04-01 14:41:44.341454
196	500107	70012004	1	4	1	flat	2026-04-01 14:41:44.341454
197	500107	70012004	2	1	1.3	data	2026-04-01 14:41:44.341454
198	500107	70012004	2	2	1.1	data	2026-04-01 14:41:44.341454
199	500107	70012004	2	3	0.64	data	2026-04-01 14:41:44.341454
200	500107	70012004	2	4	0.55	data	2026-04-01 14:41:44.341454
201	500107	70012004	3	1	1	data	2026-04-01 14:41:44.341454
202	500107	70012004	3	2	0.74	data	2026-04-01 14:41:44.341454
203	500107	70012004	3	3	0.97	data	2026-04-01 14:41:44.341454
204	500107	70012004	3	4	1.25	data	2026-04-01 14:41:44.341454
205	500107	70012004	4	1	1.15	interp	2026-04-01 14:41:44.341454
206	500107	70012004	4	2	0.92	interp	2026-04-01 14:41:44.341454
207	500107	70012004	4	3	0.8	interp	2026-04-01 14:41:44.341454
208	500107	70012004	4	4	0.9	interp	2026-04-01 14:41:44.341454
209	500107	70012004	5	1	1	flat	2026-04-01 14:41:44.341454
210	500107	70012004	5	2	1	flat	2026-04-01 14:41:44.341454
211	500107	70012004	5	3	1	flat	2026-04-01 14:41:44.341454
212	500107	70012004	5	4	1	flat	2026-04-01 14:41:44.341454
213	500107	70012004	6	1	0.99	data	2026-04-01 14:41:44.341454
214	500107	70012004	6	2	0.87	data	2026-04-01 14:41:44.341454
215	500107	70012004	6	3	0.97	data	2026-04-01 14:41:44.341454
216	500107	70012004	6	4	1.16	data	2026-04-01 14:41:44.341454
217	500107	70012004	7	1	0.94	data	2026-04-01 14:41:44.341454
218	500107	70012004	7	2	1.34	data	2026-04-01 14:41:44.341454
219	500107	70012004	7	3	0.87	data	2026-04-01 14:41:44.341454
220	500107	70012004	7	4	0.91	data	2026-04-01 14:41:44.341454
221	500107	70012004	8	1	1.31	data	2026-04-01 14:41:44.341454
222	500107	70012004	8	2	0.73	data	2026-04-01 14:41:44.341454
223	500107	70012004	8	3	0.96	data	2026-04-01 14:41:44.341454
224	500107	70012004	8	4	0.99	data	2026-04-01 14:41:44.341454
225	500107	70012004	9	1	0.87	data	2026-04-01 14:41:44.341454
226	500107	70012004	9	2	1	data	2026-04-01 14:41:44.341454
492	500107	70012002	3	4	1.25	demo_store_transfer	2026-04-03 20:49:34.982242
493	500107	70012002	4	1	1.15	demo_store_transfer	2026-04-03 20:49:34.982242
494	500107	70012002	4	2	0.92	demo_store_transfer	2026-04-03 20:49:34.982242
495	500107	70012002	4	3	0.8	demo_store_transfer	2026-04-03 20:49:34.982242
496	500107	70012002	4	4	0.9	demo_store_transfer	2026-04-03 20:49:34.982242
501	500107	70012002	6	1	0.99	demo_store_transfer	2026-04-03 20:49:34.982242
502	500107	70012002	6	2	0.87	demo_store_transfer	2026-04-03 20:49:34.982242
503	500107	70012002	6	3	0.97	demo_store_transfer	2026-04-03 20:49:34.982242
504	500107	70012002	6	4	1.16	demo_store_transfer	2026-04-03 20:49:34.982242
505	500107	70012002	7	1	0.94	demo_store_transfer	2026-04-03 20:49:34.982242
506	500107	70012002	7	2	1.34	demo_store_transfer	2026-04-03 20:49:34.982242
507	500107	70012002	7	3	0.87	demo_store_transfer	2026-04-03 20:49:34.982242
508	500107	70012002	7	4	0.91	demo_store_transfer	2026-04-03 20:49:34.982242
509	500107	70012002	8	1	1.31	demo_store_transfer	2026-04-03 20:49:34.982242
510	500107	70012002	8	2	0.73	demo_store_transfer	2026-04-03 20:49:34.982242
511	500107	70012002	8	3	0.96	demo_store_transfer	2026-04-03 20:49:34.982242
512	500107	70012002	8	4	0.99	demo_store_transfer	2026-04-03 20:49:34.982242
513	500107	70012002	9	1	0.87	demo_store_transfer	2026-04-03 20:49:34.982242
515	500107	70012002	9	3	1.13	demo_store_transfer	2026-04-03 20:49:34.982242
516	500107	70012002	9	4	1.01	demo_store_transfer	2026-04-03 20:49:34.982242
517	500107	70012002	10	1	0.96	demo_store_transfer	2026-04-03 20:49:34.982242
518	500107	70012002	10	2	0.97	demo_store_transfer	2026-04-03 20:49:34.982242
520	500107	70012002	10	4	1.12	demo_store_transfer	2026-04-03 20:49:34.982242
521	500107	70012002	11	1	0.97	demo_store_transfer	2026-04-03 20:49:34.982242
522	500107	70012002	11	2	0.93	demo_store_transfer	2026-04-03 20:49:34.982242
523	500107	70012002	11	3	1.31	demo_store_transfer	2026-04-03 20:49:34.982242
227	500107	70012004	9	3	1.13	data	2026-04-01 14:41:44.341454
228	500107	70012004	9	4	1.01	data	2026-04-01 14:41:44.341454
229	500107	70012004	10	1	0.96	data	2026-04-01 14:41:44.341454
230	500107	70012004	10	2	0.97	data	2026-04-01 14:41:44.341454
231	500107	70012004	10	3	1	data	2026-04-01 14:41:44.341454
232	500107	70012004	10	4	1.12	data	2026-04-01 14:41:44.341454
233	500107	70012004	11	1	0.97	data	2026-04-01 14:41:44.341454
234	500107	70012004	11	2	0.93	data	2026-04-01 14:41:44.341454
235	500107	70012004	11	3	1.31	data	2026-04-01 14:41:44.341454
236	500107	70012004	11	4	1	data	2026-04-01 14:41:44.341454
237	500107	70012004	12	1	1	flat	2026-04-01 14:41:44.341454
238	500107	70012004	12	2	1	flat	2026-04-01 14:41:44.341454
239	500107	70012004	12	3	1	flat	2026-04-01 14:41:44.341454
240	500107	70012004	12	4	1	flat	2026-04-01 14:41:44.341454
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.products (product_id, product_name, category, shelf_life_days, reorder_point, reorder_quantity, tray_factor, created_at, updated_at, sku, store_id, delivery_days, lead_time_days, return_days, is_active, mlp_enabled) FROM stdin;
500107	Demo_500g_Rye_Bread	bread	12	20	20	10	2025-12-10 21:00:30.890015	2026-01-01 12:06:47.286803	500107	70012004	mon,tue,thu,fri	3	tue,fri	t	f
\.


--
-- Data for Name: returns_invoices; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.returns_invoices (id, invoice_id, store_id, invoice_date, product_id, units_returned, reason, processed_at, tokens_updated) FROM stdin;
\.


--
-- Data for Name: sales_predictions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sales_predictions (prediction_id, product_id, store_id, historical_date, predicted_date, predicted_quantity, confidence, actual_quantity, variance, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: seasonal_pattern; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.seasonal_pattern (id, sku, store_id, month, day_of_week, base_avg, monthly_multiplier, dow_multiplier, expected_daily, confidence, data_points, notes, created_at, updated_at) FROM stdin;
1094	500107	70012002	1	Mon	16.9	1.46	0.98	24.2	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1095	500107	70012002	1	Tue	16.9	1.46	1.13	27.9	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1096	500107	70012002	1	Wed	16.9	1.46	0.88	21.7	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1097	500107	70012002	1	Thu	16.9	1.46	0.92	22.7	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1098	500107	70012002	1	Fri	16.9	1.46	1.06	26.1	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1099	500107	70012002	1	Sat	16.9	1.46	0.97	23.9	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1100	500107	70012002	1	Sun	16.9	1.46	1.05	25.9	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1101	500107	70012002	2	Mon	16.9	1.01	0.98	16.7	high	84	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1102	500107	70012002	2	Tue	16.9	1.01	1.13	19.3	high	84	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1103	500107	70012002	2	Wed	16.9	1.01	0.88	15.0	high	84	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1104	500107	70012002	2	Thu	16.9	1.01	0.92	15.7	high	84	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1105	500107	70012002	2	Fri	16.9	1.01	1.06	18.1	high	84	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1106	500107	70012002	2	Sat	16.9	1.01	0.97	16.5	high	84	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1107	500107	70012002	2	Sun	16.9	1.01	1.05	17.9	high	84	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1108	500107	70012002	3	Mon	16.9	0.72	0.98	11.9	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1109	500107	70012002	3	Tue	16.9	0.72	1.13	13.7	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1110	500107	70012002	3	Wed	16.9	0.72	0.88	10.7	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1111	500107	70012002	3	Thu	16.9	0.72	0.92	11.2	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1112	500107	70012002	3	Fri	16.9	0.72	1.06	12.9	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1113	500107	70012002	3	Sat	16.9	0.72	0.97	11.8	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1114	500107	70012002	3	Sun	16.9	0.72	1.05	12.8	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1115	500107	70012002	4	Mon	16.9	0.92	0.98	15.2	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1116	500107	70012002	4	Tue	16.9	0.92	1.13	17.6	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1117	500107	70012002	4	Wed	16.9	0.92	0.88	13.7	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1118	500107	70012002	4	Thu	16.9	0.92	0.92	14.3	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1119	500107	70012002	4	Fri	16.9	0.92	1.06	16.5	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1120	500107	70012002	4	Sat	16.9	0.92	0.97	15.1	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1121	500107	70012002	4	Sun	16.9	0.92	1.05	16.3	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1122	500107	70012002	5	Mon	16.9	1.08	0.98	17.9	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1123	500107	70012002	5	Tue	16.9	1.08	1.13	20.6	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1124	500107	70012002	5	Wed	16.9	1.08	0.88	16.0	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1125	500107	70012002	5	Thu	16.9	1.08	0.92	16.8	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1126	500107	70012002	5	Fri	16.9	1.08	1.06	19.3	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1127	500107	70012002	5	Sat	16.9	1.08	0.97	17.7	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1128	500107	70012002	5	Sun	16.9	1.08	1.05	19.1	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1129	500107	70012002	6	Mon	16.9	0.79	0.98	13.1	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1130	500107	70012002	6	Tue	16.9	0.79	1.13	15.1	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1131	500107	70012002	6	Wed	16.9	0.79	0.88	11.7	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1132	500107	70012002	6	Thu	16.9	0.79	0.92	12.3	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1133	500107	70012002	6	Fri	16.9	0.79	1.06	14.1	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1134	500107	70012002	6	Sat	16.9	0.79	0.97	12.9	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1135	500107	70012002	6	Sun	16.9	0.79	1.05	14.0	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1136	500107	70012002	7	Mon	16.9	0.98	0.98	16.2	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1137	500107	70012002	7	Tue	16.9	0.98	1.13	18.7	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1138	500107	70012002	7	Wed	16.9	0.98	0.88	14.6	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1139	500107	70012002	7	Thu	16.9	0.98	0.92	15.2	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1140	500107	70012002	7	Fri	16.9	0.98	1.06	17.5	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1141	500107	70012002	7	Sat	16.9	0.98	0.97	16.1	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1142	500107	70012002	7	Sun	16.9	0.98	1.05	17.4	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1143	500107	70012002	8	Mon	16.9	1.01	0.98	16.7	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1144	500107	70012002	8	Tue	16.9	1.01	1.13	19.3	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1145	500107	70012002	8	Wed	16.9	1.01	0.88	15.0	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1146	500107	70012002	8	Thu	16.9	1.01	0.92	15.7	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1147	500107	70012002	8	Fri	16.9	1.01	1.06	18.1	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1148	500107	70012002	8	Sat	16.9	1.01	0.97	16.5	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1149	500107	70012002	8	Sun	16.9	1.01	1.05	17.9	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1150	500107	70012002	9	Mon	16.9	1.10	0.98	18.2	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1151	500107	70012002	9	Tue	16.9	1.10	1.13	21.0	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1152	500107	70012002	9	Wed	16.9	1.10	0.88	16.3	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1153	500107	70012002	9	Thu	16.9	1.10	0.92	17.1	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1154	500107	70012002	9	Fri	16.9	1.10	1.06	19.7	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1155	500107	70012002	9	Sat	16.9	1.10	0.97	18.0	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1156	500107	70012002	9	Sun	16.9	1.10	1.05	19.5	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1157	500107	70012002	10	Mon	16.9	0.95	0.98	15.7	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1158	500107	70012002	10	Tue	16.9	0.95	1.13	18.1	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1159	500107	70012002	10	Wed	16.9	0.95	0.88	14.1	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1160	500107	70012002	10	Thu	16.9	0.95	0.92	14.8	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1161	500107	70012002	10	Fri	16.9	0.95	1.06	17.0	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1162	500107	70012002	10	Sat	16.9	0.95	0.97	15.6	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1163	500107	70012002	10	Sun	16.9	0.95	1.05	16.8	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1164	500107	70012002	11	Mon	16.9	1.08	0.98	17.9	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1165	500107	70012002	11	Tue	16.9	1.08	1.13	20.6	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1166	500107	70012002	11	Wed	16.9	1.08	0.88	16.0	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1167	500107	70012002	11	Thu	16.9	1.08	0.92	16.8	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1168	500107	70012002	11	Fri	16.9	1.08	1.06	19.3	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1169	500107	70012002	11	Sat	16.9	1.08	0.97	17.7	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1170	500107	70012002	11	Sun	16.9	1.08	1.05	19.1	high	90	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1171	500107	70012002	12	Mon	16.9	0.89	0.98	14.7	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1172	500107	70012002	12	Tue	16.9	0.89	1.13	17.0	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1173	500107	70012002	12	Wed	16.9	0.89	0.88	13.2	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1174	500107	70012002	12	Thu	16.9	0.89	0.92	13.8	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1175	500107	70012002	12	Fri	16.9	0.89	1.06	15.9	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1176	500107	70012002	12	Sat	16.9	0.89	0.97	14.6	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
1177	500107	70012002	12	Sun	16.9	0.89	1.05	15.8	high	93	\N	2026-04-03 20:28:26.428645	2026-04-03 20:49:34.982242
338	500107	70012004	1	Fri	12.5	1.50	1.06	19.9	medium	9	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
339	500107	70012004	1	Mon	12.5	1.50	0.98	18.4	medium	9	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
340	500107	70012004	1	Sat	12.5	1.50	0.96	18.0	medium	9	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
341	500107	70012004	1	Sun	12.5	1.50	1.05	19.7	medium	9	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
342	500107	70012004	1	Thu	12.5	1.50	0.92	17.3	medium	9	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
343	500107	70012004	1	Tue	12.5	1.50	1.14	21.4	medium	9	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
344	500107	70012004	1	Wed	12.5	1.50	0.89	16.7	medium	9	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
345	500107	70012004	2	Fri	12.5	1.15	1.06	15.3	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
346	500107	70012004	2	Mon	12.5	1.15	0.98	14.1	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
347	500107	70012004	2	Sat	12.5	1.15	0.96	13.8	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
348	500107	70012004	2	Sun	12.5	1.15	1.05	15.1	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
349	500107	70012004	2	Thu	12.5	1.15	0.92	13.2	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
350	500107	70012004	2	Tue	12.5	1.15	1.14	16.4	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
351	500107	70012004	2	Wed	12.5	1.15	0.89	12.8	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
352	500107	70012004	3	Fri	12.5	0.72	1.06	9.6	high	18	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
353	500107	70012004	3	Mon	12.5	0.72	0.98	8.8	high	18	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
354	500107	70012004	3	Sat	12.5	0.72	0.96	8.6	high	18	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
355	500107	70012004	3	Sun	12.5	0.72	1.05	9.5	high	18	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
356	500107	70012004	3	Thu	12.5	0.72	0.92	8.3	high	18	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
357	500107	70012004	3	Tue	12.5	0.72	1.14	10.3	high	18	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
358	500107	70012004	3	Wed	12.5	0.72	0.89	8.0	high	18	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
359	500107	70012004	4	Fri	12.5	1.00	1.06	13.3	estimated	0	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
360	500107	70012004	4	Mon	12.5	1.00	0.98	12.3	estimated	0	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
361	500107	70012004	4	Sat	12.5	1.00	0.96	12.0	estimated	0	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
362	500107	70012004	4	Sun	12.5	1.00	1.05	13.1	estimated	0	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
363	500107	70012004	4	Thu	12.5	1.00	0.92	11.5	estimated	0	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
364	500107	70012004	4	Tue	12.5	1.00	1.14	14.3	estimated	0	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
365	500107	70012004	4	Wed	12.5	1.00	0.89	11.1	estimated	0	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
366	500107	70012004	5	Fri	12.5	1.10	1.06	14.6	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
367	500107	70012004	5	Mon	12.5	1.10	0.98	13.5	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
368	500107	70012004	5	Sat	12.5	1.10	0.96	13.2	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
369	500107	70012004	5	Sun	12.5	1.10	1.05	14.5	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
370	500107	70012004	5	Thu	12.5	1.10	0.92	12.7	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
371	500107	70012004	5	Tue	12.5	1.10	1.14	15.7	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
372	500107	70012004	5	Wed	12.5	1.10	0.89	12.3	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
373	500107	70012004	6	Fri	12.5	0.79	1.06	10.5	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
374	500107	70012004	6	Mon	12.5	0.79	0.98	9.7	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
375	500107	70012004	6	Sat	12.5	0.79	0.96	9.5	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
376	500107	70012004	6	Sun	12.5	0.79	1.05	10.4	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
377	500107	70012004	6	Thu	12.5	0.79	0.92	9.1	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
378	500107	70012004	6	Tue	12.5	0.79	1.14	11.3	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
379	500107	70012004	6	Wed	12.5	0.79	0.89	8.8	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
380	500107	70012004	7	Fri	12.5	0.99	1.06	13.1	high	28	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
381	500107	70012004	7	Mon	12.5	0.99	0.98	12.1	high	28	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
382	500107	70012004	7	Sat	12.5	0.99	0.96	11.9	high	28	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
383	500107	70012004	7	Sun	12.5	0.99	1.05	13.0	high	28	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
384	500107	70012004	7	Thu	12.5	0.99	0.92	11.4	high	28	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
385	500107	70012004	7	Tue	12.5	0.99	1.14	14.1	high	28	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
386	500107	70012004	7	Wed	12.5	0.99	0.89	11.0	high	28	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
387	500107	70012004	8	Fri	12.5	1.03	1.06	13.7	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
388	500107	70012004	8	Mon	12.5	1.03	0.98	12.6	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
389	500107	70012004	8	Sat	12.5	1.03	0.96	12.4	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
390	500107	70012004	8	Sun	12.5	1.03	1.05	13.5	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
391	500107	70012004	8	Thu	12.5	1.03	0.92	11.9	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
392	500107	70012004	8	Tue	12.5	1.03	1.14	14.7	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
393	500107	70012004	8	Wed	12.5	1.03	0.89	11.5	high	24	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
394	500107	70012004	9	Fri	12.5	1.12	1.06	14.9	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
395	500107	70012004	9	Mon	12.5	1.12	0.98	13.7	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
396	500107	70012004	9	Sat	12.5	1.12	0.96	13.5	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
397	500107	70012004	9	Sun	12.5	1.12	1.05	14.7	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
398	500107	70012004	9	Thu	12.5	1.12	0.92	12.9	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
399	500107	70012004	9	Tue	12.5	1.12	1.14	16.0	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
400	500107	70012004	9	Wed	12.5	1.12	0.89	12.5	high	21	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
401	500107	70012004	10	Fri	12.5	0.94	1.06	12.5	high	16	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
402	500107	70012004	10	Mon	12.5	0.94	0.98	11.5	high	16	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
403	500107	70012004	10	Sat	12.5	0.94	0.96	11.3	high	16	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
404	500107	70012004	10	Sun	12.5	0.94	1.05	12.4	high	16	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
405	500107	70012004	10	Thu	12.5	0.94	0.92	10.8	high	16	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
406	500107	70012004	10	Tue	12.5	0.94	1.14	13.4	high	16	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
407	500107	70012004	10	Wed	12.5	0.94	0.89	10.5	high	16	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
408	500107	70012004	11	Fri	12.5	1.04	1.06	13.8	high	14	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
409	500107	70012004	11	Mon	12.5	1.04	0.98	12.8	high	14	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
410	500107	70012004	11	Sat	12.5	1.04	0.96	12.5	high	14	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
411	500107	70012004	11	Sun	12.5	1.04	1.05	13.7	high	14	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
412	500107	70012004	11	Thu	12.5	1.04	0.92	12.0	high	14	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
413	500107	70012004	11	Tue	12.5	1.04	1.14	14.8	high	14	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
414	500107	70012004	11	Wed	12.5	1.04	0.89	11.6	high	14	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
415	500107	70012004	12	Fri	12.5	0.91	1.06	12.1	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
416	500107	70012004	12	Mon	12.5	0.91	0.98	11.2	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
417	500107	70012004	12	Sat	12.5	0.91	0.96	10.9	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
418	500107	70012004	12	Sun	12.5	0.91	1.05	12.0	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
419	500107	70012004	12	Thu	12.5	0.91	0.92	10.5	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
420	500107	70012004	12	Tue	12.5	0.91	1.14	13.0	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
421	500107	70012004	12	Wed	12.5	0.91	0.89	10.1	medium	7	\N	2026-03-29 21:20:07.101928	2026-03-29 21:20:07.101928
\.


--
-- Data for Name: stores; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.stores (store_id, store_name, store_type, created_at) FROM stdin;
\.


--
-- Data for Name: token_returns_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.token_returns_log (id, product_id, store_id, return_date, units_returned, invoice_id, batch_id, arrival_date, expiration_date, days_on_shelf, reason, created_at) FROM stdin;
\.


--
-- Data for Name: token_sales_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.token_sales_log (id, product_id, store_id, sale_date, units_sold, batch_id, arrival_date, expiration_date, days_on_shelf, source, created_at) FROM stdin;
3	500107	70012004	2026-03-25	27	OTTO-DELIVERED-2026-03-05-500107	2026-03-05	2026-03-21	16	shelf_life	2026-03-25 20:22:03.784085
4	500107	70012004	2026-03-25	9	OTTO-DELIVERED-2026-03-09-500107	2026-03-09	2026-03-25	16	shelf_life	2026-03-25 20:22:03.784085
5	500107	70012004	2026-03-25	9	OTTO-DELIVERED-2026-03-02-500107	2026-03-02	2026-03-18	16	shelf_life	2026-03-25 20:22:03.784085
6	500107	70012004	2026-03-25	18	OTTO-DELIVERED-2026-03-03-500107	2026-03-03	2026-03-19	16	shelf_life	2026-03-25 20:22:03.784085
8	500107	70012004	2026-07-08	18	OTTO-DELIVERED-2026-03-10-500107	2026-03-10	2026-03-26	16	shelf_life	2026-07-08 12:12:43.251672
\.


--
-- Name: daily_forecast_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.daily_forecast_id_seq', 20440, true);


--
-- Name: daily_sales_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.daily_sales_log_id_seq', 18952, true);


--
-- Name: mlp_order_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.mlp_order_log_id_seq', 411, true);


--
-- Name: product_dow_multipliers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.product_dow_multipliers_id_seq', 35, true);


--
-- Name: product_monthly_multipliers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.product_monthly_multipliers_id_seq', 60, true);


--
-- Name: product_wom_multipliers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.product_wom_multipliers_id_seq', 528, true);


--
-- Name: returns_invoices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.returns_invoices_id_seq', 1, true);


--
-- Name: seasonal_pattern_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.seasonal_pattern_id_seq', 1177, true);


--
-- Name: token_returns_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.token_returns_log_id_seq', 1, true);


--
-- Name: token_sales_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.token_sales_log_id_seq', 8, true);


--
-- Name: daily_forecast daily_forecast_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_forecast
    ADD CONSTRAINT daily_forecast_pkey PRIMARY KEY (id);


--
-- Name: daily_forecast daily_forecast_sku_store_id_forecast_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_forecast
    ADD CONSTRAINT daily_forecast_sku_store_id_forecast_date_key UNIQUE (sku, store_id, forecast_date);


--
-- Name: daily_sales_log daily_sales_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_sales_log
    ADD CONSTRAINT daily_sales_log_pkey PRIMARY KEY (id);


--
-- Name: daily_sales_log daily_sales_log_store_id_sku_sale_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_sales_log
    ADD CONSTRAINT daily_sales_log_store_id_sku_sale_date_key UNIQUE (store_id, sku, sale_date);


--
-- Name: hormuz_config hormuz_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hormuz_config
    ADD CONSTRAINT hormuz_config_pkey PRIMARY KEY (product_id);


--
-- Name: inventory_transactions inventory_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_transactions
    ADD CONSTRAINT inventory_transactions_pkey PRIMARY KEY (transaction_id);


--
-- Name: mlp_order_log mlp_order_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mlp_order_log
    ADD CONSTRAINT mlp_order_log_pkey PRIMARY KEY (id);


--
-- Name: physical_counts physical_counts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.physical_counts
    ADD CONSTRAINT physical_counts_pkey PRIMARY KEY (count_id);


--
-- Name: product_dow_multipliers product_dow_multipliers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_dow_multipliers
    ADD CONSTRAINT product_dow_multipliers_pkey PRIMARY KEY (id);


--
-- Name: product_dow_multipliers product_dow_multipliers_sku_store_id_day_of_week_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_dow_multipliers
    ADD CONSTRAINT product_dow_multipliers_sku_store_id_day_of_week_key UNIQUE (sku, store_id, day_of_week);


--
-- Name: product_monthly_multipliers product_monthly_multipliers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_monthly_multipliers
    ADD CONSTRAINT product_monthly_multipliers_pkey PRIMARY KEY (id);


--
-- Name: product_monthly_multipliers product_monthly_multipliers_sku_store_id_month_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_monthly_multipliers
    ADD CONSTRAINT product_monthly_multipliers_sku_store_id_month_key UNIQUE (sku, store_id, month);


--
-- Name: product_tokens product_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_tokens
    ADD CONSTRAINT product_tokens_pkey PRIMARY KEY (token_id);


--
-- Name: product_wom_multipliers product_wom_multipliers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_wom_multipliers
    ADD CONSTRAINT product_wom_multipliers_pkey PRIMARY KEY (id);


--
-- Name: product_wom_multipliers product_wom_multipliers_sku_store_id_month_week_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_wom_multipliers
    ADD CONSTRAINT product_wom_multipliers_sku_store_id_month_week_key UNIQUE (sku, store_id, month, week);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);


--
-- Name: returns_invoices returns_invoices_invoice_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.returns_invoices
    ADD CONSTRAINT returns_invoices_invoice_id_unique UNIQUE (invoice_id);


--
-- Name: returns_invoices returns_invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.returns_invoices
    ADD CONSTRAINT returns_invoices_pkey PRIMARY KEY (id);


--
-- Name: sales_predictions sales_predictions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_predictions
    ADD CONSTRAINT sales_predictions_pkey PRIMARY KEY (prediction_id);


--
-- Name: sales_predictions sales_predictions_product_id_store_id_predicted_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_predictions
    ADD CONSTRAINT sales_predictions_product_id_store_id_predicted_date_key UNIQUE (product_id, store_id, predicted_date);


--
-- Name: seasonal_pattern seasonal_pattern_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_pattern
    ADD CONSTRAINT seasonal_pattern_pkey PRIMARY KEY (id);


--
-- Name: seasonal_pattern seasonal_pattern_sku_store_id_month_day_of_week_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_pattern
    ADD CONSTRAINT seasonal_pattern_sku_store_id_month_day_of_week_key UNIQUE (sku, store_id, month, day_of_week);


--
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (store_id);


--
-- Name: token_returns_log token_returns_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_returns_log
    ADD CONSTRAINT token_returns_log_pkey PRIMARY KEY (id);


--
-- Name: token_sales_log token_sales_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_sales_log
    ADD CONSTRAINT token_sales_log_pkey PRIMARY KEY (id);


--
-- Name: idx_product_tokens_expiration; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_tokens_expiration ON public.product_tokens USING btree (expiration_date, status);


--
-- Name: idx_product_tokens_fifo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_tokens_fifo ON public.product_tokens USING btree (product_id, store_id, arrival_date, token_id);


--
-- Name: idx_product_tokens_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_tokens_status ON public.product_tokens USING btree (product_id, store_id, status);


--
-- Name: idx_transactions_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transactions_date ON public.inventory_transactions USING btree (product_id, store_id, transaction_date);


--
-- PostgreSQL database dump complete
--

\unrestrict TUFVJ7NcgzQqKNoXsVTadYl1dy2pfJ5V6WlSeQLJeuJnGa6Vn3eHxea7nfxIqol

