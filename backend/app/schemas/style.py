from pydantic import BaseModel


class StyleOut(BaseModel):
    id: int
    name: str
    cover_image: str
    description: str

    model_config = {"from_attributes": True}


class StylePromptOut(BaseModel):
    id: int
    style_id: int
    prompt: str
    negative_prompt: str
    sort_order: int

    model_config = {"from_attributes": True}


class StyleCreate(BaseModel):
    name: str
    cover_image: str = ""
    description: str = ""


class StylePromptCreate(BaseModel):
    prompt: str
    negative_prompt: str = ""
    sort_order: int = 0
