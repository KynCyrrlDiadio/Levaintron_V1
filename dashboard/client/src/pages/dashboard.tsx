import { useState } from "react";
import { useQuery, useMutation } from "@tanstack/react-query";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Slider } from "@/components/ui/slider";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { useToast } from "@/hooks/use-toast";
import { queryClient, apiRequest } from "@/lib/queryClient";
import { Link } from "wouter";
import { 
  Wheat, 
  Cpu, 
  Database, 
  TrendingUp, 
  Package, 
  MessageSquare, 
  Activity,
  Zap,
  BarChart3,
  Clock,
  CheckCircle2,
  AlertCircle,
  Loader2,
  Send,
  RefreshCw,
  Gamepad2,
  Brain,
} from "lucide-react";
import type { Prediction, Order, TrainingRun } from "@shared/schema";

const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

export default function Dashboard() {
  const { toast } = useToast();
  const [nlQuery, setNlQuery] = useState("");
  const [predictionInput, setPredictionInput] = useState({
    currentInventory: 15,
    dayOfWeek: new Date().getDay(),
    expectedSales: 4.0,
    actualSalesRate: 3.0,
    monthlyMultiplier: 1.0,
    isHoliday: false,
    pipelineIncoming: 0,
    returnsRate: 1.0,
  });

  const { data: stats, isLoading: statsLoading } = useQuery<{
    totalPredictions: number;
    totalOrders: number;
    trainingDataCount: number;
    latestModelVersion: string;
    avgConfidence: number;
  }>({
    queryKey: ["/api/stats"],
  });

  const { data: predictions, isLoading: predictionsLoading } = useQuery<Prediction[]>({
    queryKey: ["/api/predictions"],
  });

  const { data: orders, isLoading: ordersLoading } = useQuery<Order[]>({
    queryKey: ["/api/orders"],
  });

  const { data: trainingRuns, isLoading: trainingLoading } = useQuery<TrainingRun[]>({
    queryKey: ["/api/training-runs"],
  });

  const predictMutation = useMutation({
    mutationFn: async (input: typeof predictionInput) => {
      return apiRequest("POST", "/api/predict", input);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/predictions"] });
      queryClient.invalidateQueries({ queryKey: ["/api/stats"] });
      toast({
        title: "Prediction Complete",
        description: "MLP model has generated a recommendation.",
      });
    },
    onError: (error: Error) => {
      toast({
        title: "Prediction Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });

  const nlMutation = useMutation({
    mutationFn: async (query: string) => {
      return apiRequest("POST", "/api/nl-query", { query });
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ["/api/predictions"] });
      queryClient.invalidateQueries({ queryKey: ["/api/orders"] });
      toast({
        title: "Query Processed",
        description: "Natural language query was processed successfully.",
      });
      setNlQuery("");
    },
    onError: (error: Error) => {
      toast({
        title: "Query Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });

  const generateDataMutation = useMutation({
    mutationFn: async () => {
      return apiRequest("POST", "/api/training-data/generate", { count: 100 });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/stats"] });
      toast({
        title: "Training Data Generated",
        description: "100 new training samples have been created.",
      });
    },
  });

  const trainMutation = useMutation({
    mutationFn: async () => {
      return apiRequest("POST", "/api/train", {});
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/training-runs"] });
      queryClient.invalidateQueries({ queryKey: ["/api/stats"] });
      toast({
        title: "Training Started",
        description: "MLP model training has been initiated.",
      });
    },
  });

  const getDecisionColor = (decision: number) => {
    if (decision === 0) return "bg-stone-400";
    if (decision === 5) return "bg-amber-500";
    if (decision === 10) return "bg-emerald-600";
    if (decision === 18) return "bg-blue-500";
    if (decision === 20) return "bg-emerald-700";
    if (decision === 27) return "bg-indigo-500";
    if (decision === 36) return "bg-violet-600";
    return "bg-emerald-600";
  };

  const getDecisionText = (decision: number) => {
    if (decision === 0) return "Skip Order";
    if (decision === 5) return "Order 5 (½ tray white)";
    if (decision === 10) return "Order 10 (1 tray white)";
    if (decision === 18) return "Order 18 (2 trays rye)";
    if (decision === 20) return "Order 20 (2 trays white)";
    if (decision === 27) return "Order 27 (3 trays rye)";
    if (decision === 36) return "Order 36 (4 trays rye)";
    return `Order ${decision}`;
  };

  return (
    <div className="min-h-screen bg-background">
      <div className="border-b bg-card/50 backdrop-blur-sm sticky top-0 z-10">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <div className="p-2.5 bg-primary/10 rounded-xl">
                <Wheat className="h-7 w-7 text-primary" />
              </div>
              <div>
                <h1 className="text-xl font-bold tracking-tight" data-testid="text-app-title">Levaintron</h1>
                <p className="text-sm text-muted-foreground">AI Bread Intelligence</p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <Link href="/seasonal">
                <Button variant="outline" size="sm" className="gap-1.5" data-testid="button-seasonal">
                  <TrendingUp className="h-3 w-3" />
                  Trends
                </Button>
              </Link>
              <Link href="/control">
                <Button variant="outline" size="sm" className="gap-1.5" data-testid="button-control-panel">
                  <Gamepad2 className="h-3 w-3" />
                  Control
                </Button>
              </Link>
              <Link href="/tracker">
                <Button variant="outline" size="sm" className="gap-1.5" data-testid="button-tracker">
                  <BarChart3 className="h-3 w-3" />
                  Tracker
                </Button>
              </Link>
              <Badge variant="outline" className="gap-1.5 hidden sm:flex">
                <Brain className="h-3 w-3" />
                MLP v9.0
              </Badge>
              <Badge variant="outline" className="gap-1.5 hidden sm:flex">
                <Database className="h-3 w-3" />
                PostgreSQL
              </Badge>
            </div>
          </div>
        </div>
      </div>

      <div className="container mx-auto px-4 py-6">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Predictions</p>
                  <p className="text-2xl font-bold" data-testid="text-total-predictions">
                    {statsLoading ? "-" : stats?.totalPredictions ?? 0}
                  </p>
                </div>
                <div className="p-2 bg-primary/10 rounded-lg">
                  <Wheat className="h-5 w-5 text-primary" />
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Orders Placed</p>
                  <p className="text-2xl font-bold" data-testid="text-total-orders">
                    {statsLoading ? "-" : stats?.totalOrders ?? 0}
                  </p>
                </div>
                <div className="p-2 bg-emerald-600/10 rounded-lg">
                  <Package className="h-5 w-5 text-emerald-600" />
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Training Data</p>
                  <p className="text-2xl font-bold" data-testid="text-training-samples">
                    {statsLoading ? "-" : stats?.trainingDataCount ?? 0}
                  </p>
                </div>
                <div className="p-2 bg-amber-500/10 rounded-lg">
                  <BarChart3 className="h-5 w-5 text-amber-500" />
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Confidence</p>
                  <p className="text-2xl font-bold" data-testid="text-avg-confidence">
                    {statsLoading ? "-" : `${((stats?.avgConfidence ?? 0) * 100).toFixed(1)}%`}
                  </p>
                </div>
                <div className="p-2 bg-primary/10 rounded-lg">
                  <TrendingUp className="h-5 w-5 text-primary" />
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        <div className="grid lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 space-y-6">
            <Card>
              <CardHeader className="pb-3">
                <CardTitle className="flex items-center gap-2 text-lg">
                  <MessageSquare className="h-5 w-5" />
                  Ask Levaintron
                </CardTitle>
                <CardDescription>
                  Ask in plain English about inventory, orders, or predictions
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="flex gap-2">
                  <Input
                    placeholder="e.g., 'What should I order today?' or 'How much bread do we need Thursday?'"
                    value={nlQuery}
                    onChange={(e) => setNlQuery(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && nlQuery && nlMutation.mutate(nlQuery)}
                    data-testid="input-nl-query"
                  />
                  <Button
                    onClick={() => nlQuery && nlMutation.mutate(nlQuery)}
                    disabled={!nlQuery || nlMutation.isPending}
                    data-testid="button-send-query"
                  >
                    {nlMutation.isPending ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      <Send className="h-4 w-4" />
                    )}
                  </Button>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-3">
                <CardTitle className="flex items-center gap-2 text-lg">
                  <Cpu className="h-5 w-5" />
                  MLP Decision Engine
                </CardTitle>
                <CardDescription>
                  Test the neural network — White [0, 5, 10, 20] · Rye [0, 18, 27, 36]
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="grid sm:grid-cols-2 gap-6">
                  <div className="space-y-4">
                    <div>
                      <Label className="text-sm">Current Inventory: {predictionInput.currentInventory} loaves</Label>
                      <Slider
                        value={[predictionInput.currentInventory]}
                        onValueChange={([v]) => setPredictionInput(p => ({ ...p, currentInventory: v }))}
                        max={50}
                        step={1}
                        className="mt-2"
                        data-testid="slider-inventory"
                      />
                    </div>
                    <div>
                      <Label className="text-sm">Day of Week: {DAYS[predictionInput.dayOfWeek]}</Label>
                      <Slider
                        value={[predictionInput.dayOfWeek]}
                        onValueChange={([v]) => setPredictionInput(p => ({ ...p, dayOfWeek: v }))}
                        max={6}
                        step={1}
                        className="mt-2"
                        data-testid="slider-day"
                      />
                    </div>
                    <div>
                      <Label className="text-sm">Expected Sales: {predictionInput.expectedSales.toFixed(1)} loaves/day</Label>
                      <Slider
                        value={[predictionInput.expectedSales * 10]}
                        onValueChange={([v]) => setPredictionInput(p => ({ ...p, expectedSales: v / 10 }))}
                        max={100}
                        step={1}
                        className="mt-2"
                        data-testid="slider-expected-sales"
                      />
                    </div>
                    <div>
                      <Label className="text-sm">Pipeline Incoming: {predictionInput.pipelineIncoming} units</Label>
                      <Slider
                        value={[predictionInput.pipelineIncoming]}
                        onValueChange={([v]) => setPredictionInput(p => ({ ...p, pipelineIncoming: v }))}
                        max={60}
                        step={1}
                        className="mt-2"
                        data-testid="slider-pipeline"
                      />
                    </div>
                  </div>
                  <div className="space-y-4">
                    <div>
                      <Label className="text-sm">Actual Sales Rate: {predictionInput.actualSalesRate.toFixed(1)} loaves/day</Label>
                      <Slider
                        value={[predictionInput.actualSalesRate * 10]}
                        onValueChange={([v]) => setPredictionInput(p => ({ ...p, actualSalesRate: v / 10 }))}
                        max={100}
                        step={1}
                        className="mt-2"
                        data-testid="slider-actual-sales"
                      />
                    </div>
                    <div>
                      <Label className="text-sm">Monthly Multiplier: {predictionInput.monthlyMultiplier.toFixed(2)}x</Label>
                      <Slider
                        value={[predictionInput.monthlyMultiplier * 100]}
                        onValueChange={([v]) => setPredictionInput(p => ({ ...p, monthlyMultiplier: v / 100 }))}
                        max={200}
                        step={1}
                        className="mt-2"
                        data-testid="slider-monthly-mult"
                      />
                    </div>
                    <div>
                      <Label className="text-sm">Returns Rate: {predictionInput.returnsRate.toFixed(1)}%</Label>
                      <Slider
                        value={[predictionInput.returnsRate * 10]}
                        onValueChange={([v]) => setPredictionInput(p => ({ ...p, returnsRate: v / 10 }))}
                        max={200}
                        step={1}
                        className="mt-2"
                        data-testid="slider-returns-rate"
                      />
                    </div>
                    <div className="flex items-center justify-between">
                      <Label className="text-sm">Holiday</Label>
                      <Switch
                        checked={predictionInput.isHoliday}
                        onCheckedChange={(v) => setPredictionInput(p => ({ ...p, isHoliday: v }))}
                        data-testid="switch-holiday"
                      />
                    </div>
                  </div>
                </div>
                <Button
                  onClick={() => predictMutation.mutate(predictionInput)}
                  disabled={predictMutation.isPending}
                  className="w-full"
                  size="lg"
                  data-testid="button-predict"
                >
                  {predictMutation.isPending ? (
                    <>
                      <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                      Processing...
                    </>
                  ) : (
                    <>
                      <Zap className="h-4 w-4 mr-2" />
                      Get MLP Prediction
                    </>
                  )}
                </Button>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-3">
                <CardTitle className="flex items-center gap-2 text-lg">
                  <Activity className="h-5 w-5" />
                  Recent Predictions
                </CardTitle>
              </CardHeader>
              <CardContent>
                {predictionsLoading ? (
                  <div className="flex items-center justify-center py-8">
                    <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                  </div>
                ) : predictions && predictions.length > 0 ? (
                  <ScrollArea className="h-[300px]">
                    <div className="space-y-3">
                      {predictions.map((pred) => (
                        <div
                          key={pred.id}
                          className="flex items-center justify-between p-3 bg-muted/50 rounded-lg"
                          data-testid={`prediction-item-${pred.id}`}
                        >
                          <div className="flex items-center gap-3">
                            <div className={`w-2.5 h-2.5 rounded-full ${getDecisionColor(pred.predictedDecision)}`} />
                            <div>
                              <p className="font-medium">{getDecisionText(pred.predictedDecision)}</p>
                              <p className="text-xs text-muted-foreground">
                                {new Date(pred.createdAt!).toLocaleString()}
                              </p>
                            </div>
                          </div>
                          <div className="text-right">
                            <Badge variant="secondary">
                              {(pred.confidence * 100).toFixed(1)}% confidence
                            </Badge>
                            <p className="text-xs text-muted-foreground mt-1">
                              v{pred.modelVersion}
                            </p>
                          </div>
                        </div>
                      ))}
                    </div>
                  </ScrollArea>
                ) : (
                  <div className="text-center py-8 text-muted-foreground">
                    <Wheat className="h-10 w-10 mx-auto mb-2 opacity-50" />
                    <p>No predictions yet</p>
                    <p className="text-sm">Use the engine above to make your first prediction</p>
                  </div>
                )}
              </CardContent>
            </Card>
          </div>

          <div className="space-y-6">
            <Card>
              <CardHeader className="pb-3">
                <CardTitle className="flex items-center gap-2 text-lg">
                  <BarChart3 className="h-5 w-5" />
                  Model Training
                </CardTitle>
                <CardDescription>
                  Generate data and train the MLP
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-3">
                <Button
                  variant="outline"
                  className="w-full"
                  onClick={() => generateDataMutation.mutate()}
                  disabled={generateDataMutation.isPending}
                  data-testid="button-generate-data"
                >
                  {generateDataMutation.isPending ? (
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  ) : (
                    <RefreshCw className="h-4 w-4 mr-2" />
                  )}
                  Generate Training Data
                </Button>
                <Button
                  className="w-full"
                  onClick={() => trainMutation.mutate()}
                  disabled={trainMutation.isPending || (stats?.trainingDataCount ?? 0) < 50}
                  data-testid="button-train-model"
                >
                  {trainMutation.isPending ? (
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  ) : (
                    <Brain className="h-4 w-4 mr-2" />
                  )}
                  Train MLP Model
                </Button>
                {(stats?.trainingDataCount ?? 0) < 50 && (
                  <p className="text-xs text-muted-foreground text-center">
                    Need at least 50 samples to train (currently {stats?.trainingDataCount ?? 0})
                  </p>
                )}
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-3">
                <CardTitle className="flex items-center gap-2 text-lg">
                  <Clock className="h-5 w-5" />
                  Training History
                </CardTitle>
              </CardHeader>
              <CardContent>
                {trainingLoading ? (
                  <div className="flex items-center justify-center py-6">
                    <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" />
                  </div>
                ) : trainingRuns && trainingRuns.length > 0 ? (
                  <ScrollArea className="h-[200px]">
                    <div className="space-y-2">
                      {trainingRuns.map((run) => (
                        <div
                          key={run.id}
                          className="p-3 bg-muted/50 rounded-lg text-sm"
                          data-testid={`training-run-${run.id}`}
                        >
                          <div className="flex items-center justify-between mb-1">
                            <span className="font-medium">v{run.modelVersion}</span>
                            <Badge
                              variant={run.status === "completed" ? "default" : "secondary"}
                              className="text-xs"
                            >
                              {run.status === "completed" ? (
                                <CheckCircle2 className="h-3 w-3 mr-1" />
                              ) : run.status === "failed" ? (
                                <AlertCircle className="h-3 w-3 mr-1" />
                              ) : (
                                <Loader2 className="h-3 w-3 mr-1 animate-spin" />
                              )}
                              {run.status}
                            </Badge>
                          </div>
                          <div className="text-xs text-muted-foreground space-y-0.5">
                            {run.accuracy && <p>Accuracy: {(run.accuracy * 100).toFixed(1)}%</p>}
                            {run.loss && <p>Loss: {run.loss.toFixed(4)}</p>}
                            <p>{new Date(run.startedAt!).toLocaleString()}</p>
                          </div>
                        </div>
                      ))}
                    </div>
                  </ScrollArea>
                ) : (
                  <div className="text-center py-6 text-muted-foreground">
                    <p className="text-sm">No training runs yet</p>
                  </div>
                )}
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-3">
                <CardTitle className="flex items-center gap-2 text-lg">
                  <Package className="h-5 w-5" />
                  Recent Orders
                </CardTitle>
              </CardHeader>
              <CardContent>
                {ordersLoading ? (
                  <div className="flex items-center justify-center py-6">
                    <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" />
                  </div>
                ) : orders && orders.length > 0 ? (
                  <ScrollArea className="h-[200px]">
                    <div className="space-y-2">
                      {orders.map((order) => (
                        <div
                          key={order.id}
                          className="flex items-center justify-between p-3 bg-muted/50 rounded-lg text-sm"
                          data-testid={`order-item-${order.id}`}
                        >
                          <div>
                            <p className="font-medium">{order.quantity} loaves</p>
                            <p className="text-xs text-muted-foreground">
                              {new Date(order.orderDate!).toLocaleDateString()}
                            </p>
                          </div>
                          <Badge
                            variant={order.status === "completed" ? "default" : "secondary"}
                            className="text-xs"
                          >
                            {order.status}
                          </Badge>
                        </div>
                      ))}
                    </div>
                  </ScrollArea>
                ) : (
                  <div className="text-center py-6 text-muted-foreground">
                    <Package className="h-8 w-8 mx-auto mb-2 opacity-50" />
                    <p className="text-sm">No orders yet</p>
                  </div>
                )}
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  );
}
