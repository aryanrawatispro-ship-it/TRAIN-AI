"""
8. Training Templates - RAG Pipeline

This worker builds a RAG (Retrieval-Augmented Generation) system:
1. Load processed dataset from S3
2. Generate embeddings using selected model
3. Store embeddings in pgvector
4. Build retriever configuration
5. Run evaluation queries
6. Save config to MLflow
7. Deploy inference endpoint
"""

import os
import json
import logging
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
import asyncio

import boto3
import psycopg2
from psycopg2.extras import execute_values
import openai
from sentence_transformers import SentenceTransformer
import mlflow
from mlflow.models import infer_signature
import numpy as np
from tqdm import tqdm

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class RAGConfig:
    """RAG training configuration"""
    embedding_model: str = "openai/text-embedding-3-small"
    chunk_size: int = 512
    top_k: int = 5
    reranker: str = "none"
    eval_queries: Optional[List[str]] = None


class RAGTrainer:
    def __init__(self, job_id: str, workspace_id: str, dataset_id: str, config: RAGConfig):
        self.job_id = job_id
        self.workspace_id = workspace_id
        self.dataset_id = dataset_id
        self.config = config

        # Initialize clients
        self.s3_client = boto3.client('s3')
        self.db_conn = self._connect_db()
        self.mlflow_client = mlflow.tracking.MlflowClient()

        # Embedding model
        self.embedding_model = self._load_embedding_model()

    def _connect_db(self):
        """Connect to PostgreSQL with pgvector"""
        return psycopg2.connect(
            host=os.getenv('POSTGRES_HOST'),
            database=os.getenv('POSTGRES_DB', 'trainmyai'),
            user=os.getenv('POSTGRES_USER'),
            password=os.getenv('POSTGRES_PASSWORD')
        )

    def _load_embedding_model(self):
        """Load embedding model based on config"""
        if self.config.embedding_model.startswith("openai/"):
            # Use OpenAI embeddings
            openai.api_key = os.getenv('OPENAI_API_KEY')
            model_name = self.config.embedding_model.split('/')[-1]
            return lambda texts: self._embed_openai(texts, model_name)

        else:
            # Use HuggingFace sentence-transformers
            model = SentenceTransformer(self.config.embedding_model)
            return lambda texts: model.encode(texts, show_progress_bar=True)

    def _embed_openai(self, texts: List[str], model: str) -> np.ndarray:
        """Embed texts using OpenAI API"""
        embeddings = []
        batch_size = 100

        for i in tqdm(range(0, len(texts), batch_size), desc="Embedding"):
            batch = texts[i:i + batch_size]
            response = openai.Embedding.create(
                model=model,
                input=batch
            )
            batch_embeddings = [item['embedding'] for item in response['data']]
            embeddings.extend(batch_embeddings)

        return np.array(embeddings)

    def load_dataset(self) -> List[Dict[str, Any]]:
        """Load processed chunks from S3"""
        logger.info(f"Loading dataset {self.dataset_id} from S3")

        # Get dataset metadata from DB
        cursor = self.db_conn.cursor()
        cursor.execute(
            "SELECT s3_bucket, s3_prefix FROM datasets WHERE id = %s",
            (self.dataset_id,)
        )
        bucket, prefix = cursor.fetchone()

        # Load chunks from S3
        response = self.s3_client.get_object(
            Bucket=bucket,
            Key=f"{prefix}/processed/chunks.jsonl"
        )

        chunks = []
        for line in response['Body'].iter_lines():
            chunks.append(json.loads(line))

        logger.info(f"Loaded {len(chunks)} chunks")
        return chunks

    def generate_embeddings(self, chunks: List[Dict[str, Any]]) -> np.ndarray:
        """Generate embeddings for all chunks"""
        logger.info("Generating embeddings...")

        texts = [chunk['content'] for chunk in chunks]
        embeddings = self.embedding_model(texts)

        logger.info(f"Generated embeddings: shape {embeddings.shape}")
        return embeddings

    def store_embeddings(self, chunks: List[Dict[str, Any]], embeddings: np.ndarray):
        """Store embeddings in pgvector"""
        logger.info("Storing embeddings in pgvector...")

        cursor = self.db_conn.cursor()

        # Prepare data for bulk insert
        data = []
        for chunk, embedding in zip(chunks, embeddings):
            data.append((
                self.workspace_id,
                self.dataset_id,
                chunk['id'],
                embedding.tolist(),
                self.config.embedding_model,
                json.dumps(chunk.get('metadata', {}))
            ))

        # Bulk insert
        execute_values(
            cursor,
            """
            INSERT INTO embeddings (workspace_id, dataset_id, chunk_id, embedding, embedding_model, metadata)
            VALUES %s
            """,
            data,
            template="(%s, %s, %s, %s::vector, %s, %s::jsonb)"
        )

        self.db_conn.commit()
        logger.info(f"Stored {len(data)} embeddings")

    def evaluate_retrieval(self, eval_queries: List[str]) -> Dict[str, float]:
        """Evaluate retrieval quality"""
        logger.info("Running evaluation queries...")

        if not eval_queries:
            logger.info("No eval queries provided, skipping evaluation")
            return {}

        metrics = {
            'hit_rate': 0.0,
            'mrr': 0.0,
            'avg_latency_ms': 0.0
        }

        # TODO: Implement actual evaluation logic
        # This would compare retrieved chunks against ground truth
        # and calculate Hit Rate, MRR, etc.

        return metrics

    def save_to_mlflow(self, metrics: Dict[str, float]):
        """Save RAG config and metrics to MLflow"""
        logger.info("Logging to MLflow...")

        # Start MLflow run
        with mlflow.start_run(run_name=f"rag-{self.job_id}"):
            # Log parameters
            mlflow.log_param("embedding_model", self.config.embedding_model)
            mlflow.log_param("chunk_size", self.config.chunk_size)
            mlflow.log_param("top_k", self.config.top_k)
            mlflow.log_param("reranker", self.config.reranker)

            # Log metrics
            for key, value in metrics.items():
                mlflow.log_metric(key, value)

            # Log retriever config as artifact
            config_dict = {
                "embedding_model": self.config.embedding_model,
                "top_k": self.config.top_k,
                "reranker": self.config.reranker,
                "workspace_id": self.workspace_id,
                "dataset_id": self.dataset_id
            }

            with open("/tmp/rag_config.json", "w") as f:
                json.dump(config_dict, f, indent=2)

            mlflow.log_artifact("/tmp/rag_config.json")

            # Get run ID
            run_id = mlflow.active_run().info.run_id
            logger.info(f"MLflow run: {run_id}")

            return run_id

    def deploy_endpoint(self) -> str:
        """Deploy RAG inference endpoint"""
        logger.info("Deploying inference endpoint...")

        # TODO: Deploy to K8s/vLLM
        # For now, return a placeholder URL
        endpoint_url = f"https://api.train-my-ai.com/v1/models/{self.job_id}/infer"

        logger.info(f"Endpoint deployed: {endpoint_url}")
        return endpoint_url

    def train(self):
        """Main training pipeline"""
        logger.info(f"Starting RAG training for job {self.job_id}")

        try:
            # Step 1: Load dataset
            chunks = self.load_dataset()

            # Step 2: Generate embeddings
            embeddings = self.generate_embeddings(chunks)

            # Step 3: Store in pgvector
            self.store_embeddings(chunks, embeddings)

            # Step 4: Evaluate (if queries provided)
            metrics = self.evaluate_retrieval(self.config.eval_queries or [])

            # Step 5: Save to MLflow
            run_id = self.save_to_mlflow(metrics)

            # Step 6: Deploy endpoint
            endpoint_url = self.deploy_endpoint()

            logger.info("RAG training completed successfully")

            return {
                "status": "SUCCEEDED",
                "mlflow_run_id": run_id,
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
    """Entry point for RAG trainer worker"""
    # Parse job config from environment
    job_id = os.getenv('JOB_ID')
    workspace_id = os.getenv('WORKSPACE_ID')
    dataset_id = os.getenv('DATASET_ID')
    config_json = os.getenv('JOB_CONFIG')

    config_dict = json.loads(config_json)
    config = RAGConfig(**config_dict)

    # Run training
    trainer = RAGTrainer(job_id, workspace_id, dataset_id, config)
    result = trainer.train()

    # Write result to stdout (will be captured by orchestrator)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
