import json

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.deps import require_admin
from app.database import get_db
from app.models.template import Template
from app.models.template_tag import TemplateTag
from app.models.template_tag_relation import TemplateTagRelation
from app.models.user import User
from app.schemas.template import (
    TemplateCreate,
    TemplateDetailOut,
    TemplateListItemOut,
    TemplateTagOut,
    TemplateUpdate,
)

router = APIRouter(prefix="/api/templates", tags=["创意模版"])


def _normalize_tag_names(tag_names: list[str]) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    for name in tag_names:
        normalized = (name or "").strip()
        if not normalized:
            continue
        lowered = normalized.lower()
        if lowered in seen:
            continue
        seen.add(lowered)
        result.append(normalized[:50])
    return result


def _serialize_template_list_item(template: Template) -> dict:
    return {
        "id": template.id,
        "prompt": template.prompt or "",
        "model": template.model or "",
        "result_image": template.result_image or "",
        "size": template.size,
        "resolution": template.resolution or "",
        "num_images": 1,
        "tags": [
            {"id": rel.tag.id, "name": rel.tag.name}
            for rel in sorted(template.tag_relations, key=lambda rel: rel.tag.name.lower())
            if rel.tag
        ],
        "created_at": template.created_at,
    }


def _serialize_template_detail(template: Template) -> dict:
    return {
        **_serialize_template_list_item(template),
        "reference_images": json.loads(template.reference_images or "[]"),
    }


def _sync_template_tags(db: Session, template: Template, tag_names: list[str]):
    normalized_names = _normalize_tag_names(tag_names)
    template.tag_relations.clear()
    db.flush()

    for tag_name in normalized_names:
        tag = db.query(TemplateTag).filter(TemplateTag.name == tag_name).first()
        if not tag:
            tag = TemplateTag(name=tag_name)
            db.add(tag)
            db.flush()
        template.tag_relations.append(TemplateTagRelation(tag_id=tag.id))


@router.get("", response_model=list[TemplateListItemOut])
def list_templates(
    tag_id: int | None = Query(None),
    db: Session = Depends(get_db),
):
    query = db.query(Template).order_by(Template.created_at.desc())
    if tag_id is not None:
        query = query.join(TemplateTagRelation).filter(TemplateTagRelation.tag_id == tag_id)
    templates = query.all()
    return [_serialize_template_list_item(template) for template in templates]


@router.get("/tags", response_model=list[TemplateTagOut])
def list_template_tags(db: Session = Depends(get_db)):
    return db.query(TemplateTag).order_by(TemplateTag.name.asc()).all()


@router.get("/admin/list", response_model=list[TemplateListItemOut])
def list_admin_templates(
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    templates = db.query(Template).order_by(Template.created_at.desc()).all()
    return [_serialize_template_list_item(template) for template in templates]


@router.get("/{template_id}", response_model=TemplateDetailOut)
def get_template_detail(template_id: int, db: Session = Depends(get_db)):
    template = db.query(Template).filter(Template.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="模版不存在")
    return _serialize_template_detail(template)


@router.post("", response_model=TemplateDetailOut)
def create_template(
    body: TemplateCreate,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    if not body.prompt.strip():
        raise HTTPException(status_code=400, detail="提示词不能为空")
    template = Template(
        prompt=body.prompt.strip(),
        model=body.model.strip() or "banana_pro",
        reference_images=json.dumps(body.reference_images or []),
        size=body.size,
        resolution=body.resolution,
        num_images=1,
        result_image=body.result_image,
    )
    db.add(template)
    db.flush()
    _sync_template_tags(db, template, body.tag_names)
    db.commit()
    db.refresh(template)
    return _serialize_template_detail(template)


@router.put("/{template_id}", response_model=TemplateDetailOut)
def update_template(
    template_id: int,
    body: TemplateUpdate,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    template = db.query(Template).filter(Template.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="模版不存在")
    if not body.prompt.strip():
        raise HTTPException(status_code=400, detail="提示词不能为空")

    template.prompt = body.prompt.strip()
    template.model = body.model.strip() or "banana_pro"
    template.reference_images = json.dumps(body.reference_images or [])
    template.size = body.size
    template.resolution = body.resolution
    template.num_images = 1
    template.result_image = body.result_image
    _sync_template_tags(db, template, body.tag_names)
    db.commit()
    db.refresh(template)
    return _serialize_template_detail(template)


@router.delete("/{template_id}")
def delete_template(
    template_id: int,
    _user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    template = db.query(Template).filter(Template.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="模版不存在")
    db.delete(template)
    db.commit()
    return {"message": "删除成功"}
