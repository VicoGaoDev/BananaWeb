from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import get_current_user, require_admin
from app.models.user import User
from app.models.style import Style
from app.models.style_prompt import StylePrompt
from app.schemas.style import StyleOut, StyleCreate, StylePromptCreate, StylePromptOut

router = APIRouter(prefix="/api/styles", tags=["风格"])


@router.get("", response_model=list[StyleOut])
def list_styles(
    _user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(Style).order_by(Style.id).all()


@router.post("", response_model=StyleOut)
def create_style(
    body: StyleCreate,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    style = Style(name=body.name, cover_image=body.cover_image, description=body.description)
    db.add(style)
    db.commit()
    db.refresh(style)
    return style


@router.delete("/{style_id}")
def delete_style(
    style_id: int,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    style = db.query(Style).filter(Style.id == style_id).first()
    if not style:
        return {"message": "风格不存在"}
    db.query(StylePrompt).filter(StylePrompt.style_id == style_id).delete()
    db.delete(style)
    db.commit()
    return {"message": "删除成功"}


@router.get("/{style_id}/prompts", response_model=list[StylePromptOut])
def list_prompts(
    style_id: int,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return (
        db.query(StylePrompt)
        .filter(StylePrompt.style_id == style_id)
        .order_by(StylePrompt.sort_order)
        .all()
    )


@router.post("/{style_id}/prompts", response_model=StylePromptOut)
def add_prompt(
    style_id: int,
    body: StylePromptCreate,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    prompt = StylePrompt(
        style_id=style_id,
        prompt=body.prompt,
        negative_prompt=body.negative_prompt,
        sort_order=body.sort_order,
    )
    db.add(prompt)
    db.commit()
    db.refresh(prompt)
    return prompt


@router.delete("/{style_id}/prompts/{prompt_id}")
def delete_prompt(
    style_id: int,
    prompt_id: int,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    db.query(StylePrompt).filter(
        StylePrompt.id == prompt_id, StylePrompt.style_id == style_id
    ).delete()
    db.commit()
    return {"message": "删除成功"}
