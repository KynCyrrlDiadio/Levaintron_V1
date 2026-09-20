import { useState, useEffect, useRef } from "react";
import { useQuery, useMutation } from "@tanstack/react-query";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Separator } from "@/components/ui/separator";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { Slider } from "@/components/ui/slider";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useToast } from "@/hooks/use-toast";
import { queryClient, apiRequest } from "@/lib/queryClient";
import { Input } from "@/components/ui/input";
import { Link } from "wouter";
import {
  Play,
  Square,
  Activity,
  Cpu,
  HardDrive,
  MemoryStick,
  Thermometer,
  Clock,
  CheckCircle2,
  XCircle,
  AlertTriangle,
  Loader2,
  ArrowLeft,
  Terminal,
  Server,
  Zap,
  Key,
  Wheat,
  Undo2,
  Package,
  TrendingDown,
  CalendarCheck,
  ChevronDown,
  ChevronUp,
  X,
  Maximize2,
  Minimize2,
  FileText,
  Upload,
  FileCheck,
  Trash2,
  Truck,
  Search,
  Ban,
  PackagePlus,
  CloudSun,
  Snowflake,
  Sun,
  CloudRain,
  Cloud,
} from "lucide-react";

interface PipelineStatus {
  status: "idle" | "running" | "completed" | "failed" | "aborted";
  id?: string;
  mode?: string;
  productId?: string;
  startedAt?: string;
  completedAt?: string;
  error?: string;
}

interface PipelineRun {
  id: string;
  status: string;
  mode: string;
  productId: string;
  startedAt: string;
  completedAt: string | null;
  error: string | null;
  exitCode: number | null;
}

interface SystemHealth {
  uptime_human: string;
  uptime_seconds: number;
  memory: {
    total_gb: string;
    free_gb: string;
    used_percent: string;
  };
  cpu: {
    cores: number;
    model: string;
    load_avg_1m: string;
    load_avg_5m: string;
  };
  hostname: string;
  platform: string;
  gpu: Array<{
    name: string;
    temperature_c: number;
    utilization_percent: number;
    memory_used_mb: number;
    memory_total_mb: number;
  }> | null;
  disk: {
    total: string;
    used: string;
    available: string;
    used_percent: string;
  } | null;
  pipeline: PipelineStatus;
}

const STATUS_CONFIG: Record<string, { color: string; icon: any; label: string }> = {
  idle: { color: "bg-stone-400", icon: Clock, label: "Idle" },
  running: { color: "bg-amber-500 animate-pulse", icon: Loader2, label: "Running" },
  completed: { color: "bg-emerald-600", icon: CheckCircle2, label: "Completed" },
  failed: { color: "bg-red-500", icon: XCircle, label: "Failed" },
  aborted: { color: "bg-amber-600", icon: AlertTriangle, label: "Aborted" },
};

interface ReturnsSummary {
  productId: string;
  returnRate30d: number;
  totalReturned30d: number;
  totalDelivered30d: number;
  isReturnDay: boolean;
  recentInvoices: Array<{
    invoice_id: string;
    invoice_date: string;
    units_returned: number;
    reason: string | null;
    tokens_updated: number;
  }>;
}

const PRODUCTS: Record<string, string> = {
  "500107": "Demo 500g Rye Bread",
};

function LogViewer({ lines, title, onClose }: { lines: string[]; title: string; onClose: () => void }) {
  const [expanded, setExpanded] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [lines.length]);

  return (
    <div className={`fixed inset-0 z-50 bg-black/80 flex items-end sm:items-center justify-center ${expanded ? "" : "p-4"}`} data-testid="modal-log-viewer">
      <div className={`bg-stone-950 rounded-t-xl sm:rounded-xl flex flex-col ${expanded ? "w-full h-full rounded-none" : "w-full max-w-2xl max-h-[85vh]"}`}>
        <div className="flex items-center justify-between px-4 py-3 border-b border-stone-800 shrink-0">
          <div className="flex items-center gap-2">
            <Terminal className="h-4 w-4 text-amber-400" />
            <span className="text-sm font-medium text-amber-300">{title}</span>
            <Badge variant="outline" className="text-xs text-stone-400 border-stone-700">
              {lines.length} lines
            </Badge>
          </div>
          <div className="flex items-center gap-1">
            <Button
              variant="ghost"
              size="icon"
              className="h-7 w-7 text-stone-400 hover:text-white"
              onClick={() => setExpanded(!expanded)}
              data-testid="button-toggle-fullscreen"
            >
              {expanded ? <Minimize2 className="h-4 w-4" /> : <Maximize2 className="h-4 w-4" />}
            </Button>
            <Button
              variant="ghost"
              size="icon"
              className="h-7 w-7 text-stone-400 hover:text-white"
              onClick={onClose}
              data-testid="button-close-logs"
            >
              <X className="h-4 w-4" />
            </Button>
          </div>
        </div>
        <div className="flex-1 overflow-auto p-3 min-h-0">
          <pre className="text-xs text-amber-300/90 font-mono whitespace-pre leading-5" data-testid="text-log-content">
            {lines.map((line, i) => (
              <div key={i} className="flex">
                <span className="text-stone-600 select-none w-10 shrink-0 text-right pr-2">{i + 1}</span>
                <span className={line.includes("[stderr]") ? "text-red-400/80" : line.includes("WARNING") || line.includes("⚠") ? "text-amber-500" : line.includes("ERROR") || line.includes("CRITICAL") ? "text-red-400" : line.includes("SUCCESS") || line.includes("✓") ? "text-emerald-400" : ""}>{line}</span>
              </div>
            ))}
            <div ref={bottomRef} />
          </pre>
        </div>
      </div>
    </div>
  );
}

function OrderDetailModal({ order, onClose }: { order: any; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-50 bg-black/80 flex items-end sm:items-center justify-center p-4" data-testid="modal-order-detail">
      <div className="bg-background rounded-t-xl sm:rounded-xl w-full max-w-md max-h-[80vh] overflow-auto">
        <div className="flex items-center justify-between px-4 py-3 border-b sticky top-0 bg-background">
          <div className="flex items-center gap-2">
            <Activity className="h-4 w-4 text-primary" />
            <span className="text-sm font-medium">MLP Decision Detail</span>
          </div>
          <Button variant="ghost" size="icon" className="h-7 w-7" onClick={onClose} data-testid="button-close-order-detail">
            <X className="h-4 w-4" />
          </Button>
        </div>
        <div className="p-4 space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <DetailField label="Delivery Date" value={order.delivery_date || "N/A"} />
            <DetailField label="Product" value={`SKU ${order.product_id}`} />
            <DetailField label="MLP Decision" value={order.mlp_decision != null ? `Order ${order.mlp_decision}` : "N/A"} highlight />
            <DetailField label="Total Units" value={order.total_units != null ? String(order.total_units) : "N/A"} />
            <DetailField label="Current Stock" value={order.current_stock != null ? String(order.current_stock) : "N/A"} />
            <DetailField label="Projected Stock" value={order.projected_stock != null ? String(order.projected_stock) : "N/A"} />
            <DetailField label="Pipeline Incoming" value={order.pipeline_incoming != null ? String(order.pipeline_incoming) : "N/A"} />
            <DetailField label="Expected Sales" value={order.expected_sales != null ? Number(order.expected_sales).toFixed(1) : "N/A"} />
            <DetailField label="Actual Sales Rate" value={order.actual_sales_rate != null ? Number(order.actual_sales_rate).toFixed(1) : "N/A"} />
            <DetailField label="Returns Rate" value={order.returns_rate != null ? `${Number(order.returns_rate).toFixed(1)}%` : "N/A"} />
            <DetailField label="Monthly Multiplier" value={order.monthly_multiplier != null ? Number(order.monthly_multiplier).toFixed(2) : "N/A"} />
            <DetailField label="OTTO Written" value={order.otto_write_success ? "Yes" : order.otto_write_success === false ? "Failed" : "N/A"} />
            <DetailField label="Confidence" value={order.mlp_confidence ? `${(Number(order.mlp_confidence) * 100).toFixed(1)}%` : "N/A"} />
            <DetailField label="Method" value={order.mlp_method || "N/A"} />
            <DetailField label="Tray Factor" value={order.tray_factor != null ? String(order.tray_factor) : "N/A"} />
          </div>
          {order.was_overridden && (
            <div className="rounded-lg border border-amber-500/30 bg-amber-500/5 p-2.5">
              <p className="text-xs font-medium text-amber-600 dark:text-amber-400">Override Applied</p>
              <p className="text-xs text-muted-foreground mt-0.5">
                {order.override_reason}
              </p>
            </div>
          )}
          {order.otto_action && order.otto_action === 'failed' && (
            <div className="rounded-lg border border-red-500/30 bg-red-500/5 p-2.5">
              <p className="text-xs font-medium text-red-600 dark:text-red-400">OTTO Write Failed</p>
              <p className="text-xs text-muted-foreground mt-0.5">Action: {order.otto_action}</p>
            </div>
          )}
          {order.decision_time && (
            <div className="pt-2 border-t">
              <p className="text-xs text-muted-foreground">
                Decision made: {new Date(order.decision_time).toLocaleString()}
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function DetailField({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <div className="rounded-lg border p-2.5">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className={`text-sm font-medium mt-0.5 ${highlight ? "text-primary" : ""}`}>{value}</p>
    </div>
  );
}

interface DeliveryBatch {
  batch_id: string;
  arrival_date: string;
  expiration_date: string;
  in_stock: number;
  sold: number;
  returned: number;
  expired: number;
  cancelled: number;
  total: number;
}

interface BatchesResponse {
  product_id: string;
  product_name: string;
  batches: DeliveryBatch[];
}

function CancelDeliveryPanel({ apiToken }: { apiToken: string }) {
  const { toast } = useToast();
  const [skuInput, setSkuInput] = useState("");
  const [searchedSku, setSearchedSku] = useState("");
  const [cancellingBatch, setCancellingBatch] = useState<string | null>(null);

  const { data: batchData, isLoading, refetch } = useQuery<BatchesResponse>({
    queryKey: ["/api/inventory/batches", searchedSku],
    queryFn: async () => {
      const res = await fetch(`/api/inventory/batches?product_id=${searchedSku}`);
      if (!res.ok) throw new Error("Failed to fetch batches");
      return res.json();
    },
    enabled: !!searchedSku,
  });

  const handleSearch = () => {
    const sku = skuInput.trim();
    if (!sku) {
      toast({ title: "Enter a SKU", description: "Type a product SKU to search", variant: "destructive" });
      return;
    }
    setSearchedSku(sku);
  };

  const handleCancel = async (batch: DeliveryBatch) => {
    if (batch.in_stock === 0) {
      toast({ title: "Nothing to cancel", description: "No in_stock tokens in this batch", variant: "destructive" });
      return;
    }

    const key = `${batch.batch_id}-${batch.arrival_date}`;
    setCancellingBatch(key);
    try {
      const res = await fetch("/api/inventory/batches/cancel", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(apiToken ? { "Authorization": `Bearer ${apiToken}` } : {}),
        },
        body: JSON.stringify({
          productId: searchedSku,
          batchId: batch.batch_id,
          arrivalDate: batch.arrival_date,
        }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({ error: res.statusText }));
        throw new Error(data.error || `${res.status}: ${res.statusText}`);
      }
      const data = await res.json();
      toast({
        title: "Delivery cancelled",
        description: `${data.cancelled} in_stock tokens marked cancelled for batch ${batch.arrival_date}`,
      });
      refetch();
      queryClient.invalidateQueries({ queryKey: ["/api/inventory/tokens"] });
    } catch (err: any) {
      toast({ title: "Cancel failed", description: err.message, variant: "destructive" });
    } finally {
      setCancellingBatch(null);
    }
  };

  const formatDate = (d: string) => {
    try {
      const date = new Date(d);
      return date.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });
    } catch { return d; }
  };

  const toDateOnly = (d: string) => {
    const date = new Date(d);
    date.setHours(0, 0, 0, 0);
    return date;
  };

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  return (
    <Card data-testid="card-cancel-delivery">
      <CardHeader className="pb-3">
        <CardTitle className="flex items-center gap-2 text-base">
          <Truck className="h-5 w-5" />
          Cancel Delivery
        </CardTitle>
        <CardDescription>
          Remove in_stock tokens for a delivery batch — corrects missed or cancelled deliveries
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex gap-2">
          <Input
            placeholder="Enter SKU (e.g. 500107)"
            value={skuInput}
            onChange={(e) => setSkuInput(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") handleSearch(); }}
            className="flex-1 text-sm"
            data-testid="input-cancel-sku"
          />
          <Button
            size="sm"
            onClick={handleSearch}
            disabled={isLoading}
            data-testid="button-search-batches"
          >
            {isLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Search className="h-4 w-4" />}
          </Button>
        </div>

        {searchedSku && PRODUCTS[searchedSku] && (
          <p className="text-xs text-muted-foreground">
            {PRODUCTS[searchedSku]} ({searchedSku})
          </p>
        )}

        {batchData && batchData.batches.length > 0 ? (
          <ScrollArea className="h-[320px]">
            <div className="space-y-2">
              {batchData.batches.map((batch) => {
                const key = `${batch.batch_id}-${batch.arrival_date}`;
                const isCancelling = cancellingBatch === key;
                const arrivalDate = toDateOnly(batch.arrival_date);
                const isPast = arrivalDate < today;
                const expirationDate = toDateOnly(batch.expiration_date);
                const isExpired = expirationDate < today;

                return (
                  <div
                    key={key}
                    className={`rounded-lg border p-3 space-y-2 ${isExpired ? "opacity-50" : ""}`}
                  >
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="text-sm font-medium">
                          {formatDate(batch.arrival_date)}
                          {isPast && (
                            <Badge variant="outline" className="ml-2 text-xs">past</Badge>
                          )}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          Expires {formatDate(batch.expiration_date)}
                        </p>
                      </div>
                      <Button
                        size="sm"
                        variant="destructive"
                        disabled={batch.in_stock === 0 || isCancelling}
                        onClick={() => handleCancel(batch)}
                        data-testid={`button-cancel-${batch.arrival_date}`}
                      >
                        {isCancelling ? (
                          <Loader2 className="mr-1.5 h-3 w-3 animate-spin" />
                        ) : (
                          <Ban className="mr-1.5 h-3 w-3" />
                        )}
                        Cancel ({batch.in_stock})
                      </Button>
                    </div>
                    <div className={`grid gap-1.5 ${batch.cancelled > 0 ? 'grid-cols-5' : 'grid-cols-4'}`}>
                      <div className="rounded border px-2 py-1 text-center">
                        <p className="text-xs text-muted-foreground">In Stock</p>
                        <p className="text-sm font-semibold text-emerald-600">{batch.in_stock}</p>
                      </div>
                      <div className="rounded border px-2 py-1 text-center">
                        <p className="text-xs text-muted-foreground">Sold</p>
                        <p className="text-sm font-semibold">{batch.sold}</p>
                      </div>
                      <div className="rounded border px-2 py-1 text-center">
                        <p className="text-xs text-muted-foreground">Returned</p>
                        <p className="text-sm font-semibold text-amber-600">{batch.returned}</p>
                      </div>
                      <div className="rounded border px-2 py-1 text-center">
                        <p className="text-xs text-muted-foreground">Expired</p>
                        <p className="text-sm font-semibold text-red-600">{batch.expired}</p>
                      </div>
                      {batch.cancelled > 0 && (
                        <div className="rounded border px-2 py-1 text-center">
                          <p className="text-xs text-muted-foreground">Cancelled</p>
                          <p className="text-sm font-semibold text-gray-500">{batch.cancelled}</p>
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </ScrollArea>
        ) : batchData && batchData.batches.length === 0 ? (
          <p className="text-sm text-muted-foreground py-4 text-center">
            No delivery batches found for {searchedSku}
          </p>
        ) : searchedSku && !isLoading ? (
          <p className="text-sm text-muted-foreground py-4 text-center">
            No data found
          </p>
        ) : null}
      </CardContent>
    </Card>
  );
}

function AddDeliveryTokensPanel({ apiToken }: { apiToken: string }) {
  const { toast } = useToast();
  // Local (store/MST) date — NOT UTC. toISOString() rolls to tomorrow after ~5pm MST,
  // which would pre-fill a future arrival; this feature is past/present landed stock only.
  const now = new Date();
  const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
  const [skuInput, setSkuInput] = useState("");
  const [searchedSku, setSearchedSku] = useState("");
  const [arrivalDate, setArrivalDate] = useState(todayStr);
  const [quantity, setQuantity] = useState("");
  const [notes, setNotes] = useState("");
  const [adding, setAdding] = useState(false);

  const { data: batchData, isLoading, refetch } = useQuery<BatchesResponse>({
    queryKey: ["/api/inventory/batches", "add-panel", searchedSku],
    queryFn: async () => {
      const res = await fetch(`/api/inventory/batches?product_id=${searchedSku}`);
      if (!res.ok) throw new Error("Failed to fetch batches");
      return res.json();
    },
    enabled: !!searchedSku,
  });

  const handleAdd = async () => {
    const sku = skuInput.trim();
    const qty = parseInt(quantity, 10);
    if (!sku) {
      toast({ title: "Enter a SKU", description: "Type a product SKU to add tokens for", variant: "destructive" });
      return;
    }
    if (!arrivalDate) {
      toast({ title: "Pick an arrival date", description: "Arrival date is required", variant: "destructive" });
      return;
    }
    if (arrivalDate > todayStr) {
      toast({ title: "No future dates", description: "This corrects past/present landed stock — future stock is the MLP's job", variant: "destructive" });
      return;
    }
    if (!Number.isFinite(qty) || qty < 1) {
      toast({ title: "Invalid quantity", description: "Enter a whole number of units (1 or more)", variant: "destructive" });
      return;
    }
    setAdding(true);
    try {
      const res = await fetch("/api/inventory/batches/add", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(apiToken ? { "Authorization": `Bearer ${apiToken}` } : {}),
        },
        body: JSON.stringify({
          productId: sku,
          arrivalDate,
          quantity: qty,
          notes: notes.trim() || undefined,
        }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({ error: res.statusText }));
        throw new Error(data.error || `${res.status}: ${res.statusText}`);
      }
      const data = await res.json();
      toast({
        title: "Tokens added",
        description: `${data.added} in_stock token(s) added for ${sku}, arriving ${arrivalDate} (expires ${data.expiration_date})`,
      });
      setSearchedSku(sku);
      setQuantity("");
      setNotes("");
      refetch();
      queryClient.invalidateQueries({ queryKey: ["/api/inventory/tokens"] });
      queryClient.invalidateQueries({ queryKey: ["/api/inventory/batches"] });
    } catch (err: any) {
      toast({ title: "Add failed", description: err.message, variant: "destructive" });
    } finally {
      setAdding(false);
    }
  };

  const formatDate = (d: string) => {
    try {
      return new Date(d).toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });
    } catch { return d; }
  };

  return (
    <Card data-testid="card-add-delivery">
      <CardHeader className="pb-3">
        <CardTitle className="flex items-center gap-2 text-base">
          <PackagePlus className="h-5 w-5" />
          Add New Delivery Tokens
        </CardTitle>
        <CardDescription>
          Manually add in_stock tokens for a delivery OTTO didn't capture — feeds FIFO inventory + the MLP
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-2 gap-2">
          <div className="space-y-1">
            <Label className="text-xs text-muted-foreground">SKU</Label>
            <Input
              placeholder="e.g. 921293"
              value={skuInput}
              onChange={(e) => setSkuInput(e.target.value)}
              className="text-sm"
              data-testid="input-add-sku"
            />
          </div>
          <div className="space-y-1">
            <Label className="text-xs text-muted-foreground">Arrival date</Label>
            <Input
              type="date"
              value={arrivalDate}
              max={todayStr}
              onChange={(e) => setArrivalDate(e.target.value)}
              className="text-sm"
              data-testid="input-add-arrival"
            />
          </div>
          <div className="space-y-1">
            <Label className="text-xs text-muted-foreground">Quantity (units)</Label>
            <Input
              type="number"
              min={1}
              placeholder="e.g. 18"
              value={quantity}
              onChange={(e) => setQuantity(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter") handleAdd(); }}
              className="text-sm"
              data-testid="input-add-quantity"
            />
          </div>
          <div className="space-y-1">
            <Label className="text-xs text-muted-foreground">Notes (optional)</Label>
            <Input
              placeholder="e.g. walk-in restock"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              className="text-sm"
              data-testid="input-add-notes"
            />
          </div>
        </div>

        {skuInput.trim() && PRODUCTS[skuInput.trim()] && (
          <p className="text-xs text-muted-foreground">
            {PRODUCTS[skuInput.trim()]} ({skuInput.trim()})
          </p>
        )}

        <Button
          className="w-full"
          onClick={handleAdd}
          disabled={adding}
          data-testid="button-add-tokens"
        >
          {adding ? (
            <Loader2 className="mr-1.5 h-4 w-4 animate-spin" />
          ) : (
            <PackagePlus className="mr-1.5 h-4 w-4" />
          )}
          Add Tokens
        </Button>

        {searchedSku && batchData && batchData.batches.length > 0 && (
          <div className="space-y-2 pt-1">
            <p className="text-xs font-medium text-muted-foreground">
              Current batches for {searchedSku}{isLoading ? " (refreshing…)" : ""}
            </p>
            <ScrollArea className="h-[220px]">
              <div className="space-y-2">
                {batchData.batches.map((batch) => {
                  const key = `${batch.batch_id}-${batch.arrival_date}`;
                  return (
                    <div key={key} className="rounded-lg border p-2.5 space-y-1.5">
                      <div className="flex items-center justify-between">
                        <p className="text-sm font-medium">{formatDate(batch.arrival_date)}</p>
                        <p className="text-xs text-muted-foreground">
                          Expires {formatDate(batch.expiration_date)}
                        </p>
                      </div>
                      <p className="text-[11px] text-muted-foreground truncate" title={batch.batch_id}>
                        {batch.batch_id}
                      </p>
                      <div className="grid grid-cols-4 gap-1.5">
                        <div className="rounded border px-2 py-1 text-center">
                          <p className="text-xs text-muted-foreground">In Stock</p>
                          <p className="text-sm font-semibold text-emerald-600">{batch.in_stock}</p>
                        </div>
                        <div className="rounded border px-2 py-1 text-center">
                          <p className="text-xs text-muted-foreground">Sold</p>
                          <p className="text-sm font-semibold">{batch.sold}</p>
                        </div>
                        <div className="rounded border px-2 py-1 text-center">
                          <p className="text-xs text-muted-foreground">Returned</p>
                          <p className="text-sm font-semibold text-amber-600">{batch.returned}</p>
                        </div>
                        <div className="rounded border px-2 py-1 text-center">
                          <p className="text-xs text-muted-foreground">Expired</p>
                          <p className="text-sm font-semibold text-red-600">{batch.expired}</p>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </ScrollArea>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

interface WeatherDay {
  date: string;
  temp_max: number;
  temp_min: number;
  precip_probability: number;
  precipitation_mm: number;
  weathercode: number;
  outdoor_score: number;
}

interface WeatherData {
  location: string;
  fetched_at: string;
  affected_products: Record<string, string>;
  days: WeatherDay[];
}

const SNOW_CODES = new Set([56, 57, 66, 67, 71, 73, 75, 77, 85, 86]);
const RAIN_CODES = new Set([51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99]);

function getWeatherIcon(code: number, score: number) {
  if (SNOW_CODES.has(code)) return <Snowflake className="h-4 w-4 text-blue-300" />;
  if (RAIN_CODES.has(code)) return <CloudRain className="h-4 w-4 text-blue-400" />;
  if (score > 0.5) return <Sun className="h-4 w-4 text-yellow-500" />;
  if (score > 0.15) return <CloudSun className="h-4 w-4 text-amber-400" />;
  return <Cloud className="h-4 w-4 text-gray-400" />;
}

function getScoreColor(score: number) {
  if (score >= 0.5) return "text-green-500";
  if (score >= 0.2) return "text-yellow-500";
  if (score > 0) return "text-orange-400";
  return "text-gray-400";
}

function getDayName(dateStr: string) {
  const d = new Date(dateStr + "T12:00:00");
  return d.toLocaleDateString("en-US", { weekday: "short" });
}

function WeatherPanel() {
  const { data: weather, isLoading } = useQuery<WeatherData>({
    queryKey: ["/api/weather"],
    refetchInterval: 3 * 60 * 60 * 1000,
  });

  if (isLoading) return null;
  if (!weather || !weather.days?.length) return null;

  const today = weather.days[0];
  const avgScore = weather.days.reduce((s, d) => s + d.outdoor_score, 0) / weather.days.length;

  return (
    <Card data-testid="card-weather">
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <div>
            <CardTitle className="flex items-center gap-2 text-base">
              <CloudSun className="h-5 w-5" />
              Weather Forecast
            </CardTitle>
            <CardDescription>
              {weather.location} — BBQ demand signal for MLP inputs
            </CardDescription>
          </div>
          <div className="text-right">
            <div className="flex items-center gap-1.5">
              <span className="text-xs text-muted-foreground">Today</span>
              <Badge variant="outline" className="font-mono text-sm">
                {today.temp_max.toFixed(0)}°/{today.temp_min.toFixed(0)}°C
              </Badge>
              <Badge variant={today.outdoor_score > 0.3 ? "default" : "secondary"} className="font-mono text-xs">
                {today.outdoor_score.toFixed(3)}
              </Badge>
            </div>
          </div>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-7 gap-1">
          {weather.days.map((day) => (
            <div
              key={day.date}
              className="rounded-lg border p-2 text-center space-y-1"
            >
              <div className="text-xs font-medium text-muted-foreground">
                {getDayName(day.date)}
              </div>
              <div className="text-xs text-muted-foreground">
                {day.date.slice(5)}
              </div>
              <div className="flex justify-center">
                {getWeatherIcon(day.weathercode, day.outdoor_score)}
              </div>
              <div className="text-xs font-medium">
                {day.temp_max.toFixed(0)}°/{day.temp_min.toFixed(0)}°
              </div>
              {day.precip_probability > 0 && (
                <div className="text-xs text-blue-400">
                  {day.precip_probability}%
                </div>
              )}
              <div className={`text-xs font-mono font-bold ${getScoreColor(day.outdoor_score)}`}>
                {day.outdoor_score.toFixed(2)}
              </div>
            </div>
          ))}
        </div>

        <Separator />

        <div className="flex items-center justify-between">
          <div className="space-y-1">
            <Label className="text-sm font-medium">Affected Products</Label>
            <div className="flex flex-wrap gap-1.5">
              {Object.entries(weather.affected_products).map(([pid, name]) => (
                <Badge key={pid} variant="outline" className="text-xs">
                  {name}
                </Badge>
              ))}
            </div>
          </div>
          <div className="text-right space-y-0.5">
            <div className="text-xs text-muted-foreground">14-day avg</div>
            <div className={`text-lg font-mono font-bold ${getScoreColor(avgScore)}`}>
              {avgScore.toFixed(3)}
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

interface HormuzData {
  global: number;
  products: Record<string, number>;
}

interface FifoBatch {
  arrival: string;
  initial: number;
  remaining: number;
  depleted: number;
}

interface FifoDecision {
  date: string;
  action: string;
  qty: number;
  stock_after: number;
  confidence: number;
  error?: string;
}

interface FifoProjection {
  product_id: string;
  total_tokens: number;
  estimated_remaining: number;
  total_burn: number;
  days_span: number;
  num_batches: number;
  hormuz_multiplier: number;
  method: string;
  batch_breakdown: FifoBatch[];
  decisions?: FifoDecision[];
  error?: string;
}

interface FifoProjectionResponse {
  generated_at: string;
  store_id: string;
  hormuz_preview: { global: number; products: Record<string, number> };
  include_decisions: boolean;
  projections: FifoProjection[];
}

async function fetchFifoProjection(body: {
  products: string[];
  hormuzGlobal?: number;
  hormuzOverrides?: Record<string, number>;
  includeDecisions?: boolean;
}): Promise<FifoProjectionResponse> {
  const res = await apiRequest("POST", "/api/inventory/fifo-projection", body);
  return res.json();
}

function HormuzPanel() {
  const { toast } = useToast();
  const { data: hormuz, isLoading } = useQuery<HormuzData>({
    queryKey: ["/api/hormuz"],
  });

  const [globalVal, setGlobalVal] = useState(0.85);
  const [overrides, setOverrides] = useState<Record<string, number>>({});
  const [dirty, setDirty] = useState(false);

  // FIFO projection state — baseline = saved DB values; preview = current sliders.
  // Per-row display compares preview vs baseline so the user sees the delta the
  // next pipeline run would observe if they hit Save.
  const [baseline, setBaseline] = useState<Record<string, FifoProjection>>({});
  const [preview, setPreview] = useState<Record<string, FifoProjection>>({});
  const [previewLoading, setPreviewLoading] = useState(false);

  // Save confirmation modal
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [confirmProjection, setConfirmProjection] = useState<Record<string, FifoProjection> | null>(null);
  const [confirmLoading, setConfirmLoading] = useState(false);

  const productIds = Object.keys(PRODUCTS);

  // Sync from server data
  useEffect(() => {
    if (hormuz) {
      setGlobalVal(hormuz.global);
      setOverrides(hormuz.products);
      setDirty(false);
    }
  }, [hormuz]);

  // Fetch baseline projection once after hormuz config is loaded — captures
  // what the next pipeline run would estimate using the *currently saved*
  // multipliers. Becomes the "before" column in the confirmation modal.
  useEffect(() => {
    if (!hormuz) return;
    let cancelled = false;
    fetchFifoProjection({ products: productIds })
      .then((data) => {
        if (cancelled) return;
        const map: Record<string, FifoProjection> = {};
        for (const p of data.projections) map[p.product_id] = p;
        setBaseline(map);
        setPreview(map); // initial preview matches baseline
      })
      .catch((err) => {
        console.error("Baseline projection failed:", err);
      });
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hormuz]);

  // Debounced live preview — refresh on every slider drag with 200ms tail.
  // Keeps stdout JSON clean and respects the venv subprocess overhead.
  useEffect(() => {
    if (!hormuz) return;
    if (!dirty) return;
    const handle = setTimeout(async () => {
      setPreviewLoading(true);
      try {
        const data = await fetchFifoProjection({
          products: productIds,
          hormuzGlobal: globalVal,
          hormuzOverrides: overrides,
        });
        const map: Record<string, FifoProjection> = {};
        for (const p of data.projections) map[p.product_id] = p;
        setPreview(map);
      } catch (err: any) {
        console.error("Live FIFO preview failed:", err);
      } finally {
        setPreviewLoading(false);
      }
    }, 200);
    return () => clearTimeout(handle);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [globalVal, overrides, dirty, hormuz]);

  const saveMutation = useMutation({
    mutationFn: async () => {
      await apiRequest("PUT", "/api/hormuz", { global: globalVal, products: overrides });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/hormuz"] });
      setDirty(false);
      setConfirmOpen(false);
      setConfirmProjection(null);
      toast({ title: "Hormuz config saved", description: `Global: ${globalVal}, ${Object.keys(overrides).length} overrides` });
    },
    onError: (err: Error) => {
      toast({ title: "Save failed", description: err.message, variant: "destructive" });
    },
  });

  const handleSaveClick = async () => {
    setConfirmOpen(true);
    setConfirmLoading(true);
    setConfirmProjection(null);
    try {
      const data = await fetchFifoProjection({
        products: productIds,
        hormuzGlobal: globalVal,
        hormuzOverrides: overrides,
        includeDecisions: true,
      });
      const map: Record<string, FifoProjection> = {};
      for (const p of data.projections) map[p.product_id] = p;
      setConfirmProjection(map);
    } catch (err: any) {
      toast({
        title: "Could not load projection",
        description: err.message,
        variant: "destructive",
      });
    } finally {
      setConfirmLoading(false);
    }
  };

  const setProductOverride = (pid: string, val: number | null) => {
    setDirty(true);
    if (val === null) {
      const next = { ...overrides };
      delete next[pid];
      setOverrides(next);
    } else {
      setOverrides(prev => ({ ...prev, [pid]: val }));
    }
  };

  const effectiveMultiplier = (pid: string) => {
    return overrides[pid] ?? globalVal;
  };

  if (isLoading) return null;

  return (
    <Card data-testid="card-hormuz">
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <div>
            <CardTitle className="flex items-center gap-2 text-base">
              <TrendingDown className="h-5 w-5" />
              Hormuz Multiplier
            </CardTitle>
            <CardDescription>
              Burn-rate scaler — dampen when demand slows, boost to correct FIFO drift
            </CardDescription>
          </div>
          <Button
            size="sm"
            disabled={!dirty || saveMutation.isPending}
            onClick={handleSaveClick}
          >
            {saveMutation.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : "Save"}
          </Button>
        </div>
      </CardHeader>
      <CardContent className="space-y-5">
        {/* Global slider */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Label className="text-sm font-medium">Global Multiplier</Label>
            <Badge variant="outline" className="font-mono text-sm">
              {globalVal.toFixed(2)} ({globalVal <= 1 ? `${Math.round((1 - globalVal) * 100)}% reduction` : `${Math.round((globalVal - 1) * 100)}% boost`})
            </Badge>
          </div>
          <Slider
            min={0}
            max={3}
            step={0.01}
            value={[globalVal]}
            onValueChange={([v]) => { setGlobalVal(v); setDirty(true); }}
            className="py-1"
          />
          <div className="flex justify-between text-xs text-muted-foreground">
            <span>0.00 (full stop)</span>
            <span>1.00 (baseline)</span>
            <span>3.00 (3x boost)</span>
          </div>
        </div>

        <Separator />

        {/* Per-product overrides */}
        <div className="space-y-3">
          <Label className="text-sm font-medium">Per-Product Overrides</Label>
          <div className="space-y-2">
            {Object.entries(PRODUCTS).map(([pid, name]) => {
              const hasOverride = pid in overrides;
              const effective = effectiveMultiplier(pid);
              const base = baseline[pid];
              const live = preview[pid];
              const baseRemaining = base?.estimated_remaining ?? null;
              const liveRemaining = live?.estimated_remaining ?? null;
              const totalTokens = live?.total_tokens ?? base?.total_tokens ?? null;
              const delta = (baseRemaining !== null && liveRemaining !== null)
                ? liveRemaining - baseRemaining
                : null;
              return (
                <div key={pid} className="rounded-lg border p-3">
                  <div className="flex items-center justify-between mb-1.5">
                    <div className="flex items-center gap-2 min-w-0">
                      <Switch
                        checked={hasOverride}
                        onCheckedChange={(checked) => {
                          if (checked) {
                            setProductOverride(pid, globalVal);
                          } else {
                            setProductOverride(pid, null);
                          }
                        }}
                      />
                      <span className="text-sm truncate">{name}</span>
                      <span className="text-xs text-muted-foreground">({pid})</span>
                    </div>
                    <Badge variant={hasOverride ? "default" : "secondary"} className="font-mono text-xs shrink-0">
                      {effective.toFixed(2)}
                    </Badge>
                  </div>
                  {hasOverride && (
                    <Slider
                      min={0}
                      max={3}
                      step={0.01}
                      value={[overrides[pid]]}
                      onValueChange={([v]) => setProductOverride(pid, v)}
                      className="py-1"
                    />
                  )}
                  {/* FIFO projection — shows what the next pipeline run will see */}
                  {totalTokens !== null && (
                    <div className="mt-2 flex items-center gap-2 text-xs font-mono text-muted-foreground">
                      <span>{totalTokens} tokens</span>
                      <span>→</span>
                      <span className="text-foreground">
                        est. remaining: {liveRemaining ?? "…"}
                      </span>
                      {delta !== null && delta !== 0 && (
                        <Badge
                          variant={delta < 0 ? "destructive" : "default"}
                          className="font-mono text-[10px] py-0 h-4"
                        >
                          {delta > 0 ? "+" : ""}{delta}
                        </Badge>
                      )}
                      {previewLoading && dirty && (
                        <Loader2 className="h-3 w-3 animate-spin" />
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </CardContent>

      {/* Save confirmation modal — shows current vs projected est_remaining
          and the MLP decisions the next pipeline run would emit. */}
      <Dialog open={confirmOpen} onOpenChange={(open) => {
        if (!saveMutation.isPending) setConfirmOpen(open);
      }}>
        <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Confirm Hormuz multiplier change</DialogTitle>
            <DialogDescription>
              The next pipeline run will use these projected stock estimates and MLP decisions.
              Live preview reflects the same FIFO depletion math the cron job runs at 03:00 daily.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3">
            <div className="rounded-md border p-3 bg-muted/30 text-sm">
              <div className="flex justify-between font-mono">
                <span>Global Hormuz</span>
                <span>{(hormuz?.global ?? 0).toFixed(2)} → <strong>{globalVal.toFixed(2)}</strong></span>
              </div>
            </div>

            {confirmLoading && (
              <div className="flex items-center justify-center gap-2 py-8 text-sm text-muted-foreground">
                <Loader2 className="h-4 w-4 animate-spin" />
                Running canonical FIFO projection (with MLP decisions)…
              </div>
            )}

            {!confirmLoading && confirmProjection && Object.entries(PRODUCTS).map(([pid, name]) => {
              const base = baseline[pid];
              const proj = confirmProjection[pid];
              if (!proj) return null;
              const effective = effectiveMultiplier(pid);
              const baseEff = (hormuz?.products?.[pid] ?? hormuz?.global ?? 0);
              const stockBefore = base?.estimated_remaining ?? "—";
              const stockAfter = proj.estimated_remaining;
              const delta = (typeof stockBefore === "number") ? stockAfter - stockBefore : null;
              return (
                <div key={pid} className="rounded-md border p-3">
                  <div className="flex items-center justify-between mb-1">
                    <div className="text-sm font-medium truncate">
                      {name} <span className="text-muted-foreground text-xs">({pid})</span>
                    </div>
                    <div className="font-mono text-xs">
                      H: {baseEff.toFixed(2)} → <strong>{effective.toFixed(2)}</strong>
                    </div>
                  </div>
                  <div className="flex items-center gap-2 text-xs font-mono text-muted-foreground mb-1.5">
                    <span>{proj.total_tokens} tokens</span>
                    <span>•</span>
                    <span>est. remaining: {stockBefore} → <strong className="text-foreground">{stockAfter}</strong></span>
                    {delta !== null && delta !== 0 && (
                      <Badge variant={delta < 0 ? "destructive" : "default"} className="font-mono text-[10px] py-0 h-4">
                        {delta > 0 ? "+" : ""}{delta}
                      </Badge>
                    )}
                  </div>
                  {proj.decisions && proj.decisions.length > 0 && (
                    <div className="flex flex-wrap gap-1.5 mt-1">
                      {proj.decisions.map((d, idx) => (
                        <Badge
                          key={idx}
                          variant={d.action === "ORDER" ? "default" : "secondary"}
                          className="font-mono text-[10px]"
                        >
                          {d.date.slice(5)}: {d.action} {d.qty > 0 ? d.qty : ""}
                        </Badge>
                      ))}
                    </div>
                  )}
                  {proj.error && (
                    <div className="text-xs text-destructive mt-1">{proj.error}</div>
                  )}
                </div>
              );
            })}
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setConfirmOpen(false)} disabled={saveMutation.isPending}>
              Cancel
            </Button>
            <Button
              onClick={() => saveMutation.mutate()}
              disabled={saveMutation.isPending || confirmLoading}
            >
              {saveMutation.isPending ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
              Confirm & Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}

export default function Control() {
  const { toast } = useToast();
  const [liveMode, setLiveMode] = useState(false);
  const [selectedProduct, setSelectedProduct] = useState("500107");
  const [returnUnits, setReturnUnits] = useState("");
  const [returnInvoiceId, setReturnInvoiceId] = useState("");
  const [returnReason, setReturnReason] = useState("");
  const [forceReturnDay, setForceReturnDay] = useState(false);
  const [pdfFile, setPdfFile] = useState<File | null>(null);
  const [parsedInvoice, setParsedInvoice] = useState<any>(null);
  const [pdfParsing, setPdfParsing] = useState(false);
  const [pdfProcessing, setPdfProcessing] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [viewingRunLogs, setViewingRunLogs] = useState<string | null>(null);
  const [viewingRunTitle, setViewingRunTitle] = useState("");
  const [selectedOrder, setSelectedOrder] = useState<any | null>(null);
  const [showLiveFullscreen, setShowLiveFullscreen] = useState(false);
  const [apiToken, setApiToken] = useState(() => {
    try { return localStorage.getItem("doughmind_api_token") || ""; } catch { return ""; }
  });

  useEffect(() => {
    try { localStorage.setItem("doughmind_api_token", apiToken); } catch {}
  }, [apiToken]);

  const { data: pipelineStatus } = useQuery<PipelineStatus>({
    queryKey: ["/api/pipeline/status"],
    refetchInterval: (query) => {
      const data = query.state.data as PipelineStatus | undefined;
      return data?.status === "running" ? 2000 : 10000;
    },
  });

  const { data: health } = useQuery<SystemHealth>({
    queryKey: ["/api/system/health"],
    refetchInterval: 15000,
  });

  const { data: history } = useQuery<PipelineRun[]>({
    queryKey: ["/api/pipeline/history"],
    refetchInterval: 10000,
  });

  const { data: output } = useQuery<{ lines: string[] }>({
    queryKey: ["/api/pipeline/output"],
    refetchInterval: pipelineStatus?.status === "running" ? 2000 : false,
    enabled: pipelineStatus?.status === "running",
  });

  const { data: recentOrders } = useQuery<any[]>({
    queryKey: ["/api/pipeline/orders"],
  });

  const { data: returnsSummary } = useQuery<ReturnsSummary>({
    queryKey: ["/api/returns/summary", selectedProduct],
    queryFn: async () => {
      const res = await fetch(`/api/returns/summary?product_id=${selectedProduct}`);
      if (!res.ok) throw new Error("Failed to fetch returns summary");
      return res.json();
    },
    refetchInterval: 30000,
  });

  const { data: viewingRunOutput } = useQuery<{ lines: string[] }>({
    queryKey: ["/api/pipeline/output", viewingRunLogs],
    queryFn: async () => {
      const res = await fetch(`/api/pipeline/output?runId=${viewingRunLogs}&tail=5000`);
      if (!res.ok) throw new Error("Failed to fetch run output");
      return res.json();
    },
    enabled: !!viewingRunLogs,
  });

  const returnsMutation = useMutation({
    mutationFn: async () => {
      const res = await fetch("/api/returns/process", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(apiToken ? { "Authorization": `Bearer ${apiToken}` } : {}),
        },
        body: JSON.stringify({
          productId: selectedProduct,
          unitsReturned: parseInt(returnUnits),
          invoiceId: returnInvoiceId.trim(),
          reason: returnReason.trim() || undefined,
          forceDay: forceReturnDay,
        }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({ error: res.statusText }));
        throw new Error(data.error || `${res.status}: ${res.statusText}`);
      }
      return res.json();
    },
    onSuccess: (data: any) => {
      toast({
        title: "Returns processed",
        description: `${data.tokensUpdated} units returned. 30-day rate: ${data.returnRate30d}%`,
      });
      setReturnUnits("");
      setReturnInvoiceId("");
      setReturnReason("");
      queryClient.invalidateQueries({ queryKey: ["/api/returns/summary"] });
      queryClient.invalidateQueries({ queryKey: ["/api/inventory/tokens"] });
    },
    onError: (err: any) => {
      toast({ title: "Failed to process returns", description: err.message, variant: "destructive" });
    },
  });

  const triggerMutation = useMutation({
    mutationFn: async () => {
      const res = await fetch("/api/pipeline/trigger", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(apiToken ? { "Authorization": `Bearer ${apiToken}` } : {}),
        },
        body: JSON.stringify({
          mode: liveMode ? "live" : "dry_run",
          productId: selectedProduct,
        }),
      });
      if (!res.ok) {
        const text = await res.text();
        throw new Error(`${res.status}: ${text}`);
      }
      return res.json();
    },
    onSuccess: () => {
      toast({ title: "Pipeline triggered", description: `Mode: ${liveMode ? "LIVE" : "Dry Run"}` });
      queryClient.invalidateQueries({ queryKey: ["/api/pipeline/status"] });
      queryClient.invalidateQueries({ queryKey: ["/api/pipeline/output"] });
    },
    onError: (err: any) => {
      toast({ title: "Failed to trigger pipeline", description: err.message, variant: "destructive" });
    },
  });

  const abortMutation = useMutation({
    mutationFn: async () => {
      const res = await fetch("/api/pipeline/abort", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(apiToken ? { "Authorization": `Bearer ${apiToken}` } : {}),
        },
      });
      if (!res.ok) {
        const text = await res.text();
        throw new Error(`${res.status}: ${text}`);
      }
      return res.json();
    },
    onSuccess: () => {
      toast({ title: "Pipeline aborted" });
      queryClient.invalidateQueries({ queryKey: ["/api/pipeline/status"] });
      queryClient.invalidateQueries({ queryKey: ["/api/pipeline/history"] });
    },
    onError: (err: any) => {
      toast({ title: "Failed to abort", description: err.message, variant: "destructive" });
    },
  });

  const isRunning = pipelineStatus?.status === "running";
  const statusInfo = STATUS_CONFIG[pipelineStatus?.status || "idle"] || STATUS_CONFIG.idle;

  return (
    <div className="min-h-screen bg-background">
      <header className="sticky top-0 z-50 border-b bg-background/95 backdrop-blur">
        <div className="flex items-center justify-between px-4 py-3">
          <div className="flex items-center gap-3">
            <Link href="/">
              <Button variant="ghost" size="icon" data-testid="button-back">
                <ArrowLeft className="h-5 w-5" />
              </Button>
            </Link>
            <div className="flex items-center gap-2.5">
              <Wheat className="h-5 w-5 text-primary" />
              <div>
                <h1 className="text-lg font-bold" data-testid="text-page-title">Pipeline Control</h1>
                <p className="text-xs text-muted-foreground">Levaintron Remote Management</p>
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <div className={`h-3 w-3 rounded-full ${statusInfo.color}`} data-testid="status-indicator" />
            <span className="text-sm font-medium" data-testid="text-status">{statusInfo.label}</span>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-2xl space-y-4 p-4">

        <Card data-testid="card-pipeline-trigger">
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-base">
              <Zap className="h-5 w-5" />
              Run Pipeline
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between gap-3">
              <Label htmlFor="api-token" className="text-sm flex items-center gap-1.5">
                <Key className="h-3.5 w-3.5" />
                API Token
              </Label>
              <Input
                id="api-token"
                type="password"
                placeholder="Enter token"
                value={apiToken}
                onChange={(e) => setApiToken(e.target.value)}
                className="w-[200px] text-sm"
                data-testid="input-api-token"
              />
            </div>

            <div className="flex items-center justify-between">
              <Label htmlFor="product-select" className="text-sm">Product</Label>
              <Select value={selectedProduct} onValueChange={setSelectedProduct}>
                <SelectTrigger className="w-[200px]" data-testid="select-product">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {Object.entries(PRODUCTS).map(([id, name]) => (
                    <SelectItem key={id} value={id}>{name} ({id})</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="flex items-center justify-between">
              <div>
                <Label htmlFor="live-mode" className="text-sm">Live Mode</Label>
                <p className="text-xs text-muted-foreground">
                  {liveMode ? "Will write to OTTO and submit" : "Dry run — no changes made"}
                </p>
              </div>
              <Switch
                id="live-mode"
                checked={liveMode}
                onCheckedChange={setLiveMode}
                data-testid="switch-live-mode"
              />
            </div>

            <div className="flex gap-2">
              {!isRunning ? (
                <Button
                  className="flex-1"
                  onClick={() => triggerMutation.mutate()}
                  disabled={triggerMutation.isPending}
                  data-testid="button-trigger-pipeline"
                >
                  {triggerMutation.isPending ? (
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  ) : (
                    <Play className="mr-2 h-4 w-4" />
                  )}
                  {liveMode ? "Run LIVE" : "Run Dry"}
                </Button>
              ) : (
                <Button
                  variant="destructive"
                  className="flex-1"
                  onClick={() => abortMutation.mutate()}
                  disabled={abortMutation.isPending}
                  data-testid="button-abort-pipeline"
                >
                  <Square className="mr-2 h-4 w-4" />
                  Abort Pipeline
                </Button>
              )}
            </div>
          </CardContent>
        </Card>

        {isRunning && output?.lines && output.lines.length > 0 && (
          <Card data-testid="card-live-output">
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2 text-base">
                <Terminal className="h-5 w-5" />
                Live Output
                <Badge variant="outline" className="text-xs ml-1">{output.lines.length} lines</Badge>
                <div className="ml-auto flex items-center gap-1">
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-7 w-7"
                    onClick={() => setShowLiveFullscreen(true)}
                    data-testid="button-expand-live-output"
                  >
                    <Maximize2 className="h-4 w-4" />
                  </Button>
                  <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />
                </div>
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ScrollArea className="h-[300px] rounded-lg bg-stone-900 p-3">
                <pre className="text-xs text-amber-300 font-mono whitespace-pre leading-5 overflow-x-auto" data-testid="text-live-output">
                  {output.lines.slice(-100).join("\n")}
                </pre>
              </ScrollArea>
            </CardContent>
          </Card>
        )}

        <Card data-testid="card-returns-upload">
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-base">
              <Undo2 className="h-5 w-5" />
              Returns Upload
              {returnsSummary?.isReturnDay ? (
                <Badge variant="default" className="ml-auto" data-testid="badge-return-day">
                  <CalendarCheck className="mr-1 h-3 w-3" />
                  Return Day
                </Badge>
              ) : (
                <Badge variant="outline" className="ml-auto" data-testid="badge-not-return-day">
                  Tue / Fri only
                </Badge>
              )}
            </CardTitle>
            <CardDescription>
              Process bi-weekly returns — updates FIFO tokens and MLP return rate
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {returnsSummary && (
              <div className="grid grid-cols-3 gap-2">
                <div className="rounded-lg border p-2.5 text-center">
                  <div className="flex items-center justify-center gap-1 text-xs text-muted-foreground">
                    <TrendingDown className="h-3 w-3" />
                    30d Rate
                  </div>
                  <p className="mt-1 text-lg font-semibold" data-testid="text-return-rate">
                    {returnsSummary.returnRate30d.toFixed(1)}%
                  </p>
                </div>
                <div className="rounded-lg border p-2.5 text-center">
                  <div className="text-xs text-muted-foreground">Returned</div>
                  <p className="mt-1 text-lg font-semibold" data-testid="text-total-returned">
                    {returnsSummary.totalReturned30d}
                  </p>
                </div>
                <div className="rounded-lg border p-2.5 text-center">
                  <div className="text-xs text-muted-foreground">Delivered</div>
                  <p className="mt-1 text-lg font-semibold" data-testid="text-total-delivered">
                    {returnsSummary.totalDelivered30d}
                  </p>
                </div>
              </div>
            )}

            <Tabs defaultValue="manual" className="w-full">
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="manual" className="text-xs">
                  <Package className="mr-1.5 h-3 w-3" />
                  Manual Entry
                </TabsTrigger>
                <TabsTrigger value="pdf" className="text-xs">
                  <Upload className="mr-1.5 h-3 w-3" />
                  Upload PDF
                </TabsTrigger>
              </TabsList>

              {/* ---- Manual Entry Tab ---- */}
              <TabsContent value="manual" className="space-y-3">
                <div className="flex items-center justify-between gap-3">
                  <Label htmlFor="return-units" className="text-sm flex items-center gap-1.5">
                    <Package className="h-3.5 w-3.5" />
                    Units
                  </Label>
                  <Input
                    id="return-units"
                    type="number"
                    min="1"
                    placeholder="e.g. 3"
                    value={returnUnits}
                    onChange={(e) => setReturnUnits(e.target.value)}
                    className="w-[200px] text-sm"
                    data-testid="input-return-units"
                  />
                </div>

                <div className="flex items-center justify-between gap-3">
                  <Label htmlFor="return-invoice" className="text-sm">Invoice #</Label>
                  <Input
                    id="return-invoice"
                    type="text"
                    placeholder="e.g. INV-2026-0304"
                    value={returnInvoiceId}
                    onChange={(e) => setReturnInvoiceId(e.target.value)}
                    className="w-[200px] text-sm"
                    data-testid="input-return-invoice"
                  />
                </div>

                <div className="flex items-center justify-between gap-3">
                  <Label htmlFor="return-reason" className="text-sm">Reason</Label>
                  <Input
                    id="return-reason"
                    type="text"
                    placeholder="Optional"
                    value={returnReason}
                    onChange={(e) => setReturnReason(e.target.value)}
                    className="w-[200px] text-sm"
                    data-testid="input-return-reason"
                  />
                </div>

                {!returnsSummary?.isReturnDay && (
                  <div className="space-y-2">
                    <p className="text-xs text-amber-600 dark:text-amber-400 flex items-center gap-1">
                      <AlertTriangle className="h-3 w-3" />
                      Returns are only processed on Tuesday and Friday
                    </p>
                    <div className="flex items-center gap-2">
                      <Switch
                        checked={forceReturnDay}
                        onCheckedChange={setForceReturnDay}
                        data-testid="switch-force-return-day"
                      />
                      <Label className="text-xs text-muted-foreground">Override day check</Label>
                    </div>
                  </div>
                )}

                <Button
                  className="w-full"
                  variant={(returnsSummary?.isReturnDay || forceReturnDay) ? "default" : "secondary"}
                  onClick={() => {
                    const units = parseInt(returnUnits);
                    if (isNaN(units) || units < 1 || !Number.isInteger(units)) {
                      toast({ title: "Invalid units", description: "Enter a whole number of 1 or more", variant: "destructive" });
                      return;
                    }
                    returnsMutation.mutate();
                  }}
                  disabled={returnsMutation.isPending || !returnUnits || !returnInvoiceId || (!returnsSummary?.isReturnDay && !forceReturnDay)}
                  data-testid="button-submit-returns"
                >
                  {returnsMutation.isPending ? (
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  ) : (
                    <Undo2 className="mr-2 h-4 w-4" />
                  )}
                  Process Returns
                </Button>
              </TabsContent>

              {/* ---- Upload PDF Tab ---- */}
              <TabsContent value="pdf" className="space-y-3">
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".pdf"
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      setPdfFile(file);
                      setParsedInvoice(null);
                    }
                  }}
                />

                {!parsedInvoice ? (
                  <>
                    <div
                      className="border-2 border-dashed rounded-lg p-6 text-center cursor-pointer hover:border-primary/50 transition-colors"
                      onClick={() => fileInputRef.current?.click()}
                      onDragOver={(e) => { e.preventDefault(); e.stopPropagation(); }}
                      onDrop={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        const file = e.dataTransfer.files[0];
                        if (file?.type === "application/pdf") {
                          setPdfFile(file);
                          setParsedInvoice(null);
                        } else {
                          toast({ title: "Invalid file", description: "Only PDF files are accepted", variant: "destructive" });
                        }
                      }}
                    >
                      {pdfFile ? (
                        <div className="flex items-center justify-center gap-2">
                          <FileText className="h-5 w-5 text-primary" />
                          <div className="text-left">
                            <p className="text-sm font-medium">{pdfFile.name}</p>
                            <p className="text-xs text-muted-foreground">{(pdfFile.size / 1024).toFixed(0)} KB</p>
                          </div>
                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-6 w-6 ml-2"
                            onClick={(e) => { e.stopPropagation(); setPdfFile(null); if (fileInputRef.current) fileInputRef.current.value = ""; }}
                          >
                            <Trash2 className="h-3 w-3" />
                          </Button>
                        </div>
                      ) : (
                        <>
                          <Upload className="h-8 w-8 mx-auto text-muted-foreground mb-2" />
                          <p className="text-sm text-muted-foreground">Tap to select or drag PDF invoice</p>
                          <p className="text-xs text-muted-foreground mt-1">Canada Bread returns/stale invoices</p>
                        </>
                      )}
                    </div>

                    <Button
                      className="w-full"
                      disabled={!pdfFile || pdfParsing}
                      onClick={async () => {
                        if (!pdfFile) return;
                        setPdfParsing(true);
                        try {
                          const formData = new FormData();
                          formData.append("invoice", pdfFile);
                          const res = await fetch("/api/returns/parse-pdf", {
                            method: "POST",
                            headers: apiToken ? { "Authorization": `Bearer ${apiToken}` } : {},
                            body: formData,
                          });
                          if (!res.ok) {
                            const data = await res.json().catch(() => ({ error: res.statusText }));
                            throw new Error(data.error || `${res.status}`);
                          }
                          const data = await res.json();
                          setParsedInvoice(data);
                          toast({ title: "Invoice parsed", description: `${data.products.length} products found — ${data.type} invoice` });
                        } catch (err: any) {
                          toast({ title: "PDF parse failed", description: err.message, variant: "destructive" });
                        } finally {
                          setPdfParsing(false);
                        }
                      }}
                    >
                      {pdfParsing ? (
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      ) : (
                        <FileCheck className="mr-2 h-4 w-4" />
                      )}
                      Parse Invoice
                    </Button>
                  </>
                ) : (
                  <>
                    <div className="rounded-lg border p-3 space-y-2">
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-sm font-medium">Invoice #{parsedInvoice.invoice_number}</p>
                          <p className="text-xs text-muted-foreground">{parsedInvoice.date} · {parsedInvoice.type.toUpperCase()}</p>
                        </div>
                        <Badge variant={parsedInvoice.type === "returns" ? "default" : "secondary"}>
                          {parsedInvoice.type === "returns" ? "Returns" : "Sales"}
                        </Badge>
                      </div>
                      <Separator />
                      <ScrollArea className="max-h-[160px]">
                        <div className="space-y-1">
                          {parsedInvoice.products.map((p: any, i: number) => (
                            <div key={i} className="flex items-center justify-between text-xs py-1">
                              <div>
                                <span className="font-mono text-muted-foreground">{p.product_id}</span>
                                <span className="ml-2">{p.description.length > 30 ? p.description.slice(0, 30) + "..." : p.description}</span>
                              </div>
                              <Badge variant="outline" className="text-xs">{p.quantity}</Badge>
                            </div>
                          ))}
                        </div>
                      </ScrollArea>
                      <div className="flex justify-between text-xs text-muted-foreground pt-1">
                        <span>{parsedInvoice.products.length} products</span>
                        <span className="font-medium">{parsedInvoice.total_units} total units</span>
                      </div>
                    </div>

                    {parsedInvoice.type !== "returns" && (
                      <p className="text-xs text-amber-600 dark:text-amber-400 flex items-center gap-1">
                        <AlertTriangle className="h-3 w-3" />
                        Sales invoices are not processed here — only returns/stale
                      </p>
                    )}

                    {!returnsSummary?.isReturnDay && (
                      <div className="space-y-2">
                        <p className="text-xs text-amber-600 dark:text-amber-400 flex items-center gap-1">
                          <AlertTriangle className="h-3 w-3" />
                          Returns are only processed on Tuesday and Friday
                        </p>
                        <div className="flex items-center gap-2">
                          <Switch
                            checked={forceReturnDay}
                            onCheckedChange={setForceReturnDay}
                          />
                          <Label className="text-xs text-muted-foreground">Override day check</Label>
                        </div>
                      </div>
                    )}

                    <div className="flex gap-2">
                      <Button
                        variant="outline"
                        className="flex-1"
                        onClick={() => {
                          setParsedInvoice(null);
                          setPdfFile(null);
                          if (fileInputRef.current) fileInputRef.current.value = "";
                        }}
                      >
                        <Trash2 className="mr-2 h-4 w-4" />
                        Clear
                      </Button>
                      <Button
                        className="flex-1"
                        disabled={pdfProcessing || parsedInvoice.type !== "returns" || (!returnsSummary?.isReturnDay && !forceReturnDay)}
                        onClick={async () => {
                          setPdfProcessing(true);
                          try {
                            const res = await fetch("/api/returns/process-invoice", {
                              method: "POST",
                              headers: {
                                "Content-Type": "application/json",
                                ...(apiToken ? { "Authorization": `Bearer ${apiToken}` } : {}),
                              },
                              body: JSON.stringify({
                                invoiceNumber: parsedInvoice.invoice_number,
                                invoiceDate: parsedInvoice.date,
                                invoiceType: parsedInvoice.type,
                                products: parsedInvoice.products,
                                forceDay: forceReturnDay,
                              }),
                            });
                            if (!res.ok) {
                              const data = await res.json().catch(() => ({ error: res.statusText }));
                              throw new Error(data.error || `${res.status}`);
                            }
                            const data = await res.json();
                            toast({
                              title: "Invoice processed",
                              description: `${data.totalProcessed} products updated, ${data.totalSkipped} skipped`,
                            });
                            setParsedInvoice(null);
                            setPdfFile(null);
                            if (fileInputRef.current) fileInputRef.current.value = "";
                            queryClient.invalidateQueries({ queryKey: ["/api/returns/summary"] });
                            queryClient.invalidateQueries({ queryKey: ["/api/inventory/tokens"] });
                          } catch (err: any) {
                            toast({ title: "Processing failed", description: err.message, variant: "destructive" });
                          } finally {
                            setPdfProcessing(false);
                          }
                        }}
                      >
                        {pdfProcessing ? (
                          <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        ) : (
                          <Undo2 className="mr-2 h-4 w-4" />
                        )}
                        Process Returns
                      </Button>
                    </div>
                  </>
                )}
              </TabsContent>
            </Tabs>

            {returnsSummary?.recentInvoices && returnsSummary.recentInvoices.length > 0 && (
              <>
                <Separator />
                <div>
                  <p className="text-sm font-medium mb-2">Recent Returns</p>
                  <ScrollArea className="h-[120px]">
                    <div className="space-y-1.5">
                      {returnsSummary.recentInvoices.map((inv, i) => (
                        <div key={inv.invoice_id} className="flex items-center justify-between text-sm rounded-lg border px-3 py-2" data-testid={`row-return-${i}`}>
                          <div>
                            <p className="font-medium text-xs">{inv.invoice_id}</p>
                            <p className="text-xs text-muted-foreground">
                              {new Date(inv.invoice_date).toLocaleDateString()}
                              {inv.reason ? ` · ${inv.reason}` : ""}
                            </p>
                          </div>
                          <Badge variant="outline">{inv.units_returned} units</Badge>
                        </div>
                      ))}
                    </div>
                  </ScrollArea>
                </div>
              </>
            )}
          </CardContent>
        </Card>

        <CancelDeliveryPanel apiToken={apiToken} />

        <AddDeliveryTokensPanel apiToken={apiToken} />

        <Card data-testid="card-system-health">
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-base">
              <Server className="h-5 w-5" />
              System Health
            </CardTitle>
            <CardDescription>
              {health?.hostname || "---"} · {health?.uptime_human || "---"} uptime
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-3">
              <div className="rounded-lg border p-3">
                <div className="flex items-center gap-2 text-sm text-muted-foreground">
                  <Cpu className="h-4 w-4" />
                  CPU
                </div>
                <p className="mt-1 text-lg font-semibold" data-testid="text-cpu-load">
                  {health?.cpu?.load_avg_1m || "---"}
                </p>
                <p className="text-xs text-muted-foreground">
                  {health?.cpu?.cores || 0} cores
                </p>
              </div>

              <div className="rounded-lg border p-3">
                <div className="flex items-center gap-2 text-sm text-muted-foreground">
                  <MemoryStick className="h-4 w-4" />
                  Memory
                </div>
                <p className="mt-1 text-lg font-semibold" data-testid="text-memory-usage">
                  {health?.memory?.used_percent || "---"}%
                </p>
                <p className="text-xs text-muted-foreground">
                  {health?.memory?.free_gb || "---"}GB free
                </p>
              </div>

              {health?.disk && (
                <div className="rounded-lg border p-3">
                  <div className="flex items-center gap-2 text-sm text-muted-foreground">
                    <HardDrive className="h-4 w-4" />
                    Disk
                  </div>
                  <p className="mt-1 text-lg font-semibold" data-testid="text-disk-usage">
                    {health.disk.used_percent}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {health.disk.available} free
                  </p>
                </div>
              )}

              {health?.gpu && health.gpu.length > 0 && (
                <div className="rounded-lg border p-3">
                  <div className="flex items-center gap-2 text-sm text-muted-foreground">
                    <Thermometer className="h-4 w-4" />
                    GPU
                  </div>
                  <p className="mt-1 text-lg font-semibold" data-testid="text-gpu-temp">
                    {health.gpu[0].temperature_c}°C
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {health.gpu[0].utilization_percent}% util · {health.gpu[0].name}
                  </p>
                </div>
              )}
            </div>

            {health?.gpu && health.gpu.length > 1 && (
              <div className="mt-3 space-y-2">
                <Separator />
                <p className="text-sm font-medium">All GPUs</p>
                {health.gpu.map((g, i) => (
                  <div key={i} className="flex items-center justify-between text-sm" data-testid={`text-gpu-info-${i}`}>
                    <span className="text-muted-foreground">{g.name}</span>
                    <span>{g.temperature_c}°C · {g.utilization_percent}% · {g.memory_used_mb}/{g.memory_total_mb}MB</span>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        <HormuzPanel />

        <WeatherPanel />

        <Card data-testid="card-recent-orders">
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-base">
              <Activity className="h-5 w-5" />
              Recent MLP Decisions
            </CardTitle>
            <CardDescription>Tap a decision to see full details</CardDescription>
          </CardHeader>
          <CardContent>
            {recentOrders && recentOrders.length > 0 ? (
              <ScrollArea className="h-[300px]">
                <div className="space-y-2">
                  {recentOrders.slice(0, 20).map((order: any, i: number) => (
                    <div
                      key={order.id || i}
                      className="flex items-center justify-between rounded-lg border px-3 py-2.5 text-sm cursor-pointer hover:bg-muted/50 active:bg-muted transition-colors"
                      onClick={() => setSelectedOrder(order)}
                      data-testid={`row-order-${i}`}
                    >
                      <div className="min-w-0 flex-1">
                        <p className="font-medium">{order.delivery_date || "N/A"}</p>
                        <p className="text-xs text-muted-foreground truncate">
                          SKU {order.product_id} · Stock: {order.current_stock ?? "?"}
                          {order.total_units ? ` · ${order.total_units} units` : ""}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          {order.decision_time ? new Date(order.decision_time).toLocaleString() : ""}
                        </p>
                      </div>
                      <div className="text-right shrink-0 ml-2">
                        <Badge variant={
                          order.otto_write_success ? "default" :
                          order.otto_write_success === false ? "destructive" :
                          "outline"
                        }>
                          {order.mlp_decision != null ? `Order ${order.mlp_decision}` : "logged"}
                        </Badge>
                        <p className="text-xs text-muted-foreground mt-1">
                          {order.otto_write_success ? "written" : order.mlp_method || "logged"}
                        </p>
                        {order.was_overridden && <p className="text-xs text-amber-600">Overridden</p>}
                      </div>
                    </div>
                  ))}
                </div>
              </ScrollArea>
            ) : (
              <p className="text-sm text-muted-foreground py-4 text-center" data-testid="text-no-orders">
                No pipeline decisions yet
              </p>
            )}
          </CardContent>
        </Card>

        <Card data-testid="card-run-history">
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-base">
              <Clock className="h-5 w-5" />
              Run History
            </CardTitle>
            <CardDescription>Tap a run to view its full log output</CardDescription>
          </CardHeader>
          <CardContent>
            {history && history.length > 0 ? (
              <div className="space-y-2">
                {history.map((run, i) => {
                  const info = STATUS_CONFIG[run.status] || STATUS_CONFIG.idle;
                  const duration = run.completedAt && run.startedAt
                    ? Math.round((new Date(run.completedAt).getTime() - new Date(run.startedAt).getTime()) / 1000)
                    : null;

                  return (
                    <div
                      key={run.id}
                      className="flex items-center justify-between rounded-lg border px-3 py-2.5 cursor-pointer hover:bg-muted/50 active:bg-muted transition-colors"
                      onClick={() => {
                        setViewingRunLogs(run.id);
                        setViewingRunTitle(
                          `${run.mode === "live" ? "LIVE" : "Dry Run"} · ${PRODUCTS[run.productId] || run.productId} · ${new Date(run.startedAt).toLocaleString()}`
                        );
                      }}
                      data-testid={`row-run-${i}`}
                    >
                      <div className="flex items-center gap-2 min-w-0 flex-1">
                        <div className={`h-2.5 w-2.5 rounded-full shrink-0 ${info.color}`} />
                        <div className="min-w-0">
                          <p className="text-sm font-medium">
                            {run.mode === "live" ? "LIVE" : "Dry Run"} · {PRODUCTS[run.productId] || run.productId}
                          </p>
                          <p className="text-xs text-muted-foreground">
                            {new Date(run.startedAt).toLocaleString()}
                            {duration ? ` · ${duration}s` : ""}
                          </p>
                          {run.error && (
                            <p className="text-xs text-red-500 truncate">{run.error}</p>
                          )}
                        </div>
                      </div>
                      <div className="flex items-center gap-2 shrink-0 ml-2">
                        <Badge variant={run.status === "completed" ? "default" : run.status === "failed" ? "destructive" : "outline"}>
                          {info.label}
                        </Badge>
                        <FileText className="h-4 w-4 text-muted-foreground" />
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <p className="text-sm text-muted-foreground py-4 text-center" data-testid="text-no-history">
                No runs yet
              </p>
            )}
          </CardContent>
        </Card>

      </main>

      {viewingRunLogs && viewingRunOutput && (
        <LogViewer
          lines={viewingRunOutput.lines}
          title={viewingRunTitle}
          onClose={() => {
            setViewingRunLogs(null);
            setViewingRunTitle("");
          }}
        />
      )}

      {showLiveFullscreen && output?.lines && (
        <LogViewer
          lines={output.lines}
          title="Live Pipeline Output"
          onClose={() => setShowLiveFullscreen(false)}
        />
      )}

      {selectedOrder && (
        <OrderDetailModal
          order={selectedOrder}
          onClose={() => setSelectedOrder(null)}
        />
      )}
    </div>
  );
}
