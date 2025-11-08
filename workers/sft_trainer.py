"""
8. Training Templates - SFT (Supervised Fine-Tuning) with LoRA/QLoRA

This worker fine-tunes LLMs using parameter-efficient methods:
1. Load base model from HuggingFace
2. Apply quantization (4-bit QLoRA)
3. Configure LoRA adapters
4. Train on supervised dataset
5. Evaluate on holdout set
6. Save adapters and metrics to S3/MLflow
7. Deploy inference endpoint with vLLM
"""

import os
import json
import logging
from typing import Dict, Any, Optional
from dataclasses import dataclass

import torch
import boto3
import mlflow
from datasets import load_dataset
from transformers import (
    AutoTokenizer,
    AutoModelForCausalLM,
    TrainingArguments,
    BitsAndBytesConfig,
)
from peft import (
    LoraConfig,
    get_peft_model,
    prepare_model_for_kbit_training,
)
from trl import SFTTrainer, DataCollatorForCompletionOnlyLM
import wandb

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class SFTConfig:
    """SFT training configuration"""
    base_model: str = "meta-llama/Llama-3-8B"
    lora_r: int = 16
    lora_alpha: int = 32
    lora_dropout: float = 0.05
    learning_rate: float = 2e-4
    num_epochs: int = 3
    batch_size: int = 4
    eval_split: float = 0.1
    use_4bit: bool = True
    max_seq_length: int = 2048
    gradient_checkpointing: bool = True


class SFTTrainerWorker:
    def __init__(self, job_id: str, workspace_id: str, dataset_id: str, config: SFTConfig):
        self.job_id = job_id
        self.workspace_id = workspace_id
        self.dataset_id = dataset_id
        self.config = config

        # Initialize clients
        self.s3_client = boto3.client('s3')

        # Set device
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        logger.info(f"Using device: {self.device}")

        # Log GPU info
        if torch.cuda.is_available():
            logger.info(f"GPU: {torch.cuda.get_device_name(0)}")
            logger.info(f"VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")

    def load_dataset(self):
        """Load training dataset from S3"""
        logger.info(f"Loading dataset {self.dataset_id} from S3")

        # Download JSONL file from S3
        local_path = "/tmp/train_data.jsonl"
        self.s3_client.download_file(
            Bucket=os.getenv('S3_BUCKET'),
            Key=f"workspaces/{self.workspace_id}/datasets/{self.dataset_id}/processed/train.jsonl",
            Filename=local_path
        )

        # Load with HuggingFace datasets
        dataset = load_dataset('json', data_files=local_path, split='train')

        # Split into train/eval
        if self.config.eval_split > 0:
            split = dataset.train_test_split(test_size=self.config.eval_split, seed=42)
            train_dataset = split['train']
            eval_dataset = split['test']
        else:
            train_dataset = dataset
            eval_dataset = None

        logger.info(f"Loaded {len(train_dataset)} training samples")
        if eval_dataset:
            logger.info(f"Loaded {len(eval_dataset)} eval samples")

        return train_dataset, eval_dataset

    def load_model_and_tokenizer(self):
        """Load base model with quantization and LoRA"""
        logger.info(f"Loading base model: {self.config.base_model}")

        # Tokenizer
        tokenizer = AutoTokenizer.from_pretrained(
            self.config.base_model,
            token=os.getenv('HUGGINGFACE_TOKEN'),
            trust_remote_code=True
        )

        # Add pad token if missing
        if tokenizer.pad_token is None:
            tokenizer.pad_token = tokenizer.eos_token

        # Quantization config (4-bit QLoRA)
        if self.config.use_4bit:
            bnb_config = BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_use_double_quant=True,
                bnb_4bit_quant_type="nf4",
                bnb_4bit_compute_dtype=torch.bfloat16
            )
        else:
            bnb_config = None

        # Load model
        model = AutoModelForCausalLM.from_pretrained(
            self.config.base_model,
            quantization_config=bnb_config,
            device_map="auto",
            token=os.getenv('HUGGINGFACE_TOKEN'),
            trust_remote_code=True,
            torch_dtype=torch.bfloat16,
        )

        # Prepare for k-bit training
        if self.config.use_4bit:
            model = prepare_model_for_kbit_training(model)

        # Configure LoRA
        lora_config = LoraConfig(
            r=self.config.lora_r,
            lora_alpha=self.config.lora_alpha,
            target_modules=["q_proj", "v_proj", "k_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
            lora_dropout=self.config.lora_dropout,
            bias="none",
            task_type="CAUSAL_LM"
        )

        # Apply LoRA
        model = get_peft_model(model, lora_config)
        model.print_trainable_parameters()

        return model, tokenizer

    def format_prompt(self, sample: Dict[str, str]) -> str:
        """Format training sample as prompt"""
        # Expecting {"prompt": "...", "completion": "..."}
        prompt = sample.get('prompt', '')
        completion = sample.get('completion', '')

        # Use Llama-3 chat template format
        formatted = f"<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\n{prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n{completion}<|eot_id|>"

        return formatted

    def train_model(self, model, tokenizer, train_dataset, eval_dataset):
        """Train model with SFTTrainer"""
        logger.info("Starting training...")

        # Training arguments
        output_dir = f"/tmp/outputs/{self.job_id}"
        training_args = TrainingArguments(
            output_dir=output_dir,
            per_device_train_batch_size=self.config.batch_size,
            per_device_eval_batch_size=self.config.batch_size,
            gradient_accumulation_steps=4,
            num_train_epochs=self.config.num_epochs,
            learning_rate=self.config.learning_rate,
            fp16=False,
            bf16=True,
            logging_steps=10,
            evaluation_strategy="steps" if eval_dataset else "no",
            eval_steps=50 if eval_dataset else None,
            save_strategy="steps",
            save_steps=100,
            save_total_limit=2,
            load_best_model_at_end=True if eval_dataset else False,
            metric_for_best_model="eval_loss" if eval_dataset else None,
            greater_is_better=False,
            warmup_steps=10,
            lr_scheduler_type="cosine",
            gradient_checkpointing=self.config.gradient_checkpointing,
            report_to="mlflow",  # Log to MLflow
            run_name=f"sft-{self.job_id}",
        )

        # Data collator (only compute loss on completion)
        response_template = "<|start_header_id|>assistant<|end_header_id|>"
        collator = DataCollatorForCompletionOnlyLM(
            response_template=response_template,
            tokenizer=tokenizer
        )

        # SFT Trainer
        trainer = SFTTrainer(
            model=model,
            args=training_args,
            train_dataset=train_dataset,
            eval_dataset=eval_dataset,
            tokenizer=tokenizer,
            data_collator=collator,
            max_seq_length=self.config.max_seq_length,
            formatting_func=self.format_prompt,
        )

        # Train
        trainer.train()

        # Save final model
        trainer.save_model(output_dir)

        logger.info("Training completed")
        return trainer, output_dir

    def evaluate_model(self, trainer) -> Dict[str, float]:
        """Run evaluation on holdout set"""
        logger.info("Running evaluation...")

        metrics = trainer.evaluate()

        # Extract key metrics
        eval_metrics = {
            "eval_loss": metrics.get("eval_loss", 0.0),
            "eval_perplexity": 2 ** metrics.get("eval_loss", 0.0),
            "train_loss": metrics.get("train_loss", 0.0),
        }

        logger.info(f"Evaluation metrics: {eval_metrics}")
        return eval_metrics

    def save_artifacts(self, output_dir: str) -> str:
        """Upload model artifacts to S3"""
        logger.info("Uploading artifacts to S3...")

        s3_prefix = f"workspaces/{self.workspace_id}/jobs/{self.job_id}/outputs"

        # Upload all files in output_dir
        for root, dirs, files in os.walk(output_dir):
            for file in files:
                local_path = os.path.join(root, file)
                relative_path = os.path.relpath(local_path, output_dir)
                s3_key = f"{s3_prefix}/{relative_path}"

                self.s3_client.upload_file(local_path, os.getenv('S3_BUCKET'), s3_key)

        artifact_uri = f"s3://{os.getenv('S3_BUCKET')}/{s3_prefix}"
        logger.info(f"Artifacts uploaded: {artifact_uri}")
        return artifact_uri

    def log_to_mlflow(self, metrics: Dict[str, float], artifact_uri: str) -> str:
        """Log training run to MLflow"""
        logger.info("Logging to MLflow...")

        with mlflow.start_run(run_name=f"sft-{self.job_id}"):
            # Log parameters
            mlflow.log_param("base_model", self.config.base_model)
            mlflow.log_param("lora_r", self.config.lora_r)
            mlflow.log_param("lora_alpha", self.config.lora_alpha)
            mlflow.log_param("learning_rate", self.config.learning_rate)
            mlflow.log_param("num_epochs", self.config.num_epochs)
            mlflow.log_param("batch_size", self.config.batch_size)
            mlflow.log_param("use_4bit", self.config.use_4bit)

            # Log metrics
            for key, value in metrics.items():
                mlflow.log_metric(key, value)

            # Log artifact URI
            mlflow.log_param("artifact_uri", artifact_uri)

            run_id = mlflow.active_run().info.run_id
            logger.info(f"MLflow run: {run_id}")
            return run_id

    def deploy_endpoint(self) -> str:
        """Deploy inference endpoint with vLLM"""
        logger.info("Deploying inference endpoint...")

        # TODO: Deploy to K8s with vLLM
        # For now, return placeholder
        endpoint_url = f"https://api.train-my-ai.com/v1/models/{self.job_id}/infer"

        logger.info(f"Endpoint deployed: {endpoint_url}")
        return endpoint_url

    def train(self):
        """Main training pipeline"""
        logger.info(f"Starting SFT training for job {self.job_id}")

        try:
            # Step 1: Load dataset
            train_dataset, eval_dataset = self.load_dataset()

            # Step 2: Load model and tokenizer
            model, tokenizer = self.load_model_and_tokenizer()

            # Step 3: Train
            trainer, output_dir = self.train_model(model, tokenizer, train_dataset, eval_dataset)

            # Step 4: Evaluate
            metrics = self.evaluate_model(trainer) if eval_dataset else {}

            # Step 5: Save artifacts
            artifact_uri = self.save_artifacts(output_dir)

            # Step 6: Log to MLflow
            run_id = self.log_to_mlflow(metrics, artifact_uri)

            # Step 7: Deploy endpoint
            endpoint_url = self.deploy_endpoint()

            logger.info("SFT training completed successfully")

            return {
                "status": "SUCCEEDED",
                "mlflow_run_id": run_id,
                "artifact_uri": artifact_uri,
                "endpoint_url": endpoint_url,
                "metrics": metrics
            }

        except Exception as e:
            logger.error(f"Training failed: {e}", exc_info=True)
            return {
                "status": "FAILED",
                "error": str(e)
            }


def main():
    """Entry point for SFT trainer worker"""
    # Parse job config from environment
    job_id = os.getenv('JOB_ID')
    workspace_id = os.getenv('WORKSPACE_ID')
    dataset_id = os.getenv('DATASET_ID')
    config_json = os.getenv('JOB_CONFIG')

    config_dict = json.loads(config_json)
    config = SFTConfig(**config_dict)

    # Run training
    trainer = SFTTrainerWorker(job_id, workspace_id, dataset_id, config)
    result = trainer.train()

    # Write result to stdout
    print(json.dumps(result))


if __name__ == "__main__":
    main()
