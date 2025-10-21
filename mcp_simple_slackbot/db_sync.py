"""Database synchronization script for Google Cloud Storage."""

import logging
import os
import subprocess
import sys
from pathlib import Path

logger = logging.getLogger(__name__)


def sync_database_from_gcs(bucket_name: str, db_path: str) -> bool:
    """Download database from GCS if it exists.
    
    Args:
        bucket_name: GCS bucket name
        db_path: Local path for the database
        
    Returns:
        True if database was synced or doesn't exist in GCS, False on error
    """
    if not bucket_name:
        logger.info("No GCS bucket configured, using local database only")
        return True
        
    gcs_path = f"gs://{bucket_name}/test.db"
    
    try:
        # Check if database exists in GCS
        result = subprocess.run(
            ["gsutil", "ls", gcs_path],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            # Database exists in GCS, download it
            logger.info(f"Downloading database from {gcs_path} to {db_path}")
            result = subprocess.run(
                ["gsutil", "cp", gcs_path, db_path],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                logger.info("Database downloaded successfully from GCS")
                return True
            else:
                logger.error(f"Failed to download database: {result.stderr}")
                return False
        else:
            logger.info("No existing database in GCS, will create new one")
            return True
            
    except subprocess.TimeoutExpired:
        logger.error("Timeout while syncing database from GCS")
        return False
    except Exception as e:
        logger.error(f"Error syncing database from GCS: {e}")
        return False


def sync_database_to_gcs(bucket_name: str, db_path: str) -> bool:
    """Upload database to GCS.
    
    Args:
        bucket_name: GCS bucket name
        db_path: Local path of the database
        
    Returns:
        True if database was synced successfully, False otherwise
    """
    if not bucket_name:
        logger.info("No GCS bucket configured, skipping database upload")
        return True
        
    if not os.path.exists(db_path):
        logger.warning(f"Database file {db_path} does not exist, skipping upload")
        return True
        
    gcs_path = f"gs://{bucket_name}/test.db"
    
    try:
        logger.info(f"Uploading database from {db_path} to {gcs_path}")
        result = subprocess.run(
            ["gsutil", "cp", db_path, gcs_path],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            logger.info("Database uploaded successfully to GCS")
            return True
        else:
            logger.error(f"Failed to upload database: {result.stderr}")
            return False
            
    except subprocess.TimeoutExpired:
        logger.error("Timeout while syncing database to GCS")
        return False
    except Exception as e:
        logger.error(f"Error syncing database to GCS: {e}")
        return False


def ensure_database_dir(db_path: str) -> bool:
    """Ensure the database directory exists.
    
    Args:
        db_path: Path to the database file
        
    Returns:
        True if directory exists or was created, False on error
    """
    try:
        db_dir = os.path.dirname(db_path)
        if db_dir:
            Path(db_dir).mkdir(parents=True, exist_ok=True)
        return True
    except Exception as e:
        logger.error(f"Error creating database directory: {e}")
        return False
