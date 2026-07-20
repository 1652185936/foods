from typing import Any

from fastapi import FastAPI
from fastapi.openapi.utils import get_openapi


def install_openapi_contract(application: FastAPI) -> None:
    def build_openapi() -> dict[str, Any]:
        if application.openapi_schema is not None:
            return application.openapi_schema
        schema = get_openapi(
            title=application.title,
            version=application.version,
            openapi_version=application.openapi_version,
            routes=application.routes,
        )
        for path_item in schema.get("paths", {}).values():
            for operation in path_item.values():
                if not isinstance(operation, dict):
                    continue
                for response in operation.get("responses", {}).values():
                    content = response.get("content", {})
                    problem_content = content.get("application/problem+json")
                    json_content = content.get("application/json")
                    if problem_content == {} and json_content is not None:
                        content["application/problem+json"] = json_content
                        del content["application/json"]
        application.openapi_schema = schema
        return schema

    application.__dict__["openapi"] = build_openapi
