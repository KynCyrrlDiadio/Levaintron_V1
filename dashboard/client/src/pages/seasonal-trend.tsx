import { useQuery } from "@tanstack/react-query";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
  Area,
  AreaChart,
  Legend,
} from "recharts";

const MONTH_NAMES = [
  "", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

interface MonthlyAvg {
  month: number;
  avg_daily: string;
  multiplier: string;
  confidence: string;
}

interface DailyForecast {
  forecast_date: string;
  expected_sales: string;
  monthly_multiplier: string;
  day_of_week: string;
  confidence: string;
}

interface SeasonalData {
  pattern: Array<{
    month: number;
    day_of_week: string;
    expected_daily: string;
    monthly_multiplier: string;
    confidence: string;
  }>;
  monthlyAvg: MonthlyAvg[];
  dailyForecast: DailyForecast[];
}

function getConfidenceColor(confidence: string) {
  switch (confidence) {
    case "measured": return "hsl(142, 76%, 36%)";
    case "estimated": return "hsl(45, 93%, 47%)";
    case "interpolated": return "hsl(0, 84%, 60%)";
    default: return "hsl(215, 20%, 65%)";
  }
}

function getConfidenceBadgeVariant(confidence: string): "default" | "secondary" | "destructive" | "outline" {
  switch (confidence) {
    case "measured": return "default";
    case "estimated": return "secondary";
    case "interpolated": return "destructive";
    default: return "outline";
  }
}

export default function SeasonalTrend() {
  const { data, isLoading, error } = useQuery<SeasonalData>({
    queryKey: ["/api/seasonal-trend"],
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen" data-testid="loading-seasonal">
        <div className="text-muted-foreground">Loading seasonal data...</div>
      </div>
    );
  }

  if (error || !data) {
    return (
      <div className="flex items-center justify-center min-h-screen" data-testid="error-seasonal">
        <div className="text-destructive">Failed to load seasonal data</div>
      </div>
    );
  }

  const monthlyData = data.monthlyAvg.map((m) => ({
    month: MONTH_NAMES[m.month],
    monthNum: m.month,
    avgDaily: parseFloat(m.avg_daily),
    multiplier: parseFloat(m.multiplier),
    confidence: m.confidence,
  }));

  const overallAvg = monthlyData.reduce((sum, m) => sum + m.avgDaily, 0) / monthlyData.length;

  const weeklyRolling: Array<{
    date: string;
    sales: number;
    rolling7: number | null;
    confidence: string;
  }> = [];

  if (data.dailyForecast.length > 0) {
    const dailyValues = data.dailyForecast.map((d) => ({
      date: new Date(d.forecast_date).toLocaleDateString("en-US", { month: "short", day: "numeric" }),
      sales: parseFloat(d.expected_sales),
      confidence: d.confidence,
    }));

    for (let i = 0; i < dailyValues.length; i++) {
      let rolling7: number | null = null;
      if (i >= 6) {
        const window = dailyValues.slice(i - 6, i + 1);
        rolling7 = parseFloat((window.reduce((s, v) => s + v.sales, 0) / 7).toFixed(2));
      }
      weeklyRolling.push({
        date: dailyValues[i].date,
        sales: dailyValues[i].sales,
        rolling7,
        confidence: dailyValues[i].confidence,
      });
    }
  }

  const sampledDaily = weeklyRolling.filter((_, i) => i % 7 === 0);

  const peakMonth = monthlyData.reduce((max, m) => m.avgDaily > max.avgDaily ? m : max, monthlyData[0]);
  const lowMonth = monthlyData.reduce((min, m) => m.avgDaily < min.avgDaily ? m : min, monthlyData[0]);

  return (
    <div className="min-h-screen bg-background p-4 md:p-6 space-y-6" data-testid="page-seasonal-trend">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold" data-testid="text-page-title">Seasonal Sales Trend</h1>
          <p className="text-muted-foreground text-sm">
            Levaintron · Demo 500g Rye Bread (SKU 500107) - Store 70012004
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Badge variant="default" data-testid="badge-measured">Measured (real data)</Badge>
          <Badge variant="secondary" data-testid="badge-estimated">Estimated</Badge>
          <Badge variant="destructive" data-testid="badge-interpolated">Interpolated</Badge>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card data-testid="card-avg-daily">
          <CardHeader className="flex flex-row items-center justify-between gap-2 space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Yearly Avg</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold" data-testid="text-avg-daily">{overallAvg.toFixed(1)}</div>
            <p className="text-xs text-muted-foreground">loaves/day</p>
          </CardContent>
        </Card>
        <Card data-testid="card-peak">
          <CardHeader className="flex flex-row items-center justify-between gap-2 space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Peak Month</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold" data-testid="text-peak">{peakMonth.month} ({peakMonth.avgDaily})</div>
            <p className="text-xs text-muted-foreground">{peakMonth.multiplier}x multiplier</p>
          </CardContent>
        </Card>
        <Card data-testid="card-low">
          <CardHeader className="flex flex-row items-center justify-between gap-2 space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Slowest Month</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold" data-testid="text-low">{lowMonth.month} ({lowMonth.avgDaily})</div>
            <p className="text-xs text-muted-foreground">{lowMonth.multiplier}x multiplier</p>
          </CardContent>
        </Card>
      </div>

      <Card data-testid="card-monthly-trend">
        <CardHeader>
          <CardTitle>Monthly Average Sales</CardTitle>
          <p className="text-sm text-muted-foreground">
            Average loaves sold per day by month - two peaks visible (Jul + Oct)
          </p>
        </CardHeader>
        <CardContent>
          <div className="h-[350px]">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={monthlyData} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="salesGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="hsl(30, 72%, 38%)" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="hsl(30, 72%, 38%)" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(32, 15%, 78%)" opacity={0.4} />
                <XAxis
                  dataKey="month"
                  tick={{ fontSize: 12 }}
                  stroke="hsl(25, 15%, 55%)"
                />
                <YAxis
                  domain={[3, 8]}
                  tick={{ fontSize: 12 }}
                  stroke="hsl(25, 15%, 55%)"
                  label={{ value: "Loaves/Day", angle: -90, position: "insideLeft", style: { fontSize: 12 } }}
                />
                <Tooltip
                  contentStyle={{
                    backgroundColor: "hsl(var(--card))",
                    border: "1px solid hsl(var(--border))",
                    borderRadius: "8px",
                    fontSize: "12px",
                  }}
                  formatter={(value: number, name: string) => {
                    if (name === "avgDaily") return [`${value} loaves/day`, "Avg Daily Sales"];
                    if (name === "multiplier") return [`${value}x`, "Seasonal Multiplier"];
                    return [value, name];
                  }}
                  labelFormatter={(label) => `Month: ${label}`}
                />
                <ReferenceLine
                  y={overallAvg}
                  stroke="hsl(43, 90%, 42%)"
                  strokeDasharray="5 5"
                  label={{ value: `Avg: ${overallAvg.toFixed(1)}`, position: "right", fontSize: 11, fill: "hsl(43, 90%, 42%)" }}
                />
                <ReferenceLine
                  y={6}
                  stroke="hsl(0, 72%, 50%)"
                  strokeDasharray="3 3"
                  label={{ value: "Peak threshold (6/day)", position: "right", fontSize: 10, fill: "hsl(0, 72%, 50%)" }}
                />
                <Area
                  type="monotone"
                  dataKey="avgDaily"
                  stroke="hsl(30, 72%, 38%)"
                  strokeWidth={3}
                  fill="url(#salesGradient)"
                  dot={(props: any) => {
                    const { cx, cy, payload } = props;
                    const color = getConfidenceColor(payload.confidence);
                    return (
                      <circle
                        key={`dot-${payload.monthNum}`}
                        cx={cx}
                        cy={cy}
                        r={6}
                        fill={color}
                        stroke="white"
                        strokeWidth={2}
                      />
                    );
                  }}
                  activeDot={{ r: 8 }}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </CardContent>
      </Card>

      <Card data-testid="card-multiplier-trend">
        <CardHeader>
          <CardTitle>Seasonal Multiplier</CardTitle>
          <p className="text-sm text-muted-foreground">
            How demand varies from the baseline (1.0 = average). Above 1.0 = busier, below = slower.
          </p>
        </CardHeader>
        <CardContent>
          <div className="h-[280px]">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={monthlyData} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(32, 15%, 78%)" opacity={0.4} />
                <XAxis
                  dataKey="month"
                  tick={{ fontSize: 12 }}
                  stroke="hsl(25, 15%, 55%)"
                />
                <YAxis
                  domain={[0.6, 1.4]}
                  tick={{ fontSize: 12 }}
                  stroke="hsl(25, 15%, 55%)"
                  label={{ value: "Multiplier", angle: -90, position: "insideLeft", style: { fontSize: 12 } }}
                />
                <Tooltip
                  contentStyle={{
                    backgroundColor: "hsl(var(--card))",
                    border: "1px solid hsl(var(--border))",
                    borderRadius: "8px",
                    fontSize: "12px",
                  }}
                  formatter={(value: number) => [`${value}x`, "Multiplier"]}
                />
                <ReferenceLine y={1.0} stroke="hsl(25, 15%, 55%)" strokeDasharray="5 5" />
                <Line
                  type="monotone"
                  dataKey="multiplier"
                  stroke="hsl(142, 76%, 36%)"
                  strokeWidth={2}
                  dot={(props: any) => {
                    const { cx, cy, payload } = props;
                    const color = getConfidenceColor(payload.confidence);
                    return (
                      <circle
                        key={`mult-dot-${payload.monthNum}`}
                        cx={cx}
                        cy={cy}
                        r={5}
                        fill={color}
                        stroke="white"
                        strokeWidth={2}
                      />
                    );
                  }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </CardContent>
      </Card>

      {sampledDaily.length > 0 && (
        <Card data-testid="card-daily-trend">
          <CardHeader>
            <CardTitle>Daily Forecast (2025) - 7-Day Rolling Average</CardTitle>
            <p className="text-sm text-muted-foreground">
              Shows the daily expected sales with a smoothed weekly trend line
            </p>
          </CardHeader>
          <CardContent>
            <div className="h-[350px]">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={sampledDaily} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(32, 15%, 78%)" opacity={0.4} />
                  <XAxis
                    dataKey="date"
                    tick={{ fontSize: 10 }}
                    stroke="hsl(25, 15%, 55%)"
                    interval={3}
                  />
                  <YAxis
                    domain={[3, 9]}
                    tick={{ fontSize: 12 }}
                    stroke="hsl(25, 15%, 55%)"
                    label={{ value: "Loaves/Day", angle: -90, position: "insideLeft", style: { fontSize: 12 } }}
                  />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "hsl(var(--card))",
                      border: "1px solid hsl(var(--border))",
                      borderRadius: "8px",
                      fontSize: "12px",
                    }}
                    formatter={(value: any, name: string) => {
                      if (value === null) return ["N/A", name];
                      if (name === "rolling7") return [`${value} loaves/day`, "7-Day Avg"];
                      return [`${value} loaves/day`, "Daily Expected"];
                    }}
                  />
                  <Legend />
                  <Line
                    type="monotone"
                    dataKey="sales"
                    stroke="hsl(30, 72%, 38%)"
                    strokeWidth={1}
                    dot={false}
                    opacity={0.4}
                    name="Daily Expected"
                  />
                  <Line
                    type="monotone"
                    dataKey="rolling7"
                    stroke="hsl(25, 85%, 28%)"
                    strokeWidth={2.5}
                    dot={false}
                    name="7-Day Avg"
                    connectNulls={false}
                  />
                  <ReferenceLine
                    y={6}
                    stroke="hsl(43, 90%, 42%)"
                    strokeDasharray="5 5"
                    label={{ value: "Peak demand (6/day)", position: "right", fontSize: 10, fill: "hsl(43, 90%, 42%)" }}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>
      )}

      <Card data-testid="card-data-table">
        <CardHeader>
          <CardTitle>Monthly Breakdown</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b">
                  <th className="text-left py-2 px-3 font-medium text-muted-foreground">Month</th>
                  <th className="text-right py-2 px-3 font-medium text-muted-foreground">Avg/Day</th>
                  <th className="text-right py-2 px-3 font-medium text-muted-foreground">Multiplier</th>
                  <th className="text-center py-2 px-3 font-medium text-muted-foreground">Source</th>
                  <th className="text-left py-2 px-3 font-medium text-muted-foreground">Demand</th>
                </tr>
              </thead>
              <tbody>
                {monthlyData.map((m) => (
                  <tr key={m.monthNum} className="border-b last:border-0" data-testid={`row-month-${m.monthNum}`}>
                    <td className="py-2 px-3 font-medium">{m.month}</td>
                    <td className="py-2 px-3 text-right">{m.avgDaily}</td>
                    <td className="py-2 px-3 text-right">{m.multiplier}x</td>
                    <td className="py-2 px-3 text-center">
                      <Badge variant={getConfidenceBadgeVariant(m.confidence)} className="text-xs">
                        {m.confidence}
                      </Badge>
                    </td>
                    <td className="py-2 px-3">
                      <div className="flex items-center gap-2">
                        <div
                          className="h-2 rounded-full"
                          style={{
                            width: `${(m.avgDaily / 8) * 100}%`,
                            backgroundColor: m.avgDaily >= 6 ? "hsl(0, 72%, 50%)" : m.avgDaily >= 5 ? "hsl(43, 90%, 42%)" : "hsl(30, 72%, 38%)",
                            minWidth: "8px",
                          }}
                        />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
