"""
MLP Training Pipeline

GPU-accelerated training for RTX 5060 Ti.
For use in the Levaintron demo project.
"""
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
from typing import Tuple, Dict
import time
from datetime import datetime
from pathlib import Path

from .mlp_model import BreadMLP, class_to_decision
from .data_generator import generate_training_data, samples_to_tensors, get_class_distribution


def train_model(
        num_samples: int = 10000,
        epochs: int = 500,
        batch_size: int = 32,
        learning_rate: float = 0.001,
        val_split: float = 0.2,
        device: str = "auto",
        model_save_path: str = None,
        verbose: bool = True,
        target_accuracy: float = 0.95,
        early_stop_patience: int = 150
) -> Tuple[BreadMLP, Dict]:
    """
    Train the BreadMLP model.

    Args:
        num_samples: Number of training samples to generate
        epochs: Number of training epochs
        batch_size: Batch size for training
        learning_rate: Learning rate for optimizer
        val_split: Fraction of data for validation
        device: "cuda", "cpu", or "auto"
        model_save_path: Path to save trained model
        verbose: Print training progress

    Returns:
        model: Trained BreadMLP model
        history: Training history dict
    """
    if device == "auto":
        device = "cuda" if torch.cuda.is_available() else "cpu"
    device = torch.device(device)

    if verbose:
        print(f"Training on device: {device}")
        if device.type == "cuda":
            print(f"GPU: {torch.cuda.get_device_name(0)}")

    if verbose:
        print(f"\nGenerating {num_samples} training samples...")
    samples = generate_training_data(num_samples)

    if verbose:
        print(f"Class distribution: {get_class_distribution(samples)}")

    X, y = samples_to_tensors(samples)

    split_idx = int(len(X) * (1 - val_split))
    X_train, X_val = X[:split_idx], X[split_idx:]
    y_train, y_val = y[:split_idx], y[split_idx:]

    X_train_t = torch.from_numpy(X_train).to(device)
    y_train_t = torch.from_numpy(y_train).to(device)
    X_val_t = torch.from_numpy(X_val).to(device)
    y_val_t = torch.from_numpy(y_val).to(device)

    train_dataset = TensorDataset(X_train_t, y_train_t)
    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)

    model = BreadMLP().to(device)

    if verbose:
        print(f"\nModel parameters: {model.count_parameters():,}")

    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=learning_rate)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', patience=10, factor=0.5)

    history = {"train_loss": [], "val_loss": [], "train_acc": [], "val_acc": []}
    best_val_loss = float('inf')
    best_val_acc = 0.0
    best_model_state = None
    patience_counter = 0

    start_time = time.time()

    if verbose:
        print(f"\nTarget accuracy: {target_accuracy:.1%}")
        print(f"Early stop patience: {early_stop_patience} epochs without improvement")
        print("-" * 60)

    for epoch in range(epochs):
        model.train()
        train_loss = 0.0
        train_correct = 0
        train_total = 0

        for batch_X, batch_y in train_loader:
            optimizer.zero_grad()
            outputs = model(batch_X)
            loss = criterion(outputs, batch_y)
            loss.backward()
            optimizer.step()

            train_loss += loss.item() * batch_X.size(0)
            _, predicted = outputs.max(1)
            train_total += batch_y.size(0)
            train_correct += predicted.eq(batch_y).sum().item()

        train_loss /= train_total
        train_acc = train_correct / train_total

        model.eval()
        with torch.no_grad():
            val_outputs = model(X_val_t)
            val_loss = criterion(val_outputs, y_val_t).item()
            _, val_predicted = val_outputs.max(1)
            val_acc = val_predicted.eq(y_val_t).sum().item() / len(y_val_t)

        history["train_loss"].append(train_loss)
        history["val_loss"].append(val_loss)
        history["train_acc"].append(train_acc)
        history["val_acc"].append(val_acc)

        scheduler.step(val_loss)

        # Track best model by validation accuracy (not just loss)
        improved = False
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            best_val_loss = val_loss
            best_model_state = model.state_dict().copy()
            patience_counter = 0
            improved = True
        else:
            patience_counter += 1

        if verbose and (epoch + 1) % 10 == 0:
            status = "NEW BEST!" if improved else ""
            print(f"Epoch {epoch + 1:3d}/{epochs} | "
                  f"Train Loss: {train_loss:.4f} | Train Acc: {train_acc:.4f} | "
                  f"Val Loss: {val_loss:.4f} | Val Acc: {val_acc:.4f} {status}")

        # Early stopping: reached target accuracy
        if val_acc >= target_accuracy:
            if verbose:
                print(f"\n*** TARGET ACCURACY {target_accuracy:.1%} REACHED at epoch {epoch + 1}! ***")
            break

        # Early stopping: no improvement for too long
        if patience_counter >= early_stop_patience:
            if verbose:
                print(f"\n*** Early stopping: No improvement for {early_stop_patience} epochs ***")
            break

    if best_model_state:
        model.load_state_dict(best_model_state)

    elapsed = time.time() - start_time

    if verbose:
        print(f"\nTraining completed in {elapsed:.2f}s")
        print(f"Epochs completed: {len(history['val_acc'])}/{epochs}")
        print(f"Best validation loss: {best_val_loss:.4f}")
        print(f"Best validation accuracy: {best_val_acc:.4f} ({best_val_acc * 100:.1f}%)")

    if model_save_path:
        save_path = Path(model_save_path)
        save_path.parent.mkdir(parents=True, exist_ok=True)
        torch.save({
            "model_state_dict": model.state_dict(),
            "training_config": {
                "num_samples": num_samples,
                "epochs": epochs,
                "batch_size": batch_size,
                "learning_rate": learning_rate,
            },
            "history": history,
            "best_val_loss": best_val_loss,
            "trained_at": datetime.now().isoformat(),
        }, save_path)
        if verbose:
            print(f"Model saved to: {save_path}")

    return model, history


def evaluate_model(model: BreadMLP, num_samples: int = 200, device: str = "auto") -> Dict:
    """Evaluate the model on fresh test data."""
    if device == "auto":
        device = "cuda" if torch.cuda.is_available() else "cpu"
    device = torch.device(device)

    model = model.to(device)
    model.eval()

    samples = generate_training_data(num_samples)
    X, y = samples_to_tensors(samples)

    X_t = torch.from_numpy(X).to(device)
    y_t = torch.from_numpy(y).to(device)

    with torch.no_grad():
        predictions, confidences = model.predict(X_t)
        accuracy = (predictions == y_t).float().mean().item()
        avg_confidence = confidences.mean().item()

    class_accs = {}
    for cls in range(4):
        mask = y_t == cls
        if mask.sum() > 0:
            class_acc = (predictions[mask] == y_t[mask]).float().mean().item()
            class_accs[class_to_decision(cls)] = class_acc

    return {
        "accuracy": accuracy,
        "avg_confidence": avg_confidence,
        "class_accuracy": class_accs,
        "num_samples": num_samples
    }
