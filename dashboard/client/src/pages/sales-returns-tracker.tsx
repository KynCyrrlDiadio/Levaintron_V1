import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Separator } from "@/components/ui/separator";
import { Link } from "wouter";
import {
  ArrowLeft,
  Package,
  TrendingDown,
  TrendingUp,
  ShoppingCart,
  Undo2,
  BarChart3,
  Calendar,
  Hash,
  Layers,
} from "lucide-react";

interface ProductSummary {
  product_id: string;
  product_name: string | null;
  sale_events: number;
  total_sold: number;
  first_sale: string | null;
  last_sale: string | null;
  return_events: number;
  total_returned: number;
  first_return: string | null;
  last_return: string | null;
  in_stock: number;
  sold_tokens: number;
  returned_tokens: number;
  total_tokens: number;
  return_rate_pct: number;
}

interface SaleRecord {
  id: number;
  product_id: string;
  store_id: string;
  sale_date: string;
  units_sold: number;
  batch_id: string | null;
  arrival_date: string | null;
  expiration_date: string | null;
  days_on_shelf: number | null;
  source: string | null;
  created_at: string;
  product_name: string | null;
}

interface ReturnRecord {
  id: number;
  product_id: string;
  store_id: string;
  return_date: string;
  units_returned: number;
  invoice_id: string | null;
  batch_id: string | null;
  arrival_date: string | null;
  expiration_date: string | null;
  days_on_shelf: number | null;
  reason: string | null;
  created_at: string;
  product_name: string | null;
}

// Known product names for display
const PRODUCT_NAMES: Record<string, string> = {
  "500107": "Demo 500g Rye Bread",
};

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "—";
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return "—";
  return d.toLocaleDateString("en-CA", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" });
}

function formatDateShort(dateStr: string | null): string {
  if (!dateStr) return "—";
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return "—";
  return d.toLocaleDateString("en-CA", { month: "short", day: "numeric", timeZone: "UTC" });
}

export default function SalesReturnsTracker() {
  const [selectedProduct, setSelectedProduct] = useState<string>("all");

  const { data: summary, isLoading: summaryLoading } = useQuery<ProductSummary[]>({
    queryKey: ["/api/tracker/summary"],
  });

  const { data: sales, isLoading: salesLoading } = useQuery<SaleRecord[]>({
    queryKey: ["/api/tracker/sales", selectedProduct],
    queryFn: async () => {
      const params = selectedProduct !== "all" ? `?productId=${selectedProduct}&limit=200` : "?limit=200";
      const res = await fetch(`/api/tracker/sales${params}`, { credentials: "include" });
      if (!res.ok) throw new Error("Failed to fetch sales");
      return res.json();
    },
  });

  const { data: returns, isLoading: returnsLoading } = useQuery<ReturnRecord[]>({
    queryKey: ["/api/tracker/returns", selectedProduct],
    queryFn: async () => {
      const params = selectedProduct !== "all" ? `?productId=${selectedProduct}&limit=200` : "?limit=200";
      const res = await fetch(`/api/tracker/returns${params}`, { credentials: "include" });
      if (!res.ok) throw new Error("Failed to fetch returns");
      return res.json();
    },
  });

  const totalSold = summary?.reduce((sum, p) => sum + Number(p.total_sold), 0) ?? 0;
  const totalReturned = summary?.reduce((sum, p) => sum + Number(p.total_returned), 0) ?? 0;
  const totalInStock = summary?.reduce((sum, p) => sum + Number(p.in_stock), 0) ?? 0;
  const overallReturnRate = totalSold + totalReturned > 0
    ? ((totalReturned / (totalSold + totalReturned)) * 100).toFixed(1)
    : "0.0";

  const getProductName = (pid: string) => PRODUCT_NAMES[pid] || summary?.find(s => s.product_id === pid)?.product_name || `SKU ${pid}`;

  return (
    <div className="min-h-screen bg-gradient-to-b from-stone-950 via-stone-900 to-stone-950 text-stone-100">
      {/* Header */}
      <div className="border-b border-stone-800 bg-stone-950/80 backdrop-blur-sm sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Link href="/">
              <button className="p-2 rounded-md hover:bg-stone-800 transition-colors">
                <ArrowLeft className="h-4 w-4" />
              </button>
            </Link>
            <div>
              <h1 className="text-lg font-bold tracking-tight flex items-center gap-2">
                <BarChart3 className="h-5 w-5 text-amber-500" />
                Sales & Returns Tracker
              </h1>
              <p className="text-xs text-stone-400">Token lifecycle tracking — 12-day shelf life window</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <Select value={selectedProduct} onValueChange={setSelectedProduct}>
              <SelectTrigger className="w-[220px] bg-stone-800 border-stone-700">
                <SelectValue placeholder="Filter by product" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Products</SelectItem>
                {summary?.map((p) => (
                  <SelectItem key={p.product_id} value={p.product_id}>
                    {p.product_id} — {getProductName(p.product_id)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <nav className="flex gap-1 text-xs">
              <Link href="/">
                <button className="px-2 py-1 rounded hover:bg-stone-800 text-stone-400 hover:text-stone-200">Dashboard</button>
              </Link>
              <Link href="/seasonal">
                <button className="px-2 py-1 rounded hover:bg-stone-800 text-stone-400 hover:text-stone-200">Seasonal</button>
              </Link>
              <Link href="/control">
                <button className="px-2 py-1 rounded hover:bg-stone-800 text-stone-400 hover:text-stone-200">Control</button>
              </Link>
            </nav>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 py-6 space-y-6">
        {/* Summary Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card className="bg-stone-900 border-stone-800">
            <CardHeader className="pb-2">
              <CardDescription className="text-stone-300 flex items-center gap-1.5">
                <ShoppingCart className="h-3.5 w-3.5" /> Total Sold
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold text-emerald-400">{totalSold}</div>
              <p className="text-xs text-stone-500 mt-1">units via shelf-life expiry</p>
            </CardContent>
          </Card>

          <Card className="bg-stone-900 border-stone-800">
            <CardHeader className="pb-2">
              <CardDescription className="text-stone-300 flex items-center gap-1.5">
                <Undo2 className="h-3.5 w-3.5" /> Total Returned
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold text-red-400">{totalReturned}</div>
              <p className="text-xs text-stone-500 mt-1">units via invoice processing</p>
            </CardContent>
          </Card>

          <Card className="bg-stone-900 border-stone-800">
            <CardHeader className="pb-2">
              <CardDescription className="text-stone-300 flex items-center gap-1.5">
                <Package className="h-3.5 w-3.5" /> In Stock
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold text-blue-400">{totalInStock}</div>
              <p className="text-xs text-stone-500 mt-1">active tokens across all SKUs</p>
            </CardContent>
          </Card>

          <Card className="bg-stone-900 border-stone-800">
            <CardHeader className="pb-2">
              <CardDescription className="text-stone-300 flex items-center gap-1.5">
                <TrendingDown className="h-3.5 w-3.5" /> Return Rate
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className={`text-3xl font-bold ${Number(overallReturnRate) > 5 ? "text-red-400" : Number(overallReturnRate) > 2 ? "text-amber-400" : "text-emerald-400"}`}>
                {overallReturnRate}%
              </div>
              <p className="text-xs text-stone-500 mt-1">returned / (sold + returned)</p>
            </CardContent>
          </Card>
        </div>

        {/* Per-Product Summary Table */}
        <Card className="bg-stone-900 border-stone-800">
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2 text-stone-100">
              <Layers className="h-4 w-4 text-amber-500" />
              Product Overview
            </CardTitle>
            <CardDescription className="text-stone-300">
              Token inventory status and sales/returns activity per SKU
            </CardDescription>
          </CardHeader>
          <CardContent>
            {summaryLoading ? (
              <p className="text-stone-500 text-sm">Loading...</p>
            ) : !summary || summary.length === 0 ? (
              <p className="text-stone-400 text-sm">No token data found. Token tracking begins after the first pipeline run syncs delivered tokens from the mock ordering hub.</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-stone-700 text-stone-300">
                      <th className="text-left py-2 px-3">SKU</th>
                      <th className="text-left py-2 px-3">Product</th>
                      <th className="text-right py-2 px-3">In Stock</th>
                      <th className="text-right py-2 px-3">Sold</th>
                      <th className="text-right py-2 px-3">Returned</th>
                      <th className="text-right py-2 px-3">Total Tokens</th>
                      <th className="text-right py-2 px-3">Return %</th>
                      <th className="text-left py-2 px-3">Last Sale</th>
                      <th className="text-left py-2 px-3">Last Return</th>
                    </tr>
                  </thead>
                  <tbody>
                    {summary.map((p) => (
                      <tr
                        key={p.product_id}
                        className="border-b border-stone-800 hover:bg-stone-800/50 cursor-pointer transition-colors"
                        onClick={() => setSelectedProduct(p.product_id)}
                      >
                        <td className="py-2 px-3 font-mono text-xs text-stone-200">{p.product_id}</td>
                        <td className="py-2 px-3 text-stone-100">{getProductName(p.product_id)}</td>
                        <td className="py-2 px-3 text-right">
                          <Badge variant="outline" className="border-blue-500/30 text-blue-400">
                            {p.in_stock}
                          </Badge>
                        </td>
                        <td className="py-2 px-3 text-right text-emerald-400">{p.total_sold}</td>
                        <td className="py-2 px-3 text-right text-red-400">{p.total_returned}</td>
                        <td className="py-2 px-3 text-right text-stone-100">{p.total_tokens}</td>
                        <td className="py-2 px-3 text-right">
                          <span className={Number(p.return_rate_pct) > 5 ? "text-red-400" : Number(p.return_rate_pct) > 2 ? "text-amber-400" : "text-emerald-400"}>
                            {Number(p.return_rate_pct).toFixed(1)}%
                          </span>
                        </td>
                        <td className="py-2 px-3 text-stone-300 text-xs">{formatDateShort(p.last_sale)}</td>
                        <td className="py-2 px-3 text-stone-300 text-xs">{formatDateShort(p.last_return)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Sales & Returns Detail Tabs */}
        <Tabs defaultValue="sales" className="space-y-4">
          <TabsList className="bg-stone-800">
            <TabsTrigger value="sales" className="data-[state=active]:bg-emerald-900/50 data-[state=active]:text-emerald-400">
              <TrendingUp className="h-3.5 w-3.5 mr-1.5" />
              Sales Log ({sales?.length ?? 0})
            </TabsTrigger>
            <TabsTrigger value="returns" className="data-[state=active]:bg-red-900/50 data-[state=active]:text-red-400">
              <Undo2 className="h-3.5 w-3.5 mr-1.5" />
              Returns Log ({returns?.length ?? 0})
            </TabsTrigger>
          </TabsList>

          {/* Sales Tab */}
          <TabsContent value="sales">
            <Card className="bg-stone-900 border-stone-800">
              <CardHeader>
                <CardTitle className="text-base flex items-center gap-2 text-stone-100">
                  <TrendingUp className="h-4 w-4 text-emerald-500" />
                  Token Sales Log
                  {selectedProduct !== "all" && (
                    <Badge variant="outline" className="ml-2 border-stone-600 text-stone-300 text-xs">
                      {selectedProduct} — {getProductName(selectedProduct)}
                    </Badge>
                  )}
                </CardTitle>
                <CardDescription className="text-stone-300">
                  Tokens marked as sold when they pass their 12-day shelf life expiration
                </CardDescription>
              </CardHeader>
              <CardContent>
                {salesLoading ? (
                  <p className="text-stone-500 text-sm">Loading sales data...</p>
                ) : !sales || sales.length === 0 ? (
                  <div className="text-center py-8">
                    <ShoppingCart className="h-8 w-8 text-stone-600 mx-auto mb-2" />
                    <p className="text-stone-500 text-sm">No sales records found</p>
                    <p className="text-stone-600 text-xs mt-1">Sales are logged when tokens expire past shelf life on the production machine</p>
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="border-b border-stone-700 text-stone-300">
                          <th className="text-left py-2 px-3">
                            <Hash className="h-3 w-3 inline mr-1" />ID
                          </th>
                          <th className="text-left py-2 px-3">SKU</th>
                          <th className="text-left py-2 px-3">Product</th>
                          <th className="text-left py-2 px-3">
                            <Calendar className="h-3 w-3 inline mr-1" />Sale Date
                          </th>
                          <th className="text-right py-2 px-3">Units</th>
                          <th className="text-left py-2 px-3">Arrival</th>
                          <th className="text-left py-2 px-3">Expiry</th>
                          <th className="text-right py-2 px-3">Days on Shelf</th>
                          <th className="text-left py-2 px-3">Source</th>
                          <th className="text-left py-2 px-3">Batch</th>
                        </tr>
                      </thead>
                      <tbody>
                        {sales.map((s) => (
                          <tr key={s.id} className="border-b border-stone-800/50 hover:bg-stone-800/30">
                            <td className="py-2 px-3 text-stone-400 font-mono text-xs">{s.id}</td>
                            <td className="py-2 px-3 font-mono text-xs text-stone-200">{s.product_id}</td>
                            <td className="py-2 px-3 text-stone-100">{getProductName(s.product_id)}</td>
                            <td className="py-2 px-3 text-stone-100">{formatDate(s.sale_date)}</td>
                            <td className="py-2 px-3 text-right">
                              <Badge className="bg-emerald-900/50 text-emerald-400 border-emerald-700/30">
                                {s.units_sold}
                              </Badge>
                            </td>
                            <td className="py-2 px-3 text-stone-300 text-xs">{formatDateShort(s.arrival_date)}</td>
                            <td className="py-2 px-3 text-stone-300 text-xs">{formatDateShort(s.expiration_date)}</td>
                            <td className="py-2 px-3 text-right text-stone-300">{s.days_on_shelf ?? "—"}</td>
                            <td className="py-2 px-3">
                              <Badge variant="outline" className="text-xs border-stone-600 text-stone-200">
                                {s.source || "manual"}
                              </Badge>
                            </td>
                            <td className="py-2 px-3 text-stone-500 text-xs font-mono truncate max-w-[180px]" title={s.batch_id || ""}>
                              {s.batch_id ? s.batch_id.replace("OTTO-DELIVERED-", "") : "—"}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          {/* Returns Tab */}
          <TabsContent value="returns">
            <Card className="bg-stone-900 border-stone-800">
              <CardHeader>
                <CardTitle className="text-base flex items-center gap-2 text-stone-100">
                  <Undo2 className="h-4 w-4 text-red-500" />
                  Token Returns Log
                  {selectedProduct !== "all" && (
                    <Badge variant="outline" className="ml-2 border-stone-600 text-stone-300 text-xs">
                      {selectedProduct} — {getProductName(selectedProduct)}
                    </Badge>
                  )}
                </CardTitle>
                <CardDescription className="text-stone-300">
                  Returns processed from biweekly invoices via returns_invoice_parser
                </CardDescription>
              </CardHeader>
              <CardContent>
                {returnsLoading ? (
                  <p className="text-stone-500 text-sm">Loading returns data...</p>
                ) : !returns || returns.length === 0 ? (
                  <div className="text-center py-8">
                    <Undo2 className="h-8 w-8 text-stone-600 mx-auto mb-2" />
                    <p className="text-stone-500 text-sm">No returns records found</p>
                    <p className="text-stone-600 text-xs mt-1">Returns are logged when invoices are parsed and processed on the production machine</p>
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="border-b border-stone-700 text-stone-300">
                          <th className="text-left py-2 px-3">
                            <Hash className="h-3 w-3 inline mr-1" />ID
                          </th>
                          <th className="text-left py-2 px-3">SKU</th>
                          <th className="text-left py-2 px-3">Product</th>
                          <th className="text-left py-2 px-3">
                            <Calendar className="h-3 w-3 inline mr-1" />Return Date
                          </th>
                          <th className="text-right py-2 px-3">Units</th>
                          <th className="text-left py-2 px-3">Arrival</th>
                          <th className="text-left py-2 px-3">Expiry</th>
                          <th className="text-right py-2 px-3">Days on Shelf</th>
                          <th className="text-left py-2 px-3">Reason</th>
                          <th className="text-left py-2 px-3">Invoice</th>
                          <th className="text-left py-2 px-3">Batch</th>
                        </tr>
                      </thead>
                      <tbody>
                        {returns.map((r) => (
                          <tr key={r.id} className="border-b border-stone-800/50 hover:bg-stone-800/30">
                            <td className="py-2 px-3 text-stone-400 font-mono text-xs">{r.id}</td>
                            <td className="py-2 px-3 font-mono text-xs text-stone-200">{r.product_id}</td>
                            <td className="py-2 px-3 text-stone-100">{getProductName(r.product_id)}</td>
                            <td className="py-2 px-3 text-stone-100">{formatDate(r.return_date)}</td>
                            <td className="py-2 px-3 text-right">
                              <Badge className="bg-red-900/50 text-red-400 border-red-700/30">
                                {r.units_returned}
                              </Badge>
                            </td>
                            <td className="py-2 px-3 text-stone-300 text-xs">{formatDateShort(r.arrival_date)}</td>
                            <td className="py-2 px-3 text-stone-300 text-xs">{formatDateShort(r.expiration_date)}</td>
                            <td className="py-2 px-3 text-right text-stone-300">{r.days_on_shelf ?? "—"}</td>
                            <td className="py-2 px-3 text-stone-300 text-xs">{r.reason || "—"}</td>
                            <td className="py-2 px-3 text-stone-500 text-xs font-mono">{r.invoice_id || "—"}</td>
                            <td className="py-2 px-3 text-stone-500 text-xs font-mono truncate max-w-[180px]" title={r.batch_id || ""}>
                              {r.batch_id ? r.batch_id.replace("OTTO-DELIVERED-", "") : "—"}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
}
