"""
MLP Decision Engine for Bread Ordering

A lightweight PyTorch neural network (~3K params) that makes
ordering decisions [0, 5, 10] based on inventory features.

Usage:
    from mlp_engine import MLPInference, BreadMLP
    
    # Load trained model
    engine = MLPInference("models/bread_mlp.pt")
    
    # Make prediction
    result = engine.predict(
        current_inventory=15,
        day_of_week=1,
        hour_of_day=9,
        recent_sales_rate=2.5,
        weather_score=0.8,
        is_holiday=False
    )
    print(f"Order {result.decision} loaves ({result.confidence:.0%})")
"""

from .mlp_model import BreadMLP, decision_to_class, class_to_decision, DECISION_CLASSES
from .inference import MLPInference, PredictionInput, PredictionResult
from .training import train_model, evaluate_model
from .data_generator import (
    generate_training_data, 
    get_correct_decision, 
    TrainingSample,
    samples_to_tensors,
    get_class_distribution
)

__all__ = [
    # Model
    "BreadMLP",
    "DECISION_CLASSES",
    "decision_to_class",
    "class_to_decision",
    
    # Inference
    "MLPInference",
    "PredictionInput", 
    "PredictionResult",
    
    # Training
    "train_model",
    "evaluate_model",
    
    # Data
    "generate_training_data",
    "get_correct_decision",
    "TrainingSample",
    "samples_to_tensors",
    "get_class_distribution",
]

__version__ = "1.0.0"
