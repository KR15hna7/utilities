from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import subprocess
import os
from typing import Dict, List

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
        
        return JSONResponse(
            content={
                "status": "success",
                "message": "PATH environment variable retrieved successfully",
                "total_entries": len(path_entries),
                "path_entries": path_entries,
                "raw_output": result.stdout if result.stdout else None
            },
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
