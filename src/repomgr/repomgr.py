##

import logging
import subprocess
import typer
import os
import requests
import shutil

from typing import Iterator, Optional, List, Tuple
from pathlib import Path

from .repo import Repo
from .versions import is_version, get_latest_versions

app = typer.Typer()
logger = logging.getLogger()


def build_image(repo: str, image_name: str, version: str):
    subprocess.run([
        "docker", "buildx", "build",
        "--platform", "linux/amd64,linux/arm64",
        "--build-arg", f"VERSION={version}",
        "--sbom=true",
        "--provenance=true",
        "-t", f"{repo}/{image_name}:{version}",
        "--push",
        "."
    ], check=True)

def get_images() -> Iterator[str]:
    images_path = "images"
    for d in os.listdir(images_path):
        if os.path.isdir(os.path.join(images_path, d)):
            yield d

def get_versions(image: str) -> Tuple[Optional[Repo], List[str]]:
    repo_cfg_path = f"images/{image}/repo.toml"
    tags: List[str] = []
    repo: Optional[Repo] = None

    if os.path.exists(repo_cfg_path):
        repo = Repo(repo_cfg_path)
        if repo.github:
            repo_tags: List[str] = []
            for tag in get_tags(repo.github.owner, repo.github.repo):
                if is_version(tag):
                    repo_tags.append(tag)
            tags.extend(get_latest_versions(repo_tags))

    return repo, tags

def get_tags(owner: str, repo: str, token: Optional[str] = None) -> Iterator[str]:
    url = f"https://api.github.com/repos/{owner}/{repo}/tags"
    headers = {"Authorization": f"token {token}"} if token else {}

    response = requests.get(url, headers=headers)
    response.raise_for_status()

    for tag in response.json():
        yield tag["name"]

def create_repo(repo: Repo, image: str, version: str, latest: bool):
    repo_dir = f"images/{image}/{version}"
    docker_file = f"images/{image}/Dockerfile"
    version_docker_file = f"images/{image}/{version}/Dockerfile"

    if os.path.exists(docker_file):
        if os.path.exists(repo_dir):
            return
        Path(repo_dir).mkdir(parents=True, exist_ok=True)
        shutil.copy(docker_file, version_docker_file)
        current_dir = os.getcwd()
        os.chdir(repo_dir)
        print(f"Building {image}:{version}")
        build_image(repo.docker.repo, image, version)
        if latest:
            print(f"Building {image}:latest")
            build_image(repo.docker.repo, image, "latest")
        print("Done.")
        os.chdir(current_dir)

@app.command()
def build():
    print("Building...")

    for image in get_images():
        repo, versions = get_versions(image)
        if not versions or not repo or not repo.docker:
            continue
        for n, version in enumerate(versions):
            is_latest = (n == len(versions) - 1)
            create_repo(repo, image, version, is_latest)

if __name__ == "__main__":
    app()
