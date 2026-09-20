import { spawn, type ChildProcess } from "child_process";
import path from "path";
import fs from "fs";
import { EventEmitter } from "events";
import os from "os";

export interface PipelineRun {
  id: string;
  status: "idle" | "running" | "completed" | "failed" | "aborted";
  mode: "dry_run" | "live";
  productId: string;
  startedAt: Date | null;
  completedAt: Date | null;
  output: string[];
  error: string | null;
  exitCode: number | null;
}

class PipelineManager extends EventEmitter {
  private currentRun: PipelineRun | null = null;
  private process: ChildProcess | null = null;
  private runHistory: PipelineRun[] = [];
  private maxHistory = 50;

  getStatus(): PipelineRun | { status: "idle" } {
    if (this.currentRun && this.currentRun.status === "running") {
      return this.currentRun;
    }
    return { status: "idle" };
  }

  getHistory(limit = 20): PipelineRun[] {
    return this.runHistory.slice(0, limit);
  }

  isRunning(): boolean {
    return this.currentRun?.status === "running";
  }

  trigger(options: {
    mode: "dry_run" | "live";
    productId?: string;
    pythonPath?: string;
    pipelinePath?: string;
  }): PipelineRun {
    if (this.isRunning()) {
      throw new Error("Pipeline is already running");
    }

    const run: PipelineRun = {
      id: `run_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      status: "running",
      mode: options.mode,
      productId: options.productId || "500107",
      startedAt: new Date(),
      completedAt: null,
      output: [],
      error: null,
      exitCode: null,
    };

    this.currentRun = run;

    const pipelinePath = options.pipelinePath || process.env.PIPELINE_PATH ||
      path.resolve(process.cwd(), "..");
    const venvPython = path.resolve(pipelinePath, "levaintron", "bin", "python");
    const pythonPath = options.pythonPath || process.env.PYTHON_PATH ||
      (fs.existsSync(venvPython) ? venvPython : "python3");

    const args = [
      "-m", "tests.run_pipeline_autonomous",
      "--product", run.productId,
      "--mode", run.mode,
    ];

    try {
      this.process = spawn(pythonPath, args, {
        cwd: pipelinePath,
        env: {
          ...process.env,
          PIPELINE_MODE: run.mode,
          PIPELINE_PRODUCT: run.productId,
          PYTHONUNBUFFERED: "1",
        },
        stdio: ["pipe", "pipe", "pipe"],
      });

      this.process.stdout?.on("data", (data: Buffer) => {
        const lines = data.toString().split("\n").filter(Boolean);
        run.output.push(...lines);
        this.emit("output", { runId: run.id, lines });
      });

      this.process.stderr?.on("data", (data: Buffer) => {
        const lines = data.toString().split("\n").filter(Boolean);
        run.output.push(...lines.map((l: string) => `[stderr] ${l}`));
      });

      this.process.on("close", (code: number | null) => {
        if (run.status === "aborted") {
          return;
        }
        run.exitCode = code;
        run.completedAt = new Date();
        run.status = code === 0 ? "completed" : "failed";
        if (code !== 0 && !run.error) {
          run.error = `Process exited with code ${code}`;
        }
        this.process = null;
        this.currentRun = null;
        this.runHistory.unshift({ ...run });
        if (this.runHistory.length > this.maxHistory) {
          this.runHistory = this.runHistory.slice(0, this.maxHistory);
        }
        this.emit("complete", run);
      });

      this.process.on("error", (err: Error) => {
        run.status = "failed";
        run.error = err.message;
        run.completedAt = new Date();
        this.process = null;
        this.runHistory.unshift({ ...run });
        this.emit("error", { runId: run.id, error: err.message });
      });

    } catch (err: any) {
      run.status = "failed";
      run.error = err.message;
      run.completedAt = new Date();
      this.runHistory.unshift({ ...run });
    }

    return run;
  }

  abort(): boolean {
    if (!this.process || !this.currentRun || this.currentRun.status !== "running") {
      return false;
    }

    const proc = this.process;
    const run = this.currentRun;

    run.status = "aborted";
    run.error = "Aborted by user";
    run.completedAt = new Date();
    this.runHistory.unshift({ ...run });
    this.currentRun = null;
    this.process = null;

    try {
      proc.kill("SIGTERM");
      setTimeout(() => {
        try { proc.kill("SIGKILL"); } catch {}
      }, 5000);
    } catch {}

    return true;
  }

  getOutput(runId?: string, tail = 100): string[] {
    if (runId) {
      const run = this.runHistory.find(r => r.id === runId) ||
        (this.currentRun?.id === runId ? this.currentRun : null);
      return run ? run.output.slice(-tail) : [];
    }
    return this.currentRun?.output.slice(-tail) || [];
  }
}

export function getSystemHealth(): Record<string, any> {
  const uptime = os.uptime();
  const totalMem = os.totalmem();
  const freeMem = os.freemem();
  const loadAvg = os.loadavg();
  const cpus = os.cpus();

  return {
    uptime_seconds: uptime,
    uptime_human: formatUptime(uptime),
    memory: {
      total_gb: (totalMem / 1073741824).toFixed(1),
      free_gb: (freeMem / 1073741824).toFixed(1),
      used_percent: (((totalMem - freeMem) / totalMem) * 100).toFixed(1),
    },
    cpu: {
      cores: cpus.length,
      model: cpus[0]?.model || "unknown",
      load_avg_1m: loadAvg[0].toFixed(2),
      load_avg_5m: loadAvg[1].toFixed(2),
      load_avg_15m: loadAvg[2].toFixed(2),
    },
    hostname: os.hostname(),
    platform: `${os.type()} ${os.release()}`,
    node_version: process.version,
    timestamp: new Date().toISOString(),
  };
}

function formatUptime(seconds: number): string {
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const parts = [];
  if (d > 0) parts.push(`${d}d`);
  if (h > 0) parts.push(`${h}h`);
  parts.push(`${m}m`);
  return parts.join(" ");
}

export const pipelineManager = new PipelineManager();
