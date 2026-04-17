from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# 初始化 FastAPI
app = FastAPI(title="Banana Image API", version="1.0")

# 跨域配置（已适配你的前端）
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://banana-ai-4g7iqw0p1cab24e3-1257893314.tcloudbaseapp.com",
        "https://www.bananaimage.cn",
        "https://bananaimage.cn",
        "http://localhost:5173",
    ], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------- 接口 -------------------
# 根路径接口
@app.get("/")
def root():
    return {
        "message": "✅ Banana AI 后端部署成功",
        "status": "running",
        "author": "bananaimage.cn"
    }

# 健康检查接口（你要的 heath 接口）
@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "message": "🟢 服务正常运行",
        "time": "online"
    }

# ------------------- 云函数入口 -------------------
# CloudBase 必须保留，不能删
def main(event, context):
    return app(event, context)