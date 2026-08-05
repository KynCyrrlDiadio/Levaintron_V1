"""
MLP Inference Engine v8.5

Fast predictions for real-time ordering decisions.
Supports v4 (6 inputs), v8.1 (7 inputs), and v8.5 (8 inputs) models.
Auto-detects input_size from checkpoint.

For use in the Levaintron demo project.
"""
import torch
import numpy as np
from pathlib import Path
from typing import Dict, Optional
from dataclasses import dataclass

from .mlp_model import BreadMLP, class_to_decision


@dataclass
class PredictionInput:
    """Input features for v4/legacy prediction (6 features)."""
    current_inventory: int
    day_of_week: int
    hour_of_day: int
    recent_sales_rate: float
    weather_score: float
    is_holiday: bool


@dataclass
class PredictionInputV85:
    """Input features for v8.5 prediction (8 features)."""
    current_inventory: int
    day_of_week: int
    expected_sales: float
    actual_sales_rate: float
    monthly_multiplier: float
    is_holiday: bool
    pipeline_incoming: int
    returns_rate: float


@dataclass
class PredictionResult:
    """Prediction result from the MLP."""
    decision: int
    confidence: float
    model_version: str
    all_probs: Dict[int, float]


class MLPInference:
    """
    MLP inference engine for real-time predictions.
    Auto-detects model version (v4=6 inputs, v8.5=8 inputs) from checkpoint.
    """

    def __init__(self, model_path: str, device: str = "auto"):
        if device == "auto":
            device = "cuda:1" if torch.cuda.is_available() else "cpu"
        self.device = torch.device(device)

        self.model_path = Path(model_path)
        self.model: Optional[BreadMLP] = None
        self.model_version: str = "unknown"
        self.input_size: int = 6
        self.training_config: Dict = {}

        self._load_model()

    def _load_model(self):
        if not self.model_path.exists():
            print(f"Warning: Model not found at {self.model_path}")
            self.model = BreadMLP(input_size=8).to(self.device)
            self.model_version = "untrained"
            self.input_size = 8
            return

        checkpoint = torch.load(self.model_path, map_location=self.device, weights_only=False)

        if isinstance(checkpoint, dict):
            self.input_size = checkpoint.get('input_size', 6)

        self.model = BreadMLP(input_size=self.input_size).to(self.device)
        self.model.load_state_dict(checkpoint["model_state_dict"])
        self.model.eval()

        self.training_config = checkpoint.get("training_config", {})
        trained_at = checkpoint.get("trained_at", "unknown")
        self.model_version = f"v{trained_at[:10]}" if trained_at != "unknown" else "v1.0"

        print(f"Model loaded from {self.model_path}")
        print(f"Model version: {self.model_version}, input_size: {self.input_size}")
        print(f"Parameters: {self.model.count_parameters():,}")

    def _normalize_input_v4(self, inp: PredictionInput) -> torch.Tensor:
        features = np.array([
            inp.current_inventory / 50.0,
            inp.day_of_week / 6.0,
            inp.hour_of_day / 23.0,
            inp.recent_sales_rate / 6.0,
            inp.weather_score,
            float(inp.is_holiday)
        ], dtype=np.float32)
        return torch.from_numpy(features).unsqueeze(0).to(self.device)

    def _normalize_input_v85(self, inp: PredictionInputV85) -> torch.Tensor:
        features = np.array([
            min(inp.current_inventory / 50.0, 2.0),
            inp.day_of_week / 7.0,
            min(inp.expected_sales / 10.0, 2.0),
            min(inp.actual_sales_rate / 10.0, 2.0),
            inp.monthly_multiplier,
            float(inp.is_holiday),
            min(inp.pipeline_incoming / 60.0, 2.0),
            min(inp.returns_rate / 20.0, 2.0),
        ], dtype=np.float32)
        return torch.from_numpy(features).unsqueeze(0).to(self.device)

    def predict(self, current_inventory: int, day_of_week: int,
                hour_of_day: int = 0, recent_sales_rate: float = 3.0,
                weather_score: float = 0.7, is_holiday: bool = False
                ) -> PredictionResult:
        """Legacy v4 predict interface (6 features)."""
        inp = PredictionInput(
            current_inventory=current_inventory,
            day_of_week=day_of_week,
            hour_of_day=hour_of_day,
            recent_sales_rate=recent_sales_rate,
            weather_score=weather_score,
            is_holiday=is_holiday
        )
        features = self._normalize_input_v4(inp)
        return self._run_inference(features)

    def predict_v85(self, current_inventory: int, day_of_week: int,
                    expected_sales: float, actual_sales_rate: float,
                    monthly_multiplier: float, is_holiday: bool = False,
                    pipeline_incoming: int = 0, returns_rate: float = 0.0
                    ) -> PredictionResult:
        """v8.5 predict interface (8 features)."""
        inp = PredictionInputV85(
            current_inventory=current_inventory,
            day_of_week=day_of_week,
            expected_sales=expected_sales,
            actual_sales_rate=actual_sales_rate,
            monthly_multiplier=monthly_multiplier,
            is_holiday=is_holiday,
            pipeline_incoming=pipeline_incoming,
            returns_rate=returns_rate
        )
        features = self._normalize_input_v85(inp)
        return self._run_inference(features)

    def predict_raw(self, features: list) -> PredictionResult:
        """Predict from pre-normalized feature vector."""
        x = torch.tensor([features], dtype=torch.float32).to(self.device)
        return self._run_inference(x)

    def _run_inference(self, features: torch.Tensor) -> PredictionResult:
        self.model.eval()
        with torch.no_grad():
            logits = self.model(features)
            probs = torch.softmax(logits, dim=-1).squeeze().cpu().numpy()
            class_idx = int(probs.argmax())
            confidence = float(probs[class_idx])

        decision = class_to_decision(class_idx)
        all_probs = {
            0: float(probs[0]),
            5: float(probs[1]),
            10: float(probs[2]),
            20: float(probs[3]) if len(probs) > 3 else 0.0
        }

        return PredictionResult(
            decision=decision,
            confidence=confidence,
            model_version=self.model_version,
            all_probs=all_probs
        )

    def predict_batch(self, inputs: list) -> list:
        """Make predictions for multiple raw feature vectors."""
        if not inputs:
            return []

        features = torch.tensor(inputs, dtype=torch.float32).to(self.device)

        self.model.eval()
        with torch.no_grad():
            logits = self.model(features)
            probs = torch.softmax(logits, dim=-1).cpu().numpy()

        results = []
        for i in range(len(inputs)):
            class_idx = int(probs[i].argmax())
            confidence = float(probs[i][class_idx])
            decision = class_to_decision(class_idx)

            results.append(PredictionResult(
                decision=decision,
                confidence=confidence,
                model_version=self.model_version,
                all_probs={
                    0: float(probs[i][0]),
                    5: float(probs[i][1]),
                    10: float(probs[i][2]),
                    20: float(probs[i][3]) if probs.shape[1] > 3 else 0.0
                }
            ))

        return results
