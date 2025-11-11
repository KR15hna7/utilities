from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import subprocess
import os
import json
from typing import Dict, List
from azure.storage.blob import BlobClient
from azure.core.exceptions import AzureError
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

app = FastAPI(title="Path Display API", version="1.0.0")


@app.get("/health")
async def health_check() -> Dict[str, str]:
    """
    Health check endpoint that returns the status of the application.
    """
    return {
        "status": "healthy",
        "message": "API is running successfully"
    }


@app.get("/favicon.ico")
async def favicon():
    """
    Handles favicon requests to prevent 404 errors in browser logs.
    """
    return JSONResponse(content={}, status_code=204)


@app.get("/upload-data")
async def upload_data() -> JSONResponse:
    """
    Uploads the system-specific JSON file to Azure Blob Storage.
    Requires AZURE_STORAGE_CONNECTION_STRING and AZURE_STORAGE_CONTAINER environment variables.
    """
    try:
        # Get Azure Storage configuration from environment variables
        connection_string = os.environ.get('AZURE_STORAGE_CONNECTION_STRING')
        container_name = os.environ.get('AZURE_STORAGE_CONTAINER')
        
        if not connection_string:
            raise HTTPException(
                status_code=500,
                detail="AZURE_STORAGE_CONNECTION_STRING environment variable not set"
            )
        
        if not container_name:
            raise HTTPException(
                status_code=500,
                detail="AZURE_STORAGE_CONTAINER environment variable not set"
            )
        
        # Get the directory where the script is located
        script_dir = os.path.dirname(os.path.abspath(__file__))
        
        # Build the JSON filename using system name
        system_name = os.environ.get('COMPUTERNAME', 'unknown')
        json_filename = f"{system_name}_data.json"
        json_file_path = os.path.join(script_dir, json_filename)
        
        # Check if the JSON file exists
        if not os.path.exists(json_file_path):
            raise HTTPException(
                status_code=404,
                detail=f"JSON file not found at: {json_file_path}. Please call /show-path first to generate the file."
            )
        
        # Create blob client for the upload
        blob_client = BlobClient.from_connection_string(
            conn_str=connection_string,
            container_name=container_name,
            blob_name=json_filename
        )
        
        # Upload the JSON file to Azure Blob Storage
        with open(json_file_path, 'rb') as data:
            blob_client.upload_blob(data, overwrite=True)
        
        return JSONResponse(
            content={
                "status": "success",
                "message": f"Successfully uploaded {json_filename} to Azure Blob Storage",
                "blob_name": json_filename,
                "blob_url": blob_client.url,
                "container": container_name
            },
            status_code=200
        )
    
    except AzureError as azure_error:
        raise HTTPException(
            status_code=500,
            detail=f"Azure Storage error: {str(azure_error)}"
        )
    except FileNotFoundError:
        raise HTTPException(
            status_code=404,
            detail=f"JSON file {json_filename} not found. Please call /show-path first to generate the file."
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error uploading to Azure Storage: {str(e)}"
        )


@app.get("/show-path")
async def show_path() -> JSONResponse:
    """
    Executes the show-path.bat file and returns the PATH environment variable values.
    """
    try:
        # Get the directory where the script is located
        script_dir = os.path.dirname(os.path.abspath(__file__))
        # Use the non-interactive version for API calls
        bat_file_path = os.path.join(script_dir, "show-path-nointeractive.bat")
        
        # Check if the .bat file exists
        if not os.path.exists(bat_file_path):
            raise HTTPException(
                status_code=404,
                detail=f"Batch file not found at: {bat_file_path}"
            )
        
        # Execute the batch file and capture output
        result = subprocess.run(
            ["cmd.exe", "/c", bat_file_path],
            capture_output=True,
            text=True,
            timeout=10,
            cwd=script_dir
        )
        
        # Parse the PATH entries from environment variable directly
        # This is more reliable than parsing the colored output
        path_entries = [
            entry.strip() 
            for entry in os.environ.get("PATH", "").split(";") 
            if entry.strip()
        ]
        
        # Prepare the response content
        response_content = {
            "status": "success",
            "message": "PATH environment variable retrieved successfully",
            "total_entries": len(path_entries),
            "path_entries": path_entries,
            "raw_output": result.stdout if result.stdout else None
        }
        
        # Save the response to JSON file using system name
        system_name = os.environ.get('COMPUTERNAME', 'unknown')
        data_file_name = f"{system_name}_data.json"
        data_file_path = os.path.join(script_dir, data_file_name)
        try:
            with open(data_file_path, 'w', encoding='utf-8') as f:
                json.dump(response_content, f, indent=2, ensure_ascii=False)
        except Exception as file_error:
            # Log the error but don't fail the API call
            print(f"Warning: Could not save to {data_file_name}: {str(file_error)}")
        
        return JSONResponse(
            content=response_content,
            status_code=200
        )
    
    except subprocess.TimeoutExpired:
        raise HTTPException(
            status_code=500,
            detail="Batch file execution timed out"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error executing batch file: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
