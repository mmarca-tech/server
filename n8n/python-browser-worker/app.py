import os
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from playwright.sync_api import sync_playwright

app = FastAPI(title="n8n Python Browser Worker")

BROWSERLESS_WS = os.environ.get("BROWSERLESS_WS")


class FetchRequest(BaseModel):
    url: str
    selector: Optional[str] = "h1"
    wait_until: str = "networkidle"
    timeout_ms: int = 30000


@app.get("/health")
def health():
    return {
        "ok": True,
        "browserlessConfigured": bool(BROWSERLESS_WS),
    }


@app.post("/fetch")
def fetch(req: FetchRequest):
    if not BROWSERLESS_WS:
        raise HTTPException(status_code=500, detail="BROWSERLESS_WS is not configured")

    try:
        with sync_playwright() as p:
            browser = p.chromium.connect_over_cdp(BROWSERLESS_WS)
            context = browser.contexts[0] if browser.contexts else browser.new_context()
            page = context.new_page()
            page.goto(req.url, wait_until=req.wait_until, timeout=req.timeout_ms)

            result = {
                "ok": True,
                "url": page.url,
                "title": page.title(),
            }

            if req.selector:
                locator = page.locator(req.selector).first
                try:
                    if locator.count() > 0:
                        result["selector"] = req.selector
                        result["selectorText"] = locator.inner_text(timeout=3000)
                except Exception:
                    result["selector"] = req.selector
                    result["selectorText"] = None

            browser.close()
            return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
