from fastapi import FastAPI, File, UploadFile, BackgroundTasks, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import shutil
import os
import subprocess
import uuid
import time

app = FastAPI(title="Lipsync API", description="API for lip-syncing images with audio")

UPLOAD_DIR = "uploads"
RESULT_DIR = "results"
STATIC_DIR = "static"

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(RESULT_DIR, exist_ok=True)
os.makedirs(STATIC_DIR, exist_ok=True)

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
templates = Jinja2Templates(directory="templates")

# Dictionary to store job statuses
job_statuses = {}

def process_lipsync(image_path: str, audio_path: str, output_path: str, job_id: str):
    try:
        job_statuses[job_id] = "Processing"
        command = f"python inference.py --checkpoint_path wav2lip_gan.pth --face {image_path} --audio {audio_path} --outfile {output_path}"
        subprocess.run(command, shell=True, check=True)
        job_statuses[job_id] = "Completed"

        # Remove uploaded files after processing (if applicable)
        if os.path.exists(image_path):
            os.remove(image_path)
        if os.path.exists(audio_path) and "webcam_audio" not in audio_path: 
            os.remove(audio_path)

    except Exception as e:
        job_statuses[job_id] = f"Failed: {str(e)}"

@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.post("/lipsync/")
async def create_lipsync(background_tasks: BackgroundTasks, 
                        image: UploadFile = File(None), 
                        audio: UploadFile = File(None),
                        webcam_audio: str = None): 
    if not image and not webcam_audio:
        raise HTTPException(status_code=400, detail="Either image or webcam audio is required")

    job_id = str(uuid.uuid4())
    image_path = None
    audio_path = None

    if image:
        image_filename = f"{job_id}_image{os.path.splitext(image.filename)[1]}"
        image_path = os.path.join(UPLOAD_DIR, image_filename)
        with open(image_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)

    if audio:
        audio_filename = f"{job_id}_audio{os.path.splitext(audio.filename)[1]}"
        audio_path = os.path.join(UPLOAD_DIR, audio_filename)
        with open(audio_path, "wb") as buffer:
            shutil.copyfileobj(audio.file, buffer)
    elif webcam_audio:
        audio_path = f"webcam_audio_{job_id}.wav"  # Gi? s? b?n ?ã l?u audio t? webcam vào ???ng d?n này

    output_filename = f"{job_id}_output.mp4"
    output_path = os.path.join(RESULT_DIR, output_filename)

    job_statuses[job_id] = "Queued"
    background_tasks.add_task(process_lipsync, image_path, audio_path, output_path, job_id)

    return {"message": "Lipsync process started", "job_id": job_id}



@app.get("/status/{job_id}")
async def get_status(job_id: str):
    status = job_statuses.get(job_id, "Not found")
    return {"status": status}

@app.get("/result/{job_id}")
async def get_result(job_id: str):
    if job_statuses.get(job_id) != "Completed":
        return {"error": "Result not ready yet"}
    
    result_path = os.path.join(RESULT_DIR, f"{job_id}_output.mp4")
    if os.path.exists(result_path):
        return FileResponse(result_path)
    return {"error": "Result file not found"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)