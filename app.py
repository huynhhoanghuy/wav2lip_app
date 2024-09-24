from fastapi import FastAPI, File, UploadFile, BackgroundTasks, HTTPException, Request, WebSocket, Form
from fastapi.responses import FileResponse, JSONResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import shutil
import os
import subprocess
import uuid
import time
import asyncio
import base64

app = FastAPI(title="Lipsync API", description="API for lip-syncing images with audio")
global_websocket = None

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

async def process_lipsync(image_path: str, audio_path: str, output_path: str, job_id: str, input_mode: str, websocket: WebSocket = None):
    global global_websocket
    try:
        job_statuses[job_id] = "Processing"
        command = f"python inference.py --checkpoint_path wav2lip_gan.pth --face {image_path} --audio {audio_path} --outfile {output_path} --input_mode {input_mode}"
        
        process = await asyncio.create_subprocess_shell(
            command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )

        while True:
            line = await process.stdout.readline()
            if not line:
                break
            if b"frame_ready" in line:
                with open("temp/generated_frame.jpg", "rb") as image_file:
                    encoded_string = base64.b64encode(image_file.read()).decode()
                if global_websocket:
                    try:
                        await global_websocket.send_json({"status": "frame_ready", "image": encoded_string})
                    except Exception as e:
                        print(f"Error sending frame: {e}")


        await process.wait()
        job_statuses[job_id] = "Completed"

        # Remove uploaded files after processing (if applicable)
        if os.path.exists(image_path):
            os.remove(image_path)
        if os.path.exists(audio_path) and "audio" not in audio_path: 
            os.remove(audio_path)

    except Exception as e:
        job_statuses[job_id] = f"Failed: {str(e)}"

@app.get("/generated_frame")
async def get_generated_frame():
    return FileResponse("temp/generated_frame.jpg")


@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    global global_websocket
    await websocket.accept()
    global_websocket = websocket
    while True:
        data = await websocket.receive_json()
        if data['action'] == 'start_lipsync':
            job_id = str(uuid.uuid4())
            image_path = data['image_path']
            audio_path = data['audio_path']
            input_mode = data['input_mode']
            output_path = os.path.join(RESULT_DIR, f"{job_id}_output.mp4")
            
            asyncio.create_task(process_lipsync(image_path, audio_path, output_path, job_id, input_mode, websocket))
            await websocket.send_json({"job_id": job_id})


@app.post("/lipsync/")
async def create_lipsync(
    background_tasks: BackgroundTasks, 
    image: UploadFile = File(...), 
    audio: UploadFile = File(None),
    input_mode: str = Form(...)):

    job_id = str(uuid.uuid4())
    image_filename = f"{job_id}_image{os.path.splitext(image.filename)[1]}"
    image_path = os.path.join(UPLOAD_DIR, image_filename)
    with open(image_path, "wb") as buffer:
        shutil.copyfileobj(image.file, buffer)

    if input_mode == "video":
        if not audio:
            raise HTTPException(status_code=400, detail="Audio file is required for video mode")
        audio_filename = f"{job_id}_audio{os.path.splitext(audio.filename)[1]}"
        audio_path = os.path.join(UPLOAD_DIR, audio_filename)
        with open(audio_path, "wb") as buffer:
            shutil.copyfileobj(audio.file, buffer)
    elif input_mode == "micro":
        audio_path = f"audio_{job_id}.wav"
    else:
        raise HTTPException(status_code=400, detail="Invalid input mode")

    output_filename = f"{job_id}_output.mp4"
    output_path = os.path.join(RESULT_DIR, output_filename)

    job_statuses[job_id] = "Queued"
    background_tasks.add_task(process_lipsync, image_path, audio_path, output_path, job_id, input_mode, None)

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
    uvicorn.run(app, host="localhost", port=8000)