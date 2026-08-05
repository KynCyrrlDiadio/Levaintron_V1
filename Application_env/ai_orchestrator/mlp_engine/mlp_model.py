"""
Bread MLP Model - Variable input features, 4 output classes [0, 5, 10, 20]

v4 features (6 inputs): [inventory/50, dow/6, hour/23, sales_rate/6, weather/1, is_holiday]
v8.0 features (6 inputs): [inventory/50, dow/6, expected_sales/10, actual_sales/10, monthly_mult, is_holiday]
v8.1 features (7 inputs): adds pipeline_incoming/60 to v8.0
v8.5 features (8 inputs): adds returns_rate/20 to v8.1, dow normalized /7

Same architecture for all - pass input_size to constructor.
For use in the Levaintron demo project.
"""
import torch
import torch.nn as nn
import torch.nn.functional as F


class BreadMLP(nn.Module):
    """
    Multi-Layer Perceptron for bread ordering decisions.

    Architecture:
    - Input: 6 features (normalized)
    - Hidden 1: 128 neurons + ReLU + Dropout
    - Hidden 2: 64 neurons + ReLU + Dropout
    - Hidden 3: 32 neurons + ReLU
    - Output: 4 classes (softmax)

    Total parameters: ~12,452
    """

    def __init__(self, input_size: int = 6, hidden_sizes: list = None, num_classes: int = 4, dropout: float = 0.2):
        super(BreadMLP, self).__init__()

        if hidden_sizes is None:
            hidden_sizes = [128, 64, 32]

        layers = []
        prev_size = input_size

        for i, hidden_size in enumerate(hidden_sizes):
            layers.append(nn.Linear(prev_size, hidden_size))
            layers.append(nn.ReLU())
            if i < len(hidden_sizes) - 1:
                layers.append(nn.Dropout(dropout))
            prev_size = hidden_size

        self.hidden = nn.Sequential(*layers)
        self.output = nn.Linear(prev_size, num_classes)

        self._init_weights()

    def _init_weights(self):
        for m in self.modules():
            if isinstance(m, nn.Linear):
                nn.init.kaiming_normal_(m.weight, mode='fan_in', nonlinearity='relu')
                if m.bias is not None:
                    nn.init.zeros_(m.bias)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.hidden(x)
        x = self.output(x)
        return x

    def predict(self, x: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        """Make prediction with confidence scores."""
        self.eval()
        with torch.no_grad():
            logits = self.forward(x)
            probs = F.softmax(logits, dim=-1)
            confidences, predictions = torch.max(probs, dim=-1)
        return predictions, confidences

    def count_parameters(self) -> int:
        return sum(p.numel() for p in self.parameters() if p.requires_grad)


# Class label mapping
DECISION_CLASSES = [0, 5, 10, 20]


def decision_to_class(decision: int) -> int:
    """Convert decision (0, 5, 10, 20) to class index (0, 1, 2, 3)."""
    return DECISION_CLASSES.index(decision)


def class_to_decision(class_idx: int) -> int:
    """Convert class index (0, 1, 2, 3) to decision (0, 5, 10, 20)."""
    return DECISION_CLASSES[class_idx]


if __name__ == "__main__":
    model = BreadMLP()
    print(f"Model architecture:\n{model}")
    print(f"\nTotal parameters: {model.count_parameters():,}")

    sample_input = torch.randn(4, 6)
    output = model(sample_input)
    print(f"\nInput shape: {sample_input.shape}")
    print(f"Output shape: {output.shape}")

    predictions, confidences = model.predict(sample_input)
    print(f"\nPredictions: {predictions}")
    print(f"Confidences: {confidences}")
