# 导入 FastAPI
from fastapi import FastAPI

# 创建应用
app = FastAPI()

# ------------------------------
# 你的接口 1：健康检查 /health
# ------------------------------
@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "message": "🟢 服务运行成功！",
        "source": "云托管在线"
    }

# ------------------------------
# 你的接口 2：测试接口 /test
# ------------------------------
@app.get("/test")
def test_api():
    return {
        "code": 200,
        "data": "这是测试接口"
    }

# ------------------------------
# 根路径 /
# ------------------------------
@app.get("/")
def root():
    return {
        "msg": "欢迎访问 Banana 后端 API",
        "docs": "/docs （自动生成接口文档）"
    }