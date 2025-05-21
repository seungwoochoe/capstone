from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import JSONResponse, FileResponse
from pathlib import Path
import uuid, shutil, datetime, asyncio

app = FastAPI()
ROOT = Path("uploads"); ROOT.mkdir(exist_ok=True)

@app.post("/scans")
async def create_scan(name: str = Form(...),
                      files: list[UploadFile] = File(...)):
    scan_id = str(uuid.uuid4())
    folder = ROOT / scan_id; folder.mkdir()
    for i, f in enumerate(files):
        with (folder / f"{i+1}.jpg").open("wb") as out:
            shutil.copyfileobj(f.file, out)
    # fire-and-forget “processing”
    asyncio.create_task(fake_processing(scan_id, name))
    return JSONResponse({"id": scan_id})

status: dict[str, dict] = {}

async def fake_processing(scan_id: str, name: str):
    await asyncio.sleep(1)                           # pretend work
    (ROOT / scan_id / "model.usdz").write_bytes(b" ")  # dummy file
    status[scan_id] = dict(
        id = scan_id,
        name = name,
        usdzURL = f"http://localhost:8000/uploads/{scan_id}/model.usdz",
        processedAt = datetime.datetime.utcnow().isoformat()+"Z",
        status = "finished"
    )

@app.get("/scans/{scan_id}")
async def detail(scan_id: str):
    return status.get(scan_id, {"status": "processing"})

@app.get("/uploads/{scan_id}/model.usdz")
async def usdz(scan_id: str):
    return FileResponse(ROOT / scan_id / "model.usdz")