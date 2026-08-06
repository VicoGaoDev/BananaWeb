from pydantic import BaseModel, Field, field_validator


class PromptOptimizeRequest(BaseModel):
    prompt: str = Field(min_length=1, max_length=5000)
    reference_images: list[str] = Field(default_factory=list, max_length=6)

    @field_validator("prompt")
    @classmethod
    def validate_prompt(cls, value: str) -> str:
        cleaned = (value or "").strip()
        if not cleaned:
            raise ValueError("提示词不能为空")
        return cleaned

    @field_validator("reference_images")
    @classmethod
    def validate_reference_images(cls, value: list[str]) -> list[str]:
        normalized: list[str] = []
        for item in value or []:
            cleaned = str(item or "").strip()
            if cleaned:
                normalized.append(cleaned)
        return normalized


class PromptOptimizeResponse(BaseModel):
    prompt: str
