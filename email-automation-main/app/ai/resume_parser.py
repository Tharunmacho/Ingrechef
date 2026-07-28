"""Turn extracted resume text into a structured CandidateProfile via Claude.

Uses Anthropic tool-use with a forced tool call, so the model must return JSON
matching our schema. We validate that JSON into a CandidateProfile pydantic model.
"""
from __future__ import annotations

from app.ai.schema import RESUME_TOOL_NAME, RESUME_TOOL_SCHEMA, SYSTEM_PROMPT
from app.config import settings
from app.core.exceptions import AIParseError
from app.core.models import CandidateProfile
from app.logging_config import get_logger

log = get_logger(__name__)

# Guard against runaway token usage / model context limits on huge resumes.
_MAX_INPUT_CHARS = 60_000


class ResumeParser:
    def __init__(self, api_key: str | None = None, model: str | None = None):
        self._api_key = api_key
        self._model = model
        self._client = None

    @property
    def client(self):
        if self._client is None:
            key = self._api_key or settings.anthropic_api_key
            if not key:
                raise AIParseError("ANTHROPIC_API_KEY is not configured.")
            import anthropic

            self._client = anthropic.Anthropic(api_key=key)
        return self._client

    def parse(self, resume_text: str, hint: str = "") -> CandidateProfile:
        return self._parse_via_anthropic(resume_text, hint)

    def _parse_via_anthropic(self, resume_text: str, hint: str = "") -> CandidateProfile:
        text = resume_text.strip()
        if not text:
            raise AIParseError("Empty resume text; nothing to parse.")
        if len(text) > _MAX_INPUT_CHARS:
            log.warning("Truncating resume text from %d to %d chars", len(text), _MAX_INPUT_CHARS)
            text = text[:_MAX_INPUT_CHARS]

        user_content = text
        if hint:
            user_content = f"[Context from email: {hint}]\n\n{text}"

        model_name = self._model or settings.anthropic_model
        try:
            response = self.client.messages.create(
                model=model_name,
                max_tokens=settings.anthropic_max_tokens,
                system=SYSTEM_PROMPT,
                tools=[RESUME_TOOL_SCHEMA],
                tool_choice={"type": "tool", "name": RESUME_TOOL_NAME},
                messages=[{"role": "user", "content": user_content}],
            )
        except Exception as exc:  # noqa: BLE001
            raise AIParseError(f"Anthropic API call failed: {exc}") from exc

        tool_input = self._extract_tool_input(response)
        try:
            return CandidateProfile.model_validate(tool_input)
        except Exception as exc:  # noqa: BLE001
            raise AIParseError(f"AI output did not match schema: {exc}") from exc

    @staticmethod
    def _extract_tool_input(response) -> dict:
        for block in response.content:
            if getattr(block, "type", None) == "tool_use" and block.name == RESUME_TOOL_NAME:
                return block.input
        raise AIParseError("Model did not return the expected tool call.")

    def parse_file(self, file_data: bytes, filename: str) -> tuple[CandidateProfile, ExtractedDocument]:
        import tempfile
        from pathlib import Path
        from recursai.veris_ocr import VerisOCR
        from app.core.models import ExtractedDocument
        
        suffix = Path(filename).suffix or ".pdf"
        with tempfile.TemporaryDirectory() as tmp:
            temp_file = Path(tmp) / f"temp_ocr{suffix}"
            temp_file.write_bytes(file_data)
            
            log.info("Sending resume to Veris OCR Resume API: %s", filename)
            try:
                with VerisOCR(api_key=settings.veris_ocr_api_key, base_url=settings.veris_ocr_base_url) as client:
                    res = client.resume.extract(str(temp_file))
                    
                pages = getattr(res, "pages", [])
                if isinstance(pages, list):
                    extracted_text = "\n".join(
                        page.get("text", "") if isinstance(page, dict) else getattr(page, "text", "")
                        for page in pages
                    )
                else:
                    extracted_text = ""
                    
                extracted = ExtractedDocument(
                    text=extracted_text,
                    method="veris_resume_api",
                    page_count=len(pages),
                    ocr_used=True,
                    char_count=len(extracted_text)
                )
                
                profile = map_veris_to_profile(res)
                return profile, extracted
                
            except Exception as exc:
                if not settings.anthropic_api_key:
                    log.error("Veris Resume API failed and Anthropic fallback is not configured: %s", exc)
                    raise AIParseError(f"Veris OCR extraction failed: {exc}") from exc
                    
                log.warning("Veris Resume API failed (%s). Falling back to local OCR + Anthropic parsing.", exc)
                from app.extraction.text_extractor import extract_text
                extracted = extract_text(file_data, filename)
                profile = self.parse(extracted.text)
                return profile, extracted

    def generate_reply(self, profile: CandidateProfile, email_subject: str = "") -> str:
        name = (profile.full_name or "Applicant").strip()
        skills_list = profile.skills or profile.technical_skills or []
        
        key = self._api_key or settings.anthropic_api_key
        if key and not key.startswith("sk-ant-xxx"):
            try:
                prompt = (
                    f"Generate a professional, personalized email reply to candidate {name} who submitted their resume.\n"
                    f"Candidate Name: {name}\n"
                    f"Extracted Skills: {', '.join(skills_list[:6]) if skills_list else 'N/A'}\n"
                    f"Subject: {email_subject}\n\n"
                    f"Formatting template reference:\n"
                    f"Dear {name},\n\n"
                    f"Thank you for reaching out and sharing your resume with our recruitment team.\n\n"
                    f"We noted your technical background in [list key extracted skills]. Our hiring team is currently evaluating your profile to identify suitable opportunities.\n\n"
                    f"If your background matches an active role, we will contact you directly regarding the next steps.\n\n"
                    f"Best regards,\n"
                    f"Recruitment Team"
                )
                response = self.client.messages.create(
                    model=settings.anthropic_model,
                    max_tokens=300,
                    messages=[{"role": "user", "content": prompt}]
                )
                output = response.content[0].text.strip()
                if output:
                    return output
            except Exception as exc:
                log.warning("LLM reply generation failed (%s); falling back to smart context engine.", exc)

        return generate_personalized_reply(profile)


def map_veris_to_profile(res) -> CandidateProfile:
    from app.core.models import CandidateProfile, WorkExperience, Education, Project
    
    # Extract keys safely
    data = res if isinstance(res, dict) else getattr(res, "__dict__", {})
    
    contact = data.get("contact") or {}
    emails = contact.get("emails") or []
    phones = contact.get("phones") or []
    email = emails[0] if emails else None
    phone = phones[0] if phones else None
    linkedin_url = contact.get("linkedin")
    github_url = contact.get("github")
    location = contact.get("address")
    
    projects_list = []
    for p in (data.get("projects") or []):
        projects_list.append(Project(
            name=p.get("name"),
            description=p.get("description"),
            technologies=p.get("technologies") or [],
            url=p.get("url")
        ))
        
    education_list = []
    for e in (data.get("education") or []):
        education_list.append(Education(
            institution=e.get("institution"),
            degree=e.get("degree"),
            field_of_study=e.get("field_of_study"),
            start_date=e.get("start_date"),
            end_date=e.get("end_date"),
            grade=e.get("grade")
        ))
        
    work_list = []
    for w in (data.get("experience") or []):
        work_list.append(WorkExperience(
            company=w.get("company"),
            designation=w.get("designation"),
            start_date=w.get("start_date"),
            end_date=w.get("end_date"),
            location=w.get("location"),
            description=w.get("description")
        ))
        
    skills = data.get("skills") or []
    skills_list = []
    for s in skills:
        if isinstance(s, str):
            skills_list.append(s)
        elif isinstance(s, dict) and "name" in s:
            skills_list.append(s["name"])
        else:
            skills_list.append(str(s))

    exp_years = data.get("total_experience_years")
    if exp_years is not None:
        try:
            exp_years = float(exp_years)
        except (ValueError, TypeError):
            exp_years = None
            
    additional_info = {}
    for k, v in data.items():
        if k in ("name", "contact", "personal_info", "passport_details", "designation", 
                 "highest_qualification", "experience", "skills", "projects", "education", "pages"):
            additional_info[k] = v

    name_str = (data.get("name") or "").strip()
    has_contact = bool(email or phone or linkedin_url)
    has_substance = bool(skills_list or work_list or education_list or projects_list)

    # Discard non-resume documents (random images, payment receipts, generic charts)
    is_resume_doc = bool(name_str) and (has_contact or has_substance) and name_str.lower() not in (
        "none", "null", "unknown", "untitled", "t-test", "ggraph", "group", "oo'ol"
    )

    return CandidateProfile(
        is_resume=is_resume_doc,
        confidence=1.0 if is_resume_doc else 0.0,
        full_name=data.get("name") if is_resume_doc else None,
        email=email,
        phone=phone,
        location=location,
        skills=skills_list if is_resume_doc else [],
        technical_skills=skills_list if is_resume_doc else [],
        work_experience=work_list if is_resume_doc else [],
        education=education_list if is_resume_doc else [],
        projects=projects_list if is_resume_doc else [],
        linkedin_url=linkedin_url,
        github_url=github_url,
        total_experience_years=exp_years,
        current_designation=data.get("designation"),
        additional_info=additional_info if is_resume_doc else {}
    )


def generate_personalized_reply(profile: CandidateProfile | None) -> str:
    if not profile:
        return settings.gmail_auto_reply_template

    name = (profile.full_name or "Applicant").strip()
    skills_list = profile.skills or profile.technical_skills or []

    seen = set()
    clean_skills = []
    for s in skills_list:
        if s and isinstance(s, str) and len(s) < 30 and s.lower() not in seen:
            seen.add(s.lower())
            clean_skills.append(s)
        if len(clean_skills) >= 5:
            break

    if clean_skills:
        if len(clean_skills) > 1:
            skills_str = ", ".join(clean_skills[:-1]) + f" and {clean_skills[-1]}"
        else:
            skills_str = clean_skills[0]
        skills_paragraph = f"We noted your technical background in {skills_str}."
    elif profile.current_designation:
        skills_paragraph = f"We noted your background as {profile.current_designation}."
    else:
        skills_paragraph = "We have received your application details."

    return (
        f"Dear {name},\n\n"
        f"Thank you for reaching out and sharing your resume with our recruitment team.\n\n"
        f"{skills_paragraph} Our hiring team is currently evaluating your profile to identify suitable opportunities.\n\n"
        f"If your background matches an active role, we will contact you directly regarding the next steps.\n\n"
        f"Best regards,\n"
        f"Recruitment Team"
    )
